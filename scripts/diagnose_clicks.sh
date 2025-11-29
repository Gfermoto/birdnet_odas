#!/bin/bash
# Скрипт для диагностики щелчков в аудио записи

echo "=========================================="
echo "Диагностика щелчков в аудио записи"
echo "=========================================="
echo ""

# 1. Проверка системных таймеров
echo "=== 1. Системные таймеры (возможные периодические задачи) ==="
systemctl list-timers --all --no-pager | head -20
echo ""

# 2. Проверка cron задач
echo "=== 2. Cron задачи ==="
echo "Пользовательские cron задачи:"
crontab -l 2>/dev/null || echo "Нет пользовательских cron задач"
echo ""
echo "Системные cron задачи:"
ls -la /etc/cron.d/ 2>/dev/null | head -10
echo ""

# 3. Проверка USB подключения
echo "=== 3. USB подключение микрофона ==="
echo "USB устройства Seeed:"
lsusb | grep -i seeed
echo ""
echo "USB питание (control):"
for dev in /sys/bus/usb/devices/*/power/control; do
    if [ -f "$dev" ]; then
        echo "$(basename $(dirname $(dirname $dev))): $(cat $dev)"
    fi
done | grep -v "on" || echo "Все устройства: on (autosuspend отключен)"
echo ""
echo "USB autosuspend:"
for dev in /sys/bus/usb/devices/*/power/autosuspend; do
    if [ -f "$dev" ]; then
        val=$(cat $dev)
        if [ "$val" != "-1" ]; then
            echo "$(basename $(dirname $(dirname $dev))): $val сек"
        fi
    fi
done | head -5 || echo "Все устройства: -1 (autosuspend отключен)"
echo ""

# 4. Проверка USB ошибок
echo "=== 4. USB ошибки (последние 20 строк) ==="
dmesg | grep -i "usb\|seeed\|arrayuac" | tail -20
echo ""

# 5. Проверка ALSA буферов
echo "=== 5. ALSA буферы ==="
for card in /proc/asound/card*/pcm*/sub*/hw_params; do
    if [ -f "$card" ]; then
        echo "Устройство: $card"
        cat "$card" 2>/dev/null | head -5
        echo ""
    fi
done
echo ""

# 6. Проверка процессов аудио пайплайна
echo "=== 6. Процессы аудио пайплайна ==="
ps aux | grep -E "arecord|log_mmse|sox|aplay" | grep -v grep
echo ""

# 7. Проверка CPU нагрузки
echo "=== 7. CPU нагрузка ==="
top -bn1 | head -5
echo ""

# 8. Проверка loopback устройства
echo "=== 8. ALSA Loopback устройство ==="
arecord -l | grep -i loopback || echo "Loopback не найден"
aplay -l | grep -i loopback || echo "Loopback не найден"
echo ""

# 9. Проверка настроек udev для USB
echo "=== 9. Настройки udev для USB ==="
if [ -f /etc/udev/rules.d/99-usb-autosuspend-off.rules ]; then
    echo "Файл существует:"
    cat /etc/udev/rules.d/99-usb-autosuspend-off.rules
else
    echo "Файл не найден (autosuspend может быть включен)"
fi
echo ""

# 10. Проверка настроек ALSA
echo "=== 10. Настройки ALSA ==="
if [ -f /etc/asound.conf ]; then
    echo "Файл /etc/asound.conf существует:"
    cat /etc/asound.conf
else
    echo "Файл /etc/asound.conf не найден (используются настройки по умолчанию)"
fi
echo ""

# 11. Проверка сервиса respeaker-loopback
echo "=== 11. Сервис respeaker-loopback ==="
if systemctl is-active --quiet respeaker-loopback.service; then
    echo "Сервис активен"
    systemctl status respeaker-loopback.service --no-pager -l | head -10
else
    echo "Сервис не активен"
fi
echo ""

# 12. Проверка логов сервиса (последние ошибки)
echo "=== 12. Последние ошибки в логах сервиса ==="
journalctl -u respeaker-loopback.service --no-pager -n 20 | grep -i "error\|fail\|click\|pop" || echo "Ошибок не найдено"
echo ""

echo "=========================================="
echo "Диагностика завершена"
echo "=========================================="
echo ""
echo "Рекомендации:"
echo "1. Проверьте периодические задачи (раздел 1 и 2)"
echo "2. Убедитесь, что USB autosuspend отключен (раздел 3)"
echo "3. Проверьте USB ошибки (раздел 4)"
echo "4. Проверьте размеры ALSA буферов (раздел 5)"
echo "5. Проверьте CPU нагрузку (раздел 7)"

