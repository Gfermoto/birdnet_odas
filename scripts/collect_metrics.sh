#!/bin/bash
# Сбор метрик для анализа производительности системы
# Записывает метрики в JSON формате для последующего анализа

METRICS_DIR="/var/log/birdnet-pipeline/metrics"
METRICS_FILE="$METRICS_DIR/$(date '+%Y%m%d').json"

mkdir -p "$METRICS_DIR"

# Функция нормализации числовых значений (убедиться что это число)
normalize_number() {
    local val="$1"
    # Удалить все нечисловые символы кроме точки и минуса
    val=$(echo "$val" | sed 's/[^0-9.-]//g')
    # Если пусто или не число, вернуть 0
    if [ -z "$val" ] || ! echo "$val" | grep -qE '^-?[0-9]+\.?[0-9]*$'; then
        echo "0"
    else
        echo "$val"
    fi
}

# Собрать метрики
CPU_USAGE=$(normalize_number "$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' 2>/dev/null || echo "0")")
MEM_USAGE=$(normalize_number "$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}' 2>/dev/null || echo "0")")
LOAD_AVG=$(normalize_number "$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//' 2>/dev/null || echo "0")")

# Процессы пайплайна
ARECORD_CPU=$(normalize_number "$(ps aux | grep '[a]record.*ArrayUAC10' | awk '{print $3}' | head -1 2>/dev/null || echo "0")")
LOG_MMSE_CPU=$(normalize_number "$(ps aux | grep '[l]og_mmse_processor' | awk '{print $3}' | head -1 2>/dev/null || echo "0")")
SOX_CPU=$(normalize_number "$(ps aux | grep '[s]ox.*48000' | awk '{print $3}' | head -1 2>/dev/null || echo "0")")
APLAY_CPU=$(normalize_number "$(ps aux | grep '[a]play.*2,1,0' | awk '{print $3}' | head -1 2>/dev/null || echo "0")")

# Память процессов
ARECORD_MEM=$(normalize_number "$(ps aux | grep '[a]record.*ArrayUAC10' | awk '{print $4}' | head -1 2>/dev/null || echo "0")")
LOG_MMSE_MEM=$(normalize_number "$(ps aux | grep '[l]og_mmse_processor' | awk '{print $4}' | head -1 2>/dev/null || echo "0")")

# Статистика из pipeline_stats.json
STATS_FILE="/var/log/birdnet-pipeline/pipeline_stats.json"
if [ -f "$STATS_FILE" ]; then
    RESTARTS=$(grep -o '"restarts": [0-9]*' "$STATS_FILE" | grep -o '[0-9]*' || echo "0")
    ERRORS=$(grep -o '"errors": [0-9]*' "$STATS_FILE" | grep -o '[0-9]*' || echo "0")
    UPTIME_STORED=$(grep -o '"uptime_seconds": [0-9]*' "$STATS_FILE" | grep -o '[0-9]*' || echo "0")
    CURRENT_START=$(grep -o '"current_start_time": [0-9]*' "$STATS_FILE" | grep -o '[0-9]*' || echo "0")
    
    # Вычислить актуальный uptime если есть current_start_time
    if [ "$CURRENT_START" -gt 0 ]; then
        NOW=$(date +%s)
        UPTIME_CALCULATED=$((NOW - CURRENT_START))
        # Использовать большее значение (uptime может быть обновлен вручную или фоновым процессом)
        if [ "$UPTIME_CALCULATED" -gt "$UPTIME_STORED" ]; then
            UPTIME=$UPTIME_CALCULATED
        else
            UPTIME=$UPTIME_STORED
        fi
    else
        UPTIME=$UPTIME_STORED
    fi
else
    RESTARTS=0
    ERRORS=0
    UPTIME=0
fi

# Записать метрики в JSON (NDJSON формат - одна строка = один JSON объект)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
JSON_ENTRY=$(cat <<EOF
{"timestamp":"$TIMESTAMP","cpu":{"total":$CPU_USAGE,"arecord":$ARECORD_CPU,"log_mmse":$LOG_MMSE_CPU,"sox":$SOX_CPU,"aplay":$APLAY_CPU},"memory":{"total":$MEM_USAGE,"arecord":$ARECORD_MEM,"log_mmse":$LOG_MMSE_MEM},"load":$LOAD_AVG,"pipeline":{"restarts":$RESTARTS,"errors":$ERRORS,"uptime_seconds":$UPTIME}}
EOF
)
echo "$JSON_ENTRY" >> "$METRICS_FILE"

# Ограничить размер файла (последние 1000 записей)
if [ -f "$METRICS_FILE" ]; then
    # Подсчитать количество строк (каждая строка = один JSON объект в NDJSON)
    LINE_COUNT=$(wc -l < "$METRICS_FILE" 2>/dev/null || echo "0")
    if [ "$LINE_COUNT" -gt 1000 ]; then
        # Оставить последние 1000 строк
        tail -n 1000 "$METRICS_FILE" > "${METRICS_FILE}.tmp" && mv "${METRICS_FILE}.tmp" "$METRICS_FILE"
    fi
fi

logger -t collect-metrics "Метрики собраны: $METRICS_FILE" 2>/dev/null || true

