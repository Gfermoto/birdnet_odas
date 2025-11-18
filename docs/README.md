# NanoPi M4B: BirdNET-Go + USB-микрофон

## Документация

Документация разделена на три основных раздела:

### 1. Микрофон

**[respeaker_usb4mic_setup.md](respeaker_usb4mic_setup.md)** — настройка ReSpeaker USB 4-Mic Array
- Прошивка 6-канальной firmware
- DSP настройки для птиц (HPF, шумоподавление, AGC)
- Оптимизация параметров для полевых условий
- Физическая защита (ветрозащита, ферритовый фильтр)

### 2. Пайплайн обработки

**[audio_pipeline.md](audio_pipeline.md)** — полный аудио пайплайн и алгоритм фильтрации
- Архитектура пайплайна (ReSpeaker → Log-MMSE → SoX → Loopback → BirdNET-Go)
- Алгоритм Log-MMSE шумоподавления (математические основы)
- Ресемплинг SoX (16kHz → 48kHz)
- ALSA Loopback устройство
- Производительность и оптимизация

### 3. BirdNET-Go

**[birdnet_go_setup.md](birdnet_go_setup.md)** — установка и настройка BirdNET-Go
- Docker установка
- Фиксы для NanoPi M4B (iptables-legacy, fuse-overlayfs)
- Настройка аудио устройства
- Встроенные фильтры (HPF, LPF)
- Автозапуск и troubleshooting

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

