# Урок 2. Процессы, systemd, SSH-ключи: мои ответы

# Часть A. Практика

## Задание 1. Разведка

1. PID моего Shell, PID Родителя + команда?  
  
Shell  
Команда:  
echo $$  
Вывод:  
656326  

**Родитель + команда:** 
Команда: 
ps -o pid,ppid,user,cmd -p $$
Вывод:
PID    PPID USER     CMD
656326  653626 root     /bin/bash --init-file /root/.vscode-server/cli/servers/Stable-2c.....

2. Что за процесс с PID 1?
Команда:
ps -p 1 -o comm=
Вывод:
systemd

3. Три процесса, которые больше всего занимают память (PID, пользователь, %MEM, команда)
Команда:
ps -eo pid,user,pmem,comm --sort=-pmem | head -n 4
Вывод:
PID USER     %MEM COMMAND
 656127 root     11.0 MainThread
 653545 root      7.7 MainThread
 653632 root      7.0 MainThread

4. Покажи uptime и nproc. Одним предложением: перегружен ли сервер?
Команда:
uptime

Вывод:
13:21:04 up 28 days,  3:04,  4 users,  load average: 0.44, 0.18, 0.05

Команда: nproc
Вывод:
1

# Заключение по задаче:
Все значения меньше 1, следовательно сервер НЕ нагружен.

5. Сколько процессов в каждом состоянии (R, S, D, T, Z, I)? Посчитай одной командой.
Команда:
ps -eo state | sort | uniq -c

Вывод:
 1  D
 51 I
 1  R
 84 S
 2  T

6. Какой процесс слушает порт 22 и от какого пользователя он работает?
Команда:
sudo ss -tulnp | grep :22

Вывод:
tcp   LISTEN 0      4096         0.0.0.0:22         0.0.0.0:*    users:(("sshd",pid=1019,fd=3),("systemd",pid=1,fd=117))    
tcp   LISTEN 0      4096            [::]:22            [::]:*    users:(("sshd",pid=1019,fd=4),("systemd",pid=1,fd=118))

## Задание 2. Сигналы руками

# Предварительная подготовка
root@blank-black:~/projects# cd ~/practice/lesson2
root@blank-black:~/practice/lesson2# nano tick.sh
root@blank-black:~/practice/lesson2# nano stubborn.sh
root@blank-black:~/practice/lesson2# chmod +x tick.sh
root@blank-black:~/practice/lesson2# chmod +x stubborn.sh


root@blank-black:~/practice/lesson2# ./tick.sh > tick.log 2>&1 & 
[1] 665877
root@blank-black:~/practice/lesson2# echo $!
665877
root@blank-black:~/practice/lesson2# kill -STOP 665877

[1]+  Stopped                 ./tick.sh > tick.log 2>&1
root@blank-black:~/practice/lesson2# ps -o pid,stat,cmd -p 665877
    PID STAT CMD
 665877 T    /bin/bash ./tick.sh
root@blank-black:~/practice/lesson2# tail -3 tick.log
tick: 13:39:50
tick: 13:39:51
tick: 13:39:52
root@blank-black:~/practice/lesson2# kill -CONT 665877
root@blank-black:~/practice/lesson2# ps -o pid,stat,cmd -p 665877
    PID STAT CMD
 665877 S    /bin/bash ./tick.sh
root@blank-black:~/practice/lesson2# tail -3 tick.log
tick: 13:41:45
tick: 13:41:46
tick: 13:41:47
root@blank-black:~/practice/lesson2# kill -TERM 665877
[1]+  Done                    ./tick.sh > tick.log 2>&1
root@blank-black:~/practice/lesson2# wait 665877
root@blank-black:~/practice/lesson2# echo $?
0
root@blank-black:~/practice/lesson2# tail -3 tick.log
tick: 13:42:23
tick: 13:42:24
tick: получил TERM, завершаюсь
root@blank-black:~/practice/lesson2# sleep 300 &
[1] 667157
root@blank-black:~/practice/lesson2# kill -TERM 667157
root@blank-black:~/practice/lesson2# wait 667157
[1]+  Terminated              sleep 300
root@blank-black:~/practice/lesson2# echo $?
143
root@blank-black:~/practice/lesson2# ./stubborn.sh &
[1] 667490
root@blank-black:~/practice/lesson2# kill -TERM 667490
root@blank-black:~/practice/lesson2# ps -o pid,stat,cmd -p 667490
    PID STAT CMD
 667490 S    /bin/bash ./stubborn.sh
