# Урок 1. Пользователи, права, sudo: мои ответы

Имя: Konstantin

Дата сдачи: 16.10.2026

# Часть A. Практика

## Задание 1. Разведка

```bash
# Задание 1.1
# Количество пользователей с оболочкой /etc/passwd
getent passwd | grep -c ':/bin/bash$'
5

# Считает пользователей, путь к оболочке которых заканчивается на /nologin.
getent passwd | grep -c '/nologin$'
30

# Задание 1.2 UID root, есть ли еще пользователи с таким UID?
id root

# Показывает всех пользователей с UID 0 вместе с их оболочками.
getent passwd | awk -F: '$3 == 0 { print $1 ":" $3 ":" $7 }'

uid=0(root) gid=0(root) groups=0(root)

awk -F: '$3==0 {print $1":"$3}' /etc/passwd
root:0

# Если бы еще был один пользователь с UID 0 -> возможна компрометация/ошибка

# Задание 1.3

# Какие пользователи имеют UID от 1000? Если их нет, так и напиши.
# Показывает пользователей с UID от 1000 включительно и их оболочки.
getent passwd | awk -F: '$3 >= 1000 { print $1 ":" $3 ":" $7 }'
nobody:65534

# Пользователей нет, nobody:(65534) - системная учетная запись с большим номером

# Задание 1.4
# Кто входит в группу sudo?

getent group sudo
sudo:x:27:

# Список после последнего двоеточия — члены группы. Он может быть пустым.

# Задание 1.5
# Сравни права на /etc/passwd и /etc/shadow (только ls -l, содержимое shadow не выводить) и объясни своими словами, почему они разные.

ls -l /etc/passwd /etc/shadow
-rw-r--r-- 1 root root   1793 Oct  1 08:11 /etc/passwd
-rw-r----- 1 root shadow  933 Oct  1 08:11 /etc/shadow
```

Почему права на passwd и shadow разные (своими словами):

- passwd читают все программы, чтобы сопоставлять UID и имена (ls -l, id и т. д.), поэтому он доступен на чтение всем. Паролей в нём нет.
- В shadow лежат хэши паролей. Кто их прочитает, тот сможет подбирать пароли офлайн. Поэтому читать могут только root и группа shadow, остальные не имеют доступа

## Задание 2. Права на практике

Каким способом задавал права для каждого объекта:

### Подготовительная часть.

```bash
cd ~/practice/lesson1/perm
umask                       # 0022 у root
touch public.txt secret.txt team.txt
printf '#!/bin/bash\necho hi\n' > run.sh
mkdir private
stat -c '%A %a %U:%G %n' public.txt secret.txt team.txt run.sh private  

# Исходное состояние
-rw-r--r-- 644 root:root public.txt
-rw-r--r-- 644 root:root secret.txt
-rw-r--r-- 644 root:root team.txt
-rw-r--r-- 644 root:root run.sh
drwxr-xr-x 755 root:root private

#  Выполнение задания

chmod 644 public.txt
chmod 600 secret.txt
chmod o-r team.txt
chmod +x run.sh
chmod go-rwx private

root@blank-black:~/projects/devops-4weeks/lessons/practice/lesson1/perm# stat -c '%A %a %U:%G %n' public.txt secret.txt team.txt run.sh private
-rw-r--r-- 644 root:root public.txt
-rw------- 600 root:root secret.txt
-rw-r----- 640 root:root team.txt
-rwxr-xr-x 755 root:root run.sh
drwx------ 700 root:root private
root@blank-black:~/projects/devops-4weeks/lessons/practice/lesson1/perm# ./run.sh
hi
```

### Переводы:

- `rwxr-x--x` = (751)

  rwxr-x--x: владелец rwx = 4+2+1 = 7, группа r-x = 4+1 = 5, остальные --x = 1 → 751

- `640` = (rw-r-----)

  640: 6 = rw-, 4 = r--, 0 = --- → rw-r-----

- `2775` = (буквы), цифра `2` означает: (особый бит, setgid)

  2775: цифра 2 — особый бит, затем 775 = rwxrwxr-x. Бит 2 — это setgid, он заменяет x у группы на s → rwxrwsr-x. На каталоге это значит: новые файлы наследуют группу каталога.

## Задание 3. Рабочий пользователь

