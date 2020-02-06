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

def collect_stats_from_users(report, users_objects, &block)
  users_objects.each do |user|
    user_key = "#{user.attributes['first_name']}" + ' ' + "#{user.attributes['last_name']}"
    report['usersStats'][user_key] ||= {}
    hash = block.call(user)
    report['usersStats'][user_key] = report['usersStats'][user_key].merge(hash)
  end
end

def work(file)
  file_lines = File.read(file).split("\n")

  users = []
  sessions = []

  file_lines.each do |line|
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

  report['allBrowsers'] =
    sessions
      .map { |s| s['browser'] }
      .map { |b| b.upcase }
      .sort
      .uniq
      .join(',')

  # Статистика по пользователям
  users_objects = []

  sessions_grouped_by_user = sessions.group_by{|e| e['user_id']}
  users.each do |user|
    attributes = user
    user_sessions = sessions_grouped_by_user[user['id']]
    user_object = User.new(attributes: attributes, sessions: user_sessions)
    users_objects = users_objects + [user_object]
  end

  report['usersStats'] = {}

  # Собираем количество сессий по пользователям
  collect_stats_from_users(report, users_objects) do |user|
    times = user.sessions.map{|s| s['time'].to_i}
    browsers = user.sessions.map {|s| s['browser'].upcase}
    {
      'sessionsCount' => user.sessions.count,
      # Собираем количество времени по пользователям
        'totalTime' => times.sum.to_s + ' min.',
      # Выбираем самую длинную сессию пользователя
        'longestSession' => times.max.to_s + ' min.',
      # Браузеры пользователя через запятую
        'browsers' => browsers.sort.join(', '),
      # Хоть раз использовал IE?
        'usedIE' => browsers.any? { |b| b.start_with?('INTERNET EXPLORER') },
      # Всегда использовал только Chrome?
        'alwaysUsedChrome' => browsers.all? { |b| b.start_with?('CHROME') },
      # Даты сессий через запятую в обратном порядке в формате iso8601
        'dates' => user.sessions.map{|s| s['date'] }.sort{ |a, b| b <=> a }
    }
  end

  File.write('result.json', "#{report.to_json}\n")
end
