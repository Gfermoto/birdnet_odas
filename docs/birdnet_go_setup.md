<!-- markdownlint-disable MD022 MD031 MD032 MD036 MD024 -->
# BirdNET‑Go: NanoPi M4B (ARM64, Ubuntu 24.04) — инструкция

> Цель: быстро и последовательно установить BirdNET‑Go, проверить запуск и, при необходимости, применить точечные фиксы для NanoPi M4B.
> 

---

## 1. Стабилизация системы (до установки)

```bash
sudo apt --fix-broken install
```

---

## 2. Установка

```bash
# База
sudo apt-get update && sudo apt-get install -y curl ca-certificates wget netcat-openbsd git

# Docker
curl -fsSL https://get.docker.com | sh
sudo systemctl enable --now docker

# Группа docker (без sudo)
USER_NAME=${SUDO_USER:-$USER}; sudo usermod -aG docker "$USER_NAME"
newgrp docker <<'EOF'
docker run --rm alpine echo ok
EOF

# BirdNET‑Go (официальный скрипт)
curl -fsSL https://github.com/tphakala/birdnet-go/raw/main/install.sh -o install.sh
bash ./install.sh

# Проверка
systemctl status birdnet-go --no-pager
docker ps
```

Web GUI: `http://IP_АДРЕС:8080`

---

## 3. Троблшутинг (минимум)

### Docker не стартует (частая проблема на NanoPi M4B)

Если `systemctl status docker` показывает ошибки iptables/overlay:

```bash
# Установить fuse-overlayfs и iptables
sudo apt install -y fuse-overlayfs iptables

# Переключить на iptables-legacy (для NanoPi M4B/Ubuntu Noble)
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy 2>/dev/null || \
  sudo update-alternatives --install /usr/sbin/iptables iptables /usr/sbin/iptables-legacy 10
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy 2>/dev/null || \
  sudo update-alternatives --install /usr/sbin/ip6tables ip6tables /usr/sbin/ip6tables-legacy 10

# Конфиг Docker для fuse-overlayfs
sudo mkdir -p /etc/docker
cat <<'EOF' | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {"max-size": "10m", "max-file": "3"},
  "storage-driver": "fuse-overlayfs"
}
EOF

# Перезапуск
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
sudo systemctl restart docker

# Проверка
sudo docker info | grep -E "Storage Driver|Cgroup Driver"
sudo docker run --rm alpine echo ok
```

Если всё ещё не работает:
```bash
# Проверить детали ошибки
sudo journalctl -xeu docker.service --no-pager | tail -50

# Нет прав на docker.sock
USER_NAME=${SUDO_USER:-$USER}; groups | grep docker || sudo usermod -aG docker "$USER_NAME"

# Логи BirdNET‑Go
docker logs -n 200 birdnet-go
```

---

## 4. (Пусто) — резерв под будущие примечания NanoPi M4B

### Оптимизация для полевых условий

1. **Настройка часового пояса и NTP (критично для точных timestamp)**:
   > С батарейкой RTC на NanoPi M4B время сохраняется при перезагрузке. NTP синхронизирует его с серверами времени.
   > **Важно:** BirdNET-Go должен использовать тот же часовой пояс, что и хост-система, иначе записи будут распределяться по времени неправильно.

   ```bash
   # Часовой пояс хоста
   sudo timedatectl set-timezone Europe/Moscow
   echo "Europe/Moscow" | sudo tee /etc/timezone
   
   # Включить NTP синхронизацию
   sudo timedatectl set-ntp true
   
   # Проверка
   timedatectl status
   # Должно быть: System clock synchronized: yes
   #              NTP service: active
   #              Time zone: Europe/Moscow (MSK, +0300)
   ```

