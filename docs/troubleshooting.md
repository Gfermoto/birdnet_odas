# Troubleshooting Guide

## Типичные проблемы и решения

### Проблема: Нет звука / тишина

**Симптомы:**
- BirdNET-Go не создает детекции
- Нет записей аудиоклипов

**Диагностика:**
```bash
# Проверить процессы пайплайна (должно быть 4)
ps aux | grep -E "arecord|log_mmse|sox|aplay" | grep -v grep

# Проверить USB устройство
lsusb | grep 2886

# Проверить ALSA устройства
arecord -l
aplay -l

# Проверить логи
tail -50 /var/log/birdnet-pipeline/errors.log
```

**Решения:**

1. **Перезапустить аудио пайплайн:**
```bash
sudo systemctl restart respeaker-loopback.service
```

2. **Проверить USB autosuspend:**
```bash
for dev in /sys/bus/usb/devices/*; do
    if [ -f $dev/idVendor ] && grep -q 2886 $dev/idVendor 2>/dev/null; then
        cat $dev/power/autosuspend
        cat $dev/power/control
    fi
done
```
Должно быть: autosuspend = -1, control = on

3. **Проверить модуль loopback:**
```bash
lsmod | grep snd_aloop
# Если нет, загрузить:
sudo modprobe snd-aloop
```

---

### Проблема: ReSpeaker не определяется

**Симптомы:**
- `lsusb` не показывает устройство 2886:0018
- `arecord -l` не показывает ArrayUAC10

**Решения:**

1. **Переподключить USB кабель**

2. **Проверить питание:**
```bash
# ReSpeaker требует достаточного питания USB
# Используйте качественный кабель и порт
```

3. **Проверить драйвер:**
```bash
dmesg | grep -i usb | tail -20
```

---

### Проблема: Контейнер BirdNET-Go постоянно перезапускается

**Симптомы:**
- `docker ps` показывает "Restarting"
- Веб-интерфейс недоступен

**Диагностика:**
```bash
docker ps -a
docker logs birdnet-go
```

**Решения:**

1. **Проверить конфликт с systemd сервисом:**
```bash
systemctl status birdnet-go.service
# Если активен, отключить:
sudo systemctl stop birdnet-go.service
sudo systemctl disable birdnet-go.service
sudo rm /etc/systemd/system/birdnet-go.service
```

2. **Проверить конфигурацию:**
```bash
docker exec birdnet-go cat /config/config.yaml | head -50
```

3. **Пересоздать контейнер:**
```bash
cd /path/to/birdnet_odas
docker compose down
docker compose up -d
```

---

### Проблема: Высокая нагрузка CPU

**Симптомы:**
- CPU > 80%
- Underrun ошибки в логах

**Решения:**

1. **Проверить буферы:**
```bash
grep buffer-size /usr/local/bin/respeaker_loopback.sh
```
Должно быть: buffer-size=32768, period-size=8192

2. **Снизить нагрузку BirdNET:**
```yaml
# В config.yaml
birdnet:
  threads: 2  # Уменьшить количество потоков
```

---

### Проблема: Веб-интерфейс недоступен

**Симптомы:**
- Браузер не открывает http://IP:8080
- Connection refused

**Диагностика:**
```bash
docker ps | grep birdnet
curl -I http://localhost:8080
netstat -tlnp | grep 8080
```

**Решения:**

1. **Проверить статус контейнера:**
```bash
docker ps
# Должен быть Up и (healthy)
```

2. **Проверить network_mode:**
```bash
docker inspect birdnet-go | grep NetworkMode
# Должно быть "host"
```

3. **Проверить firewall:**
```bash
sudo ufw status
sudo iptables -L -n | grep 8080
```

---

### Проблема: Много ложных срабатываний

**Симптомы:**
- Детекции видов, которых нет в локации
- Низкая confidence (0.3-0.5)

**Решения:**

1. **Повысить threshold:**
```yaml
# В config.yaml
birdnet:
  threshold: 0.7  # Вместо 0.65
```

2. **Включить географическую фильтрацию:**
```yaml
birdnet:
  latitude: 55.934
  longitude: 36.61
  rangefilter:
    model: latest
    threshold: 0.01
```

