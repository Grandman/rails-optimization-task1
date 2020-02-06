# Case-study оптимизации

## Актуальная проблема
В нашем проекте возникла серьёзная проблема.

Необходимо было обработать файл с данными, чуть больше ста мегабайт.

У нас уже была программа на `ruby`, которая умела делать нужную обработку.

Она успешно работала на файлах размером пару мегабайт, но для большого файла она работала слишком долго, и не было понятно, закончит ли она вообще работу за какое-то разумное время.

Я решил исправить эту проблему, оптимизировав эту программу.

## Формирование метрики
Для того, чтобы понимать, дают ли мои изменения положительный эффект на быстродействие программы я придумал использовать такую метрику: время выполнения программы на файле с 10000 строк

## Гарантия корректности работы оптимизированной программы
Программа поставлялась с тестом. Выполнение этого теста в фидбек-лупе позволяет не допустить изменения логики программы при оптимизации.

## Feedback-Loop
Для того, чтобы иметь возможность быстро проверять гипотезы я выстроил эффективный `feedback-loop`, который позволил мне получать обратную связь по эффективности сделанных изменений за *время, которое у вас получилось*

Вот как я построил `feedback_loop`:
  - Для начала я сравнил время выполнения программы на файлах с 1000, 2000, 3000, 4000, 10000 строк. Получилось что зависимость времени выполнения не линейная(50ms, 150ms, 300ms, 560ms, 4000ms)
  - В качестве первоначальной метрики взял выполнение файла с 10000 файлов за 100ms и написал на это тест

## Вникаем в детали системы, чтобы найти главные точки роста
Для того, чтобы найти "точки роста" для оптимизации я воспользовался:
 - ruby-prof

Вот какие проблемы удалось найти и решить

### Ваша находка №1
- ruby-prof в режиме flat показал наибольшее время в методе select
```
    %self      total      self      wait     child     calls  name                           location
    87.02      5.387     5.387     0.000     0.000     1536   Array#select
    7.62      6.147     0.472     0.000     5.675    10010  *Array#each
    0.95      0.059     0.059     0.000     0.000    20001   String#split
```
- для оптимизации нужно сократить количество вызовов метода select
    ```
    user_sessions = sessions.select { |session| session['user_id'] == user['id'] }
    ```
    для этого сгруппируем по пользователям и будем выбирать по ключу
    ```
    user_sessions = sessions.select { |session| session['user_id'] == user['id'] }
    ```
- метрика до:
    ```
    1) task-1 work for small file perform under 100 ms
     Failure/Error: expect {work }.to perform_under(100).ms.warmup(2).sample(5)
       expected block to perform under 100 ms, but performed above 4.13 sec (± 68.7 ms)
     # ./spec/task_1_spec.rb:7:in `block (3 levels) in <top (required)>'
    ```
    метрика после:
    ```
    1) task-1 work for small file perform under 100 ms
     Failure/Error: expect {work('data1.txt') }.to perform_under(100).ms.warmup(2).sample(5)
       expected block to perform under 100 ms, but performed above 537 ms (± 22.6 ms)
     # ./spec/task_1_spec.rb:7:in `block (3 levels) in <top (required)>'
     ```
- результат после профайлинга:
```

    %self      total      self      wait     child     calls  name                           location
 58.48      0.772     0.477     0.000     0.295    10011  *Array#each
  7.90      0.065     0.065     0.000     0.000    20001   String#split
  6.54      0.148     0.053     0.000     0.095    16898   Array#map
  4.85      0.078     0.040     0.000     0.039     8464   <Class::Date>#parse
  2.53      0.046     0.021     0.000     0.025     8464   Object#parse_session           /Users/grandman/my_projects/ruby_optimization/rails-optimization-task1/task-1.rb:27
