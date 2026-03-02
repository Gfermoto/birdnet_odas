# NanoPi M4B Setup

Установка BirdNET-ODAS на FriendlyElec NanoPi M4B.

## Спецификации

- **SoC:** Rockchip RK3399 (2×A72 @ 1.8GHz + 4×A53 @ 1.4GHz)
- **RAM:** 2GB DDR3
- **Storage:** eMMC или microSD
- **OS:** Ubuntu 20.04+ / Debian 11+

## Требования

**Минимальные:**
- 2GB RAM (достаточно)
- 16GB storage
- Ubuntu/Debian

**Рекомендуемые:**
- eMMC (быстрее microSD)
- 32GB+ storage
- ReSpeaker USB 4 Mic Array
- Качественное питание 5V/3A

## Установка

### Базовая установка

```bash
cd ~/birdnet_odas/platforms/nanopi-m4b
bash setup.sh
```

Скрипт установит:
- Docker
- BirdNET-Go
- Системные оптимизации
- ReSpeaker (если подключен)

Время: 15-20 минут

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

## Оптимизации для RK3399

### CPU Scheduler

RK3399 имеет big.LITTLE архитектуру. Оптимизация для аудио:

```bash
# Принудительное использование больших ядер
echo performance | sudo tee /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
```

### eMMC vs microSD

**eMMC** (рекомендуется):
- Быстрее в 2-3 раза
- Надежнее для 24/7
- Меньше latency

**microSD:**
- Использовать Class 10 UHS-I или выше
- Регулярные бэкапы

## Управление

### BirdNET-Go

```bash
docker ps
docker logs -f birdnet-go
docker compose restart
```

### Audio Pipeline

```bash
sudo systemctl status respeaker-loopback.service
sudo systemctl restart respeaker-loopback.service
journalctl -fu respeaker-loopback.service
```

## Troubleshooting

### BirdNET-Go не запускается

```bash
docker ps -a
docker logs birdnet-go
# Пересоздать:
docker compose down && docker compose up -d
```

### Микрофон не работает

```bash
lsusb | grep 2886
arecord -l
sudo systemctl restart respeaker-loopback.service
```

### Высокая нагрузка CPU

```bash
# Использовать большие ядра
echo 1 > /sys/devices/system/cpu/cpu4/online
echo 1 > /sys/devices/system/cpu/cpu5/online
```

### Перегрев

NanoPi M4B может нагреваться при высокой нагрузке:

```bash
# Проверить температуру
cat /sys/class/thermal/thermal_zone0/temp
# Результат в милиградусах (50000 = 50°C)
```

**Рекомендации:**
- Пассивный радиатор (обязательно)
- Активное охлаждение при >60°C

## Производительность

**RK3399 2GB:**
- CPU: 40-60% при детекции
- RAM: 600MB-1GB
- Latency: 100-200ms

**Оптимизация:**
- Threshold: 0.7-0.8
- Ограничить threads в BirdNET-Go:
  ```yaml
  birdnet:
    threads: 4  # вместо 6
  ```

## Конфигурация

Файл: `/path/to/birdnet_odas/config/config.yaml` (в Docker volume)

```yaml
main:
  name: "BirdNET-Go NanoPi"
  timeas24h: true

birdnet:
  latitude: 55.7558
  longitude: 37.6173
  threshold: 0.75
  threads: 4
  overlap: 1.5
  locale: ru
  
realtime:
  interval: 15
  audio:
    source: hw:2,0,0  # ALSA Loopback

output:
  sqlite:
    enabled: true

webserver:
  enabled: true
  port: 8080
```

## Известные проблемы

### DHCP на MikroTik

NanoPi может иметь проблемы с получением IP от некоторых MikroTik роутеров.

**Решение:**
```bash
bash scripts/fix_network_dhcp.sh
```

Скрипт увеличит DHCP таймауты.

### USB порты

Используйте качественный USB кабель для ReSpeaker. Некоторые дешевые кабели вызывают потери пакетов.

## Дополнительно

- [Аудио-пайплайн](../../docs/audio_pipeline.md)
- [ReSpeaker настройка](../../docs/respeaker_usb4mic_setup.md)
- [Troubleshooting](../../docs/troubleshooting.md)
- [Фикс DHCP для MikroTik](../../scripts/README.md#fix_network_dhcpsh)
