# Скрипты

Утилиты для настройки и управления BirdNET-ODAS.

## ReSpeaker

### respeaker-tune.sh

Настройка DSP параметров ReSpeaker USB 4 Mic Array.

```bash
sudo /usr/local/bin/respeaker-tune.sh
```

**Параметры:**
- HPF 180 Гц
- Шумоподавление (стационарное, нестационарное, транзиенты)
- AGC с ограничением усиления
- Отключение VAD
- Отключение LED

Автозапуск: `respeaker-tune.service`

### respeaker_loopback.sh

Аудио-пайплайн ReSpeaker → Log-MMSE → SoX → ALSA Loopback.

```bash
systemctl status respeaker-loopback.service
```

**Поток данных:**
1. ReSpeaker (16kHz, 6ch)
2. Log-MMSE (16kHz, 1ch)
3. SoX resample (48kHz, 1ch)
4. ALSA loopback

**Ключевые параметры (устойчивость):**
- `arecord --buffer-size=65536 --period-size=16384`
- `aplay  -D plughw:2,1,0 --buffer-size=65536 --period-size=16384`
- Формат: S16_LE → S16_LE; plughw включён только на playback для совместимости с loopback.

**Логи:**
- Ошибки: `/var/log/birdnet-pipeline/errors.log`
- Статистика: `/var/log/birdnet-pipeline/pipeline_stats.json`

Автозапуск: `respeaker-loopback.service`

### log_mmse_processor.py

Log-MMSE шумоподавление (Ephraim & Malah, 1985).

```bash
python3 log_mmse_processor.py < input.raw > output.raw
```

**Параметры:**
- Frame size: 1024 (FFT)
- Hop size: 512 (50% overlap)
- Alpha: 0.70 (Decision-Directed smoothing)
- Min gain: 0.01 (-40 dB floor)

Вход: 6ch interleaved (16kHz, S16_LE)
Выход: 1ch mono (16kHz, S16_LE)

### disable_led_ring.py

Отключение LED кольца ReSpeaker.

```bash
python3 /usr/local/bin/disable_led_ring.py
```

Запускается автоматически через `respeaker-tune.sh`.

## Диагностика

### check_audio_devices.sh

Проверка аудио устройств и ALSA конфигурации.

```bash
bash scripts/check_audio_devices.sh
```

Проверяет:
- USB устройства
- ALSA устройства
- Loopback модуль
- Права доступа

### check_gain.sh

Проверка уровней усиления ReSpeaker.

```bash
bash scripts/check_gain.sh
```

Показывает все параметры усиления микрофона.

### diagnose_clicks.sh

Диагностика щелчков в аудио.

```bash
bash scripts/diagnose_clicks.sh
```

Проверяет:
- USB autosuspend
- Прерывания (xrun)
- Buffer underrun
- Задержки USB

## Метрики

### collect_metrics.sh

Сбор метрик производительности.

```bash
bash scripts/collect_metrics.sh
```

Собирает:
- CPU/RAM usage
- Температура
- Audio pipeline статистика
- BirdNET-Go метрики

Сохраняет в `/var/log/birdnet-metrics/`

### install_metrics_service.sh

Установка systemd сервиса для автоматического сбора метрик.

```bash
bash scripts/install_metrics_service.sh
```

Создает таймер для запуска каждые 5 минут.

## Оптимизация

### optimize_performance.sh

Оптимизация системы для реального времени.

```bash
bash scripts/optimize_performance.sh
```

Настраивает:
- CPU governor (performance)
- Swappiness (10)
- I/O scheduler
- Network buffer

## Фиксы

### fix_birdnet_device.sh

Автоматическое определение и настройка аудио устройства BirdNET-Go.

```bash
bash scripts/fix_birdnet_device.sh
```

Обновляет `config.yaml` с правильным ALSA устройством.

### fix_network_dhcp.sh

Фикс DHCP timeout (для MikroTik роутеров).

```bash
bash scripts/fix_network_dhcp.sh
```

Увеличивает таймауты NetworkManager.

## Использование

Большинство скриптов устанавливаются автоматически через:
- `platforms/raspberry-pi/setup.sh`
- `platforms/nanopi-m4b/setup.sh`

Ручной запуск нужен только для диагностики или повторной настройки.
