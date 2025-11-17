#!/bin/bash
# Скрипт для передачи ReSpeaker через SoX в ALSA loopback
while true; do
    arecord -D hw:ArrayUAC10,0 -f S16_LE -r 16000 -c 6 -t raw 2>/dev/null | \
    sox -t raw -r 16000 -c 6 -e signed-integer -b 16 -L - \
        -t raw -r 48000 -c 1 -e signed-integer -b 16 -L - \
        remix 1 | \
    aplay -D hw:2,1,0 -f S16_LE -r 48000 -c 1 -t raw 2>/dev/null || sleep 1
done
