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
  "uptime_seconds": 0
}
EOF
    fi
    
    # Обновить статистику (простая реализация через sed)
    case "$event" in
        restart)
            local restarts=$(grep -o '"restarts": [0-9]*' "$STATS_FILE" | grep -o '[0-9]*' || echo "0")
            restarts=$((restarts + 1))
            sed -i "s/\"restarts\": [0-9]*/\"restarts\": $restarts/" "$STATS_FILE" 2>/dev/null || true
            sed -i "s/\"last_restart\": \"[^\"]*\"/\"last_restart\": \"$timestamp\"/" "$STATS_FILE" 2>/dev/null || true
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

# Счетчик ошибок с экспоненциальной задержкой
ERROR_COUNT=0
MAX_ERRORS=10

# Основной цикл
while true; do
    START_TIME=$(date +%s)
    
    # Записать время запуска
    update_stats restart
    
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
        
        # Обновить uptime в статистике
        update_stats uptime "$UPTIME"
        
        log_info "Пайплайн завершился нормально (uptime: ${UPTIME}s)"
    else
        EXIT_CODE=$?
        ERROR_COUNT=$((ERROR_COUNT + 1))
        update_stats error
        
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
