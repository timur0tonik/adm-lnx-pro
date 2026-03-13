# Репликация PostgreSQL и резервное копирование с Barman

## Цель
Настроить hot_standby репликацию с использованием физических слотов и организовать резервное копирование с помощью Barman.

## Выполненные требования
- Созданы три виртуальные машины:
  - `node1` – мастер PostgreSQL
  - `node2` – горячий standby (реплика)
  - `barman` – сервер резервного копирования Barman
- Репликация настроена через потоковую передачу WAL с использованием слота репликации.
- Barman выполняет резервное копирование с помощью `pg_basebackup` и может управлять WAL-файлами.

## Технологии
- **Хост**: Windows 11, Vagrant 2.4.9, VirtualBox 7.2.6.
- **Гостевые ОС**: собственный образ `ubuntu24-gold` (Ubuntu 24.04 LTS).
- **Система управления конфигурацией**: Ansible (локальный провижининг `ansible_local`).
- **СУБД**: PostgreSQL 17 из официального репозитория PostgreSQL.
- **Резервное копирование**: Barman.

## Структура проекта
```
.
├── Vagrantfile
└── provisioning
    ├── playbook.yml
    ├── pg_hba.conf.j2
    ├── postgresql_master.conf.j2
    ├── postgresql_slave.conf.j2
    ├── barman.conf.j2
    └── node1.conf.j2
```

## Результаты тестирования

### Проверка репликации мастере
```
vagrant@node1:~$ sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"
 pid  | usesysid |  usename   |  application_name  |  client_addr  | client_hostname | client_port |         backend_start         | backend_xmin |   state   | sent_lsn  | write_lsn | flush_lsn | replay_lsn |    write_lag    |    flush_lag    |   replay_lag    | sync_priority | sync_state |          reply_time
------+----------+------------+--------------------+---------------+-----------------+-------------+-------------------------------+--------------+-----------+-----------+-----------+-----------+------------+-----------------+-----------------+-----------------+---------------+------------+-------------------------------
 7351 |    16384 | replicator | 17/main            | 192.168.57.12 |                 |       34728 | 2026-03-13 07:32:10.362181+00 |          751 | streaming | 0/4000168 | 0/4000168 | 0/4000168 | 0/4000168  |                 |                 |                 |             0 | async      | 2026-03-13 07:42:44.056672+00
 7377 |    16385 | barman     | barman_receive_wal | 192.168.57.13 |                 |       54558 | 2026-03-13 07:38:02.651752+00 |              | streaming | 0/4000168 | 0/4000168 | 0/4000000 |            | 00:00:01.002622 | 00:04:40.516156 | 00:04:40.516156 |             0 | async      | 2026-03-13 07:42:43.194574+00
(2 rows)


vagrant@node1:~$ sudo -u postgres psql -c "SELECT slot_name, slot_type, active FROM pg_replication_slots;"
  slot_name  | slot_type | active
-------------+-----------+--------
 node1_slot  | physical  | f
 barman_slot | physical  | t
(2 rows)

```

### Проверка репликации слейве
```
vagrant@node2:~$ sudo -u postgres psql -c "SELECT pg_is_in_recovery();"
 pg_is_in_recovery
-------------------
 t
(1 row)
```

### Проверка репликации Barman

```
vagrant@barman:~$ sudo -u barman barman check node1
Server node1:
        PostgreSQL: OK
        superuser or standard user with backup privileges: OK
        PostgreSQL streaming: OK
        wal_level: OK
        replication slot: OK
        directories: OK
        retention policy settings: OK
        backup maximum age: FAILED (interval provided: 4 days, latest backup age: No available backups)
        backup minimum size: OK (0 B)
        wal maximum age: OK (no last_wal_maximum_age provided)
        wal size: OK (0 B)
        compression settings: OK
        failed backups: OK (there are 0 failed backups)
        minimum redundancy requirements: FAILED (have 0 non-incremental backups, expected at least 1)
        pg_basebackup: OK
        pg_basebackup compatible: OK
        pg_basebackup supports tablespaces mapping: OK
        systemid coherence: OK (no system Id stored on disk)
        pg_receivexlog: OK
        pg_receivexlog compatible: OK
        receive-wal running: OK
        archiver errors: OK
vagrant@barman:~$ sudo -u barman barman backup node1
Starting backup using postgres method for server node1 in /var/lib/barman/node1/base/20260313T074959
Backup start at LSN: 0/5000060 (000000010000000000000005, 00000060)
Starting backup copy via pg_basebackup for 20260313T074959
WARNING: pg_basebackup does not copy the PostgreSQL configuration files that reside outside PGDATA. Please manually backup the following files:
        /etc/postgresql/17/main/postgresql.conf
        /etc/postgresql/17/main/pg_hba.conf
        /etc/postgresql/17/main/pg_ident.conf

Copy done (time: 2 seconds)
Finalising the backup.
This is the first backup for server node1
WAL segments preceding the current backup have been found:
        000000010000000000000004 from server node1 has been removed
        000000010000000000000005 from server node1 has been removed
Backup size: 22.3 MiB
Backup end at LSN: 0/7000060 (000000010000000000000007, 00000060)
Backup completed (start time: 2026-03-13 07:49:59.941144, elapsed time: 4 seconds)
Processing xlog segments from streaming for node1 (batch size: 1)
        000000010000000000000007
vagrant@barman:~$ sudo -u barman barman list-backup node1
node1 20260313T074959 - F - Fri Mar 13 07:50:02 2026 - Size: 22.3 MiB - WAL Size: 0 B
vagrant@barman:~$ sudo -u barman barman check node1
Server node1:
        PostgreSQL: OK
        superuser or standard user with backup privileges: OK
        PostgreSQL streaming: OK
        wal_level: OK
        replication slot: OK
        directories: OK
        retention policy settings: OK
        backup maximum age: OK (interval provided: 4 days, latest backup age: 26 seconds)
        backup minimum size: OK (22.3 MiB)
        wal maximum age: OK (no last_wal_maximum_age provided)
        wal size: OK (0 B)
        compression settings: OK
        failed backups: OK (there are 0 failed backups)
        minimum redundancy requirements: OK (have 1 non-incremental backups, expected at least 1)
        pg_basebackup: OK
        pg_basebackup compatible: OK
        pg_basebackup supports tablespaces mapping: OK
        systemid coherence: OK
        pg_receivexlog: OK
        pg_receivexlog compatible: OK
        receive-wal running: OK
        archiver errors: OK
```