root@blank-black:~/practice/lesson2# kill -KILL 667490
[1]+  Killed                  ./stubborn.sh
root@blank-black:~/practice/lesson2# wait 667490
root@blank-black:~/practice/lesson2# echo $?
137

(Выводы по семи шагам.)

| Шаг                         | Сигнал                   | Что произошло с процессом | Код возврата ||---|---|---|---|
| 4 (tick.sh) | TERM | | |
| 5 (sleep) | TERM | | |
| 6 (stubborn.sh) | TERM | | |
| 7 (stubborn.sh) | KILL | | |

 Почему `stubborn.sh` пережил `SIGTERM`, а `SIGKILL` его убил:

 trap '' TERM приказывает процессу игнорировать SIGTERM. SIGKILL (как и SIGSTOP) нельзя перехватить или игнорировать: его выполняет само ядро, процесс его даже не «видит». При KILL настоящая программа потеряла бы несохраненные данные в файл или БД, оставила бы временные файлы и не сняла блокировки.




## Задание 3. Свой сервис

Unit-файл:

```ini
[Unit]
Description=Lab hello service
After=network.target

[Service]
Type=simple
User=lab-svc
ExecStart=/usr/local/bin/lab-hello.sh
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
```

Объяснение строк:

# Раздел Init
Description	                               название в status
After=network.target	                   старт после инициализации сети

# Раздел Service
Type=simple         	                   главный процесс = сам скрипт
User=lab-svc	                           работаем не под root: 
                                           если сервис взломают, ущерб ограничен правами lab-svc(требование задания, принцип наименьших привилегий)
ExecStart=/usr/local/bin/lab-hello.sh	   путь запуска(полный), потому что systemd не ищет по PATH
Restart=on-failure	                       перезапуск после падения или убийства сигналом
RestartSec=3	                           пауза 3 с (требование задания)

# Раздел Install
WantedBy=multi-user.target              	автозапуск в обычном режиме загрузки; именно эту привязку использует enable

Выводы шагов 1-6:

Шаг 1.
Команда - systemctl status lab-hello
Вывод:
service
     Loaded: loaded (/etc/systemd/system/lab-hello.service; enabled; preset: enabled)
     Active: active (running) since Fri 2026-10-30 07:29:33 UTC; 21s ago

Шаг 2.
Команда - journalctl -u lab-hello -f
Вывод:
Oct 30 07:42:18 blank-black.ptr.network lab-hello.sh[686294]: lab-hello: я жив, 07:42:18
Oct 30 07:42:23 blank-black.ptr.network lab-hello.sh[686294]: lab-hello: я жив, 07:42:23
Oct 30 07:42:28 blank-black.ptr.network lab-hello.sh[686294]: lab-hello: я жив, 07:42:28
Oct 30 07:42:33 blank-black.ptr.network lab-hello.sh[686294]: lab-hello: я жив, 07:42:33
Oct 30 07:42:38 blank-black.ptr.network lab-hello.sh[686294]: lab-hello: я жив, 07:42:38
Oct 30 07:42:43 blank-black.ptr.network lab-hello.sh[686294]: lab-hello: я жив, 07:42:43
Oct 30 07:42:48 blank-black.ptr.network lab-hello.sh[686294]: lab-hello: я жив, 07:42:48
Oct 30 07:42:53 blank-black.ptr.network lab-hello.sh[686294]: lab-hello: я жив, 07:42:53
Oct 30 07:42:58 blank-black.ptr.network lab-hello.sh[686294]: lab-hello: я жив, 07:42:58
Oct 30 07:43:03 blank-black.ptr.network lab-hello.sh[686294]: lab-hello: я жив, 07:43:03
Oct 30 07:43:08 blank-black.ptr.network lab-hello.sh[686294]: lab-hello: я жив, 07:43:08
Oct 30 07:43:13 blank-black.ptr.network lab-hello.sh[686294]: lab-hello: я жив, 07:43:13
(команды и вывод)

