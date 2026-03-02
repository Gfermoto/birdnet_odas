# Installation Guide

Руководство по установке BirdNET-ODAS на различных платформах.

## Поддерживаемые платформы

- Raspberry Pi 4/5 (4GB+ RAM)
- Raspberry Pi Compute Module 4
- NanoPi M4B (FriendlyARM)

## Требования

### Оборудование

**Минимальные:**
- Одноплатный компьютер (см. список выше)
- 4GB RAM
- 16GB microSD / eMMC
- ReSpeaker USB 4 Mic Array v2.0
- Блок питания 5V/3A
- Сетевое подключение (Ethernet рекомендуется)

**Рекомендуемые:**
- 4GB+ RAM
- 32GB+ microSD / eMMC
- Качественный USB-кабель для микрофона
- Ферритовый фильтр на USB-кабель (для подавления помех)
- Ветрозащита (deadcat/windshield) для микрофона

### Программное обеспечение

Устанавливается автоматически скриптом установки:
- Docker и Docker Compose
- ALSA утилиты (`alsa-utils`)
- Python 3.8+
- SoX (Sound eXchange)
- NumPy, SciPy (для Log-MMSE)

## Установка для Raspberry Pi

### 1. Подготовка системы

Установите Raspberry Pi OS (64-bit) или Ubuntu 22.04+ на microSD карту.

Первый запуск:
```bash
sudo apt update
sudo apt upgrade -y
sudo reboot
```

### 2. Клонирование репозитория

```bash
cd ~
git clone https://github.com/Gfermoto/birdnet_odas.git
cd birdnet_odas
```

### 3. Запуск установки

```bash
cd platforms/raspberry-pi
sudo bash setup.sh
```

Скрипт автоматически:
1. Проверит систему и зависимости
2. Установит Docker
3. Создаст конфигурацию для BirdNET-Go
4. Настроит ReSpeaker (если подключен)
5. Установит systemd сервисы
6. Применит оптимизации

**Время установки:** 10-15 минут

### 4. Перелогин

После установки Docker необходимо перелогиниться:

```bash
exit
# Подключитесь снова
ssh user@<IP>
```

### 5. Проверка установки

```bash
# Проверить Docker
docker ps

# Проверить аудио пайплайн (если ReSpeaker подключен)
systemctl status respeaker-loopback.service

# Проверить процессы
ps aux | grep -E "arecord|log_mmse|sox|aplay" | grep -v grep
# Должно быть 4 процесса
```

### 6. Доступ к веб-интерфейсу

Откройте в браузере:
```
http://<IP-адрес>:8080
```

## Установка для NanoPi M4B

### 1. Подготовка системы

Установите Ubuntu 20.04+ на eMMC или microSD.

Первый запуск:
```bash
sudo apt update
sudo apt upgrade -y
sudo reboot
```

### 2. Клонирование и установка

```bash
cd ~
git clone https://github.com/Gfermoto/birdnet_odas.git
cd birdnet_odas/platforms/nanopi-m4b
sudo bash setup.sh
```

**Время установки:** 15-20 минут

### 3. Дальнейшие шаги

Аналогично Raspberry Pi (шаги 4-6 выше).

## Настройка ReSpeaker

Если микрофон подключается после установки:

```bash
cd ~/birdnet_odas/platforms/common
sudo bash setup_respeaker.sh
sudo bash setup_audio_pipeline.sh
sudo reboot
```

После перезагрузки проверьте:

```bash
# Устройство определяется
lsusb | grep 2886

# Сервис запущен
systemctl status respeaker-loopback.service

# Процессы работают
ps aux | grep -E "arecord|log_mmse|sox|aplay" | grep -v grep
```

## Конфигурация BirdNET-Go

### Первоначальная настройка

1. Откройте веб-интерфейс: `http://<IP>:8080`
2. Перейдите в Settings
3. Настройте основные параметры:
   - **Latitude / Longitude** - ваши координаты
   - **Locale** - язык (ru для русского)
   - **Threshold** - порог уверенности (0.7 рекомендуется)

### Настройка источника звука

В Settings → Audio:
- **Audio Source**: `hw:2,0,0` (ALSA Loopback) если используется пайплайн
- **Audio Source**: `hw:ArrayUAC10,0` (ReSpeaker прямо) для тестирования

### Сохранение изменений

После изменения настроек перезапустите контейнер:

```bash
cd ~/birdnet_odas
docker compose restart
```

## Автозапуск

Все компоненты автоматически запускаются при загрузке:

**Systemd сервисы:**
```bash
systemctl status respeaker-tune.service        # DSP настройки
systemctl status respeaker-loopback.service    # Аудио пайплайн
systemctl status pipeline-healthcheck.timer    # Мониторинг
```

**Docker контейнер:**
```bash
docker ps | grep birdnet-go
# Должен быть статус: Up, (healthy)
```

Если нужно отключить автозапуск:
```bash
sudo systemctl disable respeaker-loopback.service
```

## Проверка работы

### 1. Тест микрофона

```bash
# Запись 5 секунд
arecord -D hw:ArrayUAC10,0 -f S16_LE -r 16000 -c 6 -d 5 test.wav

# Воспроизведение
aplay test.wav
```

### 2. Тест loopback

```bash
# Запись из loopback (должен быть звук, если пайплайн работает)
arecord -D hw:2,0,0 -f S16_LE -r 48000 -c 1 -d 5 loop_test.wav
aplay loop_test.wav
```

### 3. Проверка детекций

```bash
# Через API
curl -s http://localhost:8080/api/detections/latest?limit=5 | jq

# Или откройте веб-интерфейс
```

## Устранение проблем

### BirdNET-Go не запускается

```bash
# Проверить логи
docker logs birdnet-go

# Пересоздать контейнер
cd ~/birdnet_odas
docker compose down
docker compose up -d
```

### Микрофон не работает

```bash
# Проверить USB
lsusb | grep 2886

# Перезапустить сервис
sudo systemctl restart respeaker-loopback.service

# Проверить логи
journalctl -fu respeaker-loopback.service
```

### Нет детекций

1. Проверьте threshold (попробуйте 0.5)
2. Проверьте источник звука в Settings
3. Проверьте, что пайплайн работает (4 процесса)
4. Проверьте координаты (влияет на фильтрацию видов)

Полный список проблем и решений: [troubleshooting.md](troubleshooting.md)

## Дальнейшие шаги

- [Конфигурация системы](CONFIGURATION.md)
- [Настройка ReSpeaker](respeaker_usb4mic_setup.md)
- [Аудио пайплайн](audio_pipeline.md)
- [BirdNET-Go](birdnet_go_setup.md)

## Обновление

### Обновление BirdNET-Go

Настроен автоматический мониторинг через Watchtower (проверка каждые 24 часа).

Ручное обновление:
```bash
cd ~/birdnet_odas
docker compose pull
docker compose up -d
```

### Обновление проекта

```bash
cd ~/birdnet_odas
git pull
# При необходимости перезапустите сервисы
sudo systemctl restart respeaker-loopback.service
```

## Удаление

Если нужно полностью удалить систему:

```bash
# Остановить и удалить контейнер
cd ~/birdnet_odas
docker compose down -v

# Удалить сервисы
sudo systemctl stop respeaker-loopback.service respeaker-tune.service
sudo systemctl disable respeaker-loopback.service respeaker-tune.service
sudo rm /etc/systemd/system/respeaker-*.service
sudo systemctl daemon-reload

# Удалить скрипты
sudo rm /usr/local/bin/respeaker_loopback.sh
sudo rm /usr/local/bin/log_mmse_processor.py
sudo rm /usr/local/bin/respeaker-tune.sh

# Удалить модуль loopback
sudo rmmod snd-aloop
sudo rm /etc/modules-load.d/snd-aloop.conf

# Удалить репозиторий
cd ~
rm -rf birdnet_odas
```
