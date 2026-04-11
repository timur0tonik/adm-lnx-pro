# DevOps проект: отказоустойчивый WordPress с мониторингом и сбором логов

Данный проект разворачивает локальный стенд из 5 виртуальных машин с помощью **Vagrant** и **Ansible**. Стенд включает:

- Балансировщик Nginx + WordPress (два бэкенда)
- MySQL-репликацию (master‑slave)
- Централизованный сбор логов (rsyslog)
- Мониторинг Zabbix с уведомлениями в Telegram
- Автоматическое резервное копирование БД

## Быстрый старт

```bash
git clone <url-репозитория>
cd devops_project
vagrant up
```

После выполнения все машины будут доступны:

| ВМ       | IP              | Назначение                        |
|----------|-----------------|-----------------------------------|
| front    | 192.168.50.10   | Nginx‑балансировщик, HTTPS        |
| back1    | 192.168.50.11   | WordPress + MySQL (master)        |
| back2    | 192.168.50.12   | WordPress + MySQL (slave)         |
| monitor  | 192.168.50.20   | Zabbix Server + Web интерфейс     |
| logger   | 192.168.50.21   | Центральный сервер логов + бэкапы |

- WordPress доступен по адресу: `https://localhost:8443`  
  Логин: `admint`, пароль: `zuiUWoO@3O)8cW4`
- Zabbix Web: `https://192.168.50.20/zabbix`  
  Логин: `Admin`, пароль: `zabbix`

## Архитектура и взаимодействие

- **front** – принимает HTTPS‑трафик (порт 443) и проксирует HTTP‑запросы на `back1:8000` и `back2:8000` (round‑robin).
- **back1 / back2** – Nginx + PHP-FPM + WordPress. MySQL master на `back1`, slave на `back2`. Репликация базы `wordpress` настроена автоматически.
- **monitor** – Zabbix Server, собирает метрики через агентов (порт 10050). Настроены уведомления в Telegram.
- **logger** – rsyslog принимает логи от всех ВМ по TCP/UDP (порт 514), складывает в `/var/log/remote/<hostname>/`. Также на `logger` выполняются ежедневные бэкапы MySQL с мастера.

## Особенности и автоматизация

- **Автоматическое восстановление `back1`**  
  Если мастер‑БД удалить и пересоздать (`vagrant destroy back1 -f && vagrant up back1`), Ansible:
  1. Сравнит количество постов на `back1` и `back2`.
  2. При необходимости сделает дамп с `back2`, скопирует его на новый `back1` и импортирует.
  3. Перенастроит репликацию (теперь `back2` станет слейвом нового мастера).
  
- **Отказоустойчивость**  
  При падении `back1` сайт продолжает работать в режиме «только чтение» (запись в БД недоступна). После пересоздания данные синхронизируются автоматически.

- **Мониторинг**  
  Zabbix опрашивает все ВМ (агенты уже установлены и настроены)..

- **Логи**  
  Все системные логи централизованно собираются на `logger`. Просмотр:
  ```bash
  vagrant ssh logger -c "sudo tail -f /var/log/remote/front/syslog"
  ```

## Управление стендом

| Команда | Действие |
|---------|----------|
| `vagrant up` | Создать и запустить все ВМ |
| `vagrant provision <имя>` | Перезапустить Ansible‑провижининг |
| `vagrant destroy -f` | Уничтожить все ВМ |
| `vagrant ssh <имя>` | Подключиться по SSH |

## Структура проекта

```
devops_project/
├── Vagrantfile
├── certs/                     # SSL‑сертификаты для front и monitor
├── provisioning/
│   ├── playbook.yml
│   ├── inventory.ini
│   ├── ansible.cfg
│   ├── host_vars/             # (back1.yml, back2.yml)
│   └── roles/
│       ├── common/            # базовые пакеты, Zabbix agent, rsyslog client
│       ├── mysql/             # установка MySQL, репликация
│       ├── web/               # Nginx, PHP, WordPress, WP-CLI
│       ├── monitor/           # Zabbix Server, Telegram alerts
│       └── logger/            # rsyslog server, бэкапы MySQL
```

## Требования

- VirtualBox (≥ 6.0)
- Vagrant (≥ 2.2)
- Windows

