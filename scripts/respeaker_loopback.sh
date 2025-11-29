#!/bin/bash
# Скрипт для передачи ReSpeaker через Log-MMSE и SoX в ALSA loopback
while true; do
    arecord -D hw:ArrayUAC10,0 -f S16_LE -r 16000 -c 6 -t raw --buffer-size=8192 --period-size=2048 2>/dev/null | \
    python3 /usr/local/bin/log_mmse_processor.py | \
    sox -t raw -r 16000 -c 1 -e signed-integer -b 16 -L - \
        -t raw -r 48000 -c 1 -e signed-integer -b 16 -L - gain -2.0 | \
    aplay -D hw:2,1,0 -f S16_LE -r 48000 -c 1 -t raw --buffer-size=8192 --period-size=2048 2>/dev/null || sleep 1
done
