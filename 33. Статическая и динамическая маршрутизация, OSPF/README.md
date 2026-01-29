# OSPF

## Цель
Создать домашнюю сетевую лабораторию и освоить настройку протокола динамической маршрутизации OSPF в Linux.


## Реализация
- Использован **Vagrant + VirtualBox** (Windows 11, Vagrant 2.4.9, VirtualBox 7.2.4).
- Базовый бокс: собственный образ **`ubuntu24-noble`** (Ubuntu 24.04 LTS).
- Конфигурация выполнена **только через `Vagrantfile`** с использованием **shell-провижининга** (Ansible не используется).
- Для маршрутизации применён **FRRouting** из официального репозитория Ubuntu 24.04.



### Сетевые сегменты
| Сеть                | Назначение          | Участники                      |
|---------------------|---------------------|--------------------------------|
| `10.1.1.0/24`       | Клиентская сеть 1   | `client1` ↔ `router1`          |
| `10.2.2.0/24`       | Клиентская сеть 2   | `client2` ↔ `router2`          |
| `10.3.3.0/24`       | Клиентская сеть 3   | `client3` ↔ `router3`          |
| `192.168.10.0/30`   | Линк router1-router2| `router1` ↔ `router2` (cost=10)|
| `192.168.20.0/30`   | Линк router2-router3| `router2` ↔ `router3` (cost=10)|
| `192.168.30.0/30`   | Линк router1-router3| `router1` ↔ `router3` (cost=50)|

### Проверка соседства OSPF

`
vagrant@router1:~$ sudo vtysh -c 'show ip ospf neighbor'

Neighbor ID     Pri State           Up Time         Dead Time Address         Interface                        RXmtL RqstL DBsmL
2.2.2.2           1 Full/Backup     21m54s            35.284s 192.168.10.2    enp0s9:192.168.10.1                  0     0     0
3.3.3.3           1 Full/Backup     18m54s            31.104s 192.168.30.2    enp0s10:192.168.30.1                 0     0     0
`

`
vagrant@router2:~$ sudo vtysh -c 'show ip ospf neighbor'

Neighbor ID     Pri State           Up Time         Dead Time Address         Interface                        RXmtL RqstL DBsmL
1.1.1.1           1 Full/DR         5h08m02s          38.362s 192.168.10.1    enp0s9:192.168.10.2                  0     0     0
3.3.3.3           1 Full/Backup     5h04m56s          34.489s 192.168.20.2    enp0s10:192.168.20.1                 0     0     0
`

`
vagrant@router3:~$ sudo vtysh -c 'show ip ospf neighbor'

Neighbor ID     Pri State           Up Time         Dead Time Address         Interface                        RXmtL RqstL DBsmL
2.2.2.2           1 Full/DR         5h05m38s          36.887s 192.168.20.1    enp0s9:192.168.20.2                  0     0     0
1.1.1.1           1 Full/DR         5h05m43s          36.873s 192.168.30.1    enp0s10:192.168.30.2                 0     0     0
`

### Асимметричный роутинг

`
vagrant@router3:~$ sudo vtysh -c 'show ip route 10.1.1.0/24'
Routing entry for 10.1.1.0/24
  Known via "ospf", distance 110, metric 21, best
  Last update 05:56:55 ago
  * 192.168.20.1, via enp0s9, weight 1
`

### Проверка связности между клиентами

`
vagrant@client1:~$ ping -c 3 10.3.3.10
PING 10.3.3.10 (10.3.3.10) 56(84) bytes of data.
64 bytes from 10.3.3.10: icmp_seq=1 ttl=61 time=3.34 ms
64 bytes from 10.3.3.10: icmp_seq=2 ttl=61 time=3.64 ms
64 bytes from 10.3.3.10: icmp_seq=3 ttl=61 time=3.08 ms

--- 10.3.3.10 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2004ms
rtt min/avg/max/mdev = 3.078/3.352/3.639/0.229 ms
`

`
vagrant@client3:~$ ping -c 4 10.1.1.10
PING 10.1.1.10 (10.1.1.10) 56(84) bytes of data.
64 bytes from 10.1.1.10: icmp_seq=1 ttl=61 time=3.50 ms
64 bytes from 10.1.1.10: icmp_seq=2 ttl=61 time=3.64 ms
64 bytes from 10.1.1.10: icmp_seq=3 ttl=61 time=4.37 ms
64 bytes from 10.1.1.10: icmp_seq=4 ttl=61 time=3.57 ms

--- 10.1.1.10 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3005ms
rtt min/avg/max/mdev = 3.496/3.768/4.373/0.352 ms
`