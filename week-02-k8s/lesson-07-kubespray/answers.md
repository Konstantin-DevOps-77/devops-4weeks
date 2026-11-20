# Урок 7. Кластер через Kubespray

## Вопросы для самопроверки (README)
1. Компоненты control plane

kube-apiserver: единая точка входа, REST API. Проверяет аутентификацию и авторизацию, валидирует объекты и единственный общается с etcd.
etcd: хранилище состояния кластера (ключ-значение).
kube-scheduler: выбирает ноду для новых подов по ресурсам, taints/tolerations, affinity и т. д.
kube-controller-manager: набор контроллеров (Node, ReplicaSet, Deployment, Endpoints и др.), которые приводят фактическое состояние к желаемому.
cloud-controller-manager (в облаках): интеграция с провайдером (балансировщики, диски, ноды).

2. Это под, который kubelet запускает напрямую из манифеста в каталоге (/etc/kubernetes/manifests), без участия API-сервера. Control plane запускают так потому, чтобы API-сервер мог запустить поды, он уже должен работать. Kubelet поднимает его сам, перезапускает при падении, а в API создаётся только зеркальный (mirror) под, который нельзя изменить через kubectl.

3. Всё состояние (объекты, секреты, конфигурации) лежит в etcd. Без бэкапа при потере всех его членов вы теряете описание кластера: какие Deployment, Service, Secret, RBAC были. Запущенные контейнеры на нодах какое-то время продолжат работать, но управлять ими уже нельзя, и восстановить кластер придётся с нуля (из манифестов в Git, если они есть). Поэтому нужны регулярные etcdctl snapshot save и проверка восстановления.

4. kubeadm инструмент более низкого уровня. Он инициализирует control plane на одной ноде (init) и присоединяет остальные (join). Он не готовит ОС, не ставит container runtime и CNI, не управляет парком машин.
Kubespray набор Ansible-ролей. Он подготавливает ноды, ставит runtime, etcd, CNI и аддоны, а kubeadm использует внутри. Работает по инвентарю сразу для многих нод.

5. Операция идемпотентна, если повторный запуск даёт тот же результат, что и первый, и не ломает уже достигнутое состояние. Ansible описывает желаемое состояние («пакет установлен», «файл такой-то»), а не последовательность действий, и меняет только то, что отличается. Поэтому Kubespray можно перезапускать после сбоя, при добавлении ноды или смене конфигурации.

6. Kubelet и планировщик исходят из того, что лимиты памяти предсказуемы. Со swap память пода может «утекать» на диск, что ломает учёт ресурсов, делает поведение при нехватке памяти непредсказуемым и сильно снижает производительность. Исторически kubelet просто отказывался стартовать со включённым swap. Сейчас есть поддержка swap (NodeSwap) в некоторых режимах, но по умолчанию его отключают.

7. Сеть подов (pod CIDR): реальные IP подов, их выдаёт CNI, они маршрутизируются между нодами.
Сеть сервисов (service CIDR): виртуальные ClusterIP, не принадлежат ни одному интерфейсу, их транслирует kube-proxy (iptables/IPVS) или eBPF в IP подов.

Пересечение с сетью нод ломает маршрутизацию: пакет на адрес, который одновременно может быть нодой и подом или сервисом, уйдёт не туда либо будет перехвачен правилами. То же касается пересечения подов и сервисов между собой. Нужны три непересекающихся диапазона (а также без конфликта с корпоративными сетями и VPN).

8. kubectl не нашёл kubeconfig и использует адрес по умолчанию, localhost:8080, где ничего не слушает. Причины: не задан KUBECONFIG, нет ~/.kube/config, либо мы находимся на машине, где его не настроили. Решение: скопировать admin.conf в ~/.kube/config (с нужными правами) или указать export KUBECONFIG=/path/to/admin.conf. В этом случае проблема в конфигурации клиента, а не в упавшем кластере.

9. В нём лежит клиентский сертификат и ключ с правами cluster-admin (группа system:masters). Тот, у кого есть файл, имеет полный доступ к кластеру. Из Git такой секрет не вычистить (история, форки, клоны), а отозвать сертификат без перевыпуска CA нельзя. Хранить его надо в менеджере секретов, а для людей выдавать отдельные учётки с ограниченными правами.

10. Больше одной ноды нужно для отказоустойчивости: при отказе одной кластер остаётся управляемым (API, планирование, etcd). Нечётное число связано с кворумом etcd (алгоритм Raft): для работы нужно большинство, то есть ⌊n/2⌋+1 членов.

| Членов | Кворум |	Допустимо отказов | 
| ------ | ------ | ----------------- |
|   1    |   1	   |         0         | 
|   2    |   2    |	        0         |
|   3    |   2	   |         1         |
|   4    |   3	   |         1         |
|   5    |   3	   |         2         |

Четвёртая нода не добавляет устойчивости к отказам по сравнению с тремя, зато увеличивает нагрузку на репликацию и повышает вероятность потери кворума. А при разделении сети пополам на 4 ноды (2+2) ни одна из половин не получит большинства. Поэтому берут 3 или 5.  

## Шаг 0. Выбор машины
(выводы команд, таблица, решение: вариант А / Б и почему)
  
free -h                                        # память: смотри колонку total
df -h /                                        # место на диске
cat /etc/os-release | grep PRETTY_NAME         # версия ОС
systemctl is-active docker containerd          # есть ли Docker и containerd
sudo docker ps --format '{{.Names}}' 2>/dev/null   # что работает в Docker
swapon --show                                  # есть ли swap
ip -br a                                       # все интерфейсы
ip r                                           # все маршруты