```

### Ваша находка №2
- Взял stackprof, запустил в режиме `wall`. Получился такой отчет:
    ```
    ==================================
      Mode: wall(1000)
      Samples: 446 (0.45% miss rate)
      GC: 2 (0.45%)
    ==================================
     TOTAL    (pct)     SAMPLES    (pct)     FRAME
       444  (99.6%)         383  (85.9%)     Object#work
       132  (29.6%)          30   (6.7%)     Object#collect_stats_from_users
        22   (4.9%)          22   (4.9%)     Object#parse_session
         6   (1.3%)           6   (1.3%)     Object#parse_user
         3   (0.7%)           3   (0.7%)     User#initialize
         2   (0.4%)           2   (0.4%)     (sweeping)
       444  (99.6%)           0   (0.0%)     <main>
       444  (99.6%)           0   (0.0%)     <main>
       444  (99.6%)           0   (0.0%)     block in <main>
         2   (0.4%)           0   (0.0%)     (garbage collection)
    ```
- Смотрим подробнее метод `Object#work` и видим:
    ```
    207   (46.4%)                   |    52  |   file_lines.each do |line|
                                    |    53  |     cols = line.split(',')
     14    (3.1%) /     8   (1.8%)  |    54  |     users = users + [parse_user(line)] if cols[0] == 'user'
    193   (43.3%) /   171  (38.3%)  |    55  |     sessions = sessions + [parse_session(line)] if cols[0] == 'session'
                                    |    56  |   end
    ```
