# Урок 2. Процессы, systemd, SSH-ключи: мои ответы

# Часть A. Практика

## Задание 1. Разведка

1. PID моего Shell, PID Родителя + команда?

# Shell
Команда:
echo $$
Вывод:
656326

# Родитель + команда 
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

| Шаг | Сигнал | Что произошло с процессом | Код возврата |
|---|---|---|---|
| 4 (tick.sh) | TERM | | |
| 5 (sleep) | TERM | | |
| 6 (stubborn.sh) | TERM | | |
| 7 (stubborn.sh) | KILL | | |

 Почему `stubborn.sh` пережил `SIGTERM`, а `SIGKILL` его убил:
 
 trap '' TERM приказывает процессу игнорировать SIGTERM. SIGKILL (как и SIGSTOP) нельзя перехватить или игнорировать: его выполняет само ядро, процесс его даже не «видит». При KILL настоящая программа потеряла бы несохраненные данные в файл или БД, оставила бы временные файлы и не сняла блокировки.




## Задание 3. Свой сервис

Unit-файл:

```ini
(вставь файл)
```

Объяснение строк:

(по каждой строке)

Выводы шагов 1-6:

(команды и вывод)

Разница между `kill -9` и `systemctl stop`:

(твои слова)

## Задание 4. Кто стучится на сервер

(Команды, количество попыток, топ-5 логинов, вывод.)

## Задание 5. Вход по ключу

(Отпечаток ключа, права, `whoami`, `id`, `sudo whoami`. БЕЗ приватного ключа.)

## Задание 6. Закрываем root и пароль

(Вывод `sshd -T` до и после, проверки входа, объяснение про `10-hardening.conf`.)

## Задание 7. Своими словами

1. (ответ)
2. (ответ)
3. (ответ)
4. (ответ)
5. (ответ)

# Часть B. Тикеты

## OPS-201. Служба отчётов не стартует

**Симптом:**
**Влияние:**
**Диагностика:**
**Причина:**
**Решение:**
**Проверка и профилактика:**

## OPS-202. Сервер тормозит

**Симптом:**
**Влияние:**
**Диагностика:**
**Причина:**
**Решение:**
**Проверка и профилактика:**

## OPS-203. Служба долго не останавливается

**Симптом:**
**Влияние:**
**Диагностика:**
**Причина:**
**Решение:**
**Проверка и профилактика:**

## OPS-204. Ключ не принимается

**Симптом:**
**Влияние:**
**Диагностика:**
**Причина:**
**Решение:**
**Проверка и профилактика:**

# Итог

## Что было сложным

(2-3 предложения)

## Что я теперь буду делать иначе

(2-3 предложения)