|              Команда                               | Полученное значение              |          Вывод/решение          |
| ------------------------------------------         | --------------------             | -----------------------------   |
|      `nproc`                                       |        1                         | Недостаточно(нужно минимум 2)   |
|      `free -h`                                     | total 1.9Gi, available - 886Mi   | Достаточно для установки        |
|      `df -h /`                                     | Size - 30G, Avail - 13G          | Достаточно для установки        |
| `cat /etc/os-release grep PRETTY_NAME`             | PRETTY_NAME="Ubuntu 24.04.5 LTS" | Соответствует требованиям       |
| `systemctl is-active docker containerd`            | active active                    | Контейнеризация есть - не Ок    |
| `sudo docker ps --format '{{.Names}}' 2>/dev/null` | Пусто                            | Контейнеры не запущены          |
|      `swapon --show`                               | Пусто                            | Swap не запущен и/или неактивен |
|      `ip br -a`                                    | lo, enp0s3,awg0, docker0         | Присутствует docker - не ок     |
|      `ip -r`                                       | default, dev awg0, docker0       | Присутствует docker - не ок     |




## Шаг 1. Нода (для варианта А)
Выбрано создание нового сервера.
## Шаг 2. Ключ для Ansible
kostya@blank-black:~/projects/devops-4weeks/week-02-k8s/lesson-07-kubespray$ ssh -i ~/.ssh/kubespray kostya@82.148.225.27 'hostname; whoami'
blank-black2.ptr.network
kostya
## Шаг 3. Имя ноды
#Терминал А(Ansible)  
kostya@blank-black:~/projects/devops-4weeks/week-02-k8s/lesson-07-kubespray$ `ssh -i ~/.ssh/kubespray kostya@82.148.225.27 'hostname -s'`
\blank-black2
#Терминал B(Управляемая Node kubernetes)
hostnamectl
Static hostname: blank-black2.ptr.network
## Шаг 4. Kubespray и Ansible
kostya@blank-black:~/kubespray$ git describe --tags
v2.31.0
(kubespray-venv) kostya@blank-black:~/kubespray$ ansible --version | head -1
ansible [core 2.18.20]
## Шаг 5. Инвентарь
[kube_control_plane]
blank-black2 ansible_host=82.148.225.27(адрес ноды) ip=82.148.225.27(внутренний bind) ansible_user=kostya  ansible_ssh_private_key_file=~/.ssh/kubespray etcd_member_name=etcd1

[etcd:children]
kube_control_plane

[kube_node]
blank-black2

[k8s_cluster:children]
kube_control_plane
kube_node

#Проверки
(kubespray-venv) kostya@blank-black:~/kubespray$ ansible-inventory -i inventory/mycluster/inventory.ini --graph
@all:
  |--@ungrouped:
  |--@etcd:
  |  |--@kube_control_plane:
  |  |  |--blank-black2
  |--@k8s_cluster:
  |  |--@kube_control_plane:
  |  |  |--blank-black2
  |  |--@kube_node:
  |  |  |--blank-black2
(kubespray-venv) kostya@blank-black:~/kubespray$ ansible -i inventory/mycluster/inventory.ini all -m ping
[WARNING]: Platform linux on host blank-black2 is using the discovered Python interpreter at /usr/bin/python3.12, but future installation of another Python interpreter could
change the meaning of that path. See https://docs.ansible.com/ansible-core/2.18/reference_appendices/interpreter_discovery.html for more information.
blank-black2 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.12"
    },
    "changed": false,
    "ping": "pong"
}

## Шаг 6. Настройки

# Мои настройки учебного кластера

# Не трогать DNS самого сервера: если DNS кластера сломается,
# сервер (и VPN) продолжат резолвить имена как раньше
resolvconf_mode: none

# Дополнения
helm_enabled: true                     # helm на ноде, понадобится в следующих уроках
metrics_server_enabled: true           # чтобы работал kubectl top
local_path_provisioner_enabled: true   # тома (PVC) на локальном диске ноды


(kubespray-venv) kostya@blank-black:~/kubespray$ ansible-inventory -i inventory/mycluster/inventory.ini --host blank-black2   | grep -E '"(resolvconf_mode|helm_enabled|metrics_server_enabled|local_path_provisioner_enabled|kube_network_plugin|kube_proxy_mode|kube_pods_subnet|kube_service_addresses|container_manager)"'
    "container_manager": "containerd",
    "helm_enabled": true,
    "kube_network_plugin": "calico",
    "kube_pods_subnet": "10.233.64.0/18",
    "kube_proxy_mode": "ipvs",
    "kube_service_addresses": "10.233.0.0/18",
    "local_path_provisioner_enabled": true,
    "metrics_server_enabled": true,
    "resolvconf_mode": "none",
- Что будет, если положить lab.yml в group_vars/all/:
(kubespray-venv) kostya@blank-black:~/kubespray/inventory/mycluster/group_vars$ ls -l all/lab.yml
-rw-rw-r-- 1 kostya kostya 605 Nov 18 13:44 all/lab.yml
(kubespray-venv) kostya@blank-black:~/kubespray/inventory/mycluster/group_vars$ ansible-inventory -i inventory/mycluster/inventory.ini --host blank-black2   | grep -E '"(resolvconf_mode|helm_enabled|metrics_server_enabled|local_path_provisioner_enabled|kube_network_plugin|kube_proxy_mode|kube_pods_subnet|kube_service_addresses|container_manager)"'
[WARNING]: Unable to parse /home/kostya/kubespray/inventory/mycluster/group_var
s/inventory/mycluster/inventory.ini as an inventory source
[WARNING]: No inventory was parsed, only implicit localhost is available
[WARNING]: Could not match supplied host pattern, ignoring: blank-black2
ERROR! You must pass a single valid host to --host parameter

kubespray-venv) kostya@blank-black:~/kubespray$ ansible-inventory -i inventory/mycluster/inventory.ini --host blank-black2 \
  | grep -E '"(resolvconf_mode|helm_enabled|metrics_server_enabled|local_path_provisioner_enabled|kube_network_plugin|kube_proxy_mode|kube_pods_subnet|kube_service_addresses|co
