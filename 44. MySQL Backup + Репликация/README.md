# Репликация mysql

## Цель
Настроить **GTID-репликацию** MySQL между двумя виртуальными машинами (master → slave).  
База данных `bet` должна быть развёрнута на мастере, при этом реплицироваться должны только следующие таблицы:
- `bookmaker`
- `competition`
- `market`
- `odds`
- `outcome`

Таблицы `events_on_demand` и `v_same_event` должны **игнорироваться** на слейве.

---

## Реализация
- **Хост**: Windows 11, Vagrant 2.4.9, VirtualBox 7.2.6.
- **Гостевые ОС**: собственный образ `ubuntu24-gold` (Ubuntu 24.04 LTS).
- **Виртуальные машины**:
  - `master` (IP: 192.168.11.150)
  - `slave`  (IP: 192.168.11.151)
- **Система управления конфигурацией**: Ansible (устанавливается через shell-провижинер, затем запускается `ansible_local`).
- **MySQL**: версия **8.0** из стандартного репозитория Ubuntu.
- **Провижинг**:
  1. Shell-скрипт: создание swap-файла (1 ГБ) и установка Ansible.
  2. Ansible-плейбук `provisioning/playbook.yml` – настройка MySQL, конфигурация, импорт дампа, настройка репликации.

---

## Особенности проектирования и реализации

1. **Конфигурационные файлы**  
   - Все настройки MySQL вынесены в отдельные файлы в папке `conf.d/` и копируются в `/etc/mysql/conf.d/`.  
   - `01-basics.cnf` – базовые параметры, `server-id` динамически подставляется Ansible.  
   - `05-binlog.cnf` – настройки бинарного лога и закомментированные директивы `replicate-ignore-table` (раскомментируются на слейве).

2. **Обработка временного пароля**  
   - В MySQL 8.0 на Ubuntu по умолчанию используется аутентификация через Unix-сокет, поэтому временный пароль не генерируется.  
   - Для работы модулей Ansible мы принудительно задаём пароль root через `mysql_user` после запуска сервера.

3. **Игнорирование таблиц**  
   - На слейве после импорта дампа раскомментируются строки `replicate-ignore-table` в `05-binlog.cnf`, затем MySQL перезапускается.  
   - Проверка: таблицы `events_on_demand` и `v_same_event` отсутствуют на слейве.

4. **Дамп master.sql**  
   - Создаётся на мастере с ключом `--master-data` (содержит позицию бинарного лога) и исключением ненужных таблиц.  
   - Файл передаётся через общую папку `/vagrant` и автоматически импортируется на слейве.

5. **Идемпотентность**  
   - Ansible-плейбук написан с учётом повторного запуска: проверяется наличие файлов, используются модули с параметром `creates`, настройки добавляются через `lineinfile`.

---

## Результаты тестирования

### Проверка на мастере
```
vagrant@master:~$ mysql -uroot -p'OtusLinux2024!' -e "USE bet; SHOW TABLES;"
mysql: [Warning] Using a password on the command line interface can be insecure.
+---------------+
| Tables_in_bet |
+---------------+
| bookmaker     |
| competition   |
| market        |
| odds          |
| outcome       |
+---------------+
vagrant@master:~$ mysql -uroot -p'OtusLinux2024!' -e "SHOW VARIABLES LIKE 'gtid_mode';"
mysql: [Warning] Using a password on the command line interface can be insecure.
+---------------+-------+
| Variable_name | Value |
+---------------+-------+
| gtid_mode     | ON    |
+---------------+-------+
vagrant@master:~$ ss -tlnp | grep 3306
LISTEN 0      70         127.0.0.1:33060      0.0.0.0:*
LISTEN 0      151          0.0.0.0:3306       0.0.0.0:*
vagrant@master:~$

```

### Проверка на слейве
```
vagrant@slave:~$ mysql -uroot -p'OtusLinux2024!' -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master"
mysql: [Warning] Using a password on the command line interface can be insecure.
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
        Seconds_Behind_Master: 0
      Slave_SQL_Running_State: Replica has read all relay log; waiting for more updates
vagrant@slave:~$
```