**Шаг 3.**  
Команда:
 ```systemctl show -p MainPID --value lab-hello```  
Вывод:
*686294*

Команда - sudo kill -9 686294
Команда - systemctl status lab-hello
Вывод(получен новый PID - 688864, был - 686294):
lab-hello.service - Lab hello service
     Loaded: loaded (/etc/systemd/system/lab-hello.service; enabled; preset: enabled)
     Active: active (running) since Fri 2026-10-30 08:24:07 UTC; 37s ago
   Main PID: 688864 (lab-hello.sh)

**Разница между `kill -9` и `systemctl stop`:**      
`kill -9` извне, означает, что процесс «упал» (убит сигналом), поэтому Restart=on-failure это считает сбоем и перезапускает.  
 `systemctl stop` означает, что администратор сам приказал остановиться, systemd понимает это и перезапуск не включает.

**Шаг 4.**

## Задание 4. Кто стучится на сервер

sudo journalctl -u ssh --since "24 hours ago" --no-pager | grep -c "Invalid user"  
Вывод: 4863  
  
Топ 5 логинов  
sudo journalctl -u ssh --since "24 hours ago" --no-pager | grep "Invalid user" | awk '{print $8}' | sort | uniq -c | sort -rn | head -5  
  
Вывод:  
446 admin    
345 ubuntu      
226 user    
185 debian    
107 deploy    

Вывод по "нацеливанию хакеров"  
Это автоматические сканеры, которые перебирают словари типичных логинов (admin, ubuntu, user...) по всем IP подряд, а не целевая атака. Перебор паролей работает только если вход по паролю разрешён. Отключение входа по паролю делает такой перебор бессмысленным, а отключение root убирает самый популярный логин.

## Задание 5. Вход по ключу

(Отпечаток ключа, права, `whoami`, `id`, `sudo whoami`. БЕЗ приватного ключа.)
Отпечаток ключа:  
256 SHA256:TV+I7mllHrCLkY7SuNMMBXkVcFU56iiC/V5b1YaaKHA kostya-laptop (ED25519)  

Права  
root@blank-black:~/projects/devops-4weeks/week-01-linux/lesson-02-processes-systemd-ssh# ls -ld ~/.ssh  
drwx------ 2 root root 4096 Oct 30 13:40 /root/.ssh  
root@blank-black:~/projects/devops-4weeks/week-01-linux/lesson-02-processes-systemd-ssh# ls -l ~/.ssh/authorized_keys  
-rw------- 1 root root 95 Oct 30 13:40 /root/.ssh/authorized_keys  

whoami  
root

## Задание 6. Закрываем root и пароль

(Вывод `sshd -T` до и после, проверки входа, объяснение про `10-hardening.conf`.)

## Задание 7. Своими словами

1. `kill -9` vs `systemctl stop`  
 stop это команда самого systemd, он знает, что остановка намеренная, поэтому перезапуск не планирует. Убийство извне для него выглядит как аварийное завершение, что и есть случай для перезапуска по сбою(Restart=on-failure).  
2. Игнорирование SIGTERM при stop: systemd шлёт TERM, процесс молчит, systemd ждёт TimeoutStopSec (по умолчанию 90 с),  
   затем SIGKILL. В результате: долгая остановка и потеря шанса корректно завершиться.  
3. Restart=always у программы, падающей сразу: она будет перезапускаться по кругу; после более чем 5 перезапусков  
   за 10 секунд systemd сдаётся: failed (start-limit-hit). Лечение: починить причину, потом reset-failed
4. Ключ vs пароль: пароль можно подобрать, подсмотреть, и он передаётся при входе. Ключ состоит из пары; сервер проверяет владение приватным ключом, не получая его; подобрать его нельзя. Секрет: приватный файл (без .pub)
5. Почему systemd, а не &/nohup: (а) автозапуск после перезагрузки; (б) автоперезапуск при падении; (в) централизованные логи в журнале; (г) запуск под отдельным пользователем и управление через systemctl; (д) корректная остановка (TERM + таймаут).

# Часть B. Тикеты

## OPS-201. Служба отчётов не стартует

**Симптом:**  

Служба отчетов не запускается 

**Влияние:**  

Нет данных для отчетов  