ntainer_manager)"'
    "container_manager": "containerd",
    "helm_enabled": true,
    "kube_network_plugin": "calico",
    "kube_pods_subnet": "10.233.64.0/18",
    "kube_proxy_mode": "ipvs",
    "kube_service_addresses": "10.233.0.0/18",
    "local_path_provisioner_enabled": true,
    "metrics_server_enabled": true,
    "resolvconf_mode": "none",
(kubespray-venv) kostya@blank-black:~/kubespray$ 

## Шаг 7. Фаервол
kostya@blank-black2:~$ sudo ufw status numbered | tee ~/ufw-before-k8s.txt
[sudo] password for kostya: 
Status: active

     To                         Action      From
     --                         ------      ----
[ 1] 22/tcp                     ALLOW IN    Anywhere                  
[ 2] 22/tcp (v6)                ALLOW IN    Anywhere (v6)  

kostya@blank-black2:~$ sudo ufw status numbered
Status: active

     To                         Action      From
     --                         ------      ----
[ 1] 22/tcp                     ALLOW IN    Anywhere                  
[ 2] Anywhere                   ALLOW IN    10.233.64.0/18             # k8s pods
[ 3] Anywhere                   ALLOW IN    10.233.0.0/18              # k8s services
[ 4] Anywhere                   ALLOW FWD   10.233.64.0/18             # k8s pods routed
[ 5] 10.233.64.0/18             ALLOW FWD   Anywhere                   # k8s pods routed
[ 6] 22/tcp (v6)                ALLOW IN    Anywhere (v6)   

## Шаг 8. Снимок «до»
kostya@blank-black2:~/k8s-before$ nano iptables-lines.txt
109 

kostya@blank-black2:~/k8s-before$ nano free.txt
  GNU nano 7.2                                                                        free.txt                                                                                  
               total        used        free      shared  buff/cache   available
Mem:           3.8Gi       872Mi       2.7Gi       2.2Mi       499Mi       3.0Gi
Swap:             0B          0B          0B


## Шаг 9. Запуск
- PLAY RECAP:
PLAY RECAP *********************************************************************
blank-black2               : ok=648  changed=136  unreachable=0    failed=0    skipped=875  rescued=0    ignored=4   

- Время установки:
9.13
- Падения и что сделал:
Bind IP -> 10.0.0.1 -> 82.148.225.27
## Шаг 10. kubectl под своим пользователем

ДО
kubectl get nodes
E1118 14:41:40.686630   22149 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get \"http://localhost:8080/api?timeout=32s\": dial tcp 127.0.0.1:8080: connect: connection refused"
E1118 14:41:40.687072   22149 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get \"http://localhost:8080/api?timeout=32s\": dial tcp 127.0.0.1:8080: connect: connection refused"
E1118 14:41:40.688526   22149 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get \"http://localhost:8080/api?timeout=32s\": dial tcp 127.0.0.1:8080: connect: connection refused"
E1118 14:41:40.688887   22149 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get \"http://localhost:8080/api?timeout=32s\": dial tcp 127.0.0.1:8080: connect: connection refused"
E1118 14:41:40.690585   22149 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get \"http://localhost:8080/api?timeout=32s\": dial tcp 127.0.0.1:8080: connect: connection refused"
The connection to the server localhost:8080 was refused - did you specify the right host or port?

kubectl get nodes -o wide
NAME           STATUS   ROLES           AGE   VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
blank-black2   Ready    control-plane   17h   v1.35.4   82.148.225.27   <none>        Ubuntu 24.04.5 LTS   6.8.0-149-generic   containerd://2.2.3

kostya@blank-black2:~$ ls -l ~/.kube/config
-rw------- 1 kostya kostya 5653 Nov 18 14:43 /home/kostya/.kube/config


## Шаг 11. Проверки
1.1 
kostya@blank-black2:~$ kubectl get pods -A -o wide
NAMESPACE            NAME                                       READY   STATUS    RESTARTS   AGE   IP               NODE           NOMINATED NODE   READINESS GATES
kube-system          calico-kube-controllers-7c99df9fc4-rgjlk   1/1     Running   0          17h   10.233.104.129   blank-black2   <none>           <none>
kube-system          calico-node-x2p6d                          1/1     Running   0          17h   82.148.225.27    blank-black2   <none>           <none>
kube-system          coredns-58cc5d8ddf-t4d6l                   1/1     Running   0          17h   10.233.104.131   blank-black2   <none>           <none>
kube-system          dns-autoscaler-7ccf68df7c-8bqtz            1/1     Running   0          17h   10.233.104.132   blank-black2   <none>           <none>
kube-system          kube-apiserver-blank-black2                1/1     Running   0          17h   82.148.225.27    blank-black2   <none>           <none>
kube-system          kube-controller-manager-blank-black2       1/1     Running   0          17h   82.148.225.27    blank-black2   <none>           <none>
kube-system          kube-proxy-vhlxv                           1/1     Running   0          17h   82.148.225.27    blank-black2   <none>           <none>
kube-system          kube-scheduler-blank-black2                1/1     Running   0          17h   82.148.225.27    blank-black2   <none>           <none>
kube-system          metrics-server-7d5f87b57f-vzvp9            1/1     Running   0          17h   10.233.104.133   blank-black2   <none>           <none>
kube-system          nodelocaldns-w8kv5                         1/1     Running   0          17h   82.148.225.27    blank-black2   <none>           <none>
local-path-storage   local-path-provisioner-cdf455b97-8qbqw     1/1     Running   0          17h   10.233.104.130   blank-black2   <none>           <none>

1.2 
ostya@blank-black2:~$ ls -l /etc/kubernetes/manifests/
systemctl status kubelet containerd etcd --no-pager | grep -E '●|Active'
total 16
-rw------- 1 root root 4621 Nov 18 14:35 kube-apiserver.yaml
-rw------- 1 root root 3663 Nov 18 14:35 kube-controller-manager.yaml
-rw------- 1 root root 1957 Nov 18 14:35 kube-scheduler.yaml
● kubelet.service - Kubernetes Kubelet Server
     Active: active (running) since Wed 2026-11-18 14:35:53 UTC; 17h ago
