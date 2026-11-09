
# Урок 4. Bash и cron

## Задание 1. Первые скрипты

1. 
### hello.sh






3. 
Команда:
`bash hello.sh`
Вывод:    
Привет, kostya! Сейчас 09:02  

Команда:  
`./hello.sh`
Вывод:    
Permission denied    
  
Объяснение.    
В первом случае отработало корректно, во втором - в доступе отказано.  
bash hello.sh работает, потому что тут исполняется программа bash, а hello.sh это просто текстовый файл, который она читает как аргумент; право x на скрипт не нужно, достаточно права чтения r. ./hello.sh просит ядро выполнить сам файл, а ядро делает это только при наличии бита x. Поэтому без x отказ в доступе.



### greeting.sh
#!/bin/bash
echo "Привет, $USER! Сейчас $(date +%H:%M)"


## Задание 2. Кавычки
 ls #1(без кавычек)  
 Вывод:
 Создались два файла: report.txt и Q3:    

 ls #2(с кавычками):  
 Добавился файл "Q3 report.txt"    

Проверка:  
Создаем нужные каталоги и файлы. Пробуем запустить скрипт.
`mkdir -p "/tmp/my reports" && touch "/tmp/my reports/a.txt" "/tmp/my reports/b c.txt"`
`./count.sh "/tmp/my reports"`
Вывод:  
2



## Задание 3. Коды возврата
1. 
Команда:
`true; echo $?`
Вывод:
0  

Команда:    
`false; echo $?`    
Вывод:    
1      
  
Команда:  
`ls /root; echo $?`    
Вывод:  
0      
  
Команда:  
`grep -q kostya /etc/passwd; echo $?`    
Вывод:  
0        
  
Команда:  
`grep -q vasya123 /etc/passwd; echo $?`  
Вывод:  
1  

2. Почему 0:  
   Если проверка осуществляется под root, тогда 0. Если пользователь не root -> Permission denied.  
   Ни у одного пользователя нет прав просматривать каталог root'а.  
3. Почему с pipefail иначе:  

cat #1 - код 0
cat №2 - код 1

Без pipefail код конвейера равен коду ПОСЛЕДНЕЙ команды. cat упал (код 1), но gzip получил пустой вход, спокойно упаковал «ничего» и вернул 0 -> весь конвейер выглядит успешным(это ловушка).  
С pipefail конвейер возвращает код последней команды, завершившейся ошибкой, то есть 1.
Файл /tmp/x.gz создался в обоих случаях, потому что перенаправление > /tmp/x.gz выполняет shell ДО запуска команд, и файл открывается (создаётся/обнуляется) сразу. gzip потом записал в него правильный gzip-контейнер пустых данных (~20 байт). pipefail меняет код возврата, но не отменяет уже созданный файл.

## Задание 4. health.sh
Скрипт: scripts/health.sh
```
вывод ./health.sh и код 0(вывод корректен - все проверки пройдены штатно)
./health.sh;    echo "код: $?"
OK disk 51%
OK mem 998MB available
OK ssh active  
код: 0  
    
вывод ./health.sh 1 и код 1(намеренно нарушили проверку по диску -> FAIL DISK)  
./health.sh 1;  echo "код: $?"
FAIL disk 51% > 1%
OK mem 998MB available
OK ssh active
код: 1


## Задание 5. cron
- Часовой пояс:

Time zone - Etc/UTC(UTC, +0000)  

- PATH у cron:
- PATH у меня:
root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux/lesson-04-bash-cron/scripts# cat /tmp/cron-env.txt
HOME=/root
LOGNAME=root
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin
LANG=en_US.UTF-8
SHELL=/bin/sh
PWD=/root
root@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux/lesson-04-bash-cron/scripts# env | wc -l
33
- Расписания:  
*/15 * * * *   /путь/требуемая_команда        # каждые 15 минут  
30 2 * * *     /путь/требуемая_команда        # каждый день в 02:30  
0 18 * * 1-5   /путь/требуемая_команда        # по будням в 18:00  
0 4 * * 0      /путь/требуемая_команда        # воскресенье, 04:00 (можно и 7)  

## OPS-401
- **Симптом:**
- **Влияние:**
- **Диагностика:**  
# пусто
 ls -l /opt/ops401/backups
total 0  

# Проверяем журнал и что задание есть
sudo journalctl -u cron --since "10 min ago" | grep ops401 | tail
 blank-black.ptr.network CRON[1045133]: (root) CMD (/opt/ops401/backup.sh)   

cat /etc/cron.d/ops401   
*/2 * * * * root /opt/ops401/backup.sh  

- **Причина:**  
oot@blank-black:/home/kostya/projects/devops-4weeks/week-01-linux/lesson-04-bash-cron/scripts# cat /tmp/ops401-debug.log
/opt/ops401/backup.sh: line 2: ./backup.conf: No such file or directory
tar: : Cannot open: No such file or directory
tar: Error is not recoverable: exiting now
backup done

Причины:
1. source ./backup.conf относительный путь. Cron запускает задачу из домашнего каталога (/root), а не из /opt/ops401, поэтому конфиг не найден. Руками «работало», потому что Андрей сначала делал cd /opt/ops401.
2. packit лежит в /usr/local/bin, а у cron PATH=/usr/bin:/bin. У sudo же есть secure_path, включающий /usr/local/bin, поэтому у Андрея руками находилось.
3. Скрипт без set -e и без проверок, а последняя команда echo "backup done" всегда успешна, поэтому код возврата 0 и сообщение «готово» при провале(в этом и есть ловушка)
- **Решение:**
Обновленный файл backup.sh  

```
```bash
#!/bin/bash
set -euo pipefail

export PATH=/usr/local/bin:/usr/bin:/bin
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo "$(date '+%F %T') $*"; }

# shellcheck source=/dev/null
source "$SCRIPT_DIR/backup.conf"
: "${SRC:?SRC не задан в backup.conf}"
: "${DST_DIR:?DST_DIR не задан в backup.conf}"

[ -d "$SRC" ] || { log "FAIL: нет каталога $SRC" >&2; exit 1; }
mkdir -p "$DST_DIR"

ARCHIVE="$DST_DIR/data-$(date +%F-%H%M).tar.gz"
TMP="$ARCHIVE.tmp"
trap 'rm -f "$TMP"' EXIT

/usr/local/bin/packit "$TMP" "$SRC"
mv "$TMP" "$ARCHIVE"
log "backup done: $ARCHIVE"

```