2. **Настройка часового пояса в контейнере BirdNET-Go**:
   > Контейнер BirdNET-Go по умолчанию использует UTC. Необходимо настроить его на локальный часовой пояс.
   > 
   > При пересоздании контейнера нужно использовать те же volumes, иначе настройки будут потеряны. Также обязательно добавить `--device /dev/snd`, иначе аудио устройства не будут доступны.
   > 

   ```bash
   # Шаг 1: Определить volumes старого контейнера
   docker inspect birdnet-go | grep -A 5 "Mounts"
   # Запишите имена volumes (например, 3fad40c5... или birdnet-go-config)
   
   # Шаг 2: Создать backup (рекомендуется)
   docker exec birdnet-go tar -czf /tmp/backup.tar.gz /config /data
   docker cp birdnet-go:/tmp/backup.tar.gz ./backup-$(date +%Y%m%d-%H%M%S).tar.gz
   
   # Шаг 3: Остановить и удалить контейнер (volumes сохранятся)
   docker stop birdnet-go
   docker rm birdnet-go
   
   # Шаг 4: Пересоздать контейнер со всеми необходимыми параметрами
   # Если volumes имеют хешированные имена (например, 3fad40c5...):
   docker run -d \
     --name birdnet-go \
     --restart unless-stopped \
     -p 8080:8080 \
     -p 8081:8081 \
     --device /dev/snd \
     -v 3fad40c5083b7fce2a598d24433e9378258e69ab6c3e2709e01425ea15a9a070:/config \
     -v 14219d166d01ec1ff5b8983b6b62fe9377216660b00732cf8fca9706059938ad:/data \
     -e TZ=Europe/Moscow \
     -v /etc/localtime:/etc/localtime:ro \
     ghcr.io/tphakala/birdnet-go:nightly \
     birdnet-go realtime
   
   # Если volumes имеют именованные имена:
   docker run -d \
     --name birdnet-go \
     --restart unless-stopped \
     -p 8080:8080 \
     -p 8081:8081 \
     --device /dev/snd \
     -v birdnet-go-config:/config \
     -v birdnet-go-data:/data \
     -e TZ=Europe/Moscow \
     -v /etc/localtime:/etc/localtime:ro \
     ghcr.io/tphakala/birdnet-go:nightly \
     birdnet-go realtime
   
   # Шаг 5: Проверка всех компонентов
   # 5.1. Контейнер запущен
   docker ps | grep birdnet-go
   
   # 5.2. Аудио устройства доступны
   docker exec birdnet-go ls -la /dev/snd/ | head -5
   
   # 5.3. Timezone правильный
   docker exec birdnet-go date
   docker exec birdnet-go sh -c "echo TZ=\$TZ && cat /etc/timezone"
   
   # 5.4. Volumes подключены
   docker exec birdnet-go ls -la /config/ | head -5
   docker exec birdnet-go ls -la /data/ | head -5
   
   # 5.5. Аудио устройства видны в логах
   docker logs birdnet-go 2>&1 | grep -i "available\|listening\|source" | tail -3
   ```

3. **Отключение Bluetooth (экономия питания ~50-100mA)**:
   > Рекомендуется отключить BT, если не используется. Wi-Fi оставляем для удалённого доступа.

   ```bash
   # Остановить и отключить службы Bluetooth
   sudo systemctl stop bluetooth
   sudo systemctl disable bluetooth
   sudo rfkill block bluetooth
   
   # Проверка
   systemctl is-active bluetooth  # → inactive
   rfkill list bluetooth          # → Soft blocked: yes
   rfkill list wifi               # → Soft blocked: no (Wi-Fi работает)
   ```

   **Если нужно отключить и Wi-Fi (проводное подключение):**
   ```bash
   # Отключить Wi-Fi (для работы только по Ethernet)
   sudo rfkill block wifi
   nmcli radio wifi off
   
   # Включить обратно
   sudo rfkill unblock wifi
   nmcli radio wifi on
   ```

4. **Отключение USB autosuspend**:
   > Не отключает USB; лишь запрещает его усыпление. Нужно для стабильной записи с USB‑микрофона.

   ```bash
   echo 'ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="on"' \
   | sudo tee /etc/udev/rules.d/99-usb-autosuspend-off.rules
   sudo udevadm control --reload-rules && sudo udevadm trigger
   ```

