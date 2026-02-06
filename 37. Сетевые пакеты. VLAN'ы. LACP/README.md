# Строим бонды и вланы

## Цель
Научиться настраивать VLAN и LACP.

## Реализация
- Использован **Vagrant + VirtualBox** (Windows 11, Vagrant 2.4.9, VirtualBox 7.2.6).
- Базовый бокс: собственный образ **`ubuntu24-gold`** (Ubuntu 24.04 LTS).
- Конфигурация выполнена **только через `Vagrantfile`** с использованием **shell-провижининга** (Ansible не используется).

## Описание задания
- В тестовой подсети `testLAN` развернуть 4 сервера с дополнительными интерфейсами:
  - `testClient1` → `10.10.10.254/24`
  - `testClient2` → `10.10.10.254/24`
  - `testServer1` → `10.10.10.1/24`
  - `testServer2` → `10.10.10.1/24`
- Настроить изоляцию трафика через VLAN:
  - `testClient1` ↔ `testServer1` (VLAN 10)
  - `testClient2` ↔ `testServer2` (VLAN 20)
- Между `centralRouter` и `inetRouter` настроить агрегацию двух линков (бонд) и проверить отказоустойчивость при отключении интерфейсов.


## Схема сети
+------------------+ VLAN 10 +-----------------+
| testClient1  | --------------- | testServer1 |
| 10.10.10.254 |    (eth1.10)    | 10.10.10.1  |
+----------------------+ +---------------------+
+------------------+ VLAN 20 +-----------------+
| testClient2  | --------------- | testServer2 |
| 10.10.10.254 |   (eth1.20)     | 10.10.10.1  |
+----------------------+ +---------------------+


   +----------------+       +----------------+
   | centralRouter  | ======|  inetRouter    |
   | 192.168.200.1  | bond0 | 192.168.200.2  |
   +----------------+       +----------------+
      |           |           |            |
   bondLAN1    bondLAN2    bondLAN1    bondLAN2
   (enp0s8)    (enp0s9)    (enp0s8)    (enp0s9)



## Результаты тестирования
```
vagrant ssh testClient1 -c "ping -c 3 10.10.10.1"
PING 10.10.10.1 (10.10.10.1) 56(84) bytes of data.
64 bytes from 10.10.10.1: icmp_seq=1 ttl=64 time=1.78 ms
64 bytes from 10.10.10.1: icmp_seq=2 ttl=64 time=1.10 ms
64 bytes from 10.10.10.1: icmp_seq=3 ttl=64 time=1.10 ms

--- 10.10.10.1 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2004ms
rtt min/avg/max/mdev = 1.099/1.326/1.780/0.320 ms


=vagrant ssh testClient2 -c "ping -c 3 10.10.10.1"
PING 10.10.10.1 (10.10.10.1) 56(84) bytes of data.
64 bytes from 10.10.10.1: icmp_seq=1 ttl=64 time=1.84 ms
64 bytes from 10.10.10.1: icmp_seq=2 ttl=64 time=1.18 ms
64 bytes from 10.10.10.1: icmp_seq=3 ttl=64 time=0.864 ms

--- 10.10.10.1 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2002ms
rtt min/avg/max/mdev = 0.864/1.292/1.839/0.406 ms

vagrant ssh testClient1 -c "arp -n 10.10.10.1 | grep -v incomplete"
Address                  HWtype  HWaddress           Flags Mask            Iface
10.10.10.1               ether   08:00:27:f1:47:3c   C                     vlan10

vagrant ssh testClient2 -c "arp -n 10.10.10.1 | grep -v incomplete"
Address                  HWtype  HWaddress           Flags Mask            Iface
10.10.10.1               ether   08:00:27:ef:a2:5b   C                     vlan20

vagrant ssh centralRouter -c "ping -c 3 192.168.200.2"
PING 192.168.200.2 (192.168.200.2) 56(84) bytes of data.
From 192.168.200.1 icmp_seq=1 Destination Host Unreachable
From 192.168.200.1 icmp_seq=2 Destination Host Unreachable
From 192.168.200.1 icmp_seq=3 Destination Host Unreachable

--- 192.168.200.2 ping statistics ---
3 packets transmitted, 0 received, +3 errors, 100% packet loss, time 2075ms
pipe 3


vagrant ssh centralRouter -c "cat /proc/net/bonding/bond0"
Ethernet Channel Bonding Driver: v6.8.0-90-generic

Bonding Mode: fault-tolerance (active-backup)
Primary Slave: enp0s8 (primary_reselect always)
Currently Active Slave: enp0s8
MII Status: up
MII Polling Interval (ms): 100
Up Delay (ms): 0
Down Delay (ms): 0
Peer Notification Delay (ms): 0

Slave Interface: enp0s8
MII Status: up
Speed: 1000 Mbps
Duplex: full
Link Failure Count: 0
Permanent HW addr: 08:00:27:86:2c:34
Slave queue ID: 0

Slave Interface: enp0s9
MII Status: up
Speed: 1000 Mbps
Duplex: full
Link Failure Count: 0
Permanent HW addr: 08:00:27:d8:e3:fa
Slave queue ID: 0


& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" controlvm "vlan-bond_centralRouter_1770403566539_88922" setlinkstate2 off

vagrant ssh centralRouter -c "ping -c 10 192.168.200.2"
PING 192.168.200.2 (192.168.200.2) 56(84) bytes of data.
From 192.168.200.1 icmp_seq=1 Destination Host Unreachable
From 192.168.200.1 icmp_seq=2 Destination Host Unreachable
From 192.168.200.1 icmp_seq=3 Destination Host Unreachable
From 192.168.200.1 icmp_seq=4 Destination Host Unreachable
From 192.168.200.1 icmp_seq=5 Destination Host Unreachable
From 192.168.200.1 icmp_seq=6 Destination Host Unreachable
From 192.168.200.1 icmp_seq=7 Destination Host Unreachable
From 192.168.200.1 icmp_seq=8 Destination Host Unreachable
From 192.168.200.1 icmp_seq=9 Destination Host Unreachable
From 192.168.200.1 icmp_seq=10 Destination Host Unreachable

--- 192.168.200.2 ping statistics ---
10 packets transmitted, 0 received, +10 errors, 100% packet loss, time 9229ms
pipe 4


& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" controlvm "vlan-bond_centralRouter_1770403566539_88922" setlinkstate2 on

```