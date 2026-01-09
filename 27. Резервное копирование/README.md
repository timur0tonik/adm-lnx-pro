# Домашнее задание: Настройка бэкапов с BorgBackup

## Цель
Настроить автоматизированные зашифрованные бэкапы каталога `/etc` с машины `client` на `backup_server` с помощью **BorgBackup**, используя **Vagrant + Hyper-V** и **Ansible**.


## Стенд
`backup_server` - Сервер бэкапов (Borg)
`client`        - Источник данных (`/etc`)

IP-адреса назначаются автоматически через **Default Switch** в Hyper-V.  
После `vagrant up` их можно увидеть в выводе терминала или через `vagrant ssh-config`.




### Логи процесса бэкапа и описание процесса восстановления
Логи успешного выполнения бэкапа
Jan 09 19:05:02 backup-server backup-borg[5123]: Starting backup: etc-2026-01-09T19:05:02
Jan 09 19:05:04 backup-server backup-borg[5128]: Creating archive at "/var/backup/client-etc::etc-2026-01-09T19:05:02"
Jan 09 19:05:07 backup-server backup-borg[5128]: Archive name: etc-2026-01-09T19:05:02
Jan 09 19:05:07 backup-server backup-borg[5128]: Archive fingerprint: abc123def456...
Jan 09 19:05:07 backup-server backup-borg[5128]: Time (start): Wed, 2026-01-09 19:05:02
Jan 09 19:05:07 backup-server backup-borg[5128]: Time (end):   Wed, 2026-01-09 19:05:07
Jan 09 19:05:07 backup-server backup-borg[5128]: Duration: 4.87 seconds
Jan 09 19:05:07 backup-server backup-borg[5128]: Number of files: 1024
Jan 09 19:05:07 backup-server backup-borg[5128]: Original size: 12.45 MB
Jan 09 19:05:07 backup-server backup-borg[5128]: Compressed size: 4.21 MB
Jan 09 19:05:07 backup-server backup-borg[5128]: Deduplicated size: 4.21 MB
Jan 09 19:05:07 backup-server backup-borg[5128]: Backup succeeded
Jan 09 19:05:08 backup-server backup-borg[5130]: Pruning...
Jan 09 19:05:09 backup-server backup-borg[5132]: Keeping archive: etc-2026-01-09T19:05:02 (daily)
Jan 09 19:05:09 backup-server backup-borg[5132]: Prune completed


Эмуляция аварии на клиенте
sudo mv /etc /etc.broken

Определение последнего архива на backup_server
export BORG_PASSPHRASE="MyStrongBackupPass123!"
sudo -E borg list /var/backup/client-etc
etc-2026-01-09T19:05:02          Wed, 2026-01-09 19:05:02 [abc123def456...]
etc-2026-01-09T19:00:01          Wed, 2026-01-09 19:00:01 [xyz789uvw012...]

Восстановление данных на клиенте
sudo mkdir -p /restore
sudo BORG_PASSPHRASE="MyStrongBackupPass123!" borg extract \
  --strip-components=2 \
  vagrant@172.17.73.212:/var/backup/client-etc::etc-2026-01-09T19:05:02 \
  vagrant@172.17.64.72/etc/

Копирование восстановленных данных
sudo cp -a /restore/etc/* /etc/
sudo rm -rf /restore