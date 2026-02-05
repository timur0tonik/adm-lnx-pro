# VPN

## Цель
Создать домашнюю сетевую лабораторию. Научится настраивать VPN-сервер в Linux-based системах.


## Реализация
- Использован **Vagrant + VirtualBox** (Windows 11, Vagrant 2.4.9, VirtualBox 7.2.4).
- Базовый бокс: собственный образ **`ubuntu24-gold`** (Ubuntu 24.04 LTS).
- Конфигурация выполнена **только через `Vagrantfile`** с использованием **shell-провижининга** (Ansible не используется).


## Архитектура
Лаборатория включает следующие компоненты:

| Компонент    | Назначение                           | IP-адрес       |
|--------------|--------------------------------------|----------------|
| `tun-server` | OpenVPN сервер в режиме TUN (L3)     | 192.168.100.10 |
| `tun-client` | Клиент для подключения к TUN-серверу | 192.168.100.11 |
| `tap-server` | OpenVPN сервер в режиме TAP (L2)     | 192.168.100.20 |
| `tap-client` | Клиент для подключения к TAP-серверу | 192.168.100.21 |
| `openvpn-ras`| RAS-сервер для удалённого доступа    | 192.168.100.30 |


## Результаты тестирования

```
vagrant ssh tun-client -- sudo ./test-tun-speed.sh
==================================
Замер скорости через TUN-туннель
==================================
TUN-интерфейс активен
Connecting to host 10.10.1.1, port 5201
Reverse mode, remote host 10.10.1.1 is sending
[  5] local 10.10.1.2 port 55234 connected to 10.10.1.1 port 5201
[ ID] Interval           Transfer     Bitrate
[  5]   0.00-1.00   sec  2.88 MBytes  24.1 Mbits/sec
[  5]   1.00-2.00   sec  3.12 MBytes  26.2 Mbits/sec
[  5]   2.00-3.00   sec  3.12 MBytes  26.2 Mbits/sec
[  5]   3.00-4.00   sec  3.12 MBytes  26.2 Mbits/sec
[  5]   4.00-5.01   sec  3.00 MBytes  25.0 Mbits/sec
[  5]   5.01-6.00   sec  3.00 MBytes  25.3 Mbits/sec
[  5]   6.00-7.00   sec  3.12 MBytes  26.2 Mbits/sec
[  5]   7.00-8.00   sec  3.00 MBytes  25.2 Mbits/sec
[  5]   8.00-9.00   sec  3.25 MBytes  27.2 Mbits/sec
[  5]   9.00-10.00  sec  3.12 MBytes  26.2 Mbits/sec
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-10.02  sec  31.2 MBytes  26.2 Mbits/sec   27             sender
[  5]   0.00-10.00  sec  30.8 MBytes  25.8 Mbits/sec                  receiver

iperf Done.


vagrant ssh tap-client -- sudo ./test-tap-speed.sh
==================================
Замер скорости через TAP-туннель
==================================
TAP-интерфейс активен
Сервер 192.168.101.1 недоступен
PING 192.168.101.1 (192.168.101.1) 56(84) bytes of data.
From 192.168.101.100 icmp_seq=1 Destination Host Unreachable
From 192.168.101.100 icmp_seq=2 Destination Host Unreachable
From 192.168.101.100 icmp_seq=3 Destination Host Unreachable

--- 192.168.101.1 ping statistics ---
3 packets transmitted, 0 received, +3 errors, 100% packet loss, time 2027ms
pipe 2

```