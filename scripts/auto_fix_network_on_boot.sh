#!/bin/bash
# Автоматическое восстановление сети при загрузке
# Этот скрипт должен быть запущен ДО применения оптимизаций
# Но если устройство перезагрузится, он может помочь

# Проверить, есть ли проблемные сетевые параметры
if grep -q "# Оптимизация для аудио пайплайна" /etc/sysctl.conf 2>/dev/null; then
    # Удалить проблемные параметры
    sed -i '/# Оптимизация для аудио пайплайна/,/net.core.wmem_default = 262144/d' /etc/sysctl.conf
    sysctl -p > /dev/null 2>&1 || true
    
    # Перезапустить сеть
    systemctl restart NetworkManager 2>/dev/null || systemctl restart systemd-networkd 2>/dev/null || true
    
    # Поднять интерфейс
    ip link set eth0 up 2>/dev/null || true
    dhclient eth0 2>/dev/null || true
    
    logger -t auto-fix-network "Автоматически удалены проблемные сетевые параметры"
fi

