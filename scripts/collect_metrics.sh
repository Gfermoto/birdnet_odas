#!/bin/bash
# Сбор метрик для анализа производительности системы
# Записывает метрики в JSON формате для последующего анализа

METRICS_DIR="/var/log/birdnet-pipeline/metrics"
METRICS_FILE="$METRICS_DIR/$(date '+%Y%m%d').json"

mkdir -p "$METRICS_DIR"

# Собрать метрики
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' || echo "0")
MEM_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}' || echo "0")
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//' || echo "0")

# Процессы пайплайна
ARECORD_CPU=$(ps aux | grep '[a]record.*ArrayUAC10' | awk '{print $3}' | head -1 || echo "0")
LOG_MMSE_CPU=$(ps aux | grep '[l]og_mmse_processor' | awk '{print $3}' | head -1 || echo "0")
SOX_CPU=$(ps aux | grep '[s]ox.*48000' | awk '{print $3}' | head -1 || echo "0")
APLAY_CPU=$(ps aux | grep '[a]play.*2,1,0' | awk '{print $3}' | head -1 || echo "0")

# Память процессов
ARECORD_MEM=$(ps aux | grep '[a]record.*ArrayUAC10' | awk '{print $4}' | head -1 || echo "0")
LOG_MMSE_MEM=$(ps aux | grep '[l]og_mmse_processor' | awk '{print $4}' | head -1 || echo "0")

# Статистика из pipeline_stats.json
STATS_FILE="/var/log/birdnet-pipeline/pipeline_stats.json"
if [ -f "$STATS_FILE" ]; then
    RESTARTS=$(grep -o '"restarts": [0-9]*' "$STATS_FILE" | grep -o '[0-9]*' || echo "0")
    ERRORS=$(grep -o '"errors": [0-9]*' "$STATS_FILE" | grep -o '[0-9]*' || echo "0")
    UPTIME=$(grep -o '"uptime_seconds": [0-9]*' "$STATS_FILE" | grep -o '[0-9]*' || echo "0")
else
    RESTARTS=0
    ERRORS=0
    UPTIME=0
fi

# Записать метрики в JSON
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
cat >> "$METRICS_FILE" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "cpu": {
    "total": $CPU_USAGE,
    "arecord": $ARECORD_CPU,
    "log_mmse": $LOG_MMSE_CPU,
    "sox": $SOX_CPU,
    "aplay": $APLAY_CPU
  },
  "memory": {
    "total": $MEM_USAGE,
    "arecord": $ARECORD_MEM,
    "log_mmse": $LOG_MMSE_MEM
  },
  "load": $LOAD_AVG,
  "pipeline": {
    "restarts": $RESTARTS,
    "errors": $ERRORS,
    "uptime_seconds": $UPTIME
  }
}
EOF

# Ограничить размер файла (последние 1000 записей)
if [ -f "$METRICS_FILE" ]; then
    # Подсчитать количество записей (каждая запись начинается с {)
    RECORD_COUNT=$(grep -c '^{' "$METRICS_FILE" 2>/dev/null || echo "0")
    if [ "$RECORD_COUNT" -gt 1000 ]; then
        # Оставить последние 1000 записей
        tail -n 1000 "$METRICS_FILE" > "${METRICS_FILE}.tmp" && mv "${METRICS_FILE}.tmp" "$METRICS_FILE"
    fi
fi

logger -t collect-metrics "Метрики собраны: $METRICS_FILE" 2>/dev/null || true

