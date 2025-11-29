#!/bin/bash
# Скрипт оптимизации производительности для аудио пайплайна
# Применяет оптимизации CPU, I/O, памяти и сети

set -e

echo "=== Оптимизация производительности ==="

# 1. CPU Governor - performance режим
echo "1. Настройка CPU governor..."
if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [ -f "$cpu" ]; then
            echo "performance" | sudo tee "$cpu" > /dev/null 2>&1 || true
        fi
    done
    echo "   ✓ CPU governor установлен в performance"
else
    echo "   ⚠ CPU governor не поддерживается (возможно, фиксированная частота)"
fi

# 2. I/O Scheduler - deadline для SSD/eMMC
echo "2. Настройка I/O scheduler..."
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

# 3. Swappiness - минимум swap
echo "3. Настройка swappiness..."
if ! grep -q "vm.swappiness" /etc/sysctl.conf 2>/dev/null; then
    echo "vm.swappiness=1" | sudo tee -a /etc/sysctl.conf > /dev/null
fi
sudo sysctl -w vm.swappiness=1 > /dev/null 2>&1
echo "   ✓ Swappiness установлен в 1"

# 4. vm.dirty_ratio - оптимизация для аудио буферов
echo "4. Настройка vm.dirty_ratio..."
if ! grep -q "vm.dirty_ratio" /etc/sysctl.conf 2>/dev/null; then
    echo "vm.dirty_ratio=10" | sudo tee -a /etc/sysctl.conf > /dev/null
fi
if ! grep -q "vm.dirty_background_ratio" /etc/sysctl.conf 2>/dev/null; then
    echo "vm.dirty_background_ratio=5" | sudo tee -a /etc/sysctl.conf > /dev/null
fi
sudo sysctl -w vm.dirty_ratio=10 > /dev/null 2>&1
sudo sysctl -w vm.dirty_background_ratio=5 > /dev/null 2>&1
echo "   ✓ vm.dirty_ratio установлен в 10"

# 5. Увеличение лимитов файловых дескрипторов
echo "5. Настройка лимитов файловых дескрипторов..."
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

# 6. Сетевые параметры - ОТКЛЮЧЕНО (может вызвать проблемы с сетью)
# Сетевые параметры удалены из скрипта для безопасности
# Если нужна оптимизация сети, применяйте параметры вручную и тестируйте
echo "6. Сетевые параметры..."
echo "   ⚠ Сетевые параметры отключены для безопасности"

# 7. Параметры ядра для реального времени - ОТКЛЮЧЕНО (может вызвать проблемы с загрузкой)
echo "7. Параметры ядра для реального времени..."
echo "   ⚠ Параметры ядра отключены для безопасности"

# 8. CPU governor сервис - ОТКЛЮЧЕНО (может блокировать загрузку)
echo "8. CPU governor сервис..."
echo "   ⚠ Сервис set-cpu-governor отключен для безопасности"

echo ""
echo "=== Оптимизация завершена ==="
echo "Применены изменения:"
echo "  - CPU governor: performance (только текущая сессия, не сохраняется)"
echo "  - I/O scheduler: deadline"
echo "  - Swappiness: 1"
echo "  - vm.dirty_ratio: 10"
echo "  - Лимиты файловых дескрипторов: 65536"
echo ""
echo "Для применения всех изменений перезагрузите систему: sudo reboot"

