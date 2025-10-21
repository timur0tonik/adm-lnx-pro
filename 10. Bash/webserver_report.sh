#!/bin/bash

# Ежечасный отчёт о работе веб-сервера (nginx)

set -euo pipefail

log_file="/var/log/nginx/access.log"
error_log="/var/log/nginx/error.log"
email="my_service99999@mail.ru"
lock_file="/var/run/webserver_report.lock"
last_run_file="/var/log/webserver_report.lastrun"


check_lock() {
    if [ -f "$lock_file" ]; then
        echo "[$(date)] Скрипт уже запущен. Выход." >&2
        exit 1
    fi
    echo $$ > "$lock_file"
}

cleanup() {
    rm -f "$lock_file"
}
trap cleanup EXIT

# Возвращает: start_ts end_ts
get_time_range_ts() {
    local now_ts last_ts
    now_ts=$(date +%s)
    if [ -f "$last_run_file" ]; then
        last_ts=$(cat "$last_run_file")
    else
        last_ts=$((now_ts - 3600))  # 1 час назад
    fi
    echo "$last_ts" > "$last_run_file"
    echo "$last_ts $now_ts"
}

# Преобразует timestamp в человекочитаемый формат (для отчёта)
ts_to_human() {
    date -d "@$1" '+%d/%b/%Y:%H:%M:%S'
}

# Извлекает логи за период [start_ts, end_ts]
extract_logs() {
    local start_ts="$1"
    local end_ts="$2"

    awk -v start="$start_ts" -v end="$end_ts" -v log_file="$log_file" '
    {
        if (match($0, /\[([0-9]+)\/([A-Za-z]+)\/([0-9]+):([0-9:]+)/, arr)) {
            cmd = "date -d \"" arr[1] " " arr[2] " " arr[3] " " arr[4] "\" +%s 2>/dev/null"
            if ((cmd | getline ts) > 0) {
                close(cmd)
                if (ts >= start && ts <= end) {
                    print $0
                }
            } else {
                close(cmd)
            }
        }
    }' "$log_file"
}

generate_report() {
    local start_human="$1"
    local end_human="$2"
    local start_ts="$3"
    local end_ts="$4"

    echo "Отчёт о работе веб-сервера"
    echo "Временной диапазон: $start_human — $end_human"
    echo "=============================================="

    local temp_log
    temp_log=$(mktemp)
    extract_logs "$start_ts" "$end_ts" > "$temp_log"

    if [ ! -s "$temp_log" ]; then
        echo "Нет записей в логах за указанный период."
    else
        echo
        echo "=== ТОП-5 IP-адресов по количеству запросов ==="
        awk '{print $1}' "$temp_log" | sort | uniq -c | sort -nr | head -5

        echo
        echo "=== ТОП-5 запрашиваемых URL ==="
        awk -F'"' '/GET|POST/ {print $2}' "$temp_log" 2>/dev/null | cut -d' ' -f2 | sort | uniq -c | sort -nr | head -5

        echo
        echo "=== HTTP-коды ответов ==="
        awk '{print $9}' "$temp_log" | grep -E '^[0-9]{3}$' | sort | uniq -c | sort -nr

        echo
        echo "=== Ошибки веб-сервера (из error.log за последний час) ==="
        # Используем find + sed — как требует задание
        if [ -f "$error_log" ]; then
            find "$error_log" -type f -newermt "$(date -d '1 hour ago' '+%Y-%m-%d %H:%M:%S')" -exec cat {} \; | \
            sed -n "/$(date -d '1 hour ago' '+%Y\/%m\/%d %H')/,\$p"
        else
            echo "Файл ошибок не найден: $error_log"
        fi
    fi

    rm -f "$temp_log"
}

# === Основной код ===
check_lock

# Получаем временные метки в секундах
read -r start_ts end_ts < <(get_time_range_ts)

# Преобразуем для отображения в отчёте
start_human=$(ts_to_human "$start_ts")
end_human=$(ts_to_human "$end_ts")

# Генерируем отчёт
report=$(generate_report "$start_human" "$end_human" "$start_ts" "$end_ts")

# Отправляем email
echo "$report" | mail -s "Веб-отчёт за $(date '+%Y-%m-%d %H:%M')" "$email"