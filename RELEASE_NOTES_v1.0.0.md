# Релиз версии 1.0.0

Полная система автоматического распознавания птиц на NanoPi M4B

## Основные возможности

- BirdNET-Go с настройкой timezone и аудио устройств
- Log-MMSE шумоподавление для полевых условий
- SoX ресемплинг через ALSA Loopback
- ReSpeaker USB 4 Mic Array с DSP настройками
- Автоматическая установка и настройка
- Полная документация

## Компоненты

- **BirdNET-Go**: Система распознавания птиц в реальном времени
- **Log-MMSE**: Алгоритм шумоподавления для нестационарного шума (ветер, дождь)
- **SoX**: Высококачественный ресемплинг 16kHz → 48kHz
- **ALSA Loopback**: Виртуальное аудио устройство для связи компонентов
- **ReSpeaker USB 4 Mic Array**: Многоканальный USB-микрофон с beamforming

## Документация

- [README.md](README.md) - Общее описание проекта
- [docs/birdnet_go_setup.md](docs/birdnet_go_setup.md) - Установка BirdNET-Go
- [docs/audio_pipeline.md](docs/audio_pipeline.md) - Аудио пайплайн
- [docs/respeaker_usb4mic_setup.md](docs/respeaker_usb4mic_setup.md) - Настройка ReSpeaker

## Быстрый старт

```bash
git clone https://github.com/Gfermoto/birdnet_odas.git
cd birdnet_odas
sudo bash scripts/setup_nanopi.sh
```

## Изменения

- Полная настройка Docker контейнера BirdNET-Go с timezone и аудио устройствами
- Реализация Log-MMSE шумоподавления для полевых условий
- Интеграция SoX для качественного ресемплинга
- Автоматическая установка и настройка всех компонентов
- Подробная документация по всем компонентам системы

## Требования

- NanoPi M4B (или совместимая ARM64 платформа)
- Ubuntu 24.04
- ReSpeaker USB 4 Mic Array (опционально)
- SD-карта минимум 32 GB

