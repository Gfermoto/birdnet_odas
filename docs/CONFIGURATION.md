# Configuration Guide

Руководство по конфигурации BirdNET-ODAS.

## Конфигурация BirdNET-Go

### Файл конфигурации

Основной файл: `/config/config.yaml` (внутри Docker volume)

Для редактирования:
```bash
docker exec -it birdnet-go nano /config/config.yaml
# После изменений:
docker compose restart
```

### Основные параметры

#### Main Settings

```yaml
main:
  name: "BirdNET-Go Station"    # Название станции
  timeas24h: true                 # 24-часовой формат времени
  log:
    level: info                   # Уровень логирования: debug, info, warn, error
    rotation: true                # Ротация логов
```

#### BirdNET Settings

```yaml
birdnet:
  # Координаты (влияют на географическую фильтрацию видов)
  latitude: 55.7558
  longitude: 37.6173
  
  # Порог уверенности (0.0-1.0)
  # Низкий (0.5-0.6): больше детекций, но больше ложных
  # Средний (0.7-0.8): баланс
  # Высокий (0.9+): только уверенные детекции
  threshold: 0.7
  
  # Перекрытие анализа (секунды)
  overlap: 1.5
  
  # Язык названий птиц
  locale: ru
  
  # Количество потоков для обработки
  threads: 4  # Для RPi 4, уменьшите до 2 при высокой нагрузке
  
  # Географическая фильтрация
  rangefilter:
    model: latest      # Модель фильтрации
    threshold: 0.01    # Порог для фильтрации
```

#### Real-time Audio

```yaml
realtime:
  # Интервал анализа (секунды)
  interval: 15
  
  audio:
    # Источник звука
    # hw:2,0,0 - ALSA Loopback (с Log-MMSE фильтрацией)
    # hw:ArrayUAC10,0 - ReSpeaker напрямую (без фильтрации)
    source: hw:2,0,0
    
    # Экспорт аудиоклипов
    export:
      enabled: true
      path: /data/clips
      type: wav
      
      # Автоочистка старых клипов
      retention:
        policy: usage       # usage или age
        maxusage: 80%       # Максимальное использование диска
        maxage: 30d         # Максимальный возраст клипов
        minclips: 10        # Минимальное количество клипов для хранения
        keepspectrograms: true
        checkinterval: 15   # Интервал проверки (минуты)
```

#### Output

```yaml
output:
  sqlite:
    enabled: true
    path: /data/birdnet.db
  
  birdweather:
    enabled: true
    id: "YOUR_STATION_ID"
    locationaccuracy: 500    # Точность локации (метры)
  
  mqtt:
    enabled: true
    broker: "mqtt://broker:1883"
    username: ""
    password: ""
    topic: "birdnet"
```

#### Web Server

```yaml
webserver:
  enabled: true
  port: 8080
  autotls: false
  log:
    enabled: true
    path: /data/webserver.log
```

## Конфигурация ReSpeaker

### DSP параметры

Файл: `/usr/local/bin/respeaker-tune.sh`

#### Высокочастотная фильтрация (HPF)

```bash
# Отсечка низкочастотного шума (ветер, ЛЭП)
usb_4_mic_array write 0x18 0x22F0 0x003C   # HPF 180 Hz
```

Доступные значения:
- `0x0050` - 80 Hz
- `0x00A0` - 160 Hz
- `0x003C` - 180 Hz (рекомендуется)

#### Шумоподавление

**Стационарное:**
```bash
# GAMMA_NS_SR - агрессивность подавления
usb_4_mic_array write 0x18 0x22C0 0x0026   # 2.4 (рекомендуется)
# Диапазон: 0.0 - 3.0
# Больше = агрессивнее подавление

# MIN_NS_SR - минимальное усиление
usb_4_mic_array write 0x18 0x22D0 0x0009   # 0.15
# Меньше значение = больше подавление
```