- переписываем 55 строку и получаем следующее:
    ```
    ==================================
      Mode: wall(1000)
      Samples: 286 (1.04% miss rate)
      GC: 2 (0.70%)
    ==================================
     TOTAL    (pct)     SAMPLES    (pct)     FRAME
       284  (99.3%)         217  (75.9%)     Object#work
       134  (46.9%)          40  (14.0%)     Object#collect_stats_from_users
        14   (4.9%)          14   (4.9%)     Object#parse_session
         7   (2.4%)           7   (2.4%)     Object#parse_user
         6   (2.1%)           6   (2.1%)     User#initialize
         2   (0.7%)           2   (0.7%)     (sweeping)
       284  (99.3%)           0   (0.0%)     <main>
       284  (99.3%)           0   (0.0%)     <main>
       284  (99.3%)           0   (0.0%)     block in <main>
         2   (0.7%)           0   (0.0%)     (garbage collection)
    ```

    ```
    Object#work (/Users/grandman/my_projects/ruby_optimization/rails-optimization-task1/task-1.rb:46)
    samples:   217 self (75.9%)  /    284 total (99.3%)
    callers:
       295  (  103.9%)  Object#work
       284  (  100.0%)  block in <main>
        94  (   33.1%)  Object#collect_stats_from_users
    callees (67 total):
       295  (  440.3%)  Object#work
       134  (  200.0%)  Object#collect_stats_from_users
        14  (   20.9%)  Object#parse_session
         7  (   10.4%)  Object#parse_user
         6  (    9.0%)  User#initialize
    code:
                                    |    46  | def work(file)
                                    |    47  |   file_lines = File.read(file).split("\n")
                                    |    48  |
                                    |    49  |   users = []
                                    |    50  |   sessions = []
                                    |    51  |
     40   (14.0%)                   |    52  |   file_lines.each do |line|
                                    |    53  |     cols = line.split(',')
     20    (7.0%) /    13   (4.5%)  |    54  |     users = users + [parse_user(line)] if cols[0] == 'user'
     20    (7.0%) /     6   (2.1%)  |    55  |     sessions << parse_session(line) if cols[0] == 'session'
                                    |    56  |   end
                                    |    57  |
                                    |    58  |   # Отчёт в json
                                    |    59  |   #   - Сколько всего юзеров +
                                    |    60  |   #   - Сколько всего уникальных браузеров +
                                    |    61  |   #   - Сколько всего сессий +
                                    |    62  |   #   - Перечислить уникальные браузеры в алфавитном порядке через запятую и капсом +
                                    |    63  |   #
                                    |    64  |   #   - По каждому пользователю
                                    |    65  |   #     - сколько всего сессий +
                                    |    66  |   #     - сколько всего времени +
                                    |    67  |   #     - самая длинная сессия +
                                    |    68  |   #     - браузеры через запятую +
                                    |    69  |   #     - Хоть раз использовал IE? +
                                    |    70  |   #     - Всегда использовал только Хром? +
                                    |    71  |   #     - даты сессий в порядке убывания через запятую +
                                    |    72  |
                                    |    73  |   report = {}
                                    |    74  |
                                    |    75  |   report[:totalUsers] = users.count
                                    |    76  |
                                    |    77  |   # Подсчёт количества уникальных браузеров
                                    |    78  |   uniqueBrowsers = []
     78   (27.3%)                   |    79  |   sessions.each do |session|
                                    |    80  |     browser = session['browser']
    154   (53.8%) /    78  (27.3%)  |    81  |     uniqueBrowsers += [browser] if uniqueBrowsers.all? { |b| b != browser }
                                    |    82  |   end
                                    |    83  |
                                    |    84  |   report['uniqueBrowsersCount'] = uniqueBrowsers.count
                                    |    85  |
                                    |    86  |   report['totalSessions'] = sessions.count
                                    |    87  |
                                    |    88  |   report['allBrowsers'] =
                                    |    89  |     sessions
      4    (1.4%) /     2   (0.7%)  |    90  |       .map { |s| s['browser'] }
      4    (1.4%) /     2   (0.7%)  |    91  |       .map { |b| b.upcase }
                                    |    92  |       .sort
                                    |    93  |       .uniq
                                    |    94  |       .join(',')
                                    |    95  |
                                    |    96  |   # Статистика по пользователям
                                    |    97  |   users_objects = []
                                    |    98  |
     12    (4.2%) /     6   (2.1%)  |    99  |   sessions_grouped_by_user = sessions.group_by{|e| e['user_id']}
      8    (2.8%)                   |   100  |   users.each do |user|
                                    |   101  |     attributes = user
                                    |   102  |     user_sessions = sessions_grouped_by_user[user['id']]
      6    (2.1%)                   |   103  |     user_object = User.new(attributes: attributes, sessions: user_sessions)
      2    (0.7%) /     2   (0.7%)  |   104  |     users_objects = users_objects + [user_object]
                                    |   105  |   end
                                    |   106  |
                                    |   107  |   report['usersStats'] = {}
                                    |   108  |
                                    |   109  |   # Собираем количество сессий по пользователям
      4    (1.4%)                   |   110  |   collect_stats_from_users(report, users_objects) do |user|
      1    (0.3%) /     1   (0.3%)  |   111  |     { 'sessionsCount' => user.sessions.count }
                                    |   112  |   end
                                    |   113  |
                                    |   114  |   # Собираем количество времени по пользователям
     11    (3.8%)                   |   115  |   collect_stats_from_users(report, users_objects) do |user|
     10    (3.5%) /     5   (1.7%)  |   116  |     { 'totalTime' => user.sessions.map {|s| s['time']}.map {|t| t.to_i}.sum.to_s + ' min.' }
                                    |   117  |   end
                                    |   118  |
                                    |   119  |   # Выбираем самую длинную сессию пользователя
     10    (3.5%)                   |   120  |   collect_stats_from_users(report, users_objects) do |user|
     17    (5.9%) /    10   (3.5%)  |   121  |     { 'longestSession' => user.sessions.map {|s| s['time']}.map {|t| t.to_i}.max.to_s + ' min.' }
                                    |   122  |   end
                                    |   123  |
                                    |   124  |   # Браузеры пользователя через запятую
     14    (4.9%)                   |   125  |   collect_stats_from_users(report, users_objects) do |user|
      7    (2.4%) /     6   (2.1%)  |   126  |     { 'browsers' => user.sessions.map {|s| s['browser']}.map {|b| b.upcase}.sort.join(', ') }
                                    |   127  |   end
                                    |   128  |
                                    |   129  |   # Хоть раз использовал IE?
     13    (4.5%)                   |   130  |   collect_stats_from_users(report, users_objects) do |user|
     12    (4.2%) /     6   (2.1%)  |   131  |     { 'usedIE' => user.sessions.map{|s| s['browser']}.any? { |b| b.upcase =~ /INTERNET EXPLORER/ } }
                                    |   132  |   end
                                    |   133  |
                                    |   134  |   # Всегда использовал только Chrome?
     11    (3.8%)                   |   135  |   collect_stats_from_users(report, users_objects) do |user|
      9    (3.1%) /     5   (1.7%)  |   136  |     { 'alwaysUsedChrome' => user.sessions.map{|s| s['browser']}.all? { |b| b.upcase =~ /CHROME/ } }
                                    |   137  |   end
                                    |   138  |
                                    |   139  |   # Даты сессий через запятую в обратном порядке в формате iso8601
     71   (24.8%)                   |   140  |   collect_stats_from_users(report, users_objects) do |user|
    121   (42.3%) /    61  (21.3%)  |   141  |     { 'dates' => user.sessions.map{|s| s['date']}.map {|d| Date.parse(d)}.sort.reverse.map { |d| d.iso8601 } }
                                    |   142  |   end
                                    |   143  |
     14    (4.9%) /    14   (4.9%)  |   144  |   File.write('result.json', "#{report.to_json}\n")
                                    |   145  | end
    ```
