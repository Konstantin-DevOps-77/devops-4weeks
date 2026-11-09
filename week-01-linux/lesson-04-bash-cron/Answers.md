
# Урок 4. Bash и cron

## Задание 1. Первые скрипты

1. 
### hello.sh
```bash
#!/bin/bash
echo "Привет, $USER! Сейчас $(date +%H:%M)"
```

### greet.sh
```bash
#!/bin/bash
# greet.sh
if [ $# -lt 1 ]; then
  echo "Использование: $0 <имя>" >&2
  exit 1
fi
echo "Привет, $1"
```

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
count.sh
```bash
#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Использование: $0 <каталог>" >&2
  exit 1
fi

dir="$1"
if [ ! -d "$dir" ]; then
  echo "Ошибка: $dir не каталог" >&2
  exit 1
fi

count=0
for f in "$dir"/*; do
  if [ -f "$f" ]; then
    count=$((count + 1))
  fi
done
echo "$count"

```

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
```bash 
#!/bin/bash
# health.sh [порог_диска_в_%]  — проверка диска, памяти и ssh
set -euo pipefail

THRESHOLD="${1:-80}"        # аргумент или 80 по умолчанию
MIN_MEM_MB=200
fail=0                      # станет 1, если хоть одна проверка провалилась

log() {
  echo "$(date '+%F %T') $*"
}

# Порог должен быть числом, иначе сравнение ниже сломается
if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]]; then
  echo "Использование: $0 [порог_в_процентах]" >&2
  exit 2
fi

# 1. Диск
disk=$(df --output=pcent / | tail -1 | tr -dc '0-9')
if [ "$disk" -le "$THRESHOLD" ]; then
  log "OK disk ${disk}%"
else
  log "FAIL disk ${disk}% > ${THRESHOLD}%"
  fail=1
fi

# 2. Память (колонка available в free -m)
mem=$(free -m | awk '/^Mem:/ {print $7}')
if [ "$mem" -ge "$MIN_MEM_MB" ]; then
  log "OK mem ${mem}MB available"
else
  log "FAIL mem ${mem}MB available < ${MIN_MEM_MB}MB"
  fail=1
fi

# 3. Служба ssh
if systemctl is-active --quiet ssh; then
  log "OK ssh active"
else
  log "FAIL ssh not active"
  fail=1
fi

exit "$fail"

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


- PATH у меня:
* * * * * /home/ТВОЙ_ПОЛЬЗОВАТЕЛЬ/scripts/health.sh >> /home/ТВОЙ_ПОЛЬЗОВАТЕЛЬ/health.log 2>&1

Проверка(3 минуты)  
`tail -n 12 ~/health.log`
`sudo journalctl -u cron --since "5 min ago" | tail`

Правильно: в логе блоки из трёх строк раз в минуту, в журнале строки CMD (/home/.../health.sh >> ...).  
 Если журнал пустой без sudo, это права доступа, а не отсутствие запусков.


- PATH у cron:
* * * * * env > /tmp/cron-env.txt

через минуту
`cat /tmp/cron-env.txt`
`env | wc -l ; wc -l < /tmp/cron-env.txt`
`grep ^PATH= /tmp/cron-env.txt ; echo "$PATH"`

- PATH у меня:

- Расписания:  
*/15 * * * *   /путь/требуемая_команда        # каждые 15 минут  
30 2 * * *     /путь/требуемая_команда        # каждый день в 02:30  
0 18 * * 1-5   /путь/требуемая_команда        # по будням в 18:00  
0 4 * * 0      /путь/требуемая_команда        # воскресенье, 04:00 (можно и 7)  

## OPS-401   

- **Симптом:**
Не делаются резервные копии  
- **Влияние:**  
Невозможно откатить систему.  
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

1. source ./backup.conf относительный путь. Cron запускает задачу из домашнего каталога (/root), а не из /opt/ops401, поэтому конфиг не найден. Руками «работало», потому что Андрей сначала делал cd /opt/ops401.
2. packit лежит в /usr/local/bin, а у cron PATH=/usr/bin:/bin. У sudo же есть secure_path, включающий /usr/local/bin, поэтому у Андрея руками находилось.
3. Скрипт без set -e и без проверок, а последняя команда echo "backup done" всегда успешна, поэтому код возврата 0 и сообщение «готово» при провале(в этом и есть ловушка)
**Решение:**

Обновленный файл backup.sh  
/hom
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
- **Симптом:**  
Файл лога не заполняется  
- **Влияние:**  
Отчеты аналитиков приходят пустыми  
- **Диагностика:**  
`tail -n 20 /var/log/ops402.log`
root@blank-black:/opt/ops401# tail -n 20 /var/log/ops402.log
cat: '/opt/ops402/data/*.csv': No such file or directory
2026-11-09 11:34:01 OK: /opt/ops402/out/export-2026-11-09.csv.gz
После переезда данные лежат в /opt/ops402/incoming, а скрипт читает /opt/ops402/data/*.csv (каталога нет!!!)  
+ ловушка конвейера о якобы "успехе"  

`grep -v ': /opt' /var/log/ops402.log | head`  
2026-11-09 11:34:01 OK: /opt/ops402/out/export-2026-11-09.csv.gz
root@blank-black:/opt/ops401# grep -v ': /opt' /var/log/ops402.log | head
cat: '/opt/ops402/data/*.csv': No such file or directory
cat: '/opt/ops402/data/*.csv': No such file or directory
Лог отсутствует.  
  
`zcat /opt/ops402/out/export-*.csv.gz`
Пусто  


`ls /opt/ops402/ /opt/ops402/incoming/`  
/opt/ops402/:
export.sh  incoming  out

/opt/ops402/incoming/:
clients.csv  sales.csv

Каталога data нет, CSV лежат в incoming


- **Причина:**  
1. После переезда данные лежат в /opt/ops402/incoming, а скрипт читает /opt/ops402/data/*.csv (каталога нет).
2. Классическая ловушка конвейера: cat ... | gzip без pipefail; код конвейера = код gzip = 0.
3. Проверка if [ $? -eq 0 ] смотрит на этот ложный нуль, поэтому пишет «OK».
4. Ветка FAIL не делает exit с ненулевым кодом, значит даже честный «FAIL» выглядел бы для cron как успех.
5. >"$OUT" создаёт (обнуляет) итоговый файл до обработки, поэтому при ошибке остаётся пустой «архив». Он ещё и выглядит как успешный результат.  

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

#Правильная проверка

root@blank-black:/opt/ops402# sudo /opt/ops402/export.sh; echo "код: $?"
2026-11-09 11:45:12 OK: /opt/ops402/out/export-2026-11-09.csv.gz
код: 0
root@blank-black:/opt/ops402# zcat /opt/ops402/out/export-$(date +%F).csv.gz
id,city
1,Москва
2,Казань
id,sum
1,100
2,250

#Ложная проверка
root@blank-black:/opt/ops402# sudo mv /opt/ops402/incoming /opt/ops402/incoming.off
root@blank-black:/opt/ops402# sudo rm -f /opt/ops402/out/export-*.csv.gz
root@blank-black:/opt/ops402# sudo /opt/ops402/export.sh; echo "код: $?"
2026-11-09 11:46:15 FAIL: нет каталога /opt/ops402/incoming
код: 1
root@blank-black:/opt/ops402# ls /opt/ops402/out/
root@blank-black:/opt/ops402# sudo mv /opt/ops402/incoming.off /opt/ops402/incoming

- **Профилактика:**
1. всегда set -euo pipefail;
2. не проверять $? после команды, а ставить команду в if;
3. ненулевой код при ошибке;
4. проверка входных данных до начала работы(правильность и "как должно быть");
5. Запись через временный файл;
6. мониторинг не только «задача запустилась», но и «результат не пуст» (например, ненулевой размер архива и актуальная дата).

- **Что было бы с rm:**


## OPS-403
- **Симптом:**  
Не хватает части данных  
- **Влияние:**  
Часть данных переносится, часть нет. Появляется сообщение, что данные archived
- **Диагностика:**  
`ls -1 /opt/ops403/reports`
'plan 2027 final.txt'   
'Q3 report.txt'    
salary.txt  
sales.txt  

`sudo /opt/ops403/archive.sh; echo "код: $?"`
mv: cannot stat 'plan': No such file or directory
mv: cannot stat '2027': No such file or directory
mv: cannot stat 'final.txt': No such file or directory
mv: cannot stat 'Q3': No such file or directory
mv: cannot stat 'report.txt': No such file or directory
archived
код: 0 

`ls -1 /opt/ops403/reports /opt/ops403/archive`
/opt/ops403/archive:
salary.txt
sales.txt

/opt/ops403/reports:
'plan 2027 final.txt'
'Q3 report.txt'

- **Причина:**  
1. for f in $(ls): вывод ls режется по пробелам, Q3 report.txt превращается в два «файла» Q3 и report.txt, а plan 2027 final.txt в три.(проблема кавычек).в скрипте for f in $(ls); do rm $f; done файл с именем * важное.txt дал бы слова * и важное.txt  
2. mv $f ... без кавычек: даже если бы имя дошло целиком, оно снова разрезалось бы.  
3. Нет set -e и проверки результата mv, а финальный echo "archived" всегда успешен: сообщение «готово» и код 0 при провале.    

- **Решение:**
Обновленный файл 

```bash 
#!/bin/bash
set -euo pipefail