**Нестационарное:**
```bash
# GAMMA_NN_SR - агрессивность
usb_4_mic_array write 0x18 0x22E0 0x000B   # 1.1 (максимум прошивки)

# MIN_NN_SR - минимальное усиление
usb_4_mic_array write 0x18 0x22E8 0x0009   # 0.15
```

**Транзиенты:**
```bash
# Подавление кратковременных звуковых событий
usb_4_mic_array write 0x18 0x2330 0x0008   # включено
```

#### Автоматическая регулировка усиления (AGC)

```bash
# Максимальное усиление (дБ)
usb_4_mic_array write 0x18 0x2250 0x000C   # 6.0 dB

# Желаемый уровень сигнала
usb_4_mic_array write 0x18 0x2234 0x0052   # -23 dBov

# Время адаптации (секунды)
usb_4_mic_array write 0x18 0x2238 0x0019   # ~0.85 секунд
```

Рекомендации:
- **Птицы:** AGCMAXGAIN = 6.0 dB (консервативно)
- **Речь:** AGCMAXGAIN = 12.0 dB (агрессивнее)
- **Шумная среда:** уменьшите AGCMAXGAIN

#### Beamforming

```bash
# FREEZEONOFF - режим адаптации
usb_4_mic_array write 0x18 0x2265 0x0000   # 0 = адаптивный (рекомендуется)
# 1 = фиксированный (для статичных источников)
```

#### Отключение VAD

```bash
# Voice Activity Detection отключен для птиц
usb_4_mic_array write 0x18 0x2341 0x0000
```

#### Отключение LED

```bash
# Экономия энергии (важно при использовании USB-изолятора)
usb_4_mic_array write 0x18 0x2A1E 0x0000
```

### Применение настроек

После изменения `respeaker-tune.sh`:

```bash
# Применить настройки
sudo /usr/local/bin/respeaker-tune.sh

# Или перезапустить сервис
sudo systemctl restart respeaker-tune.service

# Перезапустить пайплайн
sudo systemctl restart respeaker-loopback.service
```

## Конфигурация аудио пайплайна

### Параметры обработки

Файл: `/usr/local/bin/respeaker_loopback.sh`

#### Размер буфера

```bash
BUFFER_SIZE=32768    # Стабильность
PERIOD_SIZE=8192     # Задержка

# Большие буферы = выше стабильность, больше задержка
# Меньшие буферы = меньше задержка, риск underrun
```

Рекомендации по платформе:
- **Raspberry Pi 4:** 32768/8192 (рекомендуется)
- **Raspberry Pi 3:** 65536/16384 (больше стабильность)
- **NanoPi M4B:** 32768/8192

#### Усиление

```bash
# SoX gain (дБ)
gain -2.0    # Защита от перегрузок

# Для тихих условий можно увеличить до 0.0 или +2.0
```

### Log-MMSE параметры

Файл: `/usr/local/bin/log_mmse_processor.py`

#### Минимальное усиление

```python
MIN_GAIN = 0.15  # Оптимально для птиц

# Меньше значение = агрессивнее подавление шума
# 0.01 - очень агрессивное (риск артефактов)
# 0.15 - оптимальное (рекомендуется)
# 0.30 - мягкое (меньше подавление)
```

#### Размер кадра STFT

```python
FRAME_SIZE = 1024    # Частотное разрешение
HOP_SIZE = 512       # 50% перекрытие

# Больше FRAME_SIZE = лучше частотное разрешение, больше задержка
# Меньше FRAME_SIZE = меньше задержка, хуже разрешение
```

#### Параметр сглаживания

```python
ALPHA = 0.70  # Decision-Directed метод

# 0.90 - больше сглаживание (меньше музыкальных артефактов)
# 0.70 - оптимальный баланс (рекомендуется)
# 0.50 - меньше сглаживание (быстрее адаптация)
```

## Оптимизация производительности

### CPU Governor

