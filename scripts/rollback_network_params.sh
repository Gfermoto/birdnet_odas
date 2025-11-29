#!/bin/bash
# Скрипт для отката сетевых параметров sysctl
# Использовать при физическом доступе к устройству

set -e

echo "=== Откат сетевых параметров ==="

# Создать резервную копию
if [ ! -f /etc/sysctl.conf.backup ]; then
    sudo cp /etc/sysctl.conf /etc/sysctl.conf.backup
    echo "✓ Создана резервная копия /etc/sysctl.conf"
fi

# Удалить сетевые параметры из sysctl.conf
echo "Удаление сетевых параметров из /etc/sysctl.conf..."
sudo sed -i '/# Оптимизация для аудио пайплайна/,/net.core.wmem_default = 262144/d' /etc/sysctl.conf

# Применить изменения
echo "Применение изменений..."
sudo sysctl -p > /dev/null 2>&1 || true

# Перезапустить сетевые сервисы
echo "Перезапуск сетевых сервисов..."
if systemctl is-active --quiet NetworkManager; then
    sudo systemctl restart NetworkManager
    echo "✓ NetworkManager перезапущен"
elif systemctl is-active --quiet systemd-networkd; then
    sudo systemctl restart systemd-networkd
    echo "✓ systemd-networkd перезапущен"
fi

# Проверить сетевые интерфейсы
echo ""
echo "Проверка сетевых интерфейсов:"
ip addr show | grep -E "^[0-9]+:|inet " | head -10

echo ""
echo "=== Откат завершен ==="
echo "Проверьте подключение: ping 192.168.1.136"

