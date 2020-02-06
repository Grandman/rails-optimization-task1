# Deoptimized version of homework task

require 'json'
require 'pry'
require 'date'
require 'ruby-prof'

class User
  attr_reader :attributes, :sessions

  def initialize(attributes:, sessions:)
    @attributes = attributes
    @sessions = sessions
  end
end

def read_lines(file)
  File.read(file).split("\n")
end

def parse_user(fields)
  parsed_result = {
    'id' => fields[1],
    'first_name' => fields[2],
    'last_name' => fields[3],
    'age' => fields[4],
  }
end

def parse_session(fields)
  parsed_result = {
    'user_id' => fields[1],
    'session_id' => fields[2],
    'browser' => fields[3],
    'time' => fields[4],
    'date' => fields[5],
  }
end

def collect_stats_from_users(report, users_objects)
  users_objects.each do |user|
    user_key = "#{user.attributes['first_name']} #{user.attributes['last_name']}"
    hash = collect_stats_from_user(user)

    report['usersStats'][user_key] = hash
  end
end

def collect_stats_from_user(user)
  times = user.sessions.map{|s| s['time'].to_i}
  browsers = user.sessions.map {|s| s['browser'].upcase}.sort

  used_ie = false
  allways_used_chrome = true

  browsers.each do |browser|
    used_ie = true if browser.match?(/INTERNET EXPLORER/)
    allways_used_chrome = false unless browser.match?(/CHROME/)

    break if used_ie && !allways_used_chrome
  end

  {
    'sessionsCount' => user.sessions.count,
    # Собираем количество времени по пользователям
    'totalTime' => times.sum.to_s + ' min.',
    # Выбираем самую длинную сессию пользователя
    'longestSession' => times.max.to_s + ' min.',
    # Браузеры пользователя через запятую
    'browsers' => browsers.join(', '),
    # Хоть раз использовал IE?
    'usedIE' => used_ie,
    # Всегда использовал только Chrome?
    'alwaysUsedChrome' => allways_used_chrome,
    # Даты сессий через запятую в обратном порядке в формате iso8601
    'dates' => user.sessions.map{|s| s['date'] }.sort{ |a, b| b <=> a }
  }
end

def parse_lines(lines)
  users = []
  sessions = []
  lines.each do |line|
    cols = line.split(',')
    if cols[0] == 'user'
      parsed_user = parse_user(cols)
      users << parsed_user
    end
    if cols[0] == 'session'
      parsed_session = parse_session(cols)
      sessions << parsed_session
    end
  end
  [users, sessions]
end

def collect_users_objects(users, sessions)
  users_objects = []
  sessions_grouped_by_user = sessions.group_by{|e| e['user_id']}
  users.each do |user|
    attributes = user
    user_sessions = sessions_grouped_by_user[user['id']]
    user_object = User.new(attributes: attributes, sessions: user_sessions)
    users_objects << user_object
  end
  users_objects
end

def calc_all_browsers(sessions)
  sessions
    .map { |s| s['browser'] }
    .map { |b| b.upcase }
    .sort
    .uniq
    .join(',')
end

def write_file(filename, report)
  File.write('result.json', "#{report.to_json}\n")
end

def work(file)
  file_lines = read_lines(file)

  users, sessions = parse_lines(file_lines)


  # Отчёт в json
  #   - Сколько всего юзеров +
  #   - Сколько всего уникальных браузеров +
  #   - Сколько всего сессий +
  #   - Перечислить уникальные браузеры в алфавитном порядке через запятую и капсом +
  #
  #   - По каждому пользователю
  #     - сколько всего сессий +
  #     - сколько всего времени +
  #     - самая длинная сессия +
  #     - браузеры через запятую +
  #     - Хоть раз использовал IE? +
  #     - Всегда использовал только Хром? +
  #     - даты сессий в порядке убывания через запятую +

  report = {}

  report[:totalUsers] = users.count

  # Подсчёт количества уникальных браузеров
  uniqueBrowsers = sessions.map { |session| session['browser'] }.uniq

  report['uniqueBrowsersCount'] = uniqueBrowsers.count

  report['totalSessions'] = sessions.count

  report['allBrowsers'] = calc_all_browsers(sessions)
    # Статистика по пользователям

  users_objects = collect_users_objects(users, sessions)
  report['usersStats'] = {}

  # Собираем количество сессий по пользователям
  collect_stats_from_users(report, users_objects)

  write_file('result.json', report)
end
