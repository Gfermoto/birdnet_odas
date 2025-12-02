#!/bin/bash
# Скрипт для проверки текущего усиления микрофона ReSpeaker

echo "Проверка текущих настроек AGC (Auto Gain Control)..."
echo ""

cd /root/usb_4_mic_array 2>/dev/null || {
    echo "Ошибка: папка /root/usb_4_mic_array не найдена"
    echo "Проверьте, что репозиторий usb_4_mic_array установлен"
    exit 1
}

echo "=== Текущие настройки AGC ==="
echo ""
echo "AGC включен/выключен:"
python3 tuning.py AGCONOFF 2>&1 | head -1

echo ""
echo "Максимальное усиление (AGCMAXGAIN):"
python3 tuning.py AGCMAXGAIN 2>&1 | head -1

echo ""
echo "Желаемый уровень (AGCDESIREDLEVEL):"
python3 tuning.py AGCDESIREDLEVEL 2>&1 | head -1

echo ""
echo "Время реакции AGC (AGCTIME):"
python3 tuning.py AGCTIME 2>&1 | head -1

echo ""
echo "=== Ожидаемые значения (из скрипта настройки) ==="
echo "AGCMAXGAIN: 8.0 dB"
echo "AGCDESIREDLEVEL: 0.005"
echo "AGCTIME: 0.1 сек (ожидаемое реальное значение: ~0.85 сек)"

