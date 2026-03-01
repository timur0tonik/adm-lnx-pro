# LDAP (FreeIPA)

## Цель
Научиться настраивать FreeIPA сервер и подключать к нему клиентов, а также реализовать аутентификацию по SSH-ключам и настроить firewall.

## Реализация
- **Vagrant + VirtualBox** (Windows 11, Vagrant 2.4.9, VirtualBox 7.2.6).
- Использован бокс **`almalinux/9`** (AlmaLinux 9) для сервера и клиента.
- **Сервер** настраивается через shell-скрипт `freeipa-server-centos.sh` (нативная установка FreeIPA без встроенного DNS).
- **Клиент** настраивается через Ansible (плейбук `playbook-client-centos.yml`), что автоматизирует установку пакетов, ввод в домен, настройку SSH и firewalld.
- Выполнены дополнительные задания:
  1. **Аутентификация по SSH-ключам** – на сервере создан тестовый пользователь `testuser` с сгенерированным SSH-ключом; на клиенте включена опция `AuthorizedKeysCommand` в sshd.
  2. **Firewall** – на сервере через firewalld открыты необходимые порты (Kerberos, LDAP, HTTP и др.), на клиенте также настроен firewalld.


## Особенности проектирования и реализации

1. **Выбор ОС**: AlmaLinux 9 (RHEL-совместимый) позволяет использовать нативную установку FreeIPA из официальных репозиториев. В процессе возникли проблемы с IPv6 на loopback, которые были решены принудительным включением IPv6 и добавлением адреса `::1` через `ip addr add`.
2. **Настройка сети клиента**: в `generic/rocky9` и `almalinux/9` имена интерфейсов и соединений NetworkManager могут отличаться. Был реализован динамический поиск имени соединения через `nmcli`.
3. **Автоматизация сервера** выполнена через bash-скрипт, который:
   - отключает firewalld на время установки;
   - настраивает `/etc/hosts` и hostname;
   - включает IPv6 на loopback и принудительно добавляет адрес `::1` (если отсутствует);
   - устанавливает пакеты FreeIPA;
   - выполняет `ipa-server-install` в неинтерактивном режиме без DNS;
   - после установки включает firewalld и открывает порты;
   - создаёт тестового пользователя `testuser` с SSH-ключом.
4. **Автоматизация клиента** через Ansible:
   - устанавливает необходимые пакеты (freeipa-client, sssd, oddjob и др.);
   - настраивает `/etc/hosts`;
   - выполняет `ipa-client-install` с автоматическим вводом пароля;
   - фиксит права на `/etc/sssd/sssd.conf`;
   - включает и запускает службы `sssd` и `oddjobd`;
   - настраивает `sshd` для использования `sss_ssh_authorizedkeys`;
   - открывает порты в firewalld.
5. **Дополнительные задания**:
   - SSH-ключи: на сервере генерируется ключ, публичная часть добавляется пользователю `testuser`. Приватная часть сохраняется в `/home/vagrant/testuser_key`.
   - Firewall: на сервере открыты порты для Kerberos, LDAP, HTTP и SSH; на клиенте – только необходимые для работы с сервером.

## Результаты тестирования

### Проверка сервера