- Смотрим на метрику:
    ```
    1) task-1 work for small file perform under 100 ms
     Failure/Error: expect {work('data1.txt') }.to perform_under(100).ms.warmup(2).sample(5)
       expected block to perform under 100 ms, but performed above 289 ms (± 6.16 ms)
     # ./spec/task_1_spec.rb:7:in `block (3 levels) in <top (required)>'
    ```
- По этому отчету профилировщику еще можно заметить проблемы в строке `uniqueBrowsers += [browser] if uniqueBrowsers.all? { |b| b != browser }`. Проблема в том что на каждое добавление элемента массива вызывается прогон по всему массиву. Рефакторим ее и получаем:
    ```
    1) task-1 work for small file perform under 100 ms
     Failure/Error: expect {work('data1.txt') }.to perform_under(100).ms.warmup(2).sample(5)
       expected block to perform under 100 ms, but performed above 228 ms (± 13.1 ms)
     # ./spec/task_1_spec.rb:7:in `block (3 levels) in <top (required)>'
    ```
- Опять запускаем профилировщик и видим проблему в строке:
  ```
    115   (56.1%) /    59  (28.8%)  |   137  |     { 'dates' => user.sessions.map{|s| s['date']}.map {|d| Date.parse(d)}.sort.reverse.map { |d| d.iso8601 } }
  ```
- рефакторим и получаем:
    ```
    45   (27.1%) /    23  (13.9%)  |   137  |     { 'dates' => user.sessions.map{|s| Date.strptime(s['date'], '%Y-%m-%d' ).iso8601}.sort{ |a, b| b <=> a } }
    ```

    ```
    1) task-1 work for small file perform under 100 ms
     Failure/Error: expect {work('data1.txt') }.to perform_under(100).ms.warmup(2).sample(5)
       expected block to perform under 100 ms, but performed above 207 ms (± 5.11 ms)
     # ./spec/task_1_spec.rb:7:in `block (3 levels) in <top (required)>'
     ```

- Смотрим на общий отчет и видим, что много вызовов `collect_stats_from_users`
```
    callees (60 total):
     103  (  171.7%)  Object#work
      93  (  155.0%)  Object#collect_stats_from_users
      13  (   21.7%)  Object#parse_session
       7  (   11.7%)  Object#parse_user
       2  (    3.3%)  User#initialize
```

Да и по времени занимает уже второе место:
```
  ==================================
    Mode: wall(1000)
    Samples: 166 (1.78% miss rate)
    GC: 2 (1.20%)
  ==================================
     TOTAL    (pct)     SAMPLES    (pct)     FRAME
       164  (98.8%)         104  (62.7%)     Object#work
        93  (56.0%)          38  (22.9%)     Object#collect_stats_from_users
        13   (7.8%)          13   (7.8%)     Object#parse_session
         7   (4.2%)           7   (4.2%)     Object#parse_user
         2   (1.2%)           2   (1.2%)     (sweeping)
         2   (1.2%)           2   (1.2%)     User#initialize
       164  (98.8%)           0   (0.0%)     <main>
       164  (98.8%)           0   (0.0%)     block in <main>
         2   (1.2%)           0   (0.0%)     (garbage collection)
       164  (98.8%)           0   (0.0%)     <main>
```

Сокращаем количество вызовов (объединяем все в один) и смотрим результат:

```
collect_stats_from_users(report, users_objects) do |user|
  {
    'sessionsCount' => user.sessions.count,
    # Собираем количество времени по пользователям
    'totalTime' => user.sessions.map {|s| s['time']}.map {|t| t.to_i}.sum.to_s + ' min.',
    # Выбираем самую длинную сессию пользователя
    'longestSession' => user.sessions.map {|s| s['time']}.map {|t| t.to_i}.max.to_s + ' min.',
    # Браузеры пользователя через запятую
    'browsers' => user.sessions.map {|s| s['browser']}.map {|b| b.upcase}.sort.join(', '),
    # Хоть раз использовал IE?
    'usedIE' => user.sessions.map{|s| s['browser']}.any? { |b| b.upcase =~ /INTERNET EXPLORER/ },
    # Всегда использовал только Chrome?
    'alwaysUsedChrome' => user.sessions.map{|s| s['browser']}.all? { |b| b.upcase =~ /CHROME/ },
    # Даты сессий через запятую в обратном порядке в формате iso8601
    'dates' => user.sessions.map{|s| Date.strptime(s['date'], '%Y-%m-%d' ).iso8601}.sort{ |a, b| b <=> a }
  }
