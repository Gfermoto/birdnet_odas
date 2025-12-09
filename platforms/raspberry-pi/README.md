# Raspberry Pi Setup

Установка BirdNET-ODAS на Raspberry Pi CM4/Pi4/Pi5.

## Текущая установка (CM4, 9 декабря 2025)

Система установлена на 192.168.8.193 (odas):
- Docker 29.1.2, BirdNET-Go активен (порт 8080)
- Оптимизации применены (NTP, USB autosuspend off, I/O deadline, fd limits)
- Метрики собираются каждые 5 минут
- Утилиты установлены (test_mic.sh, setup_storage.sh)

**Вечером при подключении микрофона:**
```bash
cd ~/birdnet_odas/platforms/common
bash setup_respeaker.sh && bash setup_audio_pipeline.sh
sudo reboot
# В Web GUI выбрать hw:2,0 (ТРЕТЬЕ устройство)
```

## Поддерживаемые модели

- Raspberry Pi Compute Module 4 (CM4)
- Raspberry Pi 4 Model B
- Raspberry Pi 5

## Требования

**Минимальные:**
- 2GB RAM
- 16GB storage
- Debian 11+ / Raspberry Pi OS

**Рекомендуемые:**
- 4GB RAM
- 32GB eMMC
- Внешний USB накопитель (опционально)
- ReSpeaker USB 4 Mic Array

## Установка

### Базовая установка

```bash
cd ~/birdnet_odas/platforms/raspberry-pi
bash setup.sh
```

Скрипт установит:
- Docker
- BirdNET-Go
- Системные оптимизации
- ReSpeaker (если подключен)

Время: 10-15 минут

### Перелогин

После установки Docker:

```bash
exit
ssh user@<IP>
```

### Проверка

Web GUI: `http://<IP>:8080`

## Настройка ReSpeaker

Если микрофон подключается после установки:

```bash
cd ~/birdnet_odas/platforms/common
bash setup_respeaker.sh
bash setup_audio_pipeline.sh
sudo reboot
```

Проверка:
```bash
systemctl status respeaker-loopback.service
```

## Внешний накопитель

Настройка внешнего USB для хранения клипов:

```bash
~/setup_storage.sh
```

Скрипт смонтирует накопитель в `/mnt/birdnet-data` и настроит автомонтирование.

### Конфигурация BirdNET-Go

В Web GUI (Settings):
- Clips Directory: `/mnt/birdnet-data/birdnet-clips`
- Database Path: `/mnt/birdnet-data/birdnet-db/birdnet.db`

Перезапуск:
```bash
sudo systemctl restart birdnet-go
```

## Утилиты

### Тест микрофона

```bash
~/test_mic.sh
```

### Проверка устройств

```bash
arecord -l  # устройства записи
aplay -l    # устройства воспроизведения
lsusb       # USB устройства
```

### Мониторинг

```bash
# BirdNET-Go
systemctl status birdnet-go
journalctl -fu birdnet-go

# Audio pipeline
systemctl status respeaker-loopback.service
journalctl -fu respeaker-loopback.service
```

## Управление

### BirdNET-Go

```bash
sudo systemctl start birdnet-go
sudo systemctl stop birdnet-go
sudo systemctl restart birdnet-go
```

### Audio Pipeline

```bash
sudo systemctl start respeaker-loopback.service
sudo systemctl stop respeaker-loopback.service
sudo systemctl restart respeaker-loopback.service
```

## Troubleshooting

### BirdNET-Go не запускается

```bash
journalctl -xeu birdnet-go
sudo docker logs birdnet-go
```

### Микрофон не работает

```bash
lsusb | grep -i seeed
arecord -l
sudo systemctl restart respeaker-loopback.service
```

### Нет детекций

1. Проверить микрофон: `~/test_mic.sh`
2. Проверить логи: `journalctl -fu birdnet-go`
3. Уменьшить threshold в настройках (попробовать 0.5)

### Нет места

```bash
df -h
sudo docker system prune -a
sudo journalctl --vacuum-time=7d
```

## Производительность

**CM4 4GB:**
- CPU: 30-50% при детекции
- RAM: 500MB-1GB
- Latency: <100ms

**Рекомендации:**
- Внешний USB накопитель для клипов (опционально)
- Threshold: 0.7-0.8
- Включить overlap в BirdNET-Go

## Конфигурация

Файл: `~/.config/birdnet-go/config.yaml`

```yaml
main:
  name: "BirdNET-Go Pi"
  timeas24h: true

birdnet:
  latitude: 55.7558
  longitude: 37.6173
  threshold: 0.75
  overlap: 1.5
  locale: ru
  
realtime:
  interval: 15
  audioexport:
    enabled: true
    path: /mnt/birdnet-data/birdnet-clips
    type: wav

output:
  sqlite:
    enabled: true
    path: /mnt/birdnet-data/birdnet-db/birdnet.db

webserver:
  enabled: true
  port: 8080
```

## Дополнительно

- [Аудио-пайплайн](../../docs/audio_pipeline.md)
- [ReSpeaker настройка](../../docs/respeaker_usb4mic_setup.md)
- [Troubleshooting](../../docs/troubleshooting.md)
