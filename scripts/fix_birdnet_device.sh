#!/bin/bash
# Скрипт для автоматической настройки правильного устройства в BirdNET-Go

sleep 15  # Ждем полного запуска BirdNET-Go

CONFIG_FILE="/var/lib/docker/volumes/$(docker ps --filter name=birdnet-go --format {{.Names}} | head -1)_config/_data/config.yaml" 2>/dev/null

# Альтернативный путь
if [ ! -f "$CONFIG_FILE" ]; then
    CONFIG_FILE=$(docker inspect birdnet-go 2>/dev/null | grep -i "config.yaml" | head -1 | cut -d"\"" -f4)
fi

# Если конфиг найден, проверяем и исправляем
if [ -f "$CONFIG_FILE" ]; then
    # Проверяем, какое устройство указано
    CURRENT_DEVICE=$(grep -i "audio.*device\|input.*device" "$CONFIG_FILE" 2>/dev/null | grep -o ":2,[01]")
    
    if [ "$CURRENT_DEVICE" = ":2,1" ] || [ -z "$CURRENT_DEVICE" ]; then
        echo "⚠️  Обнаружено неправильное или отсутствующее устройство"
        echo "   Нужно вручную выбрать устройство :2,0 (ТРЕТЬЕ в списке) в Web GUI"
    else
        echo "✅ Устройство настроено правильно: $CURRENT_DEVICE"
    fi
else
    echo "⚠️  Конфиг не найден, проверьте вручную в Web GUI"
fi

echo ""
echo "Инструкция:"
echo "  http://$(hostname -I | awk '{print $1}'):8080 -> Settings -> Audio Settings"
echo "  Выберите ТРЕТЬЕ устройство в списке"
echo "  Это Loopback, Loopback PCM с индексом :2,0"
