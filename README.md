# BirdNET-ODAS

Автоматическая система распознавания и мониторинга птиц на базе BirdNET-Go и ReSpeaker USB 4 Mic Array.

## Онлайн-доступ

- BirdWeather станция: https://app.birdweather.com/stations/18409/
- Web интерфейс: https://birdnet.eyera.info

## Компоненты

- **Raspberry Pi CM4/Pi4/Pi5** — одноплатный компьютер
- **BirdNET-Go** — распознавание птиц через ML
- **ReSpeaker USB 4 Mic Array** — микрофон с DSP

## Поддерживаемые платформы

| Платформа | Статус | Примечание |
|-----------|--------|------------|
| Raspberry Pi CM4 | Полная поддержка | Рекомендуется |
| Raspberry Pi 4 | Полная поддержка | Рекомендуется |
| Raspberry Pi 5 | Полная поддержка | Рекомендуется |
| NanoPi M4B | Поддерживается | Не рекомендуется (хрупкая плата) |

**Raspberry Pi предпочтительнее:** надежнее, Docker работает без фиксов, поддержка eMMC в CM4.

## Быстрая установка

### Raspberry Pi

```bash
git clone <repository-url>
cd birdnet_odas
bash platforms/raspberry-pi/setup.sh
```

### NanoPi M4B

```bash
git clone <repository-url>
cd birdnet_odas
bash platforms/nanopi-m4b/setup.sh
```

Скрипт устанавливает Docker, BirdNET-Go, настраивает ReSpeaker (если подключен) и оптимизирует систему.

Время установки: 10-15 минут.

## Структура проекта

```
birdnet_odas/
├── platforms/
│   ├── common/              # Универсальные скрипты
│   ├── raspberry-pi/        # Setup для Raspberry Pi
│   └── nanopi-m4b/          # Setup для NanoPi M4B
├── scripts/                 # Утилиты обработки аудио
├── docs/                    # Документация
└── docker-compose.yml       # Docker Compose конфигурация
```

## Документация

- [Raspberry Pi Setup](platforms/raspberry-pi/README.md) — полное руководство
- [Аудио-пайплайн](docs/audio_pipeline.md) — Log-MMSE шумоподавление
- [ReSpeaker настройка](docs/respeaker_usb4mic_setup.md) — DSP параметры
- [BirdNET-Go](docs/birdnet_go_setup.md) — установка и конфигурация
- [Troubleshooting](docs/troubleshooting.md) — решение проблем
- [Docker Compose](docs/docker_compose_guide.md) — использование compose

## Использование

После установки Web GUI доступен на `http://<IP>:8080`

### Управление сервисами

```bash
# BirdNET-Go
systemctl status birdnet-go
journalctl -fu birdnet-go

# Audio Pipeline
systemctl status respeaker-loopback.service
journalctl -fu respeaker-loopback.service
```

### Тест микрофона

```bash
~/test_mic.sh
```

## Аудио-пайплайн

```
ReSpeaker (16kHz, 6ch) 
  → Log-MMSE (16kHz, 1ch) 
  → SoX resample (48kHz, 1ch) 
  → ALSA Loopback 
  → BirdNET-Go
```

Подробности: [docs/audio_pipeline.md](docs/audio_pipeline.md)

## Производительность

**Raspberry Pi CM4 4GB:**
- CPU: 30-50% при детекции
- RAM: 500MB-1GB
- Latency: <100ms

## Hardware

**Рекомендуемая конфигурация:**
- Raspberry Pi CM4 (4GB RAM, 16GB+ eMMC)
- Блок питания 5V/3A
- ReSpeaker USB 4 Mic Array
- Внешний USB накопитель (опционально)

## Конфигурация BirdNET-Go

`~/.config/birdnet-go/config.yaml`

Основные параметры:
- `threshold: 0.75` — порог уверенности
- `overlap: 1.5` — перекрытие сегментов
- `latitude/longitude` — координаты
- `locale: ru` — русские названия

## Системные требования

**Минимальные:**
- 2GB RAM
- 16GB storage
- Debian 11+ / Raspberry Pi OS

**Рекомендуемые:**
- 4GB+ RAM
- 32GB+ eMMC
- Внешний USB накопитель (опционально)

## Docker Compose

```bash
cp env.example .env
docker-compose up -d
```

См. [docs/docker_compose_guide.md](docs/docker_compose_guide.md)

## Научная статья

Детальное описание алгоритмов и результатов: [article.md](article.md)

## License

См. LICENSE файл