```bash
adduser "konstantin"
usermod -aG sudo 'konstantin'

# Показывает UID и группы нового пользователя для проверки членства в sudo.
id "konstantin"

# Показывает наличие и владельца домашней папки пользователя.
ls -ld "/home/konstantin"

# Открыть сессию от имени рабочего пользователя
su - "konstantin"

# (вывод id ТВОЁ_ИМЯ и sudo whoami)

konstantin@blank-black:~$ sudo whoami
[sudo] password for konstantin: 
root
konstantin@blank-black:~$ id konstantin
uid=1000(konstantin) gid=10dell00(konstantin) groups=1000(konstantin),27(sudo),100(users)
```

Что будет без `-a` в `usermod -G` и чем это опасно (своими словами):

-G заменяет весь список дополнительных групп на указанный. 
Все прежние группы пользователя пропадут, а останется только sudo.
Опасноcть: пользователь потеряет доступ к ресурсам, которые давались через группы,
на системных пользователях можно сломать службы. 
Нужно использовать -aG (append)

## Задание 4. Узкое право sudo

Файл правила:

```bash
# Создаёт лабораторного пользователя lab-ops без установленного пароля.
adduser --disabled-password --gecos '' lab-ops
# Показывает полный путь к systemctl для правила sudoers.
command -v systemctl
# Открывает отдельный файл правила через редактор с проверкой синтаксиса sudoers.
visudo -f /etc/sudoers.d/lab-ops

(содержимое /etc/sudoers.d/lab-ops)
lab-ops ALL=(root) NOPASSWD: /usr/bin/systemctl status ssh

root@blank-black:/srv/lab/deploy# ls -l /etc/sudoers.d/lab-ops
-r--r----- 1 root root 59 Oct 16 06:58 /etc/sudoers.d/lab-ops
root@blank-black:/srv/lab/deploy# sudo -l -U lab-ops

Matching Defaults entries for lab-ops on blank-black:
    env_reset, mail_badpass, secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin, use_pty

User lab-ops may run the following commands on blank-black:
    (root) NOPASSWD: /usr/bin/systemctl status ssh

root@blank-black:/srv/lab/deploy# visudo -c
/etc/sudoers: parsed OK
/etc/sudoers.d/README: parsed OK
/etc/sudoers.d/lab-ops: parsed OK


# Проверки (разрешённая и две запрещённые):

# Проверка №1(разрешено)
su - lab-ops -c 'sudo -n /usr/bin/systemctl status ssh | cat'
● ssh.service - OpenBSD Secure Shell server
     Loaded: loaded (/usr/lib/systemd/system/ssh.service; disabled; preset: enabled)
     Active: active (running) since Thu 2026-10-01 10:17:01 UTC; 2 weeks 0 days ago
TriggeredBy: ● ssh.socket
       Docs: man:sshd(8)
             man:sshd_config(5)
   Main PID: 1019 (sshd)
      Tasks: 1 (limit: 2263)
     Memory: 11.0M (peak: 111.5M)
        CPU: 1h 17min 27.476s
     CGroup: /system.slice/ssh.service
             └─1019 "sshd: /usr/sbin/sshd -D [listener] 0 of 10-100 startups"

# Проверка №23(запрещено)
su - lab-ops -c 'sudo -n /usr/bin/systemctl status cron'
sudo: a password is required

# Проверка №3(запрещено)
su - lab-ops -c 'sudo -n /usr/bin/cat /etc/hostname'
sudo: a password is required
```

Зачем полный путь и чем плох `NOPASSWD: ALL` (своими словами):

### Пояснения

Полный путь: sudo сопоставляет именно конкретный исполняемый файл. 
Если бы разрешалось просто имя, любой смог бы запустить свою программу с таким же именем из своего каталога, и она запустилась бы от root. 
Путь однозначно указывает на системную программу.
NOPASSWD: ALL даёт lab-ops любую команду от root без пароля. 
Это полный root, а задача требовала одну команду (принцип наименьших привилегий). 
К тому же у lab-ops нет пароля(по условию задачи), поэтому никакой защиты не остаётся.

## Задание 5. Головоломка с каталогами