**Диагностика:**  

`sudo systemctl start lab-report`  
`systemctl status lab-report`  
`journalctl -u lab-report -n 30 --no-pager` 

**Причина:**
1. status=217/USER: пользователя lab-report не существует
2. status=203/EXEC: у /opt/lab-report/report.sh права 644, нет бита x.
3. status=1/FAILURE и в журнале ERROR: в /var/lib/lab-report/report.txt: каталога нет.

**Решение:**
1. Добавляем требуемого пользователя:    
`sudo adduser --system --group --no-create-home --quiet lab-report`
2. Добавляем бит x в права:  
`sudo chmod 755 /opt/lab-report/report.sh`  
3. Решаем вопрос с каталогом и записью в него:  
`sudo mkdir -p /var/lib/lab-report && sudo chown lab-report:lab-report /var/lib/lab-report`  

**Проверка**  
systemctl is-active lab-report  
active  
  
systemctl is-enabled lab-report  
enabled  

ps -o user,pid,cmd -p $(systemctl show -p MainPID --value lab-report)  
USER         PID CMD  
lab-rep+  694482 /bin/bash /opt/lab-report/report.sh  
  
sudo tail /var/lib/lab-report/report.txt  
(Видно, что файл растет, немного подождал)  
report 09:24:27  
report 09:24:32  
report 09:24:37  
report 09:24:42  
report 09:24:47  
report 09:24:52  
root@blank-black:~/projects# sudo tail /var/lib/lab-report/report.txt  
report 09:24:37  
report 09:24:42  
report 09:24:47  
report 09:24:52  
report 09:24:57  
report 09:25:02  
report 09:25:07  
report 09:25:12  
report 09:25:18  
report 09:25:23  

**Профилактика:**  
1. Перед деплоем проверять запуск вручную: sudo -u lab-report /opt/lab-report/report.sh.    
2. В процесс выкатки добавить проверку systemctl is-active.   
3. Не используем root и максимальные права(принцип наименьших привилегий): chmod 777 и User=root.  

## OPS-202. Сервер тормозит

**Симптом:**  
Высокая нагрузка на CPU  
**Влияние:**    
Сайт отвечает медленно  
**Диагностика:**    
top   
 PID    PPID USER     %CPU CMD  
 698809       1 lab-cru+ 25.0 /bin/bash /opt/lab-cruncher/crunch.sh  
 685245  685218 root      0.9 /root/.vscode-server/cli/servers/Stable...  
  
ps -eo pid,ppid,user,%cpu,cmd --sort=-%cpu | head -5    
  
systemctl status 698809               # к какой службе относится процесс    
systemctl cat lab-cruncher           # смотри Restart= и CPUQuota=  
root@blank-black:~/projects# systemctl cat lab-cruncher  
#/etc/systemd/system/lab-cruncher.service
[Unit]
Description=Lab nightly cruncher

[Service]
User=lab-crunch
ExecStart=/opt/lab-cruncher/crunch.sh
Restart=always
RestartSec=1
CPUQuota=25%

[Install]
WantedBy=multi-user.target

kill 698809                           # (без -9)
ps -eo pid,user,%cpu,cmd --sort=-%cpu | head -3
ps -eo pid,user,%cpu,cmd --sort=-%cpu | head -3 
    PID USER     %CPU CMD
 699692 lab-cru+ 25.1 /bin/bash /opt/lab-cruncher/crunch.sh     # PID поменялся?
**Причина:**  
1. В скрипте бесконечный пустой цикл, который ничего не делает.
2. lab-crunch, ~25% CPU (ограничено CPUQuota=25%). Запущен службой lab-cruncher.service  
3. kill PID отправляет TERM, процесс умирает, но в unit стоит Restart=always и RestartSec=1:  
   через секунду systemd поднимает его снова, PID новый. Вот почему «оно возврашается».
**Решение:**
sudo systemctl disable --now lab-cruncher

**Проверка**  
systemctl is-active lab-cruncher    
inactive.  
systemctl is-enabled lab-cruncher  
disabled  
uptime/top показывают спад:  
root@blank-black:~/projects# uptime  
 10:10:45 up 28 days, 23:53,  3 users,  load average: 0.41, 0.48, 0.22  
