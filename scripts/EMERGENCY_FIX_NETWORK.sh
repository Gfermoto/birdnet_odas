#!/bin/bash
# ЭКСТРЕННОЕ ВОССТАНОВЛЕНИЕ СЕТИ
# Использовать при физическом доступе к устройству
# Этот скрипт удалит проблемные сетевые параметры из sysctl.conf

set -e

echo "=========================================="
echo "ЭКСТРЕННОЕ ВОССТАНОВЛЕНИЕ СЕТИ"
echo "=========================================="
echo ""

# Создать резервную копию
if [ ! -f /etc/sysctl.conf.backup.$(date +%Y%m%d) ]; then
    sudo cp /etc/sysctl.conf /etc/sysctl.conf.backup.$(date +%Y%m%d)
    echo "✓ Создана резервная копия"
fi

# Удалить проблемные сетевые параметры
echo "Удаление проблемных сетевых параметров..."
sudo sed -i '/# Оптимизация для аудио пайплайна/,/net.core.wmem_default = 262144/d' /etc/sysctl.conf

# Удалить пустые строки в конце файла
sudo sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' /etc/sysctl.conf

echo "✓ Проблемные параметры удалены"

# Применить изменения
echo "Применение изменений sysctl..."
sudo sysctl -p > /dev/null 2>&1 || true

# Перезапустить сетевые сервисы
echo "Перезапуск сетевых сервисов..."
if systemctl is-active --quiet NetworkManager 2>/dev/null; then
    sudo systemctl restart NetworkManager
    echo "✓ NetworkManager перезапущен"
elif systemctl is-active --quiet systemd-networkd 2>/dev/null; then
    sudo systemctl restart systemd-networkd
    echo "✓ systemd-networkd перезапущен"
else
    echo "⚠ Сетевой сервис не найден, попробуйте вручную:"
    echo "  sudo systemctl restart NetworkManager"
    echo "  или"
    echo "  sudo systemctl restart systemd-networkd"
fi

# Проверить сетевые интерфейсы
echo ""
echo "Проверка сетевых интерфейсов:"
ip addr show | grep -E "^[0-9]+:|inet " | head -10 || true

echo ""
echo "=========================================="
echo "Восстановление завершено"
echo "=========================================="
echo ""
echo "Проверьте подключение:"
echo "  ping 192.168.1.136"
echo "  ssh root@192.168.1.136"
echo ""
echo "Если сеть не восстановилась:"
echo "  1. Проверьте кабель Ethernet"
echo "  2. Проверьте настройки роутера"
echo "  3. Попробуйте: sudo ip link set eth0 up && sudo dhclient eth0"