```bash
# Проверяет чтение файла от nobody до исправления и показывает фактический отказ.
sudo -u nobody cat /srv/lab/puzzle/a/b/c/file.txt
# Показывает владельцев и права всех компонентов пути до исправления.
namei -l /srv/lab/puzzle/a/b/c/file.txt

# Добавляет остальным пользователям только право прохода через единственный мешающий каталог.
chmod o+x /srv/lab/puzzle/a/b

# Показывает права всех компонентов пути после исправления.
namei -l /srv/lab/puzzle/a/b/c/file.txt

# Подтверждает успешное чтение файла от nobody после исправления.
sudo -u nobody cat /srv/lab/puzzle/a/b/c/file.txt


(namei -l до, результат sudo -u nobody cat до)

# Результат ДО исправления

namei -l /srv/lab/puzzle/a/b/c/file.txt
f: /srv/lab/puzzle/a/b/c/file.txt
drwxr-xr-x root root /
drwxr-xr-x root root srv
drwxr-xr-x root root lab
drwxr-xr-x root root puzzle
drwxr-xr-x root root a
drwx------ root root b
drwxr-xr-x root root c
-rw-r--r-- root root file.txt

sudo -u nobody cat /srv/lab/puzzle/a/b/c/file.txt
cat: /srv/lab/puzzle/a/b/c/file.txt: Permission denied
```

### Команда исправления:

Минимальное исправление: дать «остальным» только право входа в один этот каталог:

```bash
chmod o+x /srv/lab/puzzle/a/b
```

### Результат после исправления

```bash
namei -l /srv/lab/puzzle/a/b/c/file.txt
f: /srv/lab/puzzle/a/b/c/file.txt
drwxr-xr-x root root /
drwxr-xr-x root root srv
drwxr-xr-x root root lab
drwxr-xr-x root root puzzle
drwxr-xr-x root root a
drwx-----x root root b
drwxr-xr-x root root c
-rw-r--r-- root root file.txt

root@blank-black:~/projects/devops-4weeks/lessons/01-users-permissions# sudo -u nobody cat /srv/lab/puzzle/a/b/c/file.txt
treasure
```

Почему права на file.txt менять не пришлось и как нашёл виновника (своими словами):

Чтобы добраться до файла, нужно право x (вход) на каждом каталоге пути, а потом право r на самом файле. У файла 644 право на чтение уже было. Меняется ровно один каталог - его права становятся 701.
Нашёл виновника через namei -l: он показывает права на каждом уровне, и сразу видно каталог без x для «остальных».
Также: мы дали только x, но не r, поэтому nobody сможет открыть файл по известному имени, но не получит список содержимого b.

## Задание 6. Объясни своими словами

1. r, w, x для каталога:

    r/w/x у каталога:

    - r — можно увидеть список имён внутри;
    - w — можно создавать, переименовывать и удалять записи внутри (нужен вместе с x);
    - x — можно «входить» в каталог и обращаться к элементам по имени. 

    Например, r без x: ls каталог покажет имена, но cat каталог/файл и ls -l каталог дадут Permission denied

2. Почему 777 плохо и что делать при Permission denied:

    Почему 777 плохо: любой пользователь и любая скомпрометированная служба получают право менять и запускать файл(скрипт). 
    Это ломает безопасность. Правильно: определить, кто запускает (id), где обрывается доступ (namei -l), и выдать минимально нужное право нужному пользователю или группе. При Permission denied я проверяю, кем выполняется команда, какие у пользователя группы и где ограничен доступ по пути. Исправлять нужно конкретного владельца, группу или недостающее право, сохраняя ограничения для остальных.

3. Принцип наименьших привилегий и два примера:

    У каждого пользователя и службы ровно те права, что нужны для работы.
    Примеры из урока: 

    - узкое правило sudo для lab-ops (только systemctl status ssh); 
    - config.env с 640 для группы приложения вместо 644/777; 
    - o+x только на одном каталоге в задании 5

4. Почему «у меня под root работало» не аргумент: (ответ)

    root обладает максимальными правами и поэтому он обходит ограничения обычных файловых прав в системе, следовательно успех под root ничего не доказывает. 
    В реальной системе  приложение работает под служебным пользователем, и проблемы проявятся именно там. 
    Проверять нужно от того пользователя, от которого всё будет работать.

# Часть B. Тикеты

## OPS-101. Сервис не стартует после деплоя

**Симптом:**

```bash
sudo -u lab-app /srv/lab/app/run.sh
sudo: unable to execute /srv/lab/app/run.sh: Permission denied
```

**Влияние:**

 Пользователь lab-app не может запустить run.sh

**Диагностика:**

```bash
# Воспроизводит ошибку запуска приложения от его служебного пользователя.
sudo -u lab-app /srv/lab/app/run.sh
# Диагностика
id lab-app
ls -ld /srv/lab/app
ls -l /srv/lab/app
namei -l /srv/lab/app/run.sh

(команды и выводы: id, ls -l, namei -l)
```

**Причина:**