3. **Проверить шумоподавление:**
```bash
grep MIN_GAIN /usr/local/bin/log_mmse_processor.py
# Должно быть 0.15
```

---

### Проблема: Диск заполнен

**Симптомы:**
- df показывает > 90%
- BirdNET-Go логирует ошибки записи

**Решения:**

1. **Проверить retention настройки:**
```yaml
# В config.yaml должно быть:
realtime:
  audio:
    export:
      retention:
        policy: usage
        maxusage: 80%
        maxage: 30d
```

2. **Ручная очистка старых клипов:**
```bash
# Удалить клипы старше 7 дней
find /var/lib/docker/volumes/birdnet-go-data/_data/clips -name "*.wav" -mtime +7 -delete
```

3. **Проверить логи:**
```bash
# Ограничить размер логов Docker
# В docker-compose.yml должно быть:
logging:
  options:
    max-size: "10m"
    max-file: "3"
```

---

### Проблема: После перезагрузки ничего не работает

**Симптомы:**
- После reboot сервисы не запускаются
- Нет ReSpeaker в lsusb

**Решения:**

1. **Проверить автозапуск сервисов:**
```bash
systemctl is-enabled respeaker-loopback.service
systemctl is-enabled pipeline-healthcheck.timer
# Должно быть: enabled

# Если нет:
sudo systemctl enable respeaker-loopback.service
sudo systemctl enable pipeline-healthcheck.timer
```

2. **Проверить Docker:**
```bash
# В docker-compose.yml должно быть:
restart: unless-stopped
```

3. **Проверить модуль loopback:**
```bash
cat /etc/modules-load.d/snd-aloop.conf
# Должно содержать: snd-aloop
```

---

## Полезные команды

### Диагностика системы
```bash
# Полная проверка
bash scripts/check_audio_devices.sh

# Процессы
ps aux | grep -E "arecord|log_mmse|sox|aplay" | grep -v grep

# Логи
journalctl -fu respeaker-loopback.service
docker logs -f birdnet-go
tail -f /var/log/birdnet-pipeline/errors.log

# Статистика
cat /var/log/birdnet-pipeline/pipeline_stats.json
```

### Перезапуск компонентов
```bash
# Аудио пайплайн
sudo systemctl restart respeaker-loopback.service

# BirdNET-Go
docker compose restart

# Полная перезагрузка
sudo reboot
```

### Мониторинг
```bash
# CPU и память
htop

# Дисковое пространство
df -h
du -sh /var/lib/docker/volumes/birdnet-go-data/_data/*

# Сеть
ss -tlnp | grep 8080
```

---

## Логи и отладка

### Уровни логирования

**Увеличить детализацию логов BirdNET-Go:**
```yaml
# В config.yaml
logging:
  level: debug
```

**Включить отладку аудио:**
```yaml
realtime:
  audio:
    source: hw:2,0,0
    export:
      debug: true
```

### Тестирование аудио пайплайна

**Проверить запись с ReSpeaker:**
```bash
arecord -D hw:ArrayUAC10,0 -f S16_LE -r 16000 -c 6 -d 5 test.wav
aplay test.wav
```

**Проверить loopback:**
```bash
# Терминал 1:
aplay -D hw:2,1,0 -f S16_LE -r 48000 -c 1 test.wav

# Терминал 2:
arecord -D hw:2,0,0 -f S16_LE -r 48000 -c 1 -d 5 loop.wav
```

---

## Получение помощи

Если проблема не решена:

1. Соберите диагностическую информацию:
```bash
bash scripts/check_audio_devices.sh > diagnostic.txt
systemctl status respeaker-loopback --no-pager >> diagnostic.txt
docker ps -a >> diagnostic.txt
docker logs birdnet-go 2>&1 | tail -100 >> diagnostic.txt
```

2. Создайте Issue на GitHub с файлом diagnostic.txt

3. Укажите:
   - Модель устройства (RPi 4/5, NanoPi)
   - Версию ОС
   - Версию BirdNET-Go
   - Шаги для воспроизведения проблемы