Обновление  crontab:

PATH=/usr/local/bin:/usr/bin:/bin
*/2 * * * * root /opt/ops401/backup.sh >> /opt/ops401/backup.log 2>&1

- **Проверка:**
`ls -l /opt/ops401/backups`
`cat /opt/ops401/backup.log`
`tar -tzf /opt/ops401/backups/data-*.tar.gz`
`sudo journalctl -u cron --since "5 min ago" | grep ops401`

root@blank-black:/opt/ops401/backups# ls -l /opt/ops401/backups
total 4
-rwxr-xr-x 1 root root 611 Nov  9 11:10 backup.sh

Каждые 2 минуты пишется:
sudo journalctl -u cron --since "5 min ago" | grep ops401
Nov 09 11:10:01 blank-black.ptr.network CRON[1045864]: (root) CMD (/opt/ops401/backup.sh)
Nov 09 11:10:01 blank-black.ptr.network CRON[1045868]: (root) CMD (/opt/ops401/backup.sh >> /tmp/ops401-debug.log 2>&1)
Nov 09 11:12:01 blank-black.ptr.network CRON[1046347]: (root) CMD (/opt/ops401/backup.sh)
Nov 09 11:12:01 blank-black.ptr.network CRON[1046348]: (root) CMD (/opt/ops401/backup.sh >> /tmp/ops401-debug.log 2>&1)



- **Профилактика:**
1. полные пути в cron(относительные не используем НИКОГДА);
2. cd/путь от $0 в скриптах;
3. Устанавливаем set -euo pipefail(чтобы не было ложных "успехов");
4. Всегда пишем лог с датами;
5. мониторинг «свежести» бэкапа (например, «нет архива новее 25 часов → тревога с уведомлением»); 
6. регулярный тест восстановления на актуальную дату.


## OPS-402
(те же пункты)

## OPS-403
(те же пункты)
- **Что было бы с rm:**

## OPS-404

## Вопросы для самопроверки
1. Shebang #!/bin/bash первая строка, указывает ядру, какой интерпретатор запускать. Без неё скрипт выполнит текущий shell (в cron это /bin/sh). Скрипт, запущенный как bash script.sh, shebang игнорирует.    
2. 0 = успех. Все механизмы (if, &&, cron, systemd) судят по коду. Если при ошибке вернуть 0, ошибка не будет замечена, никто не узнает, что бэкап не сделан.  
3. "$VAR" передаёт значение как одно слово; $VAR разрезается по пробелам и подвержен раскрытию *. Пример: F="Q3 report.txt"; rm $F пытается удалить Q3 и report.txt.  
4. set -e: падение команды останавливает скрипт (cp /nope /tmp и дальше код не выполняется). set -u: необъявленная переменная это ошибка (опечатка $DESTDIR вместо $DEST_DIR). pipefail: падение любой части конвейера делает его неуспешным (cat /nope | gzip)  
5. false | true даёт 0 (код последней команды). С pipefail даёт 1   
6. Любые три из: урезанный PATH (команда не найдена); другой текущий каталог (относительные пути); нет .bashrc, переменных и алиасов; вывод потерян; нет права x на скрипт; CRLF; неверная часовая зона; неэкранированный % в crontab; в /etc/cron.d файл с точкой в имени или неверные права; нет пользователя в строке /etc/cron.d
7. */15 * * * 1-5 /полный/путь/команда  
8. flock -n /run/lock/имя.lock /полный/путь/команда


## Что было непонятно
````
