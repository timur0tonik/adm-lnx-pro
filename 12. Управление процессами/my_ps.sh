#!/bin/bash

# Реализация 'ps ax' через /proc
printf "%-8s %-6s %-8s %s\n" "PID" "TTY" "TIME" "CMD"

for pid in /proc/[0-9]*; do
    pid_num=$(basename "$pid")
    
    [[ -f "$pid/stat" ]] || continue

    read -r _ comm _ _ _ _ tty_nr _ _ _ _ _ _ utime stime _ < "$pid/stat"

    # Преобразуем utime/stime из clock ticks в секунды
    CLK_TCK=$(getconf CLK_TCK 2>/dev/null || echo 100)
    total_ticks=$((utime + stime))
    cpu_time_sec=$((total_ticks / CLK_TCK))

    # Определяем TTY
    if [[ $tty_nr -eq 0 ]]; then
        tty="?"
    else
        tty="pts/$(($tty_nr - 64))" 
    fi

    # Читаем команду из cmdline
    if [[ -f "$pid/cmdline" ]]; then
        IFS=$'\0' read -r -d '' -a cmd < "$pid/cmdline" 2>/dev/null || cmd=("${comm//[\(\)]/}")
        cmd_str="${cmd[*]}"
        [[ -z "$cmd_str" ]] && cmd_str="[${comm//[\(\)]/}]"
    else
        cmd_str="[${comm//[\(\)]/}]"
    fi

    printf "%-8s %-6s %-8s %s\n" "$pid_num" "$tty" "$cpu_time_sec" "$cmd_str"
done