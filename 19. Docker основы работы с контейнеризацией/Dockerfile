# Используем легковесный образ
FROM nginx:alpine

# Копируем нашу HTML-страницу поверх стандартной
COPY index.html /usr/share/nginx/html/index.html

# Порт уже EXPOSE'd в базовом образе, но можно явно указать
EXPOSE 80

# CMD наследуется от базового образа — запуск nginx в foreground
