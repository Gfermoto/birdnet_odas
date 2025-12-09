# Документация BirdNET-ODAS

## Быстрый старт

### Raspberry Pi

```bash
cd ~/birdnet_odas/platforms/raspberry-pi
bash setup.sh
```

См. [platforms/raspberry-pi/README.md](../platforms/raspberry-pi/README.md)

### NanoPi M4B

```bash
cd ~/birdnet_odas/platforms/nanopi-m4b
bash setup.sh
```

## Компоненты системы

### 1. ReSpeaker USB микрофон

[respeaker_usb4mic_setup.md](respeaker_usb4mic_setup.md)

- Прошивка 6-канальной firmware
- DSP настройки (HPF, AGC, шумоподавление)
- Оптимизация для полевых условий

### 2. Аудио-пайплайн

[audio_pipeline.md](audio_pipeline.md)

Полный пайплайн обработки:
```
ReSpeaker → Log-MMSE → SoX → Loopback → BirdNET-Go
```

- Log-MMSE шумоподавление
- Ресемплинг 16kHz → 48kHz
- ALSA Loopback устройство
- Производительность и метрики

### 3. BirdNET-Go

[birdnet_go_setup.md](birdnet_go_setup.md)

- Docker установка
- Конфигурация
- Встроенные фильтры
- Автозапуск

### 4. Docker Compose

[docker_compose_guide.md](docker_compose_guide.md)

- Быстрый старт
- Управление контейнером
- Миграция

### 5. Troubleshooting

[troubleshooting.md](troubleshooting.md)

- Проблемы Docker
- Проблемы аудио
- Проблемы сети
- Диагностика

## Структура проекта

```
birdnet_odas/
├── platforms/
│   ├── common/              # Универсальные скрипты
│   ├── raspberry-pi/        # Raspberry Pi setup
│   └── nanopi-m4b/          # NanoPi M4B setup
├── scripts/                 # Утилиты
├── docs/                    # Документация
└── docker-compose.yml
```

## Утилиты (scripts/)

См. [scripts/README.md](../scripts/README.md)

- Диагностика аудио
- Сбор метрик
- Оптимизация производительности
- Фиксы конфигурации
