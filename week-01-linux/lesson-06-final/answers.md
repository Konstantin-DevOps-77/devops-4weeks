# Урок 6. Итоговый инцидент INC-601

## Вопросы для самопроверки (README)
1. Причинно-следственная связь. Если изменен один параметр и состояние системы поменялось, вы точно знаете, что именно повлияло. Если изменено 2-3 и более - одновременно и стало лучше (или хуже), вы не знаете, какая из них сработала, а какая, возможно, навредила.    
Что ломается при пакетных правках:    
  
1.1 Невозможно откатить точечно. Одна из трёх правок помогла, другая ничего не сделала, третья создала новую проблему. Откатывать приходится всё сразу и начинать заново.    
1.2 Маскировка. Одно изменение может скрыть эффект другого. Например, вы перезапустили сервис и одновременно увеличили лимит памяти: нагрузка спала, но неясно, была ли это утечка памяти или зависшее соединение.    
1.3 Новые поломки накладываются на старые. Во время аварии у вас и так неполная картина. Каждое лишнее изменение добавляет неизвестную переменную.      
1.4 Потеря хронологии. Для постмортема нужна точная последовательность: «в 14:03 сделали X, в 14:05 метрика Y изменилась». Пачка правок эту связь стирает.    
  
Последовательность действий: гипотеза → одно изменение → наблюдение (подождать, посмотреть метрики и логи) → вывод → следующий шаг. Каждое действие записывайте с временем в общий канал или заметки инцидента.    
  
Исключение: если система полностью лежит и каждая минута стоит очень дорого(например, откат всего релиза целиком). Но это откат к заведомо рабочему состоянию, а не набор экспериментов, которые мы запускаем точечно/пачкой.     
     
2. Постмортем (разбор инцидента) — документ и встреча после аварии: что произошло, как обнаружили, как чинили, почему это стало возможным и что делать, чтобы не повторилось.    
    
«Без поиска виноватых» (blameless) означает, что разбор фокусируется на системе, процессах и условиях, а не на конкретном человеке. Вместо «N выкатил сломанный конфиг» формулируют: «Конфиг без валидации попал в продакшн, потому что в пайплайне нет проверки схемы».  
  
Почему это работает:    
  
Люди ошибаются всегда. Если ошибка одного человека смогла положить систему, либо серьезно повлиять на ее работу, значит, система недостаточно защищена. Устранить человека нельзя, а защиту построить можно.    
Страх поглощает информацию. Когда за ошибку наказывают, люди скрывают детали, приукрашивают хронологию или молчат о «почти авариях». Без честных данных невозможно найти реальные причины.  
Люди быстрее сообщают о проблемах. Если инженер уверен, что его не накажут, он сразу скажет «кажется, я что-то сломал», а не будет полчаса пытаться исправить втихую, попутно не прибавив новых проблем.    
Обучение вместо наказания. Инцидент — самый дорогой и самый ценный источник знаний о том, как система ведёт себя в реальности.    
  
Что обычно входит в постмортем:    
  
1. Краткое резюме и влияние (кого и насколько затронуло, длительность).    
2. Хронология с временными метками.    
3. Триггер и корневые причины.    
4. Что сработало хорошо, что плохо, где повезло/не повезло.    
5. Action items: конкретные задачи с владельцем и сроком.    

**Важно**: blameless не равно «безответственно». Это не отрицание того, что люди принимали решения. Просто эти решения необходимо разбирать в контексте: какая информация была у человека в тот момент, почему действие казалось разумным. Если в разборе всплыло повторяющееся пренебрежение правилами(фактически саботаж), это решается отдельно, вне постмортема.    
       
3. Триггер — событие, которое непосредственно запустило инцидент. Это «спусковой крючок»: то, что произошло прямо перед сбоем.    
    
Корневая причина — глубинное условие в системе, из-за которого этот триггер вообще смог привести к аварии. Это «заряженное ружьё»: уязвимость, которая существовала заранее и ждала подходящего случая.    
    
Различие в одной фразе: триггер отвечает на «что случилось именно сейчас?», корневая причина — «почему это вообще могло нас сломать?»    
    
Пример. В 03:12 сервис перестал отвечать.    
    
Триггер: сработал плановый ротатор логов, и на диске закончилось место.  
Корневые причины (их обычно несколько):  
Нет мониторинга заполнения диска с алертом заранее.  
Приложение пишет отладочные логи в продакшне без ограничения размера.  
Логи и база данных лежат на одном разделе, поэтому переполнение логов убило БД.  
  
Почему важно различать:  
  
Если «починить» только триггер (убрать ротатор, очистить диск), авария повторится через месяц от другого триггера: например, большого дампа или всплеска трафика.  
Если мы остановимся на «виноват ротатор», мы пропустим системные проблемы.  
Хороший постмортем ищет глубже, например методом «пяти почему»: почему лёг сервис → кончился диск → почему → логи росли без лимита → почему → нет политики хранения → почему → никто не владеет этой настройкой.  
  