```
$ vagrant ssh freeipa-server

# Проверка статуса служб FreeIPA (DNS не используется, поэтому named и ntp отсутствуют)
[vagrant@ipa ~]$ sudo ipactl status
Directory Service: RUNNING
krb5kdc Service: RUNNING
kadmin Service: RUNNING
httpd Service: RUNNING
ipa-custodia Service: RUNNING
pki-tomcatd Service: RUNNING
ipa-otpd Service: RUNNING
ipa: INFO: The ipactl command was successful

# Получение билета администратора
[vagrant@ipa ~]$ echo "Vagrant123!" | kinit admin
Password for admin@EXAMPLE.COM:

# Поиск тестового пользователя
[vagrant@ipa ~]$ ipa user-find testuser
--------------
1 user matched
--------------
  User login: testuser
  First name: Test
  Last name: User
  Home directory: /home/testuser
  Login shell: /bin/sh
  Principal name: testuser@EXAMPLE.COM
  Principal alias: testuser@EXAMPLE.COM
  Email address: testuser@example.com
  UID: 196600003
  GID: 196600003
  SSH public key fingerprint: SHA256:m+M9VXu7BWxFSjOPlEAMHi6pCegmfhRdsYOFBo1euAk root@ipa.example.com (ssh-rsa)
  Account disabled: False
----------------------------
Number of entries returned 1
----------------------------

# Проверка приватного ключа
[vagrant@ipa ~]$ cat /home/vagrant/testuser_key
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAABFwAAAAdzc2gtcn
NhAAAAAwEAAQAAAQEArkJcTiA8gBVteioNyoBPFr8a3VO7YdiKWEExtY/CkCFqmP8o/QVK
7pRUh8rE2jC5gkwteBqxLBk2458dQGjqLPJeIiBZs6xR6BGz7AX0LbokYPtqVGY1SvgNgj
r6IjrY3beWoJ2R7+68dwyq6dvvL7k/YKakYrxP1HnwrjEPXR3/EZD6+/9Zc6yi03RpS4ug
5XpLxOXyQQFZXb8+DA9JoBQzgnlDtxj//7h3D47BU5x/oOvo8dSGWIpjACLTA6DyY9qQvi
oDHRt4m/x8epIR8EEYbmBMMitL73H44vAUCohlfvVdheaO1leo9NObuGy/80FQG98hrCXb
sl6ljeqtNwAAA9AQhAE0EIQBNAAAAAdzc2gtcnNhAAABAQCuQlxOIDyAFW16Kg3KgE8Wvx
rdU7th2IpYQTG1j8KQIWqY/yj9BUrulFSHysTaMLmCTC14GrEsGTbjnx1AaOos8l4iIFmz
rFHoEbPsBfQtuiRg+2pUZjVK+A2COvoiOtjdt5agnZHv7rx3DKrp2+8vuT9gpqRivE/Uef
CuMQ9dHf8RkPr7/1lzrKLTdGlLi6DlekvE5fJBAVldvz4MD0mgFDOCeUO3GP//uHcPjsFT
nH+g6+jx1IZYimMAItMDoPJj2pC+KgMdG3ib/Hx6khHwQRhuYEwyK0vvcfji8BQKiGV+9V
2F5o7WV6j005u4bL/zQVAb3yGsJduyXqWN6q03AAAAAwEAAQAAAQAa+mQe+5z85BRcYZlb
/KGsma6M4xMzXUUMenS53AVZBLYOShFBnCmoe7ywfzhwYohofzxaMqEI/OhYtMALF5MK8q
+XJJ9ZPTg7BPlFdPsuKc91rPFzxT/CmQTtC2Nr8Y9fQrZ7rEQKkNE1tHeGGB9/fx8BlXBa
vDZhufUvNUzgc0FP51A23wc01mQO541n/CodGWcx8PYak/6Wwn1k1ffUytokHlVjPlYnto
DVUg5T7UFPbwV0nG/+5hgMpWd65VYAw2LrFM45tJGQkrv8cVAJA+sSF3A965nej1TfqO6x
GrJN+SM2t58T5ACD9pr8uN9lRUhaXR+0elEoY54/4PGNAAAAgEXVNdQ09D44ezwnVDY9ku
DwZjwDOPUvnSX8AHWyjyPTc8wm4j1S/haP6Kjgy3sy+kXltw+S7RgAjJHXO+VPv8eHAH0z
IMRprBMYlwIln+DOZbkmUN6y4C1AB5IBf1h1Z1oLvroLbWtG8L4YOqSNRaIJDyaJs1VGpM
8IwAhiv4LRAAAAgQDv6+0bhKK33+y1Q2CXGW7DlweF8uxwmq2Jfq36H/ZEvTo5xWReSQkN
p6cR2Le7S2bbP5yZ6ZkLTmC94AMlURhLp0wC7nT0odpoZssxyEbwJKA75/LqxO7dg1rl9u
dP60NSyEYX5upvRW/BBCqWUDvVRgpfFVIR90oJFIr8AN366wAAAIEAue/vwcoqHtuQTXE8
5voW22HYtB2003LCv9fXRqOWNCVhq66yPwpysy9S77vYReFL9idlVHdVDdBRYIdFI7NLnY
mKyjhKBbNi259UFpxPP9zcyZ5HaFkK3aD/xTbd0WN9SUwKz2zHZ1cQx1rXu9ZP31cJgnVx
V9gZA2zfDg4ra+UAAAAUcm9vdEBpcGEuZXhhbXBsZS5jb20BAgMEBQYH
-----END OPENSSH PRIVATE KEY-----

# Проверка правил firewalld (порты DNS не открыты)
[vagrant@ipa ~]$ sudo firewall-cmd --list-all
public (active)
  target: default
  icmp-block-inversion: no
  interfaces: eth0 eth1
  sources:
  services: cockpit dhcpv6-client http https kerberos kpasswd ldap ldaps ssh
  ports: 80/tcp 443/tcp 389/tcp 636/tcp 88/tcp 464/tcp
  protocols:
  forward: yes
  masquerade: no
  forward-ports:
  source-ports:
  icmp-blocks:
  rich rules:

```