end
```
```
1) task-1 work for small file perform under 100 ms
     Failure/Error: expect {work('data1.txt') }.to perform_under(100).ms.warmup(2).sample(5)
       expected block to perform under 100 ms, but performed above 139 ms (± 7.84 ms)
     # ./spec/task_1_spec.rb:7:in `block (3 levels) in <top (required)>'
```

- Опять смотрим отчет:
```
TOTAL    (pct)     SAMPLES    (pct)     FRAME
       113  (98.3%)          81  (70.4%)     Object#work
        20  (17.4%)          20  (17.4%)     Object#parse_session
         6   (5.2%)           6   (5.2%)     Object#parse_user
        49  (42.6%)           3   (2.6%)     Object#collect_stats_from_users
         3   (2.6%)           3   (2.6%)     User#initialize
         2   (1.7%)           2   (1.7%)     (sweeping)
       113  (98.3%)           0   (0.0%)     <main>
       113  (98.3%)           0   (0.0%)     <main>
       113  (98.3%)           0   (0.0%)     block in <main>
         2   (1.7%)           0   (0.0%)     (garbage collection)
```
```
                                  |    38  | def collect_stats_from_users(report, users_objects, &block)
   49   (42.6%)                   |    39  |   users_objects.each do |user|
                                  |    40  |     user_key = "#{user.attributes['first_name']}" + ' ' + "#{user.attributes['last_name']}"
                                  |    41  |     report['usersStats'][user_key] ||= {}
   49   (42.6%) /     3   (2.6%)  |    42  |     report['usersStats'][user_key] = report['usersStats'][user_key].merge(block.call(user))
                                  |    43  |   end
```
Разбиваем строчку на отдельные вызовы  и видим:
```
                                  |    38  | def collect_stats_from_users(report, users_objects, &block)
   50   (38.8%)                   |    39  |   users_objects.each do |user|
                                  |    40  |     user_key = "#{user.attributes['first_name']}" + ' ' + "#{user.attributes['last_name']}"
                                  |    41  |     report['usersStats'][user_key] ||= {}
   48   (37.2%)                   |    42  |     hash = block.call(user)
    2    (1.6%) /     2   (1.6%)  |    43  |     report['usersStats'][user_key] = report['usersStats'][user_key].merge(hash)
                                  |    44  |   end
```

Идем обратно к методу work:
```
   50   (38.8%)                   |   107  |   collect_stats_from_users(report, users_objects) do |user|
                                  |   108  |     {
                                  |   109  |       'sessionsCount' => user.sessions.count,
                                  |   110  |       # Собираем количество времени по пользователям
   14   (10.9%) /     7   (5.4%)  |   111  |         'totalTime' => user.sessions.map {|s| s['time']}.map {|t| t.to_i}.sum.to_s + ' min.',
                                  |   112  |       # Выбираем самую длинную сессию пользователя
   10    (7.8%) /     5   (3.9%)  |   113  |         'longestSession' => user.sessions.map {|s| s['time']}.map {|t| t.to_i}.max.to_s + ' min.',
                                  |   114  |       # Браузеры пользователя через запятую
   10    (7.8%) /     5   (3.9%)  |   115  |         'browsers' => user.sessions.map {|s| s['browser']}.map {|b| b.upcase}.sort.join(', '),
                                  |   116  |       # Хоть раз использовал IE?
    6    (4.7%) /     3   (2.3%)  |   117  |         'usedIE' => user.sessions.map{|s| s['browser']}.any? { |b| b.upcase =~ /INTERNET EXPLORER/ },
                                  |   118  |       # Всегда использовал только Chrome?
    8    (6.2%) /     4   (3.1%)  |   119  |         'alwaysUsedChrome' => user.sessions.map{|s| s['browser']}.all? { |b| b.upcase =~ /CHROME/ },
                                  |   120  |       # Даты сессий через запятую в обратном порядке в формате iso8601
   46   (35.7%) /    23  (17.8%)  |   121  |         'dates' => user.sessions.map{|s| Date.strptime(s['date'], '%Y-%m-%d' ).iso8601}.sort{ |a, b| b <=> a }
    1    (0.8%) /     1   (0.8%)  |   122  |     }
                                  |   123  |   end
