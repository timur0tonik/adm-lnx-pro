# Динамический веб-стенд (nginx + php-fpm + python + nodejs)

## Цель
Получить практические навыки настройки инфраструктуры с помощью манифестов и конфигураций (Infrastructure as Code) с использованием Vagrant, Ansible и Docker.  
В результате работы развёрнут стенд, объединяющий три различных веб-приложения (WordPress, Django, Node.js) под управлением Nginx как единого входного шлюза.

## Реализация
- **Vagrant + VirtualBox** (Windows 11, Vagrant 2.4.9, VirtualBox 7.2.6).
- Использован собственный образ **`ubuntu24-gold`** (Ubuntu 24.04 LTS).
- Управление конфигурацией: **Ansible** (playbook `provisioning/playbook.yml`).
- Оркестрация приложений: **Docker Compose** (файл `project/docker-compose.yml`).
- Стек приложений:
  - **WordPress** (PHP-FPM) + MySQL – порт 8083
  - **Django** (Python) – порт 8081
  - **Node.js** – порт 8082
  - **Nginx** – reverse-proxy для всех приложений

## Особенности проектирования и реализации
- Все сервисы описаны в `docker-compose.yml` и запускаются в изолированной сети `app-network`.
- Для WordPress используется официальный образ `wordpress:5.1.1-fpm-alpine`, для MySQL – `mysql:8.0`, для Node.js – `node:16.13.2-alpine3.15`, для Nginx – `nginx:1.15.12-alpine`.
- Приложение Django собирается из локального контекста `./python` с использованием `Dockerfile`.
- Ansible-плейбук выполняет:
  - установку Docker и Docker Compose plugin,
  - добавление пользователя `vagrant` в группу `docker`,
  - копирование файлов проекта в ВМ,
  - запуск контейнеров через `docker compose up -d`.
- Проброс портов: 8081, 8082, 8083 на локальную машину.

## Результаты тестирования
После выполнения `vagrant up` все контейнеры успешно запустились. Проверка:

- **http://localhost:8081** – стандартная страница Django
- **http://localhost:8082** – ответ "Hello from node js server"
- **http://localhost:8083** – установщик WordPress

Скриншоты доступны в папке `screens/` (приложены).


## Структура проекта
```
.
├── Vagrantfile
├── provisioning
│   └── playbook.yml
├── project
│   ├── docker-compose.yml
│   ├── .env
│   ├── nginx-conf
│   │   └── nginx.conf
│   ├── node
│   │   └── test.js
│   └── python
│       ├── Dockerfile
│       ├── manage.py
│       ├── requirements.txt
│       └── mysite
│           ├── __init__.py
│           ├── asgi.py
│           ├── settings.py
│           ├── urls.py
│           └── wsgi.py
└── screens
    ├── 8081.png
    ├── 8082.png
    └── 8083.png
```