5. **Очистка логов**:

   ```bash
   sudo journalctl --vacuum-time=7d
   ```

---

## 5. Web GUI — базовые настройки

### Основные настройки

1. **Location Settings**:
   - Latitude: ваша широта
   - Longitude: ваша долгота
   - Timezone: ваш часовой пояс

2. **Audio Settings**:
   
   > **Подробное описание пайплайна:** См. [audio_pipeline.md](audio_pipeline.md)
   
   Настройка аудио устройства:
   - Input Source: Network Stream
   - Sample Rate: 48000 Hz
   - Channels: 1 (Mono)
   - Buffer Size: 1024

3. **Detection Settings**:
   - Confidence Threshold: 0.7 (рекомендуется)
   - Sensitivity: Medium
   - Language: English (или ваш язык)

4. **Output Settings**:
   - Save Audio: Yes
   - Save Spectrograms: Yes
   - Export Format: CSV, JSON

## 6. Рекомендованные настройки BirdNET‑Go

### Фильтры (настроены на основе анализа спектра микрофона)

**Анализ спектра показал:**
- Пик низкочастотного шума: **93.8 Гц при -56.4 дБ** (самый громкий!)
- Высокий уровень шума до 200 Гц: -63.3 дБ
- Приемлемый уровень с 300 Гц: -69.1 дБ
- Птицы поют в диапазоне 1-10 кГц
- Выше 12 кГц: -120 дБ (практически тишина)

**Примечание:** Пик на 93.8 Гц может быть связан с ЛЭП (высоковольтные линии электропередачи), так как 93.8 Гц ≈ 2-я гармоника 50 Гц (100 Гц) с небольшим отклонением. Высокий уровень шума до 200 Гц типичен для ЛЭП 110 кВ. См. [respeaker_usb4mic_setup.md](respeaker_usb4mic_setup.md) для подробностей о защите от ЛЭП.

**Рекомендуемые настройки:**

- **HPF (High‑Pass Filter)** - убрать низкочастотный шум
  - Type: HighPass
  - Frequency: **300 Гц** (убирает шум ниже 300 Гц, включая пик на 93.8 Гц)
  - Q: **0.8** (умеренная крутизна среза)
  - Gain: 0 dB
  - Width: 0
  - Passes: **2** (двухпроходная фильтрация для лучшего подавления)

- **LPF (Low‑Pass Filter)** - сохранить диапазон птиц, убрать ультразвук
  - Type: LowPass
  - Frequency: **12000 Гц** (сохраняет весь диапазон птиц 1-10 кГц)
  - Q: **0.7** (умеренная крутизна среза)
  - Gain: 0 dB
  - Width: 0
  - Passes: **1** (однопроходная фильтрация)

**Обоснование:**
- HPF на 300 Гц безопасно убирает весь низкочастотный шум (пик на 93.8 Гц), не затрагивая диапазон птиц
- LPF на 12 кГц сохраняет весь диапазон птиц (1-10 кГц) и убирает ультразвуковые артефакты

### Формат входного аудио

- Формат: signed 16‑bit little‑endian (сырой PCM)
- Частота дискретизации: 48 кГц

### Получение GPS координат

**Через Google Maps**:

1. Откройте [Google Maps](https://maps.google.com)
2. Найдите место установки
3. Кликните правой кнопкой → "Что здесь?"
4. Скопируйте координаты

**Через мобильное приложение**:

- **GPS Status** (Android)
- **Compass** (iOS)
- **GPS Coordinates** (универсальное)

---

## 7. Мониторинг и результаты

### Web интерфейс (доступ)

После настройки BirdNET-Go предоставляет:

- **Dashboard**: Обзор обнаружений в реальном времени
- **Species List**: Список обнаруженных видов птиц
- **Audio Player**: Прослушивание записанных звуков
- **Statistics**: Статистика по времени и видам
- **Settings**: Настройка параметров

### Доступ к результатам

```bash
# Просмотр данных через Docker
docker exec -it birdnet-go ls -la /app/data/

# Копирование результатов на хост
docker cp birdnet-go:/app/data/ ./birdnet-results/
```

---

## 8. Устранение неполадок (приоритеты)

1) Docker/права:

