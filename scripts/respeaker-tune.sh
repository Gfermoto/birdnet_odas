#!/usr/bin/env bash
# Применение оптимальных DSP настроек ReSpeaker USB 4 Mic Array
# Параметры оптимизированы для записи птиц в полевых условиях
# с балансом между подавлением шума и минимизацией артефактов

set -e
cd /root/usb_4_mic_array || exit 0

# Высокочастотный фильтр (HPF): 180 Гц - максимальное значение для подавления низкочастотного шума
python3 tuning.py HPFONOFF 3

# Адаптивный beamforming: включен для автоматического направления на источник звука
python3 tuning.py FREEZEONOFF 0

# Эхоподавление: выключено (не нужно в полевых условиях)
python3 tuning.py ECHOONOFF 0
python3 tuning.py AECFREEZEONOFF 0
python3 tuning.py NLAEC_MODE 0

# Шумоподавление: все три типа включены
python3 tuning.py STATNOISEONOFF 1     # Стационарный шум (ЛЭП, гул)
python3 tuning.py NONSTATNOISEONOFF 1  # Нестационарный шум (ветер, дождь)
python3 tuning.py TRANSIENTONOFF 1     # Транзиенты (кратковременные события)

# Параметры шумоподавления (баланс между подавлением и минимизацией артефактов)
python3 tuning.py GAMMA_NS_SR 2.4   # Усиление стационарного подавления (диапазон 0-3, консервативное значение)
python3 tuning.py GAMMA_NN_SR 1.1   # Усиление нестационарного подавления (firmware limitation, не изменяется)
python3 tuning.py MIN_NS_SR 0.15    # Минимум для стационарного шума (баланс подавление/артефакты)
python3 tuning.py MIN_NN_SR 0.15    # Минимум для нестационарного шума (баланс подавление/артефакты)

# AGC (Automatic Gain Control): консервативные настройки для птиц
python3 tuning.py AGCONOFF 1                # Включить AGC
python3 tuning.py AGCMAXGAIN 6.0            # Максимальное усиление 6 dB (консервативно, не усиливает фоновый шум)
python3 tuning.py AGCDESIREDLEVEL 0.005     # Целевой уровень -23 dBov (стандарт для полевых записей)
python3 tuning.py AGCTIME 0.1               # Время реакции 0.1 сек (firmware преобразует в ~0.85 сек для стабильности)

# VAD (Voice Activity Detection): отключен для птиц (высокий порог = фактически выключен)
python3 tuning.py GAMMAVAD_SR 1000          # Очень высокий порог, записываем все звуки

# Отключить LED кольцо для снижения энергопотребления и электромагнитных помех
# Это особенно важно при использовании USB-изолятора B505S с ограниченным током (250 мА)
if [ -f /usr/local/bin/disable_led_ring.py ]; then
    python3 /usr/local/bin/disable_led_ring.py 2>/dev/null || true
fi
