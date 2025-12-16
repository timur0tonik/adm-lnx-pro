# Домашнее задание: PAM

## Задание
Ограничить доступ к системе для всех пользователей, кроме группы администраторов, в выходные дни (суббота и воскресенье), за исключением праздничных дней.

## Реализация

### 1. Подход
- Использован комбинированный PAM-стек в `/etc/pam.d/common-account`:
  - `pam_exec.so` → вызывает `/usr/local/bin/pam-holiday-check`
  - `pam_time.so` → применяет правила из `/etc/security/time.conf`

- **Порядок важен**: `pam_exec` идёт **до** `pam_time` и использует `account required`.  
  Если скрипт завершается с кодом `0` (разрешено), `pam_time` **не проверяется**.

- Скрипт `pam-holiday-check`:
  - разрешает вход в будние дни (`1–5`),
  - в выходные (`6=sat`, `7=sun`) — проверяет наличие даты в списке праздников,
  - использует статический список (для ДЗ), но легко расширяем.

- В `time.conf` разрешаем безусловный доступ:
  - группе `@sudo` (стандартная админ-группа в Ubuntu 24.04),
  - пользователю `dockeruser` (для упрощения тестирования и выполнения повышенной части).


### 2. Пользователи и права

Пользователь:`timur`. Группа: `sudo` Ограничения: Нет — всегда разрешён. Доп. права: `sudo` без пароля (по умолчанию в Vagrant-боксе)
Пользователь: `dockeruser`. Группа: `docker`. Ограничения: Нет — всегда разрешён. Доп. права: `sudo docker *`, `sudo systemctl restart docker.service` без пароля.


### 3. Праздничные дни

Файл: `/etc/security/holidays`  
Формат: `YYYY-MM-DD` (по одной дате на строку)  
Текущее содержимое:
2025-12-16
2025-12-17
2026-01-01

### 4. Проверка работы

#### 4.1. Проверка PAM-стека
vagrant@pam-hw:~$ grep -v '^#' /etc/pam.d/common-account
account required        pam_exec.so quiet /usr/local/bin/pam-holiday-check
account [success=1 new_authtok_reqd=done default=ignore]        pam_unix.so
account requisite                       pam_deny.so
account required                        pam_permit.so
account required pam_time.so


#### 4.2. Тест скрипта

# Сегодня — праздник?
vagrant@pam-hw:~$ /usr/local/bin/pam-holiday-check && echo "OK" || echo "DENIED"
OK

# Проверим субботу (имитация):
vagrant@pam-hw:~$ sudo date -s '2025-12-20 10:00:00'
Sat Dec 20 10:00:00 AM UTC 2025
vagrant@pam-hw:~$ /usr/local/bin/pam-holiday-check && echo OK || echo DENIED
OK

#### 4.3. Тест входа (извне VM)
Разрешено (админ):
ssh timur@172.30.122.213
Welcome to Ubuntu 24.04.3 LTS (GNU/Linux 6.8.0-85-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Tue Dec 16 07:45:11 PM UTC 2025

  System load:  0.54               Processes:             117
  Usage of /:   47.0% of 11.21GB   Users logged in:       1
  Memory usage: 31%                IPv4 address for eth0: 172.30.122.213
  Swap usage:   1%


Expanded Security Maintenance for Applications is not enabled.

45 updates can be applied immediately.
To see these additional updates run: apt list --upgradable

1 additional security update can be applied with ESM Apps.
Learn more about enabling ESM Apps service at https://ubuntu.com/esm


*** System restart required ***

The programs included with the Ubuntu system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Ubuntu comes with ABSOLUTELY NO WARRANTY, to the extent permitted by
applicable law.

To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

timur@pam-hw:~$ logout
Connection to 172.30.122.213 closed.

Разрешено (dockeruser):
ssh dockeruser@172.30.122.213
dockeruser@172.30.122.213's password:
Welcome to Ubuntu 24.04.3 LTS (GNU/Linux 6.8.0-85-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Tue Dec 16 07:59:44 PM UTC 2025

  System load:  0.01               Processes:             114
  Usage of /:   47.1% of 11.21GB   Users logged in:       1
  Memory usage: 30%                IPv4 address for eth0: 172.30.122.213
  Swap usage:   1%


Expanded Security Maintenance for Applications is not enabled.

45 updates can be applied immediately.
To see these additional updates run: apt list --upgradable

1 additional security update can be applied with ESM Apps.
Learn more about enabling ESM Apps service at https://ubuntu.com/esm


*** System restart required ***

The programs included with the Ubuntu system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Ubuntu comes with ABSOLUTELY NO WARRANTY, to the extent permitted by
applicable law.

dockeruser@pam-hw:~$ sudo docker ps
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
dockeruser@pam-hw:~$