```bash
systemctl status docker --no-pager
groups | grep docker || echo "not-in-docker-group"
docker run --rm alpine echo ok
```

1) Сеть/порты Web‑GUI:

```bash
ss -tulpn | grep -E ":8080|:8081"
docker ps | grep birdnet-go
docker logs -n 200 birdnet-go
```

<!-- ODAS подключение исключено из этого гайда -->

### Проблемы с Web GUI

```bash
# Проверка статуса контейнера
docker ps | grep birdnet-go

# Проверка портов
ss -tulpn | grep :8080

# Перезапуск с новыми настройками
docker compose down && docker compose up -d
```

### Проблемы с аудио (в контейнере)

```bash
# Проверка аудио устройств
docker exec -it birdnet-go arecord -l

# Тест записи
docker exec -it birdnet-go arecord -f S16_LE -r 48000 -c 1 -d 5 test.wav
```

---

## 9. Управление службой

### Основные команды

```bash
# Запуск BirdNET-Go
sudo systemctl start birdnet-go

# Остановка BirdNET-Go
sudo systemctl stop birdnet-go

# Перезапуск
sudo systemctl restart birdnet-go

# Статус
sudo systemctl status birdnet-go

# Автозапуск при загрузке
sudo systemctl enable birdnet-go
```

### Обновление

```bash
# Обновление до последней версии
curl -fsSL https://github.com/tphakala/birdnet-go/raw/main/install.sh -o install.sh
bash ./install.sh --update
```

---

## 10. Оптимизация

### Для полевых условий

- **Confidence Threshold**: 0.8 (меньше ложных срабатываний)
- **Buffer Size**: 2048 (стабильность)
- **Save Audio**: No (экономия места)

### Для стационарной работы

- **Confidence Threshold**: 0.6 (больше обнаружений)
- **Buffer Size**: 1024 (быстрота)
- **Save Audio**: Yes (полная запись)

---

## 11. Дополнительные ресурсы

### Официальная документация (ссылки)