● containerd.service - containerd container runtime
     Active: active (running) since Wed 2026-11-18 14:30:36 UTC; 17h ago
● etcd.service - etcd
     Active: active (running) since Wed 2026-11-18 14:35:03 UTC; 17h ago

Первые три строки сверху - static pod(список по манифесту), три снизу - systemd(за) 

kostya@blank-black2:~$ ls -l /etc/kubernetes/manifests/
systemctl status kubelet containerd etcd --no-pager | grep -E '●|Active'
total 16
-rw------- 1 root root 4621 Nov 18 14:35 kube-apiserver.yaml
-rw------- 1 root root 3663 Nov 18 14:35 kube-controller-manager.yaml
-rw------- 1 root root 1957 Nov 18 14:35 kube-scheduler.yaml
● kubelet.service - Kubernetes Kubelet Server
     Active: active (running) since Wed 2026-11-18 14:35:53 UTC; 17h ago
● containerd.service - containerd container runtime
     Active: active (running) since Wed 2026-11-18 14:30:36 UTC; 17h ago
● etcd.service - etcd
     Active: active (running) since Wed 2026-11-18 14:35:03 UTC; 17h ago
kostya@blank-black2:~$ systemctl status kubelet containerd etcd --no-pager | grep -E '●|Active'
● kubelet.service - Kubernetes Kubelet Server
     Active: active (running) since Wed 2026-11-18 14:35:53 UTC; 17h ago
● containerd.service - containerd container runtime
     Active: active (running) since Wed 2026-11-18 14:30:36 UTC; 17h ago
● etcd.service - etcd
     Active: active (running) since Wed 2026-11-18 14:35:03 UTC; 17h ago

Компонент               |    Тип запуска    |     Состояние
kube-apiserver          |     Static Pod    |     Манифест найден
kube-controller-manager |     Static Pod    |     Манифест найден
kube-scheduler          |     Static Pod    |     Манифест найден
kubelet                 |     systemd       |      Active (running)
containerd              |     systemd       |      Active (running)
etcd                    |     systemd       |      Active (running)


11.3 etcd
kostya@blank-black2:~$ sudo ETCDCTL_API=3 etcdctl   --cacert=/etc/ssl/etcd/ssl/ca.pem   --cert=/etc/ssl/etcd/ssl/admin-$(hostname).pem   --key=/etc/ssl/etcd/ssl/admin-$(hostname)-key.pem   --endpoints=https://127.0.0.1:2379   endpoint health -w table
{"level":"warn","ts":"2026-11-19T08:26:37.491506Z","caller":"flags/flag.go:94","msg":"unrecognized environment variable","environment-variable":"ETCDCTL_API=3"}
+------------------------+--------+------------+-------+
|        ENDPOINT        | HEALTH |    TOOK    | ERROR |
+------------------------+--------+------------+-------+
| https://127.0.0.1:2379 |   true | 8.666881ms |       |
+------------------------+--------+------------+-------+

#Без сертификатов.
kostya@blank-black2:~$ sudo ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379   endpoint health -w table
{"level":"warn","ts":"2026-11-19T08:28:48.505746Z","caller":"flags/flag.go:94","msg":"unrecognized environment variable","environment-variable":"ETCDCTL_API=3"}
{"level":"warn","ts":"2026-11-19T08:28:53.507815Z","logger":"client","caller":"v3@v3.6.10/retry_interceptor.go:68","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0xc00029a5a0/127.0.0.1:2379","peer":"Peer{Addr: <nil>, LocalAddr: <nil>, AuthInfo: <nil>}","method":"/etcdserverpb.KV/Range","attempt":0,"error":"rpc error: code = DeadlineExceeded desc = latest balancer error: connection error: desc = \"error reading server preface: remote error: tls: certificate required\""}
+------------------------+--------+--------------+---------------------------+
|        ENDPOINT        | HEALTH |     TOOK     |           ERROR           |
+------------------------+--------+--------------+---------------------------+
| https://127.0.0.1:2379 |  false | 5.001841462s | context deadline exceeded |

healthcheck не проходит.  


kostya@blank-black2:~$ sudo crictl ps | head
CONTAINER           IMAGE               CREATED             STATE               NAME                      ATTEMPT             POD ID              POD                                        NAMESPACE
b229bfd6c1081       e76b3f3568b7f       18 hours ago        Running             metrics-server            0                   81f0338c037ab       metrics-server-7d5f87b57f-vzvp9            kube-system
109c5f956ffaf       12a9bdcb186d1       18 hours ago        Running             node-cache                0                   b823688646864       nodelocaldns-w8kv5                         kube-system
941b8085831f7       b6d1a4be0743f       18 hours ago        Running             autoscaler                0                   3b7e24694b802       dns-autoscaler-7ccf68df7c-8bqtz            kube-system
ad63545b0f51b       17b9ebd6161fd       18 hours ago        Running             coredns                   0                   731e8f8f1561c       coredns-58cc5d8ddf-t4d6l                   kube-system
d333021ee584a       cb584e17a5f4b       18 hours ago        Running             local-path-provisioner    0                   9bfc89f32acd1       local-path-provisioner-cdf455b97-8qbqw     local-path-storage
13a0a00548490       d686db0e796da       18 hours ago        Running             calico-kube-controllers   0                   a6b71edc6ed6c       calico-kube-controllers-7c99df9fc4-rgjlk   kube-system
91babe050419c       cfa3bb2488693       18 hours ago        Running             calico-node               0                   eab41a6d34369       calico-node-x2p6d                          kube-system
f44319e9e25d3       f21f27cddb23d       18 hours ago        Running             kube-proxy                0                   a9940b759f6c6       kube-proxy-vhlxv                           kube-system
eed0ec12dfe63       a0eecd9b69a38       18 hours ago        Running             kube-scheduler            0                   7ce063f1b5783       kube-scheduler-blank-black2                kube-system