1. Каталог /srv/lab/app имеет 700 root:root.
lab-app для него «остальной», у него нет x, поэтому он не может даже дойти до run.sh

2. config.env имеет 600 root:root, и lab-app не может его прочитать.

**Решение:**

```bash
#1 даем группе lab-app вход в каталог(без остальных - им ничего)
chown root:lab-app /srv/lab/app
chmod 750 /srv/lab/app
sudo -u lab-app /srv/lab/app/run.sh

#2 Скрипт может исполнять только owner и lab-app

chgrp lab-app /srv/lab/app/config.env
chmod 640 /srv/lab/app/config.env
(команды)
```

**Проверка и профилактика:**

```bash
root@blank-black:~/projects/devops-4weeks/lessons/01-users-permissions# sudo -u lab-app /srv/lab/app/run.sh
App started, connecting to db.internal

root@blank-black:~/projects/devops-4weeks/lessons/01-users-permissions# sudo -u nobody cat /srv/lab/app/config.env
cat: /srv/lab/app/config.env: Permission denied

root@blank-black:~/projects/devops-4weeks/lessons/01-users-permissions# sudo -u nobody ls /srv/lab/app
ls: cannot open directory '/srv/lab/app': Permission denied
```

Профилактика: 
Проверять владельца, группу, права каталога и конфига при деплое, а запуск проверять от служебного пользователя с контролем полного вывода.

Общая причина:

Cлужебный пользователь не имел права входа в каталог (700 root), а после этого не мог прочитать конфиг (600 root). Скрипт при этом не падал

## OPS-102. Общая папка команды

**Симптом:**

```bash
// Пробуем дописать в notes от имени lab-dev2
su - lab-dev2 -c 'echo "from dev2" >> /srv/lab/shared/notes.txt'
-bash: line 1: /srv/lab/shared/notes.txt: Permission denied
```

**Влияние:**

Пользователь lab-dev2 не может ничего записать в notes.txt(lab-dev1 может)

**Диагностика:**

```bash
root@blank-black:~/projects/devops-4weeks/lessons/01-users-permissions# id lab-dev1
uid=1003(lab-dev1) gid=1003(lab-dev1) groups=1003(lab-dev1),100(users),1002(lab-team)
root@blank-black:~/projects/devops-4weeks/lessons/01-users-permissions# id lab-dev2
uid=1004(lab-dev2) gid=1004(lab-dev2) groups=1004(lab-dev2),100(users),1002(lab-team)
```

**Причина:**

```bash
root@blank-black:~/projects/devops-4weeks/lessons/01-users-permissions# ls -ld /srv/lab/shared
drwxrwx--- 2 root lab-team 4096 Oct 16 05:48 /srv/lab/shared
root@blank-black:~/projects/devops-4weeks/lessons/01-users-permissions# ls -l /srv/lab/shared
total 4
-rw-rw-r-- 1 lab-dev1 lab-dev1 16 Oct 16 05:48 notes.txt
root@blank-black:~/projects/devops-4weeks/lessons/01-users-permissions# su - lab-dev1 -c umask
0002
```

 Каталог 770 root:lab-team, оба в группе lab-team, но notes.txt создан как -rw-rw-r-- lab-dev1 lab-dev1. Файл получил основную группу создателя (lab-dev1), а не lab-team, поэтому для lab-dev2 он «чужой» и доступен только на чтение.

**Решение:**

```bash
su - lab-dev1 -c 'echo "new file" > /srv/lab/shared/new.txt'
root@blank-black:~/projects/devops-4weeks/lessons/01-users-permissions# chmod g+s /srv/lab/shared
root@blank-black:~/projects/devops-4weeks/lessons/01-users-permissions# chgrp lab-team /srv/lab/shared/notes.txt
root@blank-black:~/projects/devops-4weeks/lessons/01-users-permissions# chmod g+w /srv/lab/shared/notes.txt
root@blank-black:~/projects/devops-4weeks/lessons/01-users-permissions# ls -ld /srv/lab/shared
drwxrws--- 2 root lab-team 4096 Oct 16 05:48 /srv/lab/shared
```

**Проверка и профилактика:**

