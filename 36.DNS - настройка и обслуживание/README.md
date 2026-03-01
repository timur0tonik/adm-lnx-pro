# Настраиваем split-dns

## Цель

Создать домашнюю сетевую лабораторию для изучения основ DNS и настройки технологии Split-DNS в Linux.  
В результате выполнения работы должен быть развернут Vagrant-стенд с двумя DNS-серверами (master – ns01, slave – ns02) и двумя клиентами (client, client2).  
Требуется настроить зоны `dns.lab` и `newdns.lab` с определёнными записями, а также реализовать Split-DNS таким образом, чтобы:

- клиент1 (`client`, 192.168.50.15) видел обе зоны, но в зоне `dns.lab` только запись `web1`;
- клиент2 (`client2`, 192.168.50.16) видел только зону `dns.lab` (обе записи `web1` и `web2`), но не видел зону `newdns.lab`.


## Реализация
- **Vagrant + VirtualBox** (Windows 11, Vagrant 2.4.9, VirtualBox 7.2.6).
- Использован бокс **`almalinux/9`** (AlmaLinux 9)
- Выполнены дополнительные задания:
1. **Форк и клонирование** базового стенда [erlong15/vagrant-bind](https://github.com/erlong15/vagrant-bind).
2. **Модификация Vagrantfile**:
   - Добавлена виртуальная машина `client2` с IP 192.168.50.16.
   - Память всех ВМ увеличена до 1024 МБ для стабильной работы.
   - Тип провижинера изменён на `ansible_local`, так как хостовая ОС – Windows.
3. **Обновление Ansible-плейбука (`playbook.yml`)**:
   - Пакеты: `bind`, `bind-utils` (установка `ntp` исключена, используется встроенный chrony).
   - Создание необходимых каталогов и установка прав.
   - Копирование конфигурационных файлов и зон.
   - Настройка SELinux: после копирования файлов выполняется `restorecon`.
4. **Создание новой зоны `newdns.lab`**:
   - Файл зоны `named.newdns.lab` с записью `www`, указывающей на оба клиента.
   - Внесение соответствующих блоков в `master-named.conf` и `slave-named.conf`.
5. **Добавление записей в зону `dns.lab`**:
   - В файл `named.dns.lab` добавлены записи `web1` (192.168.50.15) и `web2` (192.168.50.16).
   - Для Split-DNS создан дополнительный файл зоны `named.dns.lab.client`, содержащий только `web1`.
6. **Настройка Split-DNS**:
   - Сгенерированы ключи TSIG для клиентов (`client-key`, `client2-key`).
   - В конфигурации `named.conf` на обоих серверах описаны access-листы и представления (view):
     - view `client` – для клиента 192.168.50.15 (зоны `dns.lab` (урезанная) и `newdns.lab`);
     - view `client2` – для клиента 192.168.50.16 (зона `dns.lab` (полная) и обратная зона);
     - view `default` – для всех остальных (полный набор зон).
   - В slave-конфигурации указаны пути к файлам зон в каталоге `/etc/named/slaves/` и настроена репликация с использованием ключей.
7. **Дополнительное задание**:
   - Настройка выполнена без отключения SELinux. Корректные контексты восстановлены с помощью `restorecon`.

## Результаты тестирования

### Проверка сервера

#### Клиент client (192.168.50.15)
```
$ vagrant ssh client
# Проверяем web1.dns.lab (должен быть доступен)
[vagrant@client ~]$ dig web1.dns.lab +short
192.168.50.15

# Проверяем web2.dns.lab
[vagrant@client ~]$ dig web2.dns.lab +short
[vagrant@client ~]$

# Проверяем www.newdns.lab (должен возвращать оба IP)
[vagrant@client ~]$ dig www.newdns.lab +short
192.168.50.15
192.168.50.16
```

#### Клиент client2 (192.168.50.16)
```
$ vagrant ssh client2
# web1.dns.lab должен быть доступен
[vagrant@client2 ~]$ dig web1.dns.lab +short
192.168.50.15

# web2.dns.lab должен быть доступен
[vagrant@client2 ~]$ dig web2.dns.lab +short
192.168.50.16

# www.newdns.lab не должен быть доступен
[vagrant@client2 ~]$ dig www.newdns.lab +short
[vagrant@client2 ~]$
```


#### Проверка работы slave-сервера
```
[vagrant@ns02 ~]$ sudo sed -i 's/^nameserver 192.168.50.10/#&/' /etc/resolv.conf
[vagrant@ns02 ~]$ dig web1.dns.lab +short
192.168.50.15
[vagrant@ns02 ~]$ sudo sed -i 's/^#nameserver 192.168.50.10/nameserver 192.168.50.10/' /etc/resolv.conf
[vagrant@ns02 ~]$
```