kostya@blank-black2:~$ kubectl get pods
No resources found in default namespace.

В окружении по умолчании нет узлов. Все узлы содержатся в namespace - kube-system + local-path-storage  

kostya@blank-black2:~$ kubectl get pods -A
NAMESPACE            NAME                                       READY   STATUS    RESTARTS   AGE
kube-system          calico-kube-controllers-7c99df9fc4-rgjlk   1/1     Running   0          17h
kube-system          calico-node-x2p6d                          1/1     Running   0          17h
kube-system          coredns-58cc5d8ddf-t4d6l                   1/1     Running   0          17h
kube-system          dns-autoscaler-7ccf68df7c-8bqtz            1/1     Running   0          17h
kube-system          kube-apiserver-blank-black2                1/1     Running   0          17h
kube-system          kube-controller-manager-blank-black2       1/1     Running   0          17h
kube-system          kube-proxy-vhlxv                           1/1     Running   0          17h
kube-system          kube-scheduler-blank-black2                1/1     Running   0          17h
kube-system          metrics-server-7d5f87b57f-vzvp9            1/1     Running   0          17h
kube-system          nodelocaldns-w8kv5                         1/1     Running   0          17h
local-path-storage   local-path-provisioner-cdf455b97-8qbqw     1/1     Running   0          17h


kostya@blank-black2:~$ kubectl get pods -n kube-system -o wide
NAME                                       READY   STATUS    RESTARTS   AGE   IP               NODE           NOMINATED NODE   READINESS GATES
calico-kube-controllers-7c99df9fc4-rgjlk   1/1     Running   0          17h   10.233.104.129   blank-black2   <none>           <none>
calico-node-x2p6d                          1/1     Running   0          17h   82.148.225.27    blank-black2   <none>           <none>
coredns-58cc5d8ddf-t4d6l                   1/1     Running   0          17h   10.233.104.131   blank-black2   <none>           <none>
dns-autoscaler-7ccf68df7c-8bqtz            1/1     Running   0          17h   10.233.104.132   blank-black2   <none>           <none>
kube-apiserver-blank-black2                1/1     Running   0          17h   82.148.225.27    blank-black2   <none>           <none>
kube-controller-manager-blank-black2       1/1     Running   0          17h   82.148.225.27    blank-black2   <none>           <none>
kube-proxy-vhlxv                           1/1     Running   0          17h   82.148.225.27    blank-black2   <none>           <none>
kube-scheduler-blank-black2                1/1     Running   0          17h   82.148.225.27    blank-black2   <none>           <none>
metrics-server-7d5f87b57f-vzvp9            1/1     Running   0          17h   10.233.104.133   blank-black2   <none>           <none>
nodelocaldns-w8kv5                         1/1     Running   0          17h   82.148.225.27    blank-black2   <none>           <none>

kostya@blank-black2:~$ kubectl get namespaces #all namespaces
NAME                 STATUS   AGE
default              Active   17h
kube-node-lease      Active   17h
kube-public          Active   17h
kube-system          Active   17h
local-path-storage   Active   17h

11.5 DNS внутри кластера

 kubectl run dnstest --rm -it --image=busybox:1.36 --restart=Never -- \
  sh -c 'nslookup kubernetes.default.svc.cluster.local; nslookup github.com'
Server:         169.254.25.10
Address:        169.254.25.10:53


Name:   kubernetes.default.svc.cluster.local
Address: 10.233.0.1 # Kubernetes API

Server:         169.254.25.10 # DNS кэш на узле
Address:        169.254.25.10:53

Non-authoritative answer:

Non-authoritative answer:
Name:   github.com
Address: 140.82.121.3

kostya@blank-black2:~$ kubectl get daemonsets -n kube-system
NAME           DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
calico-node    1         1         1       1            1           kubernetes.io/os=linux   18h
kube-proxy     1         1         1       1            1           kubernetes.io/os=linux   18h
nodelocaldns   1         1         1       1            1           kubernetes.io/os=linux   18h


11.6. Приложение  
 kubectl create deployment hello --image=nginx:1.27-alpine --replicas=2
kubectl expose deployment hello --port=80
kubectl get pods -l app=hello -o wide
kubectl get svc hello
curl -s http://$(kubectl get svc hello -o jsonpath='{.spec.clusterIP}') | head -4
deployment.apps/hello created
service/hello exposed
NAME                     READY   STATUS              RESTARTS   AGE   IP       NODE           NOMINATED NODE   READINESS GATES
hello-78bbf8c4f9-2jcdp   0/1     ContainerCreating   0          0s    <none>   blank-black2   <none>           <none>
hello-78bbf8c4f9-7bk7c   0/1     ContainerCreating   0          0s    <none>   blank-black2   <none>           <none>
NAME    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
hello   ClusterIP   10.233.46.163   <none>        80/TCP    0s
Какие IP у подов и у сервиса? Из каких они подсетей (Часть 4 README)? Удали под командой kubectl delete pod <имя одного из подов> и сразу kubectl get pods -l app=hello. Что произошло и какой компонент это сделал?С
 


kostya@blank-black2:~$ kubectl get svc -o wide
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE     SELECTOR
hello        ClusterIP   10.233.46.163   <none>        80/TCP    2m16s   app=hello  #сервис
kubernetes   ClusterIP   10.233.0.1      <none>        443/TCP   18h     <none>
kostya@blank-black2:~$ kubectl get pods -l app=hello -o wide
NAME                     READY   STATUS    RESTARTS   AGE     IP               NODE           NOMINATED NODE   READINESS GATES
hello-78bbf8c4f9-2jcdp   1/1     Running   0          2m41s   10.233.104.136   blank-black2   <none>           <none>  #под
hello-78bbf8c4f9-7bk7c   1/1     Running   0          2m41s   10.233.104.135   blank-black2   <none>           <none>  #под


kostya@blank-black2:~$ kubectl get pods -l app=hello -o wide
NAME                     READY   STATUS    RESTARTS   AGE     IP               NODE           NOMINATED NODE   READINESS GATES
hello-78bbf8c4f9-2jcdp   1/1     Running   0          2m41s   10.233.104.136   blank-black2   <none>           <none>
hello-78bbf8c4f9-7bk7c   1/1     Running   0          2m41s   10.233.104.135   blank-black2   <none>           <none>
kostya@blank-black2:~$ kubectl delete pod hello-78bbf8c4f9-2jcdp
pod "hello-78bbf8c4f9-2jcdp" deleted from default namespace

kostya@blank-black2:~$ kubectl get pods -l app=hello
NAME                     READY   STATUS    RESTARTS   AGE
hello-78bbf8c4f9-7bk7c   1/1     Running   0          7m51s
hello-78bbf8c4f9-q2w8d   1/1     Running   0          89s


## Добавился еще один под(вместо удаленного), за создание новых под отвечает kube kontroller
ReplicaSet Controller - фактически создает ноду через kube-controller-manager 
scheduler - назначает новый под узлу
kubelet - запускает контейнер

11.7 - Метрики
kubectl top nodes
kubectl top pods -A --sort-by=memory | head

kostya@blank-black2:~$ kubectl top nodes
kubectl top pods -A --sort-by=memory | head
NAME           CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)   
blank-black2   145m         10%      2252Mi          73%          
NAMESPACE            NAME                                       CPU(cores)   MEMORY(bytes)   
kube-system          kube-apiserver-blank-black2                37m          320Mi           
kube-system          calico-node-x2p6d                          27m          146Mi           
kube-system          metrics-server-7d5f87b57f-vzvp9            3m           71Mi            
kube-system          kube-controller-manager-blank-black2       13m          67Mi            
kube-system          coredns-58cc5d8ddf-t4d6l                   2m           43Mi            
kube-system          nodelocaldns-w8kv5                         2m           38Mi            
kube-system          kube-scheduler-blank-black2                7m           37Mi            
kube-system          kube-proxy-vhlxv                           5m           30Mi            
kube-system          calico-kube-controllers-7c99df9fc4-rgjlk   5m           30Mi    

#Самый  "тяжелый" - APIserver -> почти в 2 раза превосходит calico(второго по "тяжести")  

