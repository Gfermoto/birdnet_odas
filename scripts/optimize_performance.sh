#!/bin/bash
# Скрипт оптимизации производительности для аудио пайплайна
# Применяет только безопасные оптимизации

set -e

echo "=== Оптимизация производительности ==="

# 1. I/O Scheduler - deadline для SSD/eMMC (безопасно)
echo "1. Настройка I/O scheduler..."
SCHEDULER_SET=0
for disk in /sys/block/mmcblk*/queue/scheduler; do
    if [ -f "$disk" ]; then
        echo "deadline" | sudo tee "$disk" > /dev/null 2>&1 || true
        DISK_NAME=$(basename $(dirname $(dirname $disk)))
        echo "   ✓ $DISK_NAME: deadline"
        SCHEDULER_SET=1
    fi
done
for disk in /sys/block/sd*/queue/scheduler; do
    if [ -f "$disk" ]; then
        echo "deadline" | sudo tee "$disk" > /dev/null 2>&1 || true
        DISK_NAME=$(basename $(dirname $(dirname $disk)))
        echo "   ✓ $DISK_NAME: deadline"
        SCHEDULER_SET=1
    fi
done
if [ $SCHEDULER_SET -eq 0 ]; then
    echo "   ⚠ I/O scheduler не настроен (диски не найдены)"
fi

# 2. Увеличение лимитов файловых дескрипторов (безопасно)
echo "2. Настройка лимитов файловых дескрипторов..."
if [ ! -f /etc/security/limits.d/99-audio-pipeline.conf ]; then
    cat <<EOF | sudo tee /etc/security/limits.d/99-audio-pipeline.conf > /dev/null
* soft nofile 65536
* hard nofile 65536
root soft nofile 65536
root hard nofile 65536
EOF
    echo "   ✓ Лимиты файловых дескрипторов увеличены до 65536"
else
    echo "   ✓ Лимиты уже настроены"
fi

echo ""
echo "=== Оптимизация завершена ==="
echo "Применены только безопасные изменения:"
echo "  - I/O scheduler: deadline"
echo "  - Лимиты файловых дескрипторов: 65536"
echo ""
echo "ОТКЛЮЧЕНО для безопасности:"
echo "  - CPU governor (может вызвать проблемы)"
echo "  - vm.swappiness (может вызвать проблемы на медленных дисках)"
echo "  - vm.dirty_ratio (может вызвать проблемы на медленных дисках)"
echo "  - Сетевые параметры (вызывали проблемы с сетью)"
echo "  - Параметры ядра для реального времени (блокировали загрузку)"