Ещё пример - сертификат истёк, и сайт недоступен.  
Триггер — наступление даты истечения.   
Корневая причина — автоматическое продление не настроено или молча падало, а мониторинга срока сертификата нет.    
  
Практическое замечание: у инцидента чаще всего один триггер, но несколько способствующих факторов. Поэтому в современных разборах нередко говорят не «корневая причина» (единственная), а «способствующие(сопутствующие) факторы»  
4. Git действительно нужен, но он не закрывает всех случаев, особенно во время аварии.  
  
Причины делать копию (cp nginx.conf nginx.conf.bak.$(date +%F-%H%M)):  
  
4.1 Рабочий конфиг на сервере может отличаться от того, что в Git. Кто-то уже правил его руками, деплой не доехал, есть локальные отличия. Git хранит «задуманное» состояние, а копия фиксирует то, что работает прямо сейчас, в том числе с неучтёнными правками.  
4.2 Конфиг может вообще не лежать в Git. Часть серверов не под управлением конфигураций, особенно старые или собранные вручную. Часть файлов (секреты, локальные переопределения) в репозиторий сознательно не кладут.  
4.3 Скорость отката. Вернуть .bak — одна команда на самом сервере. Не нужно искать репозиторий, ветку, доступы и ждать пайплайн, когда сервис лежит.  
4.4. Git может быть недоступен именно в момент аварии. Упал Git-сервер, CI, сеть или VPN, а откатываться надо сейчас.
Сохранение точного состояния «до». Копия сохраняет права, владельца и содержимое в момент, когда вы начали. Для постмортема и диагностики можно сделать diff между «до» и «после».  
4.5 Правки на лету не коммитятся. Во время аварии вы пробуете гипотезы. Коммитить каждую пробу в основную ветку неудобно и неправильно, а копия ничего не засоряет. 

Как я буду работать:

- Копировать с сохранением атрибутов: cp -a.  
- Добавлять в имя дату и время.  
- Не перезаписывать старую копию: если вы правите второй раз, нужна новая копия, иначе потеряете первоначальное состояние.  
- После аварии принести окончательные правки в Git, чтобы репозиторий снова был источником истины, а ручные изменения не стали «дрейфом конфигурации».  
  
5. curl localhost на самом сервере проверяет только, что процесс отвечает изнутри. Пользователь же приходит снаружи и проходит весь путь целиком.  
  
Что проверка изнутри не покрывает:  

5.1 DNS. Запись может указывать не туда или не обновиться.
5.2 Балансировщик и обратный прокси. Они могут не видеть бэкенд или считать его нездоровым. 
5.3 Файрвол и группы безопасности. Порт открыт локально, но закрыт для внешнего мира.
5.4 TLS и сертификаты. Локально вы ходите по HTTP или с -k, а снаружи браузер ругается на сертификат.
5.5 CDN и кэш. Пользователь может получать закэшированную страницу с ошибкой или, наоборот, старую версию.
5.6 Маршрутизация и сеть провайдера. Часть регионов может не достучаться.
5.7 Виртуальные хосты. Запрос на localhost попадает в другой server block, чем запрос на настоящее доменное имя.  
  
Вариант - починили приложение, curl localhost:8080 возвращает 200, объявляете «всё починено». 
А пользователи по-прежнему видят 502, потому что балансировщик помечал бэкенд как неисправный и не вернул его в ротацию.

Как проверять правильно:

- С внешней машины, из другой сети: curl -sS -o /dev/null -w '%{http_code} %{time_total}\n' https://example.com/.
- Именно по боевому домену и по HTTPS, без -k.
- Не одним запросом, а несколькими, чтобы попасть на разные бэкенды за балансировщиком.
- Проверять не только главную, но и ключевые пользовательские сценарии (логин, оплата, API).
- Использовать внешний мониторинг (синтетические проверки из нескольких регионов), если он есть.
- Смотреть метрики реального трафика: доля ошибок, задержки. Они подтверждают, что пользователи действительно в порядке.

Принцип: проверять нужно с точки зрения пользователя. Инцидент закрыт не тогда, когда сервис «выглядит живым» для вас, а когда его работу подтверждает внешний наблюдатель либо конечный пользователь.  
6. Что значит «не уничтожай улики»? Пример команды, которая чинит, но стирает информацию о причине.

Смысл: во время починки многие действия уничтожают данные, по которым потом можно понять, что именно произошло. Если улики стёрты, постмортем превращается в гадание, а причина остаётся нераскрытой и авария повторится.

Что относится к уликам:

Логи (приложения, системы, ядра).
Состояние процесса: память, открытые файлы, сетевые соединения, стеки потоков.
Core-дампы и heap-дампы.
Содержимое временных файлов, очередей, кэшей.
Метрики и текущие значения (нагрузка, число соединений).
Сам «сломанный» конфиг или файл.

Команды, которые чинят, но стирают информацию:

- systemctl restart myapp (или kill -9) без предварительного сбора данных. Сервис поднимается, но вы потеряли состояние зависшего процесса: потоки, заблокированные на чём-то, утечку в памяти, число открытых дескрипторов, список соединений.
- > /var/log/app/error.log или rm /var/log/app/*.log для «освобождения места». Диск освободился, сервис ожил, но логи с моментом сбоя исчезли.
- rm -rf /tmp/* или очистка кэша/очереди. Исчезают потенциально «ядовитые» сообщения или файлы, из-за которых всё сломалось.
- Перезапись конфига без копии. Теряется вариант «до».
- Перезагрузка сервера (reboot). Стирается вся оперативная память, процессы и состояние ядра.

Конкретный пример. Сервис вырос по памяти и упёрся в OOM. Вы делаете systemctl restart myapp, всё работает. Но нет понимания, что именно занимало память, и утечка вернётся через неделю.

Как сделать правильно (сначала собрать, потом чинить):


- Сохранить логи и состояние в безопасное место
`mkdir -p /root/incident-$(date +%F-%H%M) && cd $_`
`cp -a /var/log/app/ ./logs/`
`journalctl -u myapp --since "2 hours ago" > journal.txt`
`dmesg -T > dmesg.txt`
`ps auxf > ps.txt`
`ss -tanp > connections.txt`
`free -m > mem.txt; df -h > disk.txt`
- дамп процесса/потоков, если применимо  
`cat /proc/$(pidof myapp)/status > proc-status.txt`
`ls -l /proc/$(pidof myapp)/fd | wc -l > open-fds.txt`

И только после этого перезапускать.

Если срочность не позволяет всё собрать: хотя бы минимум: journalctl/логи в файл, ps, ss, dmesg. Это занимает секунды.

Дополнительные меры:

Для логов: использовать cp/mv вместо > или rm; для освобождения места сжимать (gzip) и переносить логи, а не удалять.
Делать снимки (snapshot) диска или ВМ, если случай серьёзный.

Общий принцип: сначала зафиксировать, потом чинить. Улики нужны, чтобы докопаться до корневой причины, а не только убрать симптом.

## Черновик
(сюда пиши по ходу: время, команда, что увидел. Можно неаккуратно, это рабочие записи)

---

# Отчёт об инциденте INC-601

**Начал:** - 13.11.2026 17.00    
**Закончил:** - 13.11.2026 20.00   
**Часовой пояс:** - UTC+3(Moscow time)  
**Контрольная сумма orders.db от стенда:**:   73c8ebb18af388d4c75c0d81159142a4  /mnt/ops6/data/orders.db
**Читал ли код стенда:** - да(бегло, особо не вчитывался)

1. Диагностика


# Шаг.1. Проверяем состояние службы.
`sudo systemctl status ops6-shop.service --no-pager -l`  
ops6-shop.service - OPS-6 shop frontend  
     Loaded: loaded (/etc/systemd/system/ops6-shop.service; enabled;   preset: enabled)  
     Active: active (running) since Fri 2026-11-13 15:28:46 UTC; 246ms ago    
   Main PID: 1326299 (python3)  
      Tasks: 1 (limit: 2263)  
     Memory: 16.7M (peak: 20.2M)  
        CPU: 191ms  
     CGroup: /system.slice/ops6-shop.service  
             └─1326299 /usr/bin/python3 /opt/ops6/shop.py  

Вывод: служба active, running и enabled.    

# Шаг.2 Проверяем журнал службы  
`sudo journalctl -u ops6-shop.service -n 60 --no-pager`    
вывод:  
     ```bash  
     Nov 13 15:30:08 blank-black.ptr.network python3[1326918]:   PermissionError: [Errno 13] Permission denied: '/etc/ops6/shop.conf'  
     Nov 13 15:30:08 blank-black.ptr.network systemd[1]: ops6-shop.    service: Main process exited, code=exited, status=1/FAILURE  
     Nov 13 15:30:08 blank-black.ptr.network systemd[1]: ops6-shop.service: Failed with result 'exit-code'.  
     ```  
Permission Denied, status=1, Failed  
  
Вывод: найдена проблема с доступом к файлу конфига.
  
# Шаг 3. Проверяем права и пользоватей службы + смотрим конфиг  
     ```bash  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo ls -l /etc/ops6/shop.conf   
     -rw------- 1 root root 129 Nov 13 15:22 /etc/ops6/shop.conf # Файл есть  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo namei -l /etc/ops6/shop.conf  
     f: /etc/ops6/shop.conf  
     drwxr-xr-x root root /  
     drwxr-xr-x root root etc  
     drwxr-xr-x root root ops6  
     -rw------- root root shop.conf  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# id ops6shop  
     uid=996(ops6shop) gid=986(ops6shop) groups=986(ops6shop)  
     ```  
     ```bash  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo -u ops6shop test -r /etc/ops6/shop.conf  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# printf 'Конфиг читается пользователем службы, код: %s\n' "$?"  
     Конфиг читается пользователем службы, код: 1  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux#   sudo sed -E 's/^([[:space:]]*DB_PASSWORD[[:space:]]*=).*/\1***/' /etc/ops6/shop.conf # Выводим конфиг с замаскированным паролем  
     # Магазин: конфиг релиза 2.4  
     BIND=127.0.0.1  
     PORT=8600  
     LOG=/mnt/ops6/logs/shop.log  
     DB_PASSWORD=***  
     ```  
Вывод: файл root:root 600, служба работает как ops6shop, чтение ей запрещено. Просмотр с sudo не доказывает, что конфиг видит сама служба.
Другими словами, служба не может прочитать собственный конфиг.  

# Шаг 4. Проверяем загруженность диска.  
     ```bash  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# findmnt /mnt/ops6 # смотрим на подключенные файловые системы  
     TARGET    SOURCE     FSTYPE OPTIONS  
     /mnt/ops6 /dev/loop0 ext4   rw,relatime  
  
     # Проверяем состояние диска, видно что заполнен полностью.  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# df -h /mnt/ops6  
     Filesystem      Size  Used Avail Use% Mounted on  
     /dev/loop0       71M   66M     0 100% /mnt/ops6  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# df -i /mnt/ops6  
     Filesystem     Inodes IUsed IFree IUse% Mounted on  
     /dev/loop0      20480    17 20463    1% /mnt/ops6  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo du -xhd1 /mnt/ops6  
     16K     /mnt/ops6/lost+found  
     4.0K    /mnt/ops6/spool  
     5.1M    /mnt/ops6/data  
     4.0K    /mnt/ops6/logs  
     5.1M    /mnt/ops6  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo du -x -B1 -s /mnt/ops6  
     5275648 /mnt/ops6  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# df -B1 /mnt/ops6  
     Filesystem     1B-blocks     Used Available Use% Mounted on  
     /dev/loop0      74395648 68526080         0 100% /mnt/ops6  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo lsof -nP +aL1 /mnt/ops6  
     COMMAND     PID     USER   FD   TYPE DEVICE SIZE/OFF NLINK NODE NAME
     python3 1323813 ops6ship    3w   REG    7,0 63246336     0   16 /mnt/ops6/spool/ship-buffer.log (deleted) 
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo systemctl status ops6-logship.service --no-pager -l  
     sudo journalctl -u ops6-logship.service -n 30 --no-pager  
     ● ops6-logship.service - OPS-6 log shipper  
          Loaded: loaded (/etc/systemd/system/ops6-logship.service;   enabled; preset: (enabled)  
          Active: active (running) since Fri 2026-11-13 15:22:32 UTC;   19min ago  
     Main PID: 1323813 (python3)  
          Tasks: 1 (limit: 2263)  
          Memory: 123.6M (peak: 126.5M)  
          CPU: 255ms  
          CGroup: /system.slice/ops6-logship.service  
               └─1323813 /usr/bin/python3 /opt/ops6/logship.py  
  
     Nov 13 15:22:32 blank-black.ptr.network systemd[1]: Started ops6-logship.service - OPS-6 log shipper.  
     Nov 13 09:52:25 blank-black.ptr.network systemd[1]: Started ops6-logship.service - OPS-6 log shipper.  
     Nov 13 11:29:23 blank-black.ptr.network systemd[1]: Stopping ops6-logship.service - OPS-6 log shipper...  
     Nov 13 11:29:23 blank-black.ptr.network systemd[1]: ops6-logship.service: Deactivated successfully.  
     Nov 13 11:29:23 blank-black.ptr.network systemd[1]: Stopped ops6-logship.service - OPS-6 log shipper.  
     Nov 13 11:29:24 blank-black.ptr.network systemd[1]: Started ops6-logship.service - OPS-6 log shipper.  
     Nov 13 11:59:02 blank-black.ptr.network systemd[1]: Stopping ops6-logship.service - OPS-6 log shipper...  
     Nov 13 11:59:02 blank-black.ptr.network systemd[1]: ops6-logship.service: Deactivated successfully.  
     Nov 13 11:59:02 blank-black.ptr.network systemd[1]: Stopped ops6-logship.service - OPS-6 log shipper.  
     Nov 13 11:59:03 blank-black.ptr.network systemd[1]: Started ops6-logship.service - OPS-6 log shipper.  
     Nov 13 15:22:30 blank-black.ptr.network systemd[1]: Stopping ops6-logship.service - OPS-6 log shipper...  
     Nov 13 15:22:30 blank-black.ptr.network systemd[1]: ops6-logship.service: Deactivated successfully.  
     Nov 13 15:22:30 blank-black.ptr.network systemd[1]: Stopped ops6-logship.service - OPS-6 log shipper.  
     Nov 13 15:22:32 blank-black.ptr.network systemd[1]: Started ops6-logship.service - OPS-6 log shipper.  
     ```
  
* Вывод: файл буфера был удалён, но оставался открытым процессом ops6-logship через дескриптор 3. Его блоки учитывались в df, однако файл отсутствовал в обходе du. Поэтому rm не решил проблему освобождения диска.  

### Исправление

# Шаг1. Очищаем диск корректным образом.  
     ```bash  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo systemctl stop ops6-logship.service  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo lsof -nP +aL1 /mnt/ops6  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# df -h /mnt/ops6  
     Filesystem      Size  Used Avail Use% Mounted on  
     /dev/loop0       71M  5.1M   61M   8% /mnt/ops6  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo du -xhd1 /mnt/ops6  
     16K     /mnt/ops6/lost+found  
     4.0K    /mnt/ops6/spool  
     5.1M    /mnt/ops6/data  
     4.0K    /mnt/ops6/logs  
     5.1M    /mnt/ops6  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo md5sum /mnt/ops6/data/orders.db  
     73c8ebb18af388d4c75c0d81159142a4  /mnt/ops6/data/orders.db  
     ```
* Вывод по очистке: gосле штатной остановки службы дескриптор закрылся и место освободилось.  
  

# Шаг 2. Производим назначение доступа для чтения конфига ops6shop.  
     ```bash  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo chown root:ops6shop /etc/ops6/shop.conf  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo chmod 640 /etc/ops6/shop.conf  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo ls -l /etc/ops6/shop.conf  
     -rw-r----- 1 root ops6shop 129 Nov 13 15:22 /etc/ops6/shop.conf  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo -u ops6shop test -r /etc/ops6/shop.conf  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# printf 'Чтение службой после исправления, код: %s\n' "$?"  
     Чтение службой после исправления, код: 0  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# 
     ```
     Вывод: даем чтение по принципу наименьших привилегий  

# Шаг 3. Пробуем запустить службу.  
     ```bash  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo systemctl reset-failed ops6-shop.service  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo systemctl start ops6-shop.service  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo systemctl status ops6-shop.service --no-pager -l  
     ● ops6-shop.service - OPS-6 shop frontend  
          Loaded: loaded (/etc/systemd/system/ops6-shop.service; enabled;   preset: enabled)  
          Active: active (running) since Fri 2026-11-13 15:52:18 UTC; 2min 10s ago  
     Main PID: 1336200 (python3)  
          Tasks: 1 (limit: 2263)  
          Memory: 8.9M (peak: 9.2M)  
          CPU: 66ms  
          CGroup: /system.slice/ops6-shop.service  
               └─1336200 /usr/bin/python3 /opt/ops6/shop.py  

     #Ресет не удалил последней записи журнала
     Nov 13 15:52:16 blank-black.ptr.network systemd[1]: ops6-shop.service: Failed with result 'exit-code'.  
     Nov 13 15:52:18 blank-black.ptr.network systemd[1]: ops6-shop.service: Scheduled restart job, restart counter is at 9571.  
     Nov 13 15:52:18 blank-black.ptr.network systemd[1]: Started ops6-shop.service - OPS-6 shop frontend.  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# 
     ```  

* Вывод: Локально всё OK.  

# Шаг 4. Проверяем, отвечает ли приложение снаружи и на каком адресе слушает.  
     ``` bash  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo ss -tlnp 'sport = :8600'  
     State                Recv-Q               Send-Q       Local   Address:Port      Peer Address:Port          Process                
     LISTEN               0                    5             127.0.0.1:8600         0.0.0.0:*                  users:(("python3",pid=1336200,fd=4))  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# curl --noproxy '*' -i --max-time 5 http://127.0.0.1:8600/health  
     HTTP/1.0 200 OK  
     Server: BaseHTTP/0.6 Python/3.12.3  
     Date: Fri, 13 Nov 2026 15:58:44 GMT  
     Content-Type: text/html; charset=utf-8  
     Content-Length: 3  

     ok

     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo systemctl show ops6-shop.service -p User -p Group -p NRestarts  
     NRestarts=0  
     User=ops6shop  
     Group=ops6shop  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# 
     ```  
* Вывод: LISTEN 127.0.0.1:8600 - Python слушает только loopback сервера. Через публичный IP этот сокет недоступен(=пользователи не могут работать)  
  
# Шаг 5. Изменим адрес прослушивания для доступа внешних пользователей.  
     ```bash  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo sed -i -E 's/^BIND=.*/BIND=0.0.0.0/' /etc/ops6/shop.conf  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo systemctl restart ops6-shop.service  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo ss -tlnp 'sport = :8600'  
     State   Recv-Q     Send-Q    Local Address:Port  Peer Address:Port      Process       
     LISTEN     0       5              0.0.0.0:8600            0.0.0.0:*       users:(("python3",pid=1337447,fd=4))  
     ```

# Шаг 6. Проверяем внешнее подключение.   
```shell  
     PS C:\WINDOWS\system32> Test-NetConnection 212.113.116.203 -Port 8600  
  
  
     ComputerName     : 212.113.116.203  
     RemoteAddress    : 212.113.116.203  
     RemotePort       : 8600  
     InterfaceAlias   : happ-xray  
     SourceAddress    : 172.19.0.1  
     TcpTestSucceeded : True  



     PS C:\WINDOWS\system32> curl.exe --noproxy '*' -i --connect-timeout 5 --max-time 10 "http://212.113.116.203:8600/health"  
  
     curl: (28) Operation timed out after 10000 milliseconds with 0 bytes received  
     PS C:\WINDOWS\system32>  
```  
* Вывод: Базовое соединение установлено, но с curl пришло 0 байтов, необходимо проверить фаервол и правила.

# Шаг 7. Проверяем фаервол.  
     ```bash  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# if command -v ufw > /dev/null; then
     sudo ufw status verbose
     sudo ufw show added
     fi
     Status: active
     Logging: on (low)
     Default: deny (incoming), allow (outgoing), deny (routed)
     New profiles: skip

     To                         Action      From
     --                         ------      ----
     22/tcp                     ALLOW IN    Anywhere                  
     80/tcp                     ALLOW IN    Anywhere                  
     443/tcp                    ALLOW IN    Anywhere                  
     443/udp                    ALLOW IN    Anywhere                  
     37363/tcp                  ALLOW IN    Anywhere                  
     8443/tcp                   ALLOW IN    Anywhere                  
     8080/tcp                   ALLOW IN    Anywhere                  
     22/tcp (v6)                ALLOW IN    Anywhere (v6)             
     80/tcp (v6)                ALLOW IN    Anywhere (v6)             
     443/tcp (v6)               ALLOW IN    Anywhere (v6)             
     443/udp (v6)               ALLOW IN    Anywhere (v6)             
     37363/tcp (v6)             ALLOW IN    Anywhere (v6)             
     8443/tcp (v6)              ALLOW IN    Anywhere (v6)             
     8080/tcp (v6)              ALLOW IN    Anywhere (v6)             

     Added user rules (see 'ufw status' for running firewall):
     ufw allow 22/tcp
     ufw allow 80/tcp
     ufw allow 443/tcp
     ufw allow 443/udp
     ufw allow 37363/tcp
     ufw allow 8443/tcp
     ufw allow 8080/tcp

     # Добавляем 8600  
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo ufw allow 8600/tcp comment 'ops6-lab'  
     Rule added  
     Rule added (v6)  
     ```
     
* Вывод: фаерволл блокировал порт 8600, добавили необходимое правило. 


# Шаг 8. Повторно проверяем внешнее подключение.  
     ```shell  
     PS C:\Users\Admin> Test-NetConnection 212.113.116.203 -Port 8600  
  
     ComputerName     : 212.113.116.203  
     RemoteAddress    : 212.113.116.203  
     RemotePort       : 8600  
     InterfaceAlias   : happ-xray  
     SourceAddress    : 172.19.0.1  
     TcpTestSucceeded : True  

     PS C:\WINDOWS\system32> curl.exe --noproxy '*' -i --connect-timeout 5 --max-time 10 "http://212.113.116.203:8600/health"  

     HTTP/1.0 200 OK  
     Server: BaseHTTP/0.6 Python/3.12.3  
     Date: Fri, 13 Nov 2026 16:20:38 GMT  
     Content-Type: text/html; charset=utf-8  
     Content-Length: 3  

     ok
     ```
* Вывод - руками починили приложение

# Профилактика повторного падения 
#Проверить авточистку логов
     ```bash
     sudo -u ops6shop bash -c 'head -c 11M /dev/zero >> /mnt/ops6/logs/shop.log' # Добавляем 11 мб к логам
     sudo stat -c 'size=%s inode=%i' /mnt/ops6/logs/shop.log
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# df -h /mnt/ops6
     Filesystem      Size  Used Avail Use% Mounted on
     /dev/loop0       71M   21M   45M  32% /mnt/ops6 # 32% 21 MB занято
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sleep 120
     root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# df -h /mnt/ops6
     Filesystem      Size  Used Avail Use% Mounted on
     /dev/loop0       71M   11M   45M  32% /mnt/ops6 # 15% 11 MB занято
     ```

* Вывод: лог обнулился, магазин отвечает

## Вопросы коллегам
1. Диме: «Какие именно параметры и права ты менял в /etc/ops6/shop.conf в релизе 2.4 (владелец, режим, значения BIND/PORT/LOG) и какой там был старый конфиг? Проверял ли ты после выката доступность снаружи?» Зачем: восстановить, что было «до», и выяснить, была ли проверка после выката.  
2. Пете: «Какой именно командой ты чистил в 03:25 (rm/truncate/что именно, какой файл) и перезапускал ли что-то после?» Зачем: подтвердить версию с rm по файлу, который держит процесс, и уточнить, что он проверял после.  



# К отчету
before: root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux#  md5sum /mnt/ops6/data/orders.db 
73c8ebb18af388d4c75c0d81159142a4  /mnt/ops6/data/orders.db
after:
root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux#  md5sum /mnt/ops6/data/orders.db 
73c8ebb18af388d4c75c0d81159142a4  /mnt/ops6/data/orders.db

## Приёмка
Выполнить и вставить выводы по каждому пункту.
1. Снаружи: Test-NetConnection <IP> -Port 8600 → True;  
```shell
PS C:\Users\Admin> Test-NetConnection 212.113.116.203 -Port 8600


ComputerName     : 212.113.116.203
RemoteAddress    : 212.113.116.203
RemotePort       : 8600
InterfaceAlias   : happ-xray
SourceAddress    : 172.19.0.1
TcpTestSucceeded : True
```
 браузер; 
 Магазин работает

 curl.exe -s http://<IP>:8600/health
curl -s http://212.113.116.203:8600/health
ok
2. Служба здорова:
`sudo systemctl restart ops6-shop` 
`systemctl status ops6-shop` (active (running))
systemctl status ops6-shop
● ops6-shop.service - OPS-6 shop frontend
     Loaded: loaded (/etc/systemd/system/ops6-shop.service; enabled; preset: enabled)
     Active: active (running) since Sat 2026-11-14 16:15:50 UTC; 9s ago
   Main PID: 1380724 (python3)
      Tasks: 1 (limit: 2263)
     Memory: 9.5M (peak: 9.7M)
        CPU: 523ms
     CGroup: /system.slice/ops6-shop.service
             └─1380724 /usr/bin/python3 /opt/ops6/shop.py
`systemctl is-enabled ops6-shop (enabled)` снова /health.
```bash
root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# systemctl is-enabled ops6-shop
enabled
root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# curl -s http://212.113.116.203:8600/health
ok
```
3. Безопасность: 
`ls -l /etc/ops6/shop.conf`
```bash
root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# ls -l /etc/ops6/shop.conf
-rw-r----- 1 root ops6shop 127 Nov 13 16:02 /etc/ops6/shop.conf
```
`ps -o user,pid,cmd -C python3` (пользователь ops6shop, не root). Показывать без пароля.
```bash
 ps -o user,pid,cmd -C python3
USER         PID CMD
mtr-bac+     916 /usr/bin/python3 /usr/local/lib/3x-ui-pro/mtr-backend.py --port 18055
root     1015058 python3 -m http.server 8080 --bind 127.0.0.1 --directory /root/web
ops6ship 1338026 /usr/bin/python3 /opt/ops6/logship.py
ops6shop 1380724 /usr/bin/python3 /opt/ops6/shop.py
```

4. Место освобождено честно:
`df -h /mnt/ops6`
```bash
root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# df -h /mnt/ops6
Filesystem      Size  Used Avail Use% Mounted on
/dev/loop0       71M   15M   51M  23% /mnt/ops6
```

`sudo du -xsh /mnt/ops6`
```bash
root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo du -xsh /mnt/ops6
15M     /mnt/ops6
```
`sudo lsof +L1 | grep ops6` (пусто).
```bash
root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo lsof +L1 | grep ops6
root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# 
```
Заказы целы: 
`md5sum /mnt/ops6/data/orders.db` совпадает с выводом стенда.
**Контрольная сумма orders.db от стенда:**:   73c8ebb18af388d4c75c0d81159142a4  /mnt/ops6/data/orders.db
```bash
root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# md5sum /mnt/ops6/data/orders.db
73c8ebb18af388d4c75c0d81159142a4  /mnt/ops6/data/orders.db
```
5. Авария не повторится сама:
`sudo -u ops6shop bash -c 'head -c 11M /dev/zero >> /mnt/ops6/logs/shop.log`
`ls -l /mnt/ops6/logs/shop.log` (11 МБ), ждать до 2 минут, 
```bash
root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# df -h /mnt/ops6
Filesystem      Size  Used Avail Use% Mounted on
/dev/loop0       71M   18M   48M  27% /mnt/ops6
root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# df -h /mnt/ops6
Filesystem      Size  Used Avail Use% Mounted on
/dev/loop0       71M  6.8M   59M  11% /mnt/ops6
```
снова 
`` (нулевой размер или маленький),
`tail /var/log/ops6-cleanup.log` (запись trimmed).
```bash
cleanup ok
cleanup ok
cleanup ok
2026-11-14 16:22:01 trimmed /mnt/ops6/spool/ship-buffer.log
cleanup ok
cleanup ok
cleanup ok
cleanup ok
2026-11-14 16:30:02 trimmed /mnt/ops6/logs/shop.log
cleanup ok
```

Отчёт полный: 
`grep -n 'Sh0p' answers.md` (должно быть пусто, ищем фрагмент пароля), проверить, что везде ***.
```bash
root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# grep -n 'Sh0p' lesson-06-final/answers.md
576:`grep -n 'Sh0p' answers.md` (должно быть пусто, ищем фрагмент пароля), проверить, что везде ***.
root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# 
```

НО! Если вместо sed использовать cat -> пароль будет выведен явно и в нем фигурирует Sh0
p

# Основной триггер: релиз 2.4 (конфиг) и внешняя причина: отправщик логов накопил буфер, пока коллектор недоступен.
# Корневые причины:
1. Конфиг после релиза не читается пользователем службы (root:root 600).
2. В конфиге BIND=127.0.0.1, сайт не слушает внешний интерфейс.
3. Буфер отправщика логов не ограничен по размеру и забил диск.
4. Место «удалили» через rm, файл остался занятым процессом -> место не вернулось.
5. Чистка по расписанию не работала: у cron нет /usr/local/bin в PATH, скрипт скрывал ошибку («cleanup ok», код 0) и ничего не логировал.  

#Исходный вариант(сообщение об очистке появляется всегда - нет условия его обработки)
```bash
root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo cat /etc/cron.d/ops6-cleanup
*/2 * * * * root /opt/ops6/cleanup.sh >> /var/log/ops6-cleanup.log 2>&1
root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux# sudo cat /opt/ops6/cleanup.sh
#!/bin/bash
# Чистка буферов и логов магазина: всё, что больше 10 МБ, обнуляем
for f in /mnt/ops6/spool/*.log /mnt/ops6/logs/*.log; do
  if [ $(stat -c %s $f) -gt 10485760 ]; then
    logtrim $f
  fi
done
echo "cleanup ok"
```

# Способствующие факторы:
1. нет проверки доступности снаружи после выката;
2. алерт на диск не закрывали проверкой результата, дежурный самостоятельно решил, что «мониторинг глючит»;
3. в инструкции дежурного нет lsof +L1 и truncate;
4. нет алерта на свежесть чистки;
5. диск не в fstab, сервис не знает про зависимость от диска (RequiresMountsFor);
6. жалобы клиентов пришли раньше, чем мы сами заметили сбой(в силу причин выше).  


## 5 почему (для чистки/диска)
1. Почему сайт не работал? Служба не стартовала.  
2. Почему не стартовала? Не читался конфиг, и не было места для лога.  
3. Почему не было места? Буфер отправщика заполнил диск, а rm не освободил место, пока процесс держал файл.  
4. Почему не сработала чистка? Cron не находил logtrim, скрипт всё равно писал «ok».  
5. Почему никто не заметил? Нет лога чистки, нет алерта на её результат и на доступность сайта снаружи.  
  
## Действия, чтобы не повторилось.
| Что сделать | Кто (роль) |Срочность|
| ----------- | ---------- | ------- |    
|Добавить в пайплайн проверку curl снаружи на /health после выката|DevOps|Высокая|  
|Ограничить размер буфера отправщика логов (потолок в конфиге / отдельный лимит на spool)|Dev|Высокая|  
|Абсолютные пути, кавычки, честный код возврата, лог в /var/log|DevOps|Высокая|  
|Алерт на свежесть лога чистки и на размер spool|DevOps|средняя|  
|Алерт «сайт недоступен снаружи» с проверкой не с самого сервера|DevOps|высокая|  
|Дополнить инструкцию дежурного: lsof +L1, truncate вместо rm, проверять, что алерт погас|дежурный/DevOps|высокая|  
|Проверка прав и владельца конфигов в шаблоне релиза (root:группа службы, 640)|Dev|средняя|  
|Прописать диск в fstab и RequiresMountsFor=/mnt/ops6 в unit|DevOps|средняя|  
|Разобраться, почему коллектор логов был недоступен|DevOps|средняя|  

## Что было сложнее всего
1. Был соблазн сразу решить продакшен(пустить пользователей) -> придерживаться последовательности исправлений.  
2. Многослойность инцидента.  