- [BirdNET-Go GitHub](https://github.com/tphakala/birdnet-go)
- [BirdNET-Go Wiki](https://github.com/tphakala/birdnet-go/wiki)
- [BirdNET Cornell Lab](https://birdnet.cornell.edu/)

### Полезные ссылки

- [eBird Database](https://ebird.org/) - база данных птиц
- [Xeno-canto](https://xeno-canto.org/) - аудио библиотека птиц
- [Merlin Bird ID](https://merlin.allaboutbirds.org/) - мобильное приложение

---

*Документ создан для проекта BirdNET‑Go на NanoPi M4B*  
*Последнее обновление: $(date +%Y-%m-%d)*

---

## Быстрый запуск контейнера (опционально)

```bash
# Важно: контейнер должен быть запущен с правильным timezone и доступом к аудио
docker run -d --name birdnet-go --restart unless-stopped \
  -p 8080:8080 -p 8081:8081 \
  --device /dev/snd \
  -v birdnet-go-config:/config \
  -v birdnet-go-data:/data \
  -e TZ=Europe/Moscow \
  -v /etc/localtime:/etc/localtime:ro \
  ghcr.io/tphakala/birdnet-go:nightly \
  birdnet-go realtime

docker logs -f birdnet-go
```

**Примечание:** Параметры `-e TZ=Europe/Moscow` и `-v /etc/localtime:/etc/localtime:ro` необходимы для правильного распределения записей по времени. Без них контейнер будет использовать UTC, и записи будут неправильно распределяться по времени.

---

## Мониторинг и управление

### Docker команды

```bash
# Просмотр контейнеров
docker ps

# Просмотр логов
docker logs -f birdnet-go

# Перезапуск/остановка/удаление
docker restart birdnet-go
docker stop birdnet-go && docker rm birdnet-go

# Обновление образа и перезапуск
docker pull ghcr.io/tphakala/birdnet-go:nightly
docker stop birdnet-go || true
docker rm birdnet-go || true
docker run -d --name birdnet-go --restart unless-stopped \
  -p 8080:8080 -p 8081:8081 \
  --device /dev/snd \
  -v birdnet-go-config:/config \
  -v birdnet-go-data:/data \
  -e TZ=Europe/Moscow \
  -v /etc/localtime:/etc/localtime:ro \
  ghcr.io/tphakala/birdnet-go:nightly \
  birdnet-go realtime
```

### Web GUI

После запуска система доступна по адресам:

- **BirdNET-Go Web UI**: `http://IP_АДРЕС:8080`
- **API**: `http://IP_АДРЕС:8081`

### Мониторинг ресурсов

```bash
# Использование ресурсов контейнерами
docker stats

# Использование диска
docker system df

# Очистка неиспользуемых ресурсов
docker system prune -a
```

---

## Настройка и конфигурация

### Переменные окружения

```bash
# .env файл
BIRDNET_LATITUDE=55.7558
BIRDNET_LONGITUDE=37.6176
BIRDNET_MIN_CONFIDENCE=0.7
BIRDNET_SAMPLE_RATE=48000
BIRDNET_CHANNELS=1
BIRDNET_BITS=16

# Критически важно для правильного времени записей:
TZ=Europe/Moscow

<!-- ODAS переменные убраны из .env в этом гайде -->

# Настройки Docker (при необходимости)
```

**Важно:** Переменная `TZ=Europe/Moscow` (или ваш часовой пояс) должна быть установлена при запуске контейнера, иначе записи будут распределяться по времени неправильно (используется UTC вместо локального времени).

---

## Устранение неполадок

### Проблемы с Docker

```bash
# Проверка логов
docker logs -n 200 birdnet-go

# Сеть
docker network ls

# Перезапуск контейнера
docker restart birdnet-go
```

### Проблемы с аудио

```bash
# Проверка аудио устройств в контейнере
docker exec -it birdnet-go ls -la /dev/snd/

# Проверка PulseAudio
docker exec -it birdnet-go pulseaudio --check

# Тест аудио
docker exec -it birdnet-go arecord -l
```

<!-- Раздел ODAS подключений удалён для упрощения гайда -->

---

## Мониторинг производительности

```bash
# Установка Prometheus и Grafana
docker run -d --name prometheus -p 9090:9090 prom/prometheus
docker run -d --name grafana -p 3000:3000 grafana/grafana

# Мониторинг контейнеров
docker run -d --name cadvisor -p 8080:8080 \
  --volume=/:/rootfs:ro \
  --volume=/var/run:/var/run:ro \
  --volume=/sys:/sys:ro \
  --volume=/var/lib/docker/:/var/lib/docker:ro \
  --volume=/dev/disk/:/dev/disk:ro \
  gcr.io/cadvisor/cadvisor:latest
```

---

## Backup и восстановление

### Автоматический backup

```bash
#!/bin/bash
# backup_birdnet.sh

BACKUP_DIR="/backup/birdnet-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup данных
docker cp birdnet-go:/app/data "$BACKUP_DIR/"
docker cp birdnet-go:/app/logs "$BACKUP_DIR/"

# Backup конфигурации
cp docker-compose.yml "$BACKUP_DIR/"
cp .env "$BACKUP_DIR/"

# Сжатие
tar -czf "$BACKUP_DIR.tar.gz" "$BACKUP_DIR"
rm -rf "$BACKUP_DIR"

echo "Backup создан: $BACKUP_DIR.tar.gz"
```

### Восстановление

```bash
#!/bin/bash
# restore_birdnet.sh

BACKUP_FILE="$1"
if [ -z "$BACKUP_FILE" ]; then
    echo "Использование: $0 backup_file.tar.gz"
    exit 1
fi

# Остановка контейнера
docker stop birdnet-go || true

# Восстановление данных
tar -xzf "$BACKUP_FILE"
docker cp data/ birdnet-go:/app/
docker cp logs/ birdnet-go:/app/

# Запуск контейнера
docker run -d --name birdnet-go --restart unless-stopped \
  -p 8080:8080 -p 8081:8081 \
  --device /dev/snd \
  -v birdnet-go-config:/config \
  -v birdnet-go-data:/data \
  -e TZ=Europe/Moscow \
  -v /etc/localtime:/etc/localtime:ro \
  ghcr.io/tphakala/birdnet-go:nightly \
  birdnet-go realtime
```

---

## Дополнительные ресурсы

### Официальная документация

- [Docker Documentation](https://docs.docker.com/)
- [BirdNET-Go GitHub](https://github.com/tphakala/birdnet-go)

### Полезные инструменты

- [Portainer](https://www.portainer.io/) - Web UI для Docker
- [Watchtower](https://containrrr.dev/watchtower/) - Автообновление контейнеров
- [Traefik](https://traefik.io/) - Reverse proxy для контейнеров

### Сообщество

- [Docker Community](https://forums.docker.com/)
- [BirdNET Discord](https://discord.gg/birdnet)

---

## Полная конфигурация Docker контейнера

Здесь описаны все параметры запуска контейнера BirdNET-Go, которые используются в текущей рабочей конфигурации.

### Анализ текущей конфигурации

#### Проверка текущего контейнера

```bash
# Получить полную информацию о контейнере
docker inspect birdnet-go --format "{{json .}}" | python3 -m json.tool

# Проверить volumes
docker inspect birdnet-go | grep -A 10 "Mounts"

# Проверить devices
docker inspect birdnet-go | grep -A 5 "Devices"

# Проверить переменные окружения
docker inspect birdnet-go | grep -A 10 "Env"
```

### Параметры запуска

#### 1. Базовые параметры

- `-d` - Запуск в фоновом режиме (detached)
- `--name birdnet-go` - Имя контейнера (для удобного управления)
- `--restart unless-stopped` - Автоматический перезапуск при сбоях (кроме ручной остановки)

#### 2. Сетевые порты

- `-p 8080:8080` - Web GUI (обязательно)
- `-p 8081:8081` - API (обязательно)

**Проверка:**
```bash
ss -tulpn | grep -E ":8080|:8081"
```

#### 3. Доступ к аудио устройствам

- `--device /dev/snd` - Предоставляет доступ ко всем ALSA устройствам

Без этого параметра контейнер не видит звуковые карты, BirdNET-Go не сможет выбрать аудио источник, в логах будет ошибка "Audio device validation failed: no hardware audio capture devices found".

**Проверка:**
```bash
docker exec birdnet-go ls -la /dev/snd/
# Должны быть видны все устройства: controlC*, pcmC*D*
```

**Альтернативные варианты (не рекомендуются):**
- `--privileged` - дает полный доступ ко всем устройствам (небезопасно)
- `--device /dev/snd:/dev/snd` - то же самое, что `--device /dev/snd`

#### 4. Volumes

**Конфигурация:**
- `-v <CONFIG_VOLUME>:/config` - Хранит настройки BirdNET-Go (config.yaml, tokens.json и т.д.)

**Данные:**
- `-v <DATA_VOLUME>:/data` - Хранит базу данных, записи, логи

При пересоздании контейнера нужно использовать те же volumes, иначе настройки будут потеряны.

**Как найти volumes старого контейнера:**
```bash
# Способ 1: Через docker inspect
docker inspect birdnet-go | grep -A 5 "Mounts"

# Способ 2: Через docker volume ls
docker volume ls

# Способ 3: Через docker ps (если контейнер запущен)
docker ps --format "{{.Names}}" | xargs docker inspect | grep -A 5 "Mounts"
```

**Типы volumes:**
- **Именованные volumes** (рекомендуется): `birdnet-go-config`, `birdnet-go-data`
- **Анонимные volumes** (хеши): `3fad40c5...`, `14219d1...` (используются при первом запуске)

#### 5. Timezone

- `-e TZ=Europe/Moscow` - Переменная окружения для часового пояса
- `-v /etc/localtime:/etc/localtime:ro` - Монтирование файла timezone с хоста (read-only)

Оба параметра нужны: `TZ` устанавливает переменную окружения (используется многими приложениями), `/etc/localtime` - системный файл timezone (используется системными вызовами).

**Проверка:**
```bash
docker exec birdnet-go date
# Должно показывать локальное время (MSK), а не UTC

docker exec birdnet-go sh -c "echo TZ=\$TZ && cat /etc/timezone"
# Должно быть: TZ=Europe/Moscow
#              Europe/Moscow
```

**Без этих параметров:**
- Контейнер использует UTC
- Записи распределяются по времени неправильно
- Timestamp в именах файлов будет в UTC

#### 6. Образ и команда

- `ghcr.io/tphakala/birdnet-go:nightly` - Официальный образ (nightly версия)
- `birdnet-go realtime` - Команда запуска (realtime режим)

**Альтернативные теги:**
- `:latest` - стабильная версия (может быть устаревшей)
- `:nightly` - последняя версия (рекомендуется)

### Дополнительные параметры (опционально)

#### Логирование

```bash
--log-driver json-file \
--log-opt max-size=10m \
--log-opt max-file=3
```

**По умолчанию:** Docker использует json-file driver с этими настройками.

#### Ограничения ресурсов

```bash
--memory="2g" \
--cpus="2.0"
```

**Для NanoPi M4B:** Обычно не требуется, система сама управляет ресурсами.

#### Сетевая изоляция

```bash
--network bridge
```

**По умолчанию:** bridge network (стандартно для Docker).

### Чеклист перед пересозданием контейнера

- [ ] Определены volumes старого контейнера
- [ ] Проверено, что volumes содержат данные (config.yaml, birdnet.db)
- [ ] Подготовлена команда запуска с правильными volumes
- [ ] Добавлен `--device /dev/snd`
- [ ] Добавлены параметры timezone (`-e TZ` и `-v /etc/localtime`)
- [ ] Проверены порты (8080, 8081)
- [ ] Установлен `--restart unless-stopped`

### Типичные ошибки и их решения

#### Ошибка: "Audio device validation failed"

**Причина:** Отсутствует `--device /dev/snd`

**Решение:**
```bash
docker stop birdnet-go
docker rm birdnet-go
# Пересоздать с --device /dev/snd
```

#### Ошибка: Записи распределяются по времени неправильно

**Причина:** Отсутствуют параметры timezone

**Решение:**
```bash
docker stop birdnet-go
docker rm birdnet-go
# Пересоздать с -e TZ=Europe/Moscow и -v /etc/localtime:/etc/localtime:ro
```

#### Ошибка: Настройки потеряны после пересоздания

**Причина:** Использованы новые volumes вместо старых

**Решение:**
```bash
# Найти старые volumes
docker inspect <OLD_CONTAINER_ID> | grep -A 5 "Mounts"

# Использовать их при пересоздании
```

#### Ошибка: "Volume not found"

**Причина:** Volume был удален

**Решение:**
```bash
# Проверить существующие volumes
docker volume ls

# Если volume удален, нужно восстановить из backup или начать заново
```

### Рекомендации

1. Используйте именованные volumes для новых установок:
   ```bash
   -v birdnet-go-config:/config
   -v birdnet-go-data:/data
   ```

2. **Создавайте backup перед изменениями:**
   ```bash
   docker exec birdnet-go tar -czf /tmp/backup.tar.gz /config /data
   docker cp birdnet-go:/tmp/backup.tar.gz ./backup-$(date +%Y%m%d).tar.gz
   ```

3. **Документируйте volumes:**
   ```bash
   # Сохранить информацию о volumes
   docker inspect birdnet-go | grep -A 10 "Mounts" > volumes-info.txt
   ```

4. **Используйте docker-compose** для сложных конфигураций (опционально)

---


