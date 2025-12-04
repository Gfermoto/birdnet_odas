#!/bin/bash
# Скрипт для передачи ReSpeaker через Log-MMSE и SoX в ALSA loopback
# С логированием и статистикой для анализа производительности

LOG_DIR="/var/log/birdnet-pipeline"
STATS_FILE="$LOG_DIR/pipeline_stats.json"
ERROR_LOG="$LOG_DIR/errors.log"

# Создать директорию для логов
mkdir -p "$LOG_DIR"

# Функция логирования ошибок
log_error() {
    local msg="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $msg" >> "$ERROR_LOG"
    logger -t respeaker-loopback -p err "$msg" 2>/dev/null || true
}

# Функция логирования информации
log_info() {
    local msg="$1"
    logger -t respeaker-loopback -p info "$msg" 2>/dev/null || true
}

# Функция обновления статистики (простая реализация без jq)
update_stats() {
    local event=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Создать файл статистики, если не существует
    if [ ! -f "$STATS_FILE" ]; then
        cat > "$STATS_FILE" <<EOF
{
  "start_time": "$timestamp",
  "restarts": 0,
  "errors": 0,
  "last_error": "",
  "last_restart": "",
  "uptime_seconds": 0,
  "current_start_time": 0
}
EOF
    else
        # Обновить существующий файл, добавив недостающее поле current_start_time если его нет
        if ! grep -q '"current_start_time"' "$STATS_FILE"; then
            # Добавить поле перед закрывающей скобкой
            sed -i 's/}$/  "current_start_time": 0\n}/' "$STATS_FILE" 2>/dev/null || true
        fi
    fi
    
    # Обновить статистику (простая реализация через sed)
    case "$event" in
        start)
            # Установить время начала текущей сессии
            local start_time=$(date +%s)
            sed -i "s/\"current_start_time\": [0-9]*/\"current_start_time\": $start_time/" "$STATS_FILE" 2>/dev/null || true
            sed -i "s/\"last_restart\": \"[^\"]*\"/\"last_restart\": \"$timestamp\"/" "$STATS_FILE" 2>/dev/null || true
            ;;
        restart)
            local restarts=$(grep -o '"restarts": [0-9]*' "$STATS_FILE" | grep -o '[0-9]*' || echo "0")
            restarts=$((restarts + 1))
            sed -i "s/\"restarts\": [0-9]*/\"restarts\": $restarts/" "$STATS_FILE" 2>/dev/null || true
            sed -i "s/\"last_restart\": \"[^\"]*\"/\"last_restart\": \"$timestamp\"/" "$STATS_FILE" 2>/dev/null || true
            # Обновить время начала новой сессии
            local start_time=$(date +%s)
            sed -i "s/\"current_start_time\": [0-9]*/\"current_start_time\": $start_time/" "$STATS_FILE" 2>/dev/null || true
            ;;
        error)
            local errors=$(grep -o '"errors": [0-9]*' "$STATS_FILE" | grep -o '[0-9]*' || echo "0")
            errors=$((errors + 1))
            sed -i "s/\"errors\": [0-9]*/\"errors\": $errors/" "$STATS_FILE" 2>/dev/null || true
            sed -i "s/\"last_error\": \"[^\"]*\"/\"last_error\": \"$timestamp\"/" "$STATS_FILE" 2>/dev/null || true
            ;;
        uptime)
            local uptime=$2
            sed -i "s/\"uptime_seconds\": [0-9]*/\"uptime_seconds\": $uptime/" "$STATS_FILE" 2>/dev/null || true
            ;;
    esac
}

# Функция периодического обновления uptime (запускается в фоне)
update_uptime_loop() {
    while true; do
        sleep 30
        if [ -f "$STATS_FILE" ]; then
            local current_start=$(grep -o '"current_start_time": [0-9]*' "$STATS_FILE" | grep -o '[0-9]*' || echo "0")
            if [ "$current_start" -gt 0 ]; then
                local now=$(date +%s)
                local uptime=$((now - current_start))
                if [ "$uptime" -gt 0 ]; then
                    sed -i "s/\"uptime_seconds\": [0-9]*/\"uptime_seconds\": $uptime/" "$STATS_FILE" 2>/dev/null || true
                fi
            fi
        fi
    done
}

# Счетчик ошибок с экспоненциальной задержкой
ERROR_COUNT=0
MAX_ERRORS=10

# Запустить фоновый процесс для периодического обновления uptime
update_uptime_loop &
UPTIME_PID=$!

# Очистка при выходе
trap "kill $UPTIME_PID 2>/dev/null || true; exit" INT TERM EXIT

# Инициализировать статистику при первом запуске
if [ ! -f "$STATS_FILE" ]; then
    update_stats start
fi

# Основной цикл
while true; do
    START_TIME=$(date +%s)
    
    # Обновить время начала сессии (не увеличиваем счетчик рестартов при нормальной работе)
    update_stats start
    
    log_info "Запуск аудио пайплайна"
    
    # Запустить пайплайн с логированием ошибок
    if arecord -D hw:ArrayUAC10,0 -f S16_LE -r 16000 -c 6 -t raw --buffer-size=8192 --period-size=2048 2>>"$ERROR_LOG" | \
       python3 /usr/local/bin/log_mmse_processor.py 2>>"$ERROR_LOG" | \
       sox -t raw -r 16000 -c 1 -e signed-integer -b 16 -L - \
           -t raw -r 48000 -c 1 -e signed-integer -b 16 -L - gain -2.0 2>>"$ERROR_LOG" | \
       aplay -D hw:2,1,0 -f S16_LE -r 48000 -c 1 -t raw --buffer-size=8192 --period-size=2048 2>>"$ERROR_LOG"; then
        
        # Успешный запуск - сбросить счетчик ошибок
        ERROR_COUNT=0
        END_TIME=$(date +%s)
        UPTIME=$((END_TIME - START_TIME))
        
        # Обновить uptime в статистике (фоновый процесс тоже обновляет, но обновим здесь для точности)
        update_stats uptime "$UPTIME"
        
        log_info "Пайплайн завершился нормально (uptime: ${UPTIME}s)"
        
        # Если пайплайн завершился нормально, это не ошибка - не увеличиваем счетчик рестартов
        # Счетчик рестартов увеличивается только при ошибках
    else
        EXIT_CODE=$?
        ERROR_COUNT=$((ERROR_COUNT + 1))
        update_stats error
        update_stats restart  # Увеличить счетчик рестартов только при ошибке
        
        log_error "Ошибка пайплайна (код: $EXIT_CODE, счетчик: $ERROR_COUNT/$MAX_ERRORS)"
        
        # Экспоненциальная задержка: 1s, 2s, 4s, 8s, 16s, max 30s
        DELAY=$((2 ** (ERROR_COUNT - 1)))
        if [ $DELAY -gt 30 ]; then
            DELAY=30
        fi
        
        if [ $ERROR_COUNT -ge $MAX_ERRORS ]; then
            log_error "Критическая ошибка: достигнут лимит ошибок ($MAX_ERRORS). Остановка."
            exit 1
        fi
        
        log_info "Повтор через ${DELAY} секунд..."
        sleep $DELAY
    fi
done
