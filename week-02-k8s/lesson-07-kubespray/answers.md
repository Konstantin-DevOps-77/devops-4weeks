# Урок 7. Кластер через Kubespray

## Вопросы для самопроверки (README)
1.
...
10.

## Шаг 0. Выбор машины
(выводы команд, таблица, решение: вариант А / Б и почему)

## Шаг 1. Нода (для варианта А)
Выбрано создание нового сервера.
## Шаг 2. Ключ для Ansible
kostya@blank-black:~/projects/devops-4weeks/week-02-k8s/lesson-07-kubespray$ ssh -i ~/.ssh/kubespray kostya@82.148.225.27 'hostname; whoami'
blank-black2.ptr.network
kostya
## Шаг 3. Имя ноды
#Терминал А(Ansible)
kostya@blank-black:~/projects/devops-4weeks/week-02-k8s/lesson-07-kubespray$ ssh -i ~/.ssh/kubespray kostya@82.148.225.27 'hostname -s'
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

### 11.1 ... 11.10
## Шаг 12. Доступ с Windows (если делал)
## Шаг 13. NodePort снаружи
## Шаг 14. Тикеты
### K8S-701
- **Симптом:**
- **Влияние:**
- **Диагностика:**
- **Причина:**
- **Решение:**
- **Проверка:**
- **Профилактика:**
### K8S-702
### K8S-703
## Шаг 15. Git

## Что было непонятно