### Проверка клиента
```
$ vagrant ssh freeipa-client

# Проверка статуса SSSD
[vagrant@client ~]$ sudo systemctl status sssd | grep Active
     Active: active (running) since Sun 2026-03-01 10:41:48 UTC; 39min ago

# Проверка, что пользователь testuser доступен через SSSD
[vagrant@client ~]$ getent passwd testuser
testuser:*:196600003:196600003:Test User:/home/testuser:/bin/sh

# Получение билета Kerberos для администратора
[vagrant@client ~]$ echo "Vagrant123!" | kinit admin
Password for admin@EXAMPLE.COM:
[vagrant@client ~]$ klist
Ticket cache: KCM:1000
Default principal: admin@EXAMPLE.COM

Valid starting       Expires              Service principal
03/01/2026 11:22:08  03/02/2026 10:44:56  krbtgt/EXAMPLE.COM@EXAMPLE.COM

# Поиск пользователя admin через IPA
[vagrant@client ~]$ ipa user-find admin
--------------
1 user matched
--------------
  User login: admin
  Last name: Administrator
  Home directory: /home/admin
  Login shell: /bin/bash
  Principal name: admin@EXAMPLE.COM
  Principal alias: admin@EXAMPLE.COM, root@EXAMPLE.COM
  UID: 196600000
  GID: 196600000
  Account disabled: False
----------------------------
Number of entries returned 1
----------------------------

# Проверка правил firewalld
[vagrant@client ~]$ sudo firewall-cmd --list-all
public (active)
  target: default
  icmp-block-inversion: no
  interfaces: eth0 eth1
  sources:
  services: cockpit dhcpv6-client ssh
  ports:
  protocols:
  forward: yes
  masquerade: no
  forward-ports:
  source-ports:
  icmp-blocks:
  rich rules:

# Проверка входа по SSH-ключу для пользователя testuser
# Копируем приватный ключ с сервера (файл /home/vagrant/testuser_key)
[vagrant@client ~]$ cat > /tmp/testuser_key <<'EOF'
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAABFwAAAAdzc2gtcn
NhAAAAAwEAAQAAAQEArkJcTiA8gBVteioNyoBPFr8a3VO7YdiKWEExtY/CkCFqmP8o/QVK
7pRUh8rE2jC5gkwteBqxLBk2458dQGjqLPJeIiBZs6xR6BGz7AX0LbokYPtqVGY1SvgNgj
r6IjrY3beWoJ2R7+68dwyq6dvvL7k/YKakYrxP1HnwrjEPXR3/EZD6+/9Zc6yi03RpS4ug
5XpLxOXyQQFZXb8+DA9JoBQzgnlDtxj//7h3D47BU5x/oOvo8dSGWIpjACLTA6DyY9qQvi
oDHRt4m/x8epIR8EEYbmBMMitL73H44vAUCohlfvVdheaO1leo9NObuGy/80FQG98hrCXb
sl6ljeqtNwAAA9AQhAE0EIQBNAAAAAdzc2gtcnNhAAABAQCuQlxOIDyAFW16Kg3KgE8Wvx
rdU7th2IpYQTG1j8KQIWqY/yj9BUrulFSHysTaMLmCTC14GrEsGTbjnx1AaOos8l4iIFmz
rFHoEbPsBfQtuiRg+2pUZjVK+A2COvoiOtjdt5agnZHv7rx3DKrp2+8vuT9gpqRivE/Uef
CuMQ9dHf8RkPr7/1lzrKLTdGlLi6DlekvE5fJBAVldvz4MD0mgFDOCeUO3GP//uHcPjsFT
nH+g6+jx1IZYimMAItMDoPJj2pC+KgMdG3ib/Hx6khHwQRhuYEwyK0vvcfji8BQKiGV+9V
2F5o7WV6j005u4bL/zQVAb3yGsJduyXqWN6q03AAAAAwEAAQAAAQAa+mQe+5z85BRcYZlb
/KGsma6M4xMzXUUMenS53AVZBLYOShFBnCmoe7ywfzhwYohofzxaMqEI/OhYtMALF5MK8q
+XJJ9ZPTg7BPlFdPsuKc91rPFzxT/CmQTtC2Nr8Y9fQrZ7rEQKkNE1tHeGGB9/fx8BlXBa
vDZhufUvNUzgc0FP51A23wc01mQO541n/CodGWcx8PYak/6Wwn1k1ffUytokHlVjPlYnto
DVUg5T7UFPbwV0nG/+5hgMpWd65VYAw2LrFM45tJGQkrv8cVAJA+sSF3A965nej1TfqO6x
GrJN+SM2t58T5ACD9pr8uN9lRUhaXR+0elEoY54/4PGNAAAAgEXVNdQ09D44ezwnVDY9ku
DwZjwDOPUvnSX8AHWyjyPTc8wm4j1S/haP6Kjgy3sy+kXltw+S7RgAjJHXO+VPv8eHAH0z
IMRprBMYlwIln+DOZbkmUN6y4C1AB5IBf1h1Z1oLvroLbWtG8L4YOqSNRaIJDyaJs1VGpM
8IwAhiv4LRAAAAgQDv6+0bhKK33+y1Q2CXGW7DlweF8uxwmq2Jfq36H/ZEvTo5xWReSQkN
p6cR2Le7S2bbP5yZ6ZkLTmC94AMlURhLp0wC7nT0odpoZssxyEbwJKA75/LqxO7dg1rl9u
dP60NSyEYX5upvRW/BBCqWUDvVRgpfFVIR90oJFIr8AN366wAAAIEAue/vwcoqHtuQTXE8
5voW22HYtB2003LCv9fXRqOWNCVhq66yPwpysy9S77vYReFL9idlVHdVDdBRYIdFI7NLnY
mKyjhKBbNi259UFpxPP9zcyZ5HaFkK3aD/xTbd0WN9SUwKz2zHZ1cQx1rXu9ZP31cJgnVx
V9gZA2zfDg4ra+UAAAAUcm9vdEBpcGEuZXhhbXBsZS5jb20BAgMEBQYH
-----END OPENSSH PRIVATE KEY-----
EOF
[vagrant@client ~]$ chmod 600 /tmp/testuser_key
[vagrant@client ~]$ ssh -i /tmp/testuser_key testuser@localhost
Last login: Sun Mar  1 11:01:03 2026 from 127.0.0.1

```