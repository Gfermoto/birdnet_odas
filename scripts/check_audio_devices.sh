#!/bin/bash
# Скрипт для проверки занятых аудио устройств

echo "═══════════════════════════════════════════════════════"
echo "🔍 ПРОВЕРКА АУДИО УСТРОЙСТВ"
echo "═══════════════════════════════════════════════════════"
echo ""

echo "1. Занятые ALSA устройства:"
lsof /dev/snd/* 2>/dev/null | grep -E "COMMAND|arecord|aplay|birdnet" || echo "   (нет процессов)"

echo ""
echo "2. BirdNET-Go устройство:"
docker logs birdnet-go 2>&1 | grep -E "Listening on|selected" | tail -1

echo ""
echo "3. Проверка device 0 (capture для BirdNET-Go):"
if timeout 1 arecord -D hw:2,0,0 -f S16_LE -r 48000 -c 1 /dev/null 2>&1 | grep -q "busy"; then
    echo "   ✅ Device 0 занят (правильно - используется BirdNET-Go)"
else
    echo "   ⚠️  Device 0 свободен (BirdNET-Go не использует его)"
fi

echo ""
echo "4. Процесс respeaker-loopback:"
if ps aux | grep -E "aplay.*2,1" | grep -v grep >/dev/null; then
    echo "   ✅ Использует device 1 для playback (правильно)"
    echo "   BirdNET-Go должен читать из device 0 (ТРЕТЬЕ устройство в списке)"
else
    echo "   ⚠️  Процесс не найден"
fi

echo ""
echo "═══════════════════════════════════════════════════════"