11.8 
kostya@blank-black2:~$ kubectl get storageclass
NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  45h
kostya@blank-black2:~$ kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 100Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: test-writer
spec:
  containers:
    - name: writer
      image: busybox:1.36
      command: ["sh", "-c", "echo hello-from-pod > /data/hello.txt && sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: test-pvc
EOF
persistentvolumeclaim/test-pvc created
pod/test-writer created
kostya@blank-black2:~$ kubectl get pvc test-pvc
NAME       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
test-pvc   Bound    pvc-f205461b-2a7a-4bbc-b9c1-d0607c9bf8e2   100Mi      RWO            local-path     <unset>                 21s
kostya@blank-black2:~$ sudo find /opt/local-path-provisioner -name hello.txt -exec cat {} \;
[sudo] password for kostya: 
hello-from-pod

#Данные pod лежат физически на нашей VPS(терминал B), в каталоге тома под /opt/local-path-provisioner/.   
Статус Bound означает, что PVC привязан к этому тому.

Если под пересоздать на той же ноде, файл сохранится.
Если нода временно выключится, данные будут недоступны до её возвращения.
Если диск ноды потерян, данные пропадут без резервнойц копии, local-path хранит их только на одной ноде.

11.9  
kostya@blank-black2:~$ free -h
               total        used        free      shared  buff/cache   available
Mem:           3.8Gi       1.7Gi       316Mi       4.8Mi       2.1Gi       2.1Gi
Swap:             0B          0B          0B
kostya@blank-black2:~$ sudo iptables-save | wc -l
561
kostya@blank-black2:~$ diff ~/k8s-before/hosts.txt /etc/hosts
2c2
< 127.0.1.1 ubuntu24
---
> 127.0.1.1 blank-black2.ptr.network blank-black2 ubuntu24
kostya@blank-black2:~$ diff ~/k8s-before/resolv.txt /etc/resolv.conf
kostya@blank-black2:~$ swapon --show
kostya@blank-black2:~$ systemctl list-units --type=service --state=running --no-legend | awk '{print $1}' |
> ^C
kostya@blank-black2:~$ diff ~/k8s-before/services.txt -
^C
kostya@blank-black2:~$ systemctl list-units --type=service --state=running --no-legend | awk '{print $1}' |
> diff ~/k8s-before/services.txt -
0a1
> containerd.service
2a4
> etcd.service
4a7
> kubelet.service

# Сравнение с до:  
kostya@blank-black2:~/k8s-before$ nano iptables-lines.txt
109 

kostya@blank-black2:~/k8s-before$ nano free.txt
  GNU nano 7.2                                                                        free.txt                                                                                  
               total        used        free      shared  buff/cache   available
Mem:           3.8Gi       872Mi       2.7Gi       2.2Mi       499Mi       3.0Gi
Swap:             0B          0B          0B

#Почти в 5 раз выросло число iptables(включает служебные строки дампа -> используется cache), сильно изменилась занимаемая память - уменьшилась в 2 раза
> diff ~/k8s-before/services.txt -
0a1
> containerd.service
2a4
> etcd.service
4a7
> kubelet.service

Добавились новые службы (containerd/etcd/kubelet).service
Поменялись ли /etc/hosts и resolv.conf? - Не поменялись



## Шаг 12. Доступ с Windows (если делал)
# Шаг 12.

```shell
kubectl get podes
```

```shell

NAME           STATUS   ROLES           AGE   VERSION
blank-black2   Ready    control-plane   45h   v1.35.4

```
почему это безопаснее, чем открыть 6443 в ufw?
За счет того, что на Windows порт 6443 доступен только локально через 127.0.0.1 - нет возможности подключиться снаружи

Если открыть 6443/tcp в UFW для всех, любый из интернета сможент подключиться к API и отправлять ему запросы - могут Ддосить 

## Шаг 13. NodePort снаружи
kostya@blank-black2:~$ kubectl expose deployment hello --name=hello-nodeport --type=NodePort --port=80
service/hello-nodeport exposed
kostya@blank-black2:~$ kubectl get svc hello-nodeport
NAME             TYPE       CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
hello-nodeport   NodePort   10.233.9.94   <none>        80:31336/TCP   30s

kostya@blank-black2:~$ sudo ufw status
[sudo] password for kostya: 
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere                  
Anywhere                   ALLOW       10.233.64.0/18             # k8s pods
Anywhere                   ALLOW       10.233.0.0/18              # k8s services
22/tcp (v6)                ALLOW       Anywhere (v6)             

Anywhere                   ALLOW FWD   10.233.64.0/18             # k8s pods routed
10.233.64.0/18             ALLOW FWD   Anywhere                   # k8s pods routed

#Порта в UFW нет
PS C:\Users\Admin> curl.exe -sS -i -m 5 "http://82.148.225.27:31336/"
curl: (28) Connection timed out after 5010 milliseconds


Таймаут сам по себе не показывает, где был остановлен трафик, его недостаточно чтобы подтвердить защиту NodePort
На UFW при защите Node-services полагаться нельзя.


## Шаг 14. Тикеты
### K8S-701
- **Не запускается сервис отчетов:**
- **Нет информации отчеть:**
- **Симптом:** у Deployment 0/1 готовых реплик, контейнер отчетов не запущен и логов нет
- **Влияние:** Сервис отчётов недоступен
- **Диагностика:**

65s         Warning   FailedScheduling    pod/ops701-report-668c9c9b4f-xlzm5    0/1 nodes are available: 1 Insufficient memory. no new claims to deallocate, preemption: 0/1 nodes are available: 1 Preemption is not helpful for scheduling.

- **Причина:** В запросе указано 64 Gi. Scheduler сранвивает запросы с доступной для планированоия ёмкостью ноды. По условию стенда приложению достаточно 64 Mi

- **Решение:**
```bash
kostya@blank-black2:~$ kubectl -n ops7 set resources deployment/ops701-report -c report --requests=cpu=100m,memory=64Mi
deployment.apps/ops701-report resource requirements updated
kostya@blank-black2:~$ kubectl -n ops7 rollout status deployment/ops701-report --timeout=180s
deployment "ops701-report" successfully rolled out
```
*set resources изменил запрос на ожидаемый


- **Проверка:**
```bash
kostya@blank-black2:~$ kubectl -n ops7 get pods -l app=ops701-report -o wide
NAME                            READY   STATUS    RESTARTS   AGE   IP               NODE           NOMINATED NODE   READINESS GATES
ops701-report-879f56977-7vbbk   1/1     Running   0          21s   10.233.104.143   blank-black2   <none>           <none>
```

* Реплика 1/1 Running

- **Профилактика:**

* Проверять единицы, фактическое потребление и доступную ёмкость при развёртывании, в соответсвии с ожидаемыми значениями.


### K8S-702  
- **Симптом и влияние:**
У новой версии фронта нет готовой реплики. Основные сообщение находятся в событиях kubelet, потому что контейнер ещё не стартовал.

- **Диагностика:**
```bash
kostya@blank-black2:~$ kubectl -n ops7 get pods -l app=ops702-web -o wide
NAME                          READY   STATUS             RESTARTS   AGE   IP               NODE           NOMINATED NODE   READINESS GATES
ops702-web-7dc558dcfd-25cml   0/1     ImagePullBackOff   0          13m   10.233.104.141   blank-black2   <none>           <none>
kostya@blank-black2:~$ kubectl -n ops7 describe pods -l app=ops702-web
Name:             ops702-web-7dc558dcfd-25cml
Namespace:        ops7
Priority:         0
Service Account:  default
Node:             blank-black2/82.148.225.27
Start Time:       Fri, 20 Nov 2026 12:20:30 +0000
Labels:           app=ops702-web
                  pod-template-hash=7dc558dcfd
Annotations:      cni.projectcalico.org/containerID: cabb7aa50b72828e8c7dee8feaad04efce2b8e6bdd0ce97c876c4aac4eaa21fa
                  cni.projectcalico.org/podIP: 10.233.104.141/32
                  cni.projectcalico.org/podIPs: 10.233.104.141/32
Status:           Pending
IP:               10.233.104.141
IPs:
  IP:           10.233.104.141
Controlled By:  ReplicaSet/ops702-web-7dc558dcfd
Containers:
  web:
    Container ID:   
    Image:          nginx:1.27-alpinee
    Image ID:       
    Port:           <none>
    Host Port:      <none>
    State:          Waiting
      Reason:       ImagePullBackOff
    Ready:          False
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-pnhsz (ro)
Conditions:
  Type                        Status
  PodReadyToStartContainers   True 
  Initialized                 True 
  Ready                       False 
  ContainersReady             False 
  PodScheduled                True 
Volumes:
  kube-api-access-pnhsz:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    Optional:                false
    DownwardAPI:             true
QoS Class:                   BestEffort
Node-Selectors:              <none>
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:
  Type     Reason     Age                   From               Message
  ----     ------     ----                  ----               -------
  Normal   Scheduled  13m                   default-scheduler  Successfully assigned ops7/ops702-web-7dc558dcfd-25cml to blank-black2
  Normal   Pulling    10m (x5 over 13m)     kubelet            spec.containers{web}: Pulling image "nginx:1.27-alpinee"
  Warning  Failed     10m (x5 over 13m)     kubelet            spec.containers{web}: Failed to pull image "nginx:1.27-alpinee": rpc error: code = NotFound desc = get image config descriptor: unexpected media type text/html for sha256:d66d1e14dce1e26b1948b98164d70f90e4e236a75bca2b074e6d5dced62212b7: not found
  Warning  Failed     10m (x5 over 13m)     kubelet            spec.containers{web}: Error: ErrImagePull
  Normal   BackOff    3m34s (x42 over 13m)  kubelet            spec.containers{web}: Back-off pulling image "nginx:1.27-alpinee"
  Warning  Failed     3m21s (x43 over 13m)  kubelet            spec.containers{web}: Error: ImagePullBackOff
kostya@blank-black2:~$ ubectl -n ops7 get deployment ops702-web \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
ubectl: command not found
kostya@blank-black2:~$ kubectl -n ops7 get deployment ops702-web   -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
nginx:1.27-alpinee
```

- **Причина:**
* nginx:1.27-alpinee - опечатка. Поэтому при Failed to pull image у нас причина что образ не был найден (not found)

- **Решение:**
```bash
kostya@blank-black2:~$ kubectl -n ops7 set image deployment/ops702-web web=nginx:1.27-alpine
deployment.apps/ops702-web image updated
kostya@blank-black2:~$ kubectl -n ops7 rollout status deployment/ops702-web --timeout=180s
deployment "ops702-web" successfully rolled out
```

* Через kubectl set зададим верное имя образа

- **Проверка:**
```bash
kostya@blank-black2:~$ kubectl -n ops7 get pods -l app=ops702-web -o wide
NAME                         READY   STATUS    RESTARTS   AGE   IP               NODE           NOMINATED NODE   READINESS GATES
ops702-web-867569fd9-bs74r   1/1     Running   0          13s   10.233.104.144   blank-black2   <none>           <none>
kostya@blank-black2:~$ kubectl -n ops7 get deployment ops702-web \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
nginx:1.27-alpine
```
* Имя образа теперь верное, и поэтому при pull image находится

- **Профилактика:**
Проверять именование и их существование образов в контейнерах.

### K8S-703  
- **Симптом:**
- **Влияние:**
- **Диагностика:**
```bash
kostya@blank-black2:~$ kubectl -n ops7 rollout status deployment/ops703-api --timeout=180s
deployment "ops703-api" successfully rolled out
kostya@blank-black2:~$ kubectl -n ops7 get pods -l app=ops703-api -o wide --show-labels
NAME                          READY   STATUS    RESTARTS   AGE   IP               NODE           NOMINATED NODE   READINESS GATES   LABELS
ops703-api-58c799cfbc-fxhgj   1/1     Running   0          20m   10.233.104.140   blank-black2   <none>           <none>            app=ops703-api,pod-template-hash=58c799cfbc
ops703-api-58c799cfbc-xcrcb   1/1     Running   0          20m   10.233.104.142   blank-black2   <none>           <none>            app=ops703-api,pod-template-hash=58c799cfbc
kostya@blank-black2:~$ kubectl -n ops7 describe svc ops703-api
Name:                     ops703-api
Namespace:                ops7
Labels:                   <none>
Annotations:              <none>
Selector:                 app=ops703-backend
Type:                     ClusterIP
IP Family Policy:         SingleStack
IP Families:              IPv4
IP:                       10.233.38.196
IPs:                      10.233.38.196
Port:                     <unset>  80/TCP
TargetPort:               80/TCP
Endpoints:                
Session Affinity:         None
Internal Traffic Policy:  Cluster
Events:                   <none>
kostya@blank-black2:~$ kubectl -n ops7 get endpointslice -l kubernetes.io/service-name=ops703-api -o wide
NAME               ADDRESSTYPE   PORTS     ENDPOINTS   AGE
ops703-api-842fp   IPv4          <unset>   <unset>     21m
kostya@blank-black2:~$ kubectl -n ops7 run curltest --rm -i --image=busybox:1.36 --restart=Never -- \
  wget -S -O- -T 3 http://ops703-api.ops7
All commands and output from this session will be recorded in container logs, including credentials and sensitive information passed through the command prompt.
If you don't see a command prompt, try pressing enter.
wget: can't connect to remote host (10.233.38.196): Connection refused
pod "curltest" deleted from ops7 namespace
pod ops7/curltest terminated (Error)
```

- **Причина:**
* У Service селектор `app=ops703-backend`, у подов метка `app=ops703-api`. В EndpointSlice нет адресов бэкендов.

- **Решение:**
```bash
kostya@blank-black2:~$ kubectl -n ops7 patch service ops703-api --type=merge \
  -p '{"spec":{"selector":{"app":"ops703-api"}}}'
service/ops703-api patched
kostya@blank-black2:~$ kubectl -n ops7 get endpointslice -l kubernetes.io/service-name=ops703-api -o wide
NAME               ADDRESSTYPE   PORTS   ENDPOINTS                       AGE
ops703-api-842fp   IPv4          80      10.233.104.142,10.233.104.140   23m
```
- **Проверка:**
```bash
kostya@blank-black2:~$ kubectl -n ops7 run curltest --rm -i --image=busybox:1.36 --restart=Never -- \
  wget -S -O- -T 3 http://ops703-api.ops7
Connecting to ops703-api.ops7 (10.233.38.196:80)
  HTTP/1.1 200 OK
  Server: nginx/1.27.5
  Date: Fri, 20 Nov 2026 12:44:11 GMT
  Content-Type: text/html
  Content-Length: 615
  Last-Modified: Wed, 16 Apr 2025 12:55:34 GMT
  Connection: close
  ETag: "67ffa8c6-267"
  Accept-Ranges: bytes
  
writing to stdout
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
-                    100% |********************************|   615  0:00:00 ETA
written to stdout
pod "curltest" deleted from ops7 namespace
kostya@blank-black2:~$ 
```

- **Профилактика:**
Сопоставлять адреса selector с pod labels и проверять HTTP из другого пода после выкладки.

## Шаг 15. Git

## Что было непонятно