```
рефакторим и получаем:
```
                                  |   106  |   # Собираем количество сессий по пользователям
   22   (22.9%)                   |   107  |   collect_stats_from_users(report, users_objects) do |user|
    2    (2.1%) /     1   (1.0%)  |   108  |     times = user.sessions.map{|s| s['time'].to_i}
    4    (4.2%) /     2   (2.1%)  |   109  |     browsers = user.sessions.map {|s| s['browser'].upcase}
                                  |   110  |     {
                                  |   111  |       'sessionsCount' => user.sessions.count,
                                  |   112  |       # Собираем количество времени по пользователям
                                  |   113  |         'totalTime' => times.sum.to_s + ' min.',
                                  |   114  |       # Выбираем самую длинную сессию пользователя
                                  |   115  |         'longestSession' => times.max.to_s + ' min.',
                                  |   116  |       # Браузеры пользователя через запятую
                                  |   117  |         'browsers' => browsers.sort.join(', '),
                                  |   118  |       # Хоть раз использовал IE?
   12   (12.5%) /     6   (6.2%)  |   119  |         'usedIE' => browsers.any? { |b| b.start_with?('INTERNET EXPLORER') },
                                  |   120  |       # Всегда использовал только Chrome?
                                  |   121  |         'alwaysUsedChrome' => browsers.all? { |b| b.start_with?('CHROME') },
                                  |   122  |       # Даты сессий через запятую в обратном порядке в формате iso8601
    6    (6.2%) /     3   (3.1%)  |   123  |         'dates' => user.sessions.map{|s| s['date'] }.sort{ |a, b| b <=> a }
    3    (3.1%) /     3   (3.1%)  |   124  |     }
                                  |   125  |   end
```

```
1) task-1 work for small file perform under 100 ms
     Failure/Error: expect {work('data1.txt') }.to perform_under(100).ms.warmup(2).sample(5)
       expected block to perform under 100 ms, but performed above 111 ms (± 4.43 ms)
     # ./spec/task_1_spec.rb:7:in `block (3 levels) in <top (required)>'
```

- Опять запускаем профилировщик и смотрим метод work
```
   40   (41.7%)                   |    53  |   file_lines.each do |line|
                                  |    54  |     cols = line.split(',')
   14   (14.6%) /    10  (10.4%)  |    55  |     users = users + [parse_user(line)] if cols[0] == 'user'
   26   (27.1%) /     4   (4.2%)  |    56  |     sessions << parse_session(line) if cols[0] == 'session'
                                  |    57  |   end
```

Разбиваем вызовы метода parse_user и parse_session:
```
   35   (37.2%)                   |    53  |   file_lines.each do |line|
                                  |    54  |     cols = line.split(',')
    9    (9.6%) /     9   (9.6%)  |    55  |     if cols[0] == 'user'
    2    (2.1%)                   |    56  |       parsed_user = parse_user(line)
                                  |    57  |       users << parsed_user
                                  |    58  |     end
    1    (1.1%) /     1   (1.1%)  |    59  |     if cols[0] == 'session'
   23   (24.5%)                   |    60  |       parsed_session = parse_session(line)
                                  |    61  |       sessions << parsed_session
                                  |    62  |     end
                                  |    63  |   end
```
Значит проблема в parsed_session, идем к отчету по ней:

```
Object#parse_session (/Users/grandman/my_projects/ruby_optimization/rails-optimization-task1/task-1.rb:27)
  samples:    23 self (24.5%)  /     23 total (24.5%)
  callers:
      23  (  100.0%)  Object#work
  code:
                                  |    27  | def parse_session(session)
                                  |    28  |   fields = session.split(',')
   23   (24.5%) /    23  (24.5%)  |    29  |   parsed_result = {
                                  |    30  |     'user_id' => fields[1],
```

Видим, что и там и там у строки вызывается split, убираем из методов и смотрим результат:

```
➜  rails-optimization-task1 git:(master) ✗ rspec
.

Finished in 0.71747 seconds (files took 0.27934 seconds to load)
1 example, 0 failures
```

Изначальный тест тоже проходит
```
ruby spec/test.rb
Run options: --seed 62432

# Running:

.

Finished in 0.002446s, 408.8307 runs/s, 408.8307 assertions/s.

1 runs, 1 assertions, 0 failures, 0 errors, 0 skips
```

- Пробуем запустить на большом файле и видим, что до сих пор время его выполнения намного больше 30 секунд

## Результаты
В результате проделанной оптимизации наконец удалось обработать файл с данными.
Удалось улучшить метрику системы с *того, что у вас было в начале, до того, что получилось в конце* и уложиться в заданный бюджет.

*Какими ещё результами можете поделиться*

## Защита от регрессии производительности
Для защиты от потери достигнутого прогресса при дальнейших изменениях программы *о performance-тестах, которые вы написали*