root@blank-black:~/projects# uptime  
 10:10:53 up 28 days, 23:54,  3 users,  load average: 0.34, 0.46, 0.21  
root@blank-black:~/projects# uptime  
 10:10:59 up 28 days, 23:54,  3 users,  load average: 0.32, 0.45, 0.21  

**Профилактика**  
1. Спросить у владельца: что делает служба, зачем нужна и в какое время. 
2. Запуск по расписанию (timer/cron), Nice=, CPUQuota=, MemoryMax=
3. Установить мониторинг загрузки CPU и алерты.  

## OPS-203. Служба долго не останавливается

**Симптом:**  
**Влияние:**  
**Диагностика:**  
`time sudo systemctl stop lab-worker`
real    0m20.242s
user    0m0.004s
sys     0m0.008s  

`systemctl status lab-worker`  


   loaded (/etc/systemd/system/lab-worker.service; disabled; preset: enabled)
     Active: failed (Result: timeout) since Fri 2026-10-30 14:36:01 UTC; 1min 19s ago
   Duration: 21.344s
    Process: 723982 ExecStart=/opt/lab-worker/worker.sh (code=killed, signal=KILL)
   Main PID: 723982 (code=killed, signal=KILL)
        CPU: 5ms  

**Причина:**  
Причина: в скрипте trap '' TERM HUP игнорирует TERM, как stubborn.sh; systemd ждёт таймаут и добивает KILL. Тот же приём (игнор) наследуют и дочерние процессы, в том числе длинный sleep 60. Из-за KILL «последняя пачка данных» не сохраняется.
**Решение:**  
Надо исправить скрипт(проблема в нем)
bash
#!/bin/bash
trap 'echo "worker: получил TERM, сохраняю и завершаюсь"; exit 0' TERM
echo "worker: старт"
while true; do
  echo "worker: обрабатываю пачку"
  sleep 60 &
  wait $!
done

**Проверка и профилактика:**  
root@blank-black:~/projects/devops-4weeks/week-01-linux/lesson-02-processes-systemd-ssh# sudo systemctl start lab-worker
root@blank-black:~/projects/devops-4weeks/week-01-linux/lesson-02-processes-systemd-ssh# time sudo systemctl stop lab-worker

real    0m0.030s
user    0m0.002s
sys     0m0.007s
root@blank-black:~/projects/devops-4weeks/week-01-linux/lesson-02-processes-systemd-ssh# journalctl -u lab-worker -n 10


Oct 30 14:42:31 blank-black.ptr.network worker.sh[725612]: worker: старт
Oct 30 14:42:31 blank-black.ptr.network worker.sh[725612]: worker: обрабатываю пачку
Oct 30 14:42:49 blank-black.ptr.network systemd[1]: Stopping lab-worker.service - Lab batch worker...
Oct 30 14:42:49 blank-black.ptr.network worker.sh[725612]: worker: получил TERM, сохраняю и завершаюсь
Oct 30 14:42:49 blank-black.ptr.network systemd[1]: lab-worker.service: Deactivated successfully.
Oct 30 14:42:49 blank-black.ptr.network systemd[1]: Stopped lab-worker.service - Lab batch worker.

Oct 30 14:42:31 blank-black.ptr.network worker.sh[725612]: worker: обрабатываю пачку
Oct 30 14:42:49 blank-black.ptr.network systemd[1]: Stopping lab-worker.service - Lab batch worker...
Oct 30 14:42:49 blank-black.ptr.network worker.sh[725612]: worker: получил TERM, сохраняю и завершаюсь
Oct 30 14:42:49 blank-black.ptr.network systemd[1]: lab-worker.service: Deactivated successfully.
Oct 30 14:42:49 blank-black.ptr.network systemd[1]: Stopped lab-worker.service - Lab batch worker.
Про HUP: SIGHUP приходит при закрытии терминала. У службы под systemd терминала нет, поэтому игнорировать HUP не нужно;
## OPS-204. Ключ не принимается

**Симптом:**    
**Влияние:**    
**Диагностика:**   
**Причина:**    
**Решение:**  
**Профилактика**

# Итог

## Что было сложным

(2-3 предложения)

## Что я теперь буду делать иначе

(2-3 предложения)