SRC=/opt/ops403/reports
DST=/opt/ops403/archive

[ -d "$SRC" ] || { echo "нет каталога $SRC" >&2; exit 1; }
[ -d "$DST" ] || { echo "нет каталога $DST" >&2; exit 1; }

count=0
for f in "$SRC"/*; do
  [ -f "$f" ] || continue                  # пропуск, если файлов нет (шаблон не раскрылся) или это не файл
  name="${f##*/}"
  if [ -e "$DST/$name" ]; then
    echo "ошибка: $name уже есть в архиве, остановка" >&2
    exit 1
  fi
  mv -- "$f" "$DST/"
  count=$((count + 1))
done

echo "archived: $count files"

```
- **Проверка:**
#Проверили архивацию
root@blank-black:/opt/ops403# sudo /opt/ops403/archive.sh; echo "код: $?"
archived: 2 files
код: 0

#Смотрим в репортс(пусто)
root@blank-black:/opt/ops403# ls -1 /opt/ops403/reports

#Теперь все файлы на месте(archive)
root@blank-black:/opt/ops403# ls -1 /opt/ops403/archive
'plan 2027 final.txt'
'Q3 report.txt'
salary.txt
sales.txt

Вывод.
В скрипте for f in $(ls); do rm $f; done файл с именем * важное.txt дал бы слова * и важное.txt. Звёздочка без кавычек раскрывается bash в имена всех файлов текущего каталога, поэтому rm * УДАЛИЛ БЫ ВСЕ СОДЕРЖИМОЕ КАТАЛОГА, включая важные отчёты, и без корзины, безвозвратно. Слово важное.txt дополнительно дало бы ошибку «нет такого файла», а скрипт всё равно написал бы «готово».

- **Профилактика:**
1. шаблон скрипта со строгим режимом; 
2. Тестовые файлы с пробелами, * и кириллицей в именах как обязательная часть теста.

## OPS-404
 **Симптом:**  
Дублируются отчеты 
- **Влияние:**  
Время обработки увеличено -> нагрузка на систему возросла
- **Диагностика:** 

#Пересечение и дублирование отчетов
`cat /var/log/ops404.log`
2026-11-09 12:20:01 start pid=1051492
2026-11-09 12:21:01 start pid=1051722
2026-11-09 12:21:31 end   pid=1051492
2026-11-09 12:22:01 start pid=1051758

`ps -eo pid,lstart,cmd | grep '[r]eport.sh'`
1051845 Mon Nov  9 12:23:01 2026 /bin/sh -c /opt/ops404/report.sh >> /var/log/ops404.log 2>&1
1051849 Mon Nov  9 12:23:01 2026 /bin/bash /opt/ops404/report.sh

`pgrep -af report.sh`
1051890 /bin/sh -c /opt/ops404/report.sh >> /var/log/ops404.log 2>&1
1051895 /bin/bash /opt/ops404/report.sh

`grep -v ': /opt' /var/log/ops402.log | head`  
2026-11-09 11:34:01 OK: /opt/ops402/out/export-2026-11-09.csv.gz
root@blank-black:/opt/ops401# grep -v ': /opt' /var/log/ops402.log | head
cat: '/opt/ops402/data/*.csv': No such file or directory
cat: '/opt/ops402/data/*.csv': No such file or directory
Лог отсутствует.  
  
`zcat /opt/ops402/out/export-*.csv.gz`
Пусто  


`ls /opt/ops402/ /opt/ops402/incoming/`  
/opt/ops402/:
export.sh  incoming  out

/opt/ops402/incoming/:
clients.csv  sales.csv

Каталога data нет, CSV лежат в incoming


- **Причина:**  
1. После переезда данные лежат в /opt/ops402/incoming, а скрипт читает /opt/ops402/data/*.csv (каталога нет).
2. Классическая ловушка конвейера: cat ... | gzip без pipefail; код конвейера = код gzip = 0.
3. Проверка if [ $? -eq 0 ] смотрит на этот ложный нуль, поэтому пишет «OK».
4. Ветка FAIL не делает exit с ненулевым кодом, значит даже честный «FAIL» выглядел бы для cron как успех.
5. >"$OUT" создаёт (обнуляет) итоговый файл до обработки, поэтому при ошибке остаётся пустой «архив». Он ещё и выглядит как успешный результат.  

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

#Правильно начинаются и заканчиваются без пересечений

root@blank-black:/opt/ops404# cat /var/log/ops404.log
2026-11-09 12:31:01 start pid=1052765
2026-11-09 12:32:31 end   pid=1052765
2026-11-09 12:33:01 start pid=1052953

#Перехват флоком.

root@blank-black:/opt/ops404# pgrep -af report.sh
1053130 /bin/sh -c /usr/bin/flock -n /run/lock/ops404.lock /opt/ops404/report.sh >> /var/log/ops404.log 2>&1
1053132 /usr/bin/flock -n /run/lock/ops404.lock /opt/ops404/report.sh
1053134 /bin/bash /opt/ops404/report.sh

- **Профилактика:**
1. всегда set -euo pipefail;
2. не проверять $? после команды, а ставить команду в if;
3. ненулевой код при ошибке;
4. проверка входных данных до начала работы(правильность и "как должно быть");
5. Запись через временный файл;
6. мониторинг не только «задача запустилась», но и «результат не пуст» (например, ненулевой размер архива и актуальная дата).

- **Что было бы с rm:**

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
