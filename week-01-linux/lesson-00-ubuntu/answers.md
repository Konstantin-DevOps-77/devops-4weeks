# Урок 0. Ubuntu: мои ответы

Имя: Константин
Дата сдачи: 12.10.2026

## Задание 1. Знакомство с сервером

whoami: root

hostname: blank-black.ptr.network

pwd: /root

date: Mon Oct 12 05:44:47 AM UTC 2026

cat /etc/os-release:
PRETTY_NAME="Ubuntu 24.04.5 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
VERSION="24.04.5 LTS (Noble Numbat)"
VERSION_CODENAME=noble
ID=ubuntu
ID_LIKE=debian
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
UBUNTU_CODENAME=noble
LOGO=ubuntu-logo

## Задание 2. Песочница

Команда:

mkdir -p ~/practice/lesson0/{docs,scripts,backup}
ls -R ~/practice/lesson0


Результат:

/root/practice/lesson0:
backup  docs  scripts

/root/practice/lesson0/backup:

/root/practice/lesson0/docs:

/root/practice/lesson0/scripts:



## Задание 3. Первый файл

```
// второй вариант - одной командой
printf '%s\n' 'Hello, Ubuntu' > ~/practice/lesson0/docs/hello.txt
printf '%s\n' "Konstantin" >> ~/practice/lesson0/docs/hello.txt
date >> ~/practice/lesson0/docs/hello.txt
cat ~/practice/lesson0/docs/hello.txt

// простое выполнение
root@blank-black:~/practice/lesson0/docs# nano hello.txt
root@blank-black:~/practice/lesson0/docs# wc -l hello.txt
2 hello.txt
root@blank-black:~/practice/lesson0/docs# date >> hello.txt
root@blank-black:~/practice/lesson0/docs# wc -l hello.txt
3 hello.txt
root@blank-black:~/practice/lesson0/docs# cat hello.txt
Hello, Ubuntu
Konstantin
Mon Oct 12 11:35:26 AM UTC 2026
root@blank-black:~/practice/lesson0/docs# 

```

## Задание 4. Копировать, переименовать, переместить

Команды, которые я использовал:

```


```
root@blank-black:~/practice/lesson0# cp docs/hello.txt backup/
root@blank-black:~/practice/lesson0# cd backup
root@blank-black:~/practice/lesson0/backup# ls
hello.txt
root@blank-black:~/practice/lesson0/backup# cat hello.txt
Hello, Ubuntu
Konstantin
Mon Oct 12 11:35:26 AM UTC 2026
root@blank-black:~/practice/lesson0/backup# cd ..
root@blank-black:~/practice/lesson0# cd docs
root@blank-black:~/practice/lesson0/docs# ls 
hello.txt
root@blank-black:~/practice/lesson0/docs# mv hello.txt greeting.txt
root@blank-black:~/practice/lesson0/docs# ls
greeting.txt
root@blank-black:~/practice/lesson0/docs# cd ..
root@blank-black:~/practice/lesson0# cd scripts
root@blank-black:~/practice/lesson0/scripts# touch todo.txt
root@blank-black:~/practice/lesson0/scripts# ls -R ~/practice/lesson0
/root/practice/lesson0:
backup  docs  scripts

/root/practice/lesson0/backup:
hello.txt

/root/practice/lesson0/docs:
greeting.txt

/root/practice/lesson0/scripts:
todo.txt
Результат:

```
root@blank-black:~/practice/lesson0/scripts# ls -R ~/practice/lesson0
/root/practice/lesson0:
backup  docs  scripts

/root/practice/lesson0/backup:
hello.txt

/root/practice/lesson0/docs:
greeting.txt

/root/practice/lesson0/scripts:
todo.txt


root@blank-black:~/practice/lesson0/backup# cat hello.txt
Hello, Ubuntu
Konstantin
Mon Oct 12 11:35:26 AM UTC 2026
```

## Задание 5. Читаем файлы

```
(вывод head, tail и wc -l для /etc/passwd)
root@blank-black:~/practice/lesson0/backup# head -n 3 /etc/passwd && tail -n 2 /etc/passwd
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
sshd:x:109:65534::/run/sshd:/usr/sbin/nologin
mtr-backend:x:999:988::/home/mtr-backend:/usr/sbin/nologin

root@blank-black:~/practice/lesson0/backup# wc -l  /etc/passwd
34 /etc/passwd

```

Строка с Port в sshd_config:

#Port 22

```
Что означает # в начале строки (своими словами):

# означает что строка закомментирована


## Задание 6. Справка и опции

Опции:

- размеры в человеческом виде: (опция)
- сортировка по размеру: (опция)
- обратный порядок: (опция)

Итоговая команда и её вывод:

```

