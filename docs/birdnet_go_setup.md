<!-- markdownlint-disable MD022 MD031 MD032 MD036 MD024 -->
# BirdNET‑Go: NanoPi M4B (ARM64, Ubuntu 24.04) — инструкция

> Цель: быстро и последовательно установить BirdNET‑Go, проверить запуск и, при необходимости, применить точечные фиксы для NanoPi M4B.

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

   ```bash
   # Часовой пояс
   sudo timedatectl set-timezone Europe/Moscow
   
   # Включить NTP синхронизацию
   sudo timedatectl set-ntp true
   
   # Проверка
   timedatectl status
   # Должно быть: System clock synchronized: yes
   #              NTP service: active
   ```

2. **Отключение Bluetooth (экономия питания ~50-100mA)**:
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

3. **Отключение USB autosuspend**:
   > Не отключает USB; лишь запрещает его усыпление. Нужно для стабильной записи с USB‑микрофона.

   ```bash
   echo 'ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="on"' \
   | sudo tee /etc/udev/rules.d/99-usb-autosuspend-off.rules
   sudo udevadm control --reload-rules && sudo udevadm trigger
   ```

4. **Очистка логов**:

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

### Фильтры

- HPF (High‑Pass Filter)
  - Cutoff: 300 Гц
  - Q: 0.8
  - Attenuation: 24 дБ/окт

- LPF (Low‑Pass Filter)
  - Cutoff: 7000 Гц
  - Q: 0.7
  - Attenuation: 12 дБ/окт

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

## 🚀 Быстрый запуск контейнера (опционально)

```bash
docker run -d --name birdnet-go --restart unless-stopped \
  -p 8080:8080 -p 8081:8081 \
  tphakala/birdnet-go:latest

docker logs -f birdnet-go
```

---

## 📊 Мониторинг и управление

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
docker pull tphakala/birdnet-go:latest
docker stop birdnet-go || true
docker rm birdnet-go || true
docker run -d --name birdnet-go --restart unless-stopped \
  -p 8080:8080 -p 8081:8081 \
  tphakala/birdnet-go:latest
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

## 🔧 Настройка и конфигурация

### Переменные окружения

```bash
# .env файл
BIRDNET_LATITUDE=55.7558
BIRDNET_LONGITUDE=37.6176
BIRDNET_MIN_CONFIDENCE=0.7
BIRDNET_SAMPLE_RATE=48000
BIRDNET_CHANNELS=1
BIRDNET_BITS=16

<!-- ODAS переменные убраны из .env в этом гайде -->

# Настройки Docker (при необходимости)
```

---

## 🚨 Устранение неполадок

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

## 📈 Мониторинг производительности

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

## 🔄 Backup и восстановление

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
  tphakala/birdnet-go:latest
```

---

## 📚 Дополнительные ресурсы

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

*Документ создан для проекта BirdNET‑Go на NanoPi M4B*  
*Последнее обновление: $(date +%Y-%m-%d)*