Для стабильной работы рекомендуется режим `performance`:

```bash
# Временно
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Постоянно (добавить в /etc/rc.local)
```

### USB Autosuspend

Отключение автоприостановки для ReSpeaker (критично!):

```bash
# Проверить текущее состояние
cat /sys/bus/usb/devices/*/power/control | grep -v on

# Отключить для всех USB
for dev in /sys/bus/usb/devices/*/power/control; do
    echo on > $dev 2>/dev/null
done
```

Правило udev автоматически отключает для ReSpeaker.

### Логирование Docker

Ограничение размера логов:

В `docker-compose.yml`:
```yaml
services:
  birdnet-go:
    logging:
      options:
        max-size: "10m"
        max-file: "3"
```

## Мониторинг и метрики

### Статистика пайплайна

Файл: `/var/log/birdnet-pipeline/pipeline_stats.json`

```bash
# Просмотр статистики
cat /var/log/birdnet-pipeline/pipeline_stats.json | jq
```

Метрики:
- `start_time` - время запуска
- `uptime` - время работы
- `restarts` - количество перезапусков
- `errors` - количество ошибок

### Health Check

Автоматическая проверка каждые 2 минуты:

```bash
systemctl status pipeline-healthcheck.timer
journalctl -fu pipeline-healthcheck.service
```

## Интеграция с внешними системами

### MQTT для Home Assistant

Конфигурация в `config.yaml`:

```yaml
output:
  mqtt:
    enabled: true
    broker: "mqtt://homeassistant.local:1883"
    username: "birdnet"
    password: "your_password"
    topic: "birdnet/detections"
```

Пример автоматизации в Home Assistant:

```yaml
automation:
  - alias: "Notify on rare bird"
    trigger:
      platform: mqtt
      topic: "birdnet/detections"
    condition:
      - condition: template
        value_template: "{{ trigger.payload_json.confidence > 0.9 }}"
    action:
      - service: notify.mobile_app
        data:
          message: "Detected: {{ trigger.payload_json.species }}"
```

### BirdWeather Integration

1. Зарегистрируйтесь на [BirdWeather](https://birdweather.com)
2. Создайте станцию
3. Получите Station ID
4. Добавьте в `config.yaml`:

```yaml
output:
  birdweather:
    enabled: true
    id: "12345"  # Ваш Station ID
    locationaccuracy: 500
```

## Резервное копирование

### Конфигурация

```bash
# Бэкап config.yaml
docker cp birdnet-go:/config/config.yaml ~/birdnet_config_backup.yaml

# Восстановление
docker cp ~/birdnet_config_backup.yaml birdnet-go:/config/config.yaml
docker compose restart
```

### База данных

```bash
# Бэкап SQLite
docker exec birdnet-go sqlite3 /data/birdnet.db ".backup /data/birdnet_backup.db"
docker cp birdnet-go:/data/birdnet_backup.db ~/

# Восстановление
docker cp ~/birdnet_backup.db birdnet-go:/data/birdnet_restored.db
# Затем измените path в config.yaml
```

## Дополнительные ресурсы

- [Установка](INSTALLATION.md)
- [Troubleshooting](troubleshooting.md)
- [ReSpeaker](respeaker_usb4mic_setup.md)
- [Аудио пайплайн](audio_pipeline.md)
- [BirdNET-Go документация](birdnet_go_setup.md)

---

## 📖 Навигация

- [Главная](../README.md)
- [Руководство по установке](INSTALLATION.md)
- [Руководство по настройке](CONFIGURATION.md)
- [Решение проблем](troubleshooting.md)
- [Настройка ReSpeaker](respeaker_usb4mic_setup.md)
- [Аудио пайплайн](audio_pipeline.md)
- [Настройка BirdNET-Go](birdnet_go_setup.md)
- [Структура проекта](../PROJECT_STRUCTURE.md)
- [Contributing](../CONTRIBUTING.md)