//-l включает полный список
// -S Сортировка по убыванию
// -h человеческий вид
// -r не пишем, так как иначе у нас будут самые маленькие значения
root@blank-black:~/practice/lesson0/backup# ls -lhS /etc | head -n 6
total 956K
-rw-r--r-- 1 root root       74K Jul 12  2023 mime.types
-rw-r--r-- 1 root root       26K Oct  1 07:42 ld.so.cache
-rw-r--r-- 1 root root       13K Mar 27  2021 services
-rw-r--r-- 1 root root       13K Feb 22  2024 login.defs
drwxr-xr-x 9 root root       12K Sep 28 10:59 apparmor.d

// -l -
```

## Задание 7. Пакеты

Последняя строка apt update:

```
34 packages can be upgraded. Run 'apt list --upgradable' to see them.

```

```
(вывод tree и which tree)

root@blank-black:~/practice/lesson0/backup# tree -L 2 ~/practice/lesson0
/root/practice/lesson0
├── backup
│   └── hello.txt
├── docs
│   └── greeting.txt
└── scripts
    └── todo.txt

4 directories, 3 files

root@blank-black:~/practice/lesson0/backup# which tree
/usr/bin/tree

Чем apt update отличается от apt upgrade и почему мы не запускаем upgrade на этом сервере (своими словами):

Главное различие в том, что apt update обновляет только локальный каталог (индекс) доступных пакетов, 
а apt upgrade устанавливает свежие версии для уже установленных в системе программ.

Apt ugrade мы не запускаем, потому что оно может затронуть службы и работу сервера.

## Задание 8. Состояние сервера

| Параметр | Значение |
|---|---|
| Версия Ubuntu | Ubuntu 24.04.5 LTS |
| Версия ядра | 6.8.0-142-generic |
| Сколько работает без перезагрузки | up 1 week, 4 days, 2 hours, 49 minutes |
| Число ядер процессора | 1 |
| Всего памяти / доступно памяти | 1.9Gi / 236Mi |
| Размер диска / занято | 30Gb / 7.9G |

Сходится ли с заказом на Aeza:
Сходится, но есть разница между Gi и Gb. 1.9Gi примерно равно 2Gb, за счет того что 1 1 Gi = 1.07 Gb. 
(1-2 предложения)

## Задание 9. Читаем ошибки

### 1. lss

```
Command 'lss' not found, but there are 16 similar ones.

```

Причина: (своими словами)
Ошибка заключается в лишней s - неверно набрана команда.

Правильно:

```
ls

```

### 2. cd /etc/ssh2

bash: cd: /etc/ssh2: No such file or directory

Причина: (своими словами)

Ошибка заключается в неверном имени директории

Правильно:

```
cd: /etc/ssh

```

### 3. cat nothing.txt

cat: /root/practice/lesson0/docs/nothing.txt: No such file or directory

Причина: (своими словами)

Ошибка заключается в попытке прочитать несуществующий файл

Правильно

//Читаем существующий файл

cat: /root/practice/lesson0/docs/greeting.txt

### 4. mkdir ~/practice/lesson0/a/b/c

mkdir: cannot create directory ‘/root/practice/lesson0/a/b/c’: No such file or directory

Причина: (своими словами)

Ошибка заключается в попытке вложенную папку без существующих родительских каталогов

Правильно

//Создание вложенной структуры папок с ключом -p

mkdir -p ~/practice/lesson0/a/b/c


## Задание 10. Объясни своими словами

1. `~`, `.`, `..`: (ответ)
~  — обозначает домашний каталог текущего пользователя
.  — обозначает текущий каталог (то место в файловой системе, где находимся в данный момент)
.. — обозначает родительский каталог (папку на один уровень выше относительно нашей текущей позиции)

2. `>` и `>>`: (ответ)
    > - означает перезапись файла
    >> - означает ДОБАВЛЕНИЕ в конец существующего файла

    > файл полностью пересоздается и это более опасно!

3. Абсолютный и относительный путь: (ответ)
~ - домашний каталог(путь от root) -абсолютный пусть
Абсолютный путь начинается с ~/, (т.е полный путь к нужному каталогу),
 относительный - от текущего каталога, в котором находимся сейчас.


~/practice/lesson0 - мы стоим тут
./docs/greeting.txt - относительный путь

cd /

~/practice/lesson0/docs/greeting.txt - абсолютный путь



4. Три папки из корня: (ответ)

/etc - системные настройки
/home - домашние папки пользователей
/var - временные файлы + журналы пользователей

## Что было сложным

(относительный и абсолютный путь - не сразу разобрался. И как правильно отобразить таблицу параметров сервера, чтобы не разъезжалось.

     