```bash
# Создаёт новый файл от первого разработчика для проверки наследования группы и доступа.
su - lab-dev1 -c 'echo "new file from dev1" > /srv/lab/shared/new.txt'

# Проверяет дописывание в новый файл от второго разработчика.
su - lab-dev2 -c 'echo "added by dev2" >> /srv/lab/shared/new.txt'

# Проверяет дописывание в существовавший до исправления файл от второго разработчика.
su - lab-dev2 -c 'echo "added to old file by dev2" >> /srv/lab/shared/notes.txt'

# Показывает группу и права старого и нового файлов.
ls -l /srv/lab/shared/notes.txt /srv/lab/shared/new.txt

# Подтверждает чтение обоих общих файлов от второго разработчика.
su - lab-dev2 -c 'cat /srv/lab/shared/notes.txt /srv/lab/shared/new.txt'

# Создаёт дополнительный файл с ограничивающим umask для проверки default ACL.
su - lab-dev1 -c 'umask 0077; echo "ACL check" > /srv/lab/shared/acl-check.txt'

# Проверяет сохранение групповой записи при ограничивающем umask создателя.
su - lab-dev2 -c 'echo "dev2 can append" >> /srv/lab/shared/acl-check.txt'

# Проверяет запрет просмотра списка файлов посторонним пользователем.
sudo -u nobody ls /srv/lab/shared

# Проверяет запрет чтения общего файла посторонним пользователем по известному имени.
sudo -u nobody cat /srv/lab/shared/new.txt

su - lab-dev1 -c 'echo "new file" > /srv/lab/shared/new.txt'
root@blank-black:~/projects/devops-4weeks/lessons/01-users-permissions# ls -l /srv/lab/shared
total 8
-rw-rw-r-- 1 lab-dev1 lab-team  9 Oct 16 06:02 new.txt
-rw-rw-r-- 1 lab-dev1 lab-team 16 Oct 16 05:48 notes.txt
root@blank-black:~/projects/devops-4weeks/lessons/01-users-permissions# su - lab-dev2 -c 'echo "dev2 to new" >> /srv/lab/shared/new.txt'
root@blank-black:~/projects/devops-4weeks/lessons/01-users-permissions# su - lab-dev2 -c 'echo "dev2 to old" >> /srv/lab/shared/notes.txt'
root@blank-black:~/projects/devops-4weeks/lessons/01-users-permissions# cat /srv/lab/shared/new.txt /srv/lab/shared/notes.txt
new file
dev2 to new
notes from dev1
dev2 to old
root@blank-black:~/projects/devops-4weeks/lessons/01-users-permissions# sudo -u nobody ls /srv/lab/shared
ls: cannot open directory '/srv/lab/shared': Permission denied
```

(как не допустить повторения)

Профилактика: 
Общие рабочие каталоги всегда создавать с группой команды и setgid (2770); umask 0002 у пользователей.
Лишние привилегии не назначаем(принцип наименьших привилегий)

Общая причина:

Второй пользователь группы lab-team не имел возможность записать ничего в файл, потому что при создании он наследовал группу владельца и другие пользователи были для него "чужими"

## OPS-103. Скрипт деплоя не запускается

### Воспроизведение ошибки

Переходим в каталог деплоя и пытаемся запустить скрипт

```bash
root@blank-black:~/projects/devops-4weeks/lessons/01-users-permissions# cd /srv/lab/deploy
root@blank-black:/srv/lab/deploy# ./deploy.sh
bash: ./deploy.sh: Permission denied
root@blank-black:/srv/lab/deploy# ls -l deploy.sh
-rw-r--r-- 1 root root 60 Oct 16 06:22 deploy.sh
```

### Ошибка 1

 Permission denied; у файла 644 — нет бита x(он не может выполниться)

### Добавляем права

```bash
root@blank-black:/srv/lab/deploy# chmod u+x deploy.sh
root@blank-black:/srv/lab/deploy# ./deploy.sh
root@blank-black:/srv/lab/deploy# ./deploy.sh
bash: ./deploy.sh: cannot execute: required file not found
```

Файл на месте, но «не найден» интерпретатор: в первой строке #!/bin/bash\r, то есть Linux ищет программу с именем bash + символ возврата каретки.

### Ошибка 2

В конце видно M$

```bash
root@blank-black:/srv/lab/deploy# file deploy.sh
deploy.sh: Bourne-Again shell script, ASCII text executable, with CRLF line terminators
root@blank-black:/srv/lab/deploy# cat -A deploy.sh
#!/bin/bash^M$
echo "Deploy started"^M$
echo "Deploy finished"^M$
```

### Убираем CRLF и восстанавливаем нормальную работу

```bash
root@blank-black:/srv/lab/deploy# sed -i 's/\r$//' deploy.sh
root@blank-black:/srv/lab/deploy# file deploy.sh
deploy.sh: Bourne-Again shell script, ASCII text executable
root@blank-black:/srv/lab/deploy# cat -A deploy.sh
#!/bin/bash$
echo "Deploy started"$
echo "Deploy finished"$
```

