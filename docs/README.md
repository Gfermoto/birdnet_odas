# NanoPi M4B: BirdNET-Go + USB-микрофон

## Документация

1. **[birdnet_go_setup.md](birdnet_go_setup.md)** — установка BirdNET-Go на NanoPi M4B
   - Docker
   - Фиксы для M4B (iptables-legacy, fuse-overlayfs)
   - Автозапуск
   - Troubleshooting

2. **[respeaker_usb4mic_setup.md](respeaker_usb4mic_setup.md)** — настройка ReSpeaker USB 4-Mic Array
   - Прошивка 6-канальной firmware
   - DSP настройки для птиц
   - Интеграция с BirdNET-Go
   - Стартовые скрипты

## Быстрый старт

```bash
# 1. Установить Docker и BirdNET-Go
curl -fsSL https://github.com/tphakala/birdnet-go/raw/main/install.sh -o install.sh
bash ./install.sh

# 2. Настроить USB-микрофон (если ReSpeaker)
git clone https://github.com/respeaker/usb_4_mic_array.git
cd usb_4_mic_array
sudo python3 dfu.py --download 6_channels_firmware.bin

# 3. Открыть Web GUI
http://IP_АДРЕС:8080
```

## Файлы

- docs/ — вся документация
- scripts/ — утилиты (установщик, тест микрофона)
- config/ — (пусто, не требуется)