### Как не допустить повторения с Windows

1) В VS Code: в строке состояния справа переключить CRLF → LF; в настройках `files.eol = \n`.
2) В репозитории файл .gitattributes со строкой `*.sh text eol=lf`.
3) На Windows-машине: `git config --global core.autocrlf input`

## OPS-104. Ключ не принимается

### Воспроизводим проблему

```bash
ssh-keygen -y -f /srv/lab/keys/id_lab
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@         WARNING: UNPROTECTED PRIVATE KEY FILE!          @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
Permissions 0644 for '/srv/lab/keys/id_lab' are too open.
It is required that your private key files are NOT accessible by others.
This private key will be ignored.
Load key "/srv/lab/keys/id_lab": bad permissions
```

### Проверяем разрешения

```bash
root@blank-black:/srv/lab/deploy# ls -l /srv/lab/keys/id_lab
-rw-r--r-- 1 root root 419 Oct 16 06:37 /srv/lab/keys/id_lab
```

### Назначаем разрешения

```bash
root@blank-black:/srv/lab/deploy# chmod 600 /srv/lab/keys/id_lab
```

```bash
# Подтверждает установку прав 600 без чтения приватного ключа.
stat -c '%A %a %U:%G %n' /srv/lab/keys/id_lab
```

### Проверка

```bash
root@blank-black:/srv/lab/deploy# ssh-keygen -y -f /srv/lab/keys/id_lab
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICF5dhLykuYw3FFyQWzDcRiuHqD0CdTOu2/j+hr92vQj root@blank-black.ptr.network
```

Печатается только открытый(public) ключ, секретный не показывается.

### Почему SSH так строг к правам на ключ

Причина: права 644 позволяли другим пользователям прочитать приватный ключ. 

Влияние: SSH отказывается использовать такой ключ из-за риска его раскрытия.
Если приватный ключ могут читать другие пользователи, любой из них способен подключиться как владелец. Поэтому SSH отказывается использовать ключ с правами шире 600 и тем самым защищает пользователя от его собственной ошибки(защита от дурака).

# Итог

## Что было сложным

Соблюдать и проверять "лишние" привилегии. Необходимо тщательная и детальная проверка всех сервисов, даже если они с первого взгляда работают хорошо.

## Что я теперь буду делать иначе

1) Соблюдать принцип наименьших привилегий.
2) Всегда точно моделировать проблему из-под рабочего пользователя(не-root). 
3) Внимательно отслеживать репозитории на предмет наличия ключей и других важных данных, которые могут быть скомпрометированы

## Уборка

### Чистка

```bash
# Удаляет лабораторного пользователя приложения и его домашнюю папку 
deluser --remove-home lab-app

# Удаляет первого лабораторного разработчика с его домашней папкой.
deluser --remove-home lab-dev1

# Удаляет второго лабораторного разработчика с его домашней папкой.
deluser --remove-home lab-dev2

# Удаляет лабораторного пользователя узкого правила sudo с его домашней папкой.
deluser --remove-home lab-ops

# Удаляет учебного пользователя lab-try
deluser --remove-home lab-try

# Удаляет общую лабораторную группу разработчиков.
delgroup lab-team

# Удаляет группу приложения
delgroup lab-app

# Удаляет учебную группу lab-demo1
delgroup lab-demo1

# Удаляет учебную группу lab-demo2
delgroup lab-demo2

# Удаляет правила sudoers.
rm -f -- /etc/sudoers.d/lab-ops

# Проверяет корректность sudoers.
visudo -c

# Удаляет проверенную папку стендов вместе с её содержимым.
rm -r -- /srv/lab
```

### Проверка

```bash
# Проверяет отсутствие лабораторных пользователей с префиксом lab-.
getent passwd | grep lab-

# Проверяет отсутствие лабораторных групп с префиксом lab-.
getent group | grep lab-

# Показывает содержимое /srv после удаления лабораторного стенда.
ls /srv

# Подтверждает отсутствие каталога /srv/lab отдельным сообщением.
test ! -e /srv/lab && printf '%s\n' '/srv/lab удалён'

# Подтверждает сохранение постоянного рабочего пользователя и его групп.
id "konstantin"

# Подтверждает сохранение домашней папки рабочего пользователя.
ls -ld "/home/konstantin"

# Проверяет итоговую корректность конфигурации sudoers.
visudo -c
```
