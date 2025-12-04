# Устранение неполадок BirdNET-Go

Решения наиболее распространенных проблем при работе с BirdNET-Go на NanoPi M4B.

---

## Содержание

1. [DNS timeout при загрузке на BirdWeather](#dns-timeout)
2. [Ошибки MQTT подключения](#mqtt-errors)
3. [Ошибки template_renderer в веб-интерфейсе](#template-errors)
4. [Сетевые режимы Docker: host vs bridge](#network-modes)
5. [Проблемы с получением IP через DHCP (MikroTik)](#dhcp-timeout)
6. [Автоматическое обновление BirdNET-Go](#auto-update)

---

## DNS timeout при загрузке на BirdWeather {#dns-timeout}

### Проблема

Ошибка при загрузке звуковых ландшафтов на BirdWeather:
```
BirdWeather soundscape upload timeout: Post "https://app.birdweather.com/api/v1/stations/.../soundscapes": dial tcp: lookup app.birdweather.com on 192.168.1.1:53: read udp 172.17.0.3:53462->192.168.1.1:53: i/o timeout
```

### Причина

Контейнер BirdNET-Go использует DNS-сервер роутера (192.168.1.1), который может:
- Не отвечать на DNS-запросы
- Отвечать слишком медленно
- Быть недоступным в определенные моменты

### Решение

Добавить надежные DNS-серверы при создании контейнера:

```bash
docker run -d \
  --name birdnet-go \
  --restart unless-stopped \
  --dns 8.8.8.8 \        # Google DNS (основной)
  --dns 1.1.1.1 \        # Cloudflare DNS (резервный)
  --dns 192.168.1.1 \    # Роутер (локальный)
  -p 8080:8080 \
  -p 8081:8081 \
  --device /dev/snd \
  -v birdnet-go-config:/config \
  -v birdnet-go-data:/data \
  -e TZ=Europe/Moscow \
  -v /etc/localtime:/etc/localtime:ro \
  ghcr.io/tphakala/birdnet-go:nightly \
  birdnet-go realtime
```

### Применение исправления

Если контейнер уже запущен, его нужно пересоздать:

```bash
# 1. Остановить и удалить контейнер (volumes сохранятся)
docker stop birdnet-go
docker rm birdnet-go

# 2. Определить volumes старого контейнера
docker inspect birdnet-go | grep -A 5 "Mounts"

# 3. Пересоздать с DNS-настройками (используя те же volumes)
docker run -d \
  --name birdnet-go \
  --restart unless-stopped \
  --dns 8.8.8.8 \
  --dns 1.1.1.1 \
  --dns 192.168.1.1 \
  -p 8080:8080 \
  -p 8081:8081 \
  --device /dev/snd \
  -v <ваш-config-volume>:/config \
  -v <ваш-data-volume>:/data \
  -e TZ=Europe/Moscow \
  -v /etc/localtime:/etc/localtime:ro \
  ghcr.io/tphakala/birdnet-go:nightly \
  birdnet-go realtime
```

### Альтернативное решение 1: Настройка DNS для всех контейнеров (только для bridge режима)

**Важно:** Это решение работает только для контейнеров в bridge режиме. Для `network_mode: host` см. "Альтернативное решение 2" ниже.

Можно настроить DNS по умолчанию для всех Docker контейнеров через `/etc/docker/daemon.json`:

```bash
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "dns": ["8.8.8.8", "1.1.1.1", "192.168.1.1"]
}
EOF

sudo systemctl restart docker
```

### Альтернативное решение 2: Настройка DNS на хосте (для network_mode: host)

Если используется `network_mode: host` (например, в docker-compose.yml), настройки `dns` в Docker **игнорируются**, так как контейнер использует сетевой стек хоста напрямую. В этом случае нужно настроить DNS на самом хосте.

**Через systemd-resolved (Ubuntu/Debian):**

```bash
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/dns_servers.conf > /dev/null <<EOF
[Resolve]
DNS=8.8.8.8 1.1.1.1 192.168.1.1
FallbackDNS=8.8.4.4 1.0.0.1
EOF

sudo systemctl restart systemd-resolved
```

**Через /etc/resolv.conf (если не используется systemd-resolved):**

```bash
sudo cp /etc/resolv.conf /etc/resolv.conf.backup
sudo tee /etc/resolv.conf > /dev/null <<EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
nameserver 192.168.1.1
EOF
```

Подробнее см. раздел "Настройка DNS на хосте" в [docker_compose_guide.md](docker_compose_guide.md).

### Проверка

```bash
# Проверить DNS-настройки в контейнере
docker exec birdnet-go cat /etc/resolv.conf

# Проверить логи на наличие ошибок DNS
docker logs birdnet-go | grep -i "dns\|timeout\|birdweather"
```

---

## Ошибки MQTT подключения {#mqtt-errors}

### Проблемы

1. **pingresp not received, disconnecting** - MQTT клиент не получает ответ на ping, отключается
2. **context deadline exceeded** - таймаут при публикации сообщений в MQTT
3. **MQTT Integration Failed** - не удается подключиться или отправить данные

### Причины

1. Отсутствие настроек keepalive/timeout
2. Сетевые задержки между контейнером и MQTT брокером
3. Перегрузка брокера
4. Проблемы с сетью Docker (bridge режим может вызывать задержки)

### Решения

#### Решение 1: Использование сетевого режима host (рекомендуется)

Если проблемы с сетью Docker, используйте режим `--network host`:

```bash
# Остановить контейнер
docker stop birdnet-go
docker rm birdnet-go

# Пересоздать с network host
docker run -d \
  --name birdnet-go \
  --restart unless-stopped \
  --network host \
  --dns 8.8.8.8 \
  --dns 1.1.1.1 \
  # -p 8080:8080 \  # Не нужно в режиме host (порты доступны напрямую)
  # -p 8081:8081 \  # Не нужно в режиме host (порты доступны напрямую)
  --device /dev/snd \
  -v birdnet-go-config:/config \
  -v birdnet-go-data:/data \
  -e TZ=Europe/Moscow \
  -v /etc/localtime:/etc/localtime:ro \
  ghcr.io/tphakala/birdnet-go:nightly \
  birdnet-go realtime
```

**Важно:** В режиме `--network host` порты 8080 и 8081 будут доступны напрямую, без проброса портов (закомментированы).

#### Решение 2: Проверка доступности брокера

```bash
# Проверить доступность брокера с хоста
ping -c 3 192.168.1.10

# Проверить порт MQTT
nc -zv 192.168.1.10 1883
```

#### Решение 3: Проверка настроек MQTT брокера

Убедитесь, что MQTT брокер (Home Assistant или другой):
1. Работает и доступен на указанном адресе
2. Принимает подключения с указанными учетными данными
3. Не перегружен и отвечает на ping запросы
4. Имеет достаточные таймауты для keepalive

#### Решение 4: Временное отключение MQTT

Если MQTT не критичен для работы, можно временно отключить через веб-интерфейс BirdNET-Go (Settings → MQTT → Disable).

### Диагностика

```bash
# Просмотр логов MQTT
docker logs birdnet-go | grep -i mqtt

# Просмотр последних ошибок
docker logs birdnet-go | grep -i "error\|timeout\|disconnect" | tail -20

# Проверить статус контейнера
docker ps | grep birdnet-go
```

### Мониторинг

```bash
# Мониторинг в реальном времени
docker logs -f birdnet-go | grep -i mqtt

# Проверка ошибок
docker logs birdnet-go 2>&1 | grep -i "mqtt.*error\|pingresp\|timeout" | tail -10
```

---

## Ошибки template_renderer в веб-интерфейсе {#template-errors}

### Проблема

Ошибка в веб-интерфейсе BirdNET-Go:
```
ERROR (TemplateRenderer): Error executing template birdsTable: template: birdsTable.html:44:202: executing "birdsTable" at <title .Note.CommonName>: error calling title: runtime error: slice bounds out of range [40:10]
```

### Причина

Ошибка возникает при обработке названий птиц функцией `title` в Go шаблоне. Проблема может быть связана с:
1. Пустыми или некорректными значениями `CommonName` в базе данных
2. Проблемами с кодировкой (русские названия птиц)
3. Багом в функции `title` при обработке определенных строк

### Решения

#### Решение 1: Обновление до последней версии (рекомендуется)

```bash
# Остановить контейнер
docker stop birdnet-go

# Получить последнюю версию
docker pull ghcr.io/tphakala/birdnet-go:nightly

# Пересоздать контейнер (сохраняя volumes)
docker rm birdnet-go
docker run -d \
  --name birdnet-go \
  --restart unless-stopped \
  --dns 8.8.8.8 \
  --dns 1.1.1.1 \
  --dns 192.168.1.1 \
  -p 8080:8080 \
  -p 8081:8081 \
  --device /dev/snd \
  -v birdnet-go-config:/config \
  -v birdnet-go-data:/data \
  -e TZ=Europe/Moscow \
  -v /etc/localtime:/etc/localtime:ro \
  ghcr.io/tphakala/birdnet-go:nightly \
  birdnet-go realtime
```

#### Решение 2: Перезапуск контейнера

Иногда простая перезагрузка помогает:

```bash
docker restart birdnet-go
```

#### Решение 3: Очистка некорректных записей в базе данных

Если обновление не помогло, можно попробовать очистить некорректные записи (требует Python в контейнере):

```bash
docker exec -it birdnet-go python3 << 'EOF'
import sqlite3
conn = sqlite3.connect('/data/birdnet.db')
cursor = conn.cursor()

# Найти записи с пустыми или некорректными CommonName
cursor.execute("SELECT id, common_name FROM detections WHERE common_name IS NULL OR common_name = '' OR LENGTH(common_name) = 0")
empty_names = cursor.fetchall()
print(f"Найдено записей с пустыми названиями: {len(empty_names)}")

# ВАЖНО: Сделайте backup перед удалением!
# cursor.execute("DELETE FROM detections WHERE common_name IS NULL OR common_name = '' OR LENGTH(common_name) = 0")
# conn.commit()

conn.close()
EOF
```

### Проверка исправления

```bash
# Проверить логи
docker logs birdnet-go | grep -i error

# Проверить веб-интерфейс
curl -I http://localhost:8080
```

**Важно:** Эта ошибка не критична - BirdNET-Go продолжает работать и записывать птиц, но некоторые записи могут не отображаться в веб-интерфейсе.

---

## Сетевые режимы Docker: host vs bridge {#network-modes}

### Анализ безопасности для отдельного одноплатника

**Безопасно использовать `--network host` для вашего случая:**

**Причины:**
1. **Изолированное устройство** - одноплатник используется только для BirdNET-Go
2. **Локальная сеть** - устройство в домашней/локальной сети, не экспонируется в интернет
3. **Минимальная поверхность атаки** - нет других критичных сервисов на хосте
4. **Нет конфликтов портов** - порты 8080/8081 свободны на хосте

**Потенциальные риски (минимальные):**
- Отсутствие сетевой изоляции (не критично для изолированного устройства)
- Прямой доступ к портам хоста (не конфликтует с другими сервисами)

**Рекомендация:** Для отдельного одноплатника в локальной сети использование `--network host` безопасно и рекомендуется для улучшения стабильности MQTT.

### Текущая конфигурация (bridge режим)

По умолчанию контейнер использует **bridge** режим:
- Контейнер имеет свой собственный IP-адрес в Docker сети (например, `172.17.0.3`)
- Создается виртуальная сеть между контейнерами
- Порты пробрасываются явно через `-p 8080:8080`
- NAT (Network Address Translation) используется для связи с хостом и внешней сетью

### Что даст `--network host`?

#### Преимущества:

1. **Прямой доступ к локальной сети**
   - Контейнер использует сетевой стек хоста напрямую
   - Нет дополнительного уровня NAT/маршрутизации
   - Прямое подключение к локальным сервисам без промежуточных слоев

2. **Меньше задержек (latency)**
   - Убирается один уровень сетевой абстракции
   - Прямое подключение = быстрее отклик
   - Меньше вероятность таймаутов

3. **Упрощение сетевой конфигурации**
   - Не нужно пробрасывать порты (`-p 8080:8080` не нужен)
   - Контейнер видит все сетевые интерфейсы хоста
   - Работает как обычное приложение на хосте

4. **Лучшая совместимость с локальными сервисами**
   - MQTT брокер виден напрямую
   - Нет проблем с маршрутизацией в Docker сети
   - Меньше проблем с DNS resolution

#### Недостатки:

1. **Отсутствие сетевой изоляции**
   - Контейнер имеет полный доступ к сети хоста
   - Потенциальные риски безопасности (для домашней сети обычно не критично)

2. **Конфликты портов**
   - Контейнер использует порты хоста напрямую
   - Если порт 8080 уже занят на хосте, будет конфликт

3. **Ограниченная поддержка**
   - Работает только на Linux

### Сравнение для MQTT

**Bridge режим (текущий):**
```
Контейнер (172.17.0.3) 
  → Docker bridge network 
  → NAT 
  → Хост (192.168.1.136) 
  → Локальная сеть 
  → MQTT брокер (192.168.1.10:1883)
```

**Проблемы:**
- Дополнительные уровни маршрутизации
- Возможные задержки на NAT
- Проблемы с keepalive/ping могут быть связаны с NAT timeout

**Host режим:**
```
Контейнер 
  → Хост (192.168.1.136) напрямую 
  → Локальная сеть 
  → MQTT брокер (192.168.1.10:1883)
```

**Преимущества:**
- Прямое подключение, без промежуточных слоев
- Меньше задержек
- Более стабильное keepalive соединение

### Когда использовать `--network host`?

**Рекомендуется использовать, если:**
- Проблемы с подключением к локальным сервисам (MQTT, Home Assistant)
- Таймауты и проблемы с keepalive
- Нужна максимальная производительность сети
- Работаете в домашней/доверенной сети

**Не рекомендуется, если:**
- Нужна изоляция контейнеров (production, multi-tenant)
- Порт 8080 уже занят другим приложением
- Работаете в небезопасной сети

### Как применить `--network host`?

```bash
# 1. Остановить и удалить текущий контейнер
docker stop birdnet-go
docker rm birdnet-go

# 2. Определить volumes (если нужно)
docker volume ls | grep birdnet

# 3. Пересоздать с --network host
docker run -d \
  --name birdnet-go \
  --restart unless-stopped \
  --network host \
  --dns 8.8.8.8 \
  --dns 1.1.1.1 \
  # -p 8080:8080 \  # Не нужно в режиме host (порты доступны напрямую)
  # -p 8081:8081 \  # Не нужно в режиме host (порты доступны напрямую)
  --device /dev/snd \
  -v birdnet-go-config:/config \
  -v birdnet-go-data:/data \
  -e TZ=Europe/Moscow \
  -v /etc/localtime:/etc/localtime:ro \
  ghcr.io/tphakala/birdnet-go:nightly \
  birdnet-go realtime
```

**Важно:** В режиме `--network host`:
- Проброс портов `-p 8080:8080 -p 8081:8081` не нужен (закомментирован)
- Web UI будет доступен на `http://192.168.1.136:8080` (IP хоста)
- MQTT подключение будет напрямую к `192.168.1.10:1883`

### Проверка после применения

```bash
# Проверить сетевой режим
docker inspect birdnet-go --format '{{.HostConfig.NetworkMode}}'
# Должно быть: host

# Проверить логи MQTT
docker logs birdnet-go | grep -i mqtt | tail -10
```

---

## Общие команды диагностики

### Проверка статуса контейнера

```bash
# Статус контейнера
docker ps | grep birdnet-go

# Детальная информация
docker inspect birdnet-go

# Логи в реальном времени
docker logs -f birdnet-go
```

### Проверка сети

```bash
# Сетевой режим
docker inspect birdnet-go --format '{{.HostConfig.NetworkMode}}'

# DNS настройки
docker exec birdnet-go cat /etc/resolv.conf

# IP адрес контейнера (для bridge режима)
docker inspect birdnet-go --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
```

### Проверка volumes

```bash
# Список volumes
docker volume ls | grep birdnet

# Информация о volumes контейнера
docker inspect birdnet-go | grep -A 10 "Mounts"
```

### Мониторинг ресурсов

```bash
# Использование ресурсов
docker stats birdnet-go

# Использование диска
docker system df
```

---

## ReSpeaker отключается / ошибки "No such device" {#usb-autosuspend}

### Проблема

Аудио пайплайн постоянно перезапускается, в логах ошибки:
```
arecord: pcm_read:2240: read error: No such device
overrun!!! (at least 1495.620 ms long)
underrun!!! (at least 39.702 ms long)
```

Статистика показывает множество перезапусков (например, 101 раз за 14 минут) с коротким uptime (2-3 секунды).

### Причина

**USB autosuspend** отключает ReSpeaker через несколько секунд для экономии энергии. Это критическая проблема для realtime аудио обработки.

### Диагностика

Проверьте настройки USB autosuspend для ReSpeaker:

```bash
# Найти USB устройство ReSpeaker
lsusb | grep -i seeed
# Вывод: Bus 003 Device 002: ID 2886:0018 Seeed Technology Inc. ReSpeaker 4 Mic Array (UAC1.0)

# Найти путь в /sys
ls -la /sys/bus/usb/devices/ | grep 2886

# Проверить настройки autosuspend (например, для 3-1)
cat /sys/bus/usb/devices/3-1/power/autosuspend
cat /sys/bus/usb/devices/3-1/power/control

# Если autosuspend = 2 (или другое малое значение), это проблема!
# Правильные значения: autosuspend=-1, control=on
```

### Решение 1: Немедленное исправление (временное)

Отключить autosuspend для текущей сессии:

```bash
# Найти устройство (замените 3-1 на ваш путь)
USB_DEVICE=$(ls -d /sys/bus/usb/devices/*-* | xargs -I {} sh -c 'grep -q "2886" {}/idVendor 2>/dev/null && echo {}' | head -1)

# Отключить autosuspend
echo -1 | sudo tee $USB_DEVICE/power/autosuspend
echo on | sudo tee $USB_DEVICE/power/control

# Проверить
cat $USB_DEVICE/power/autosuspend  # Должно быть: -1
cat $USB_DEVICE/power/control      # Должно быть: on
```

### Решение 2: Постоянное исправление через udev правила

Создать udev правила для автоматического отключения autosuspend:

```bash
sudo tee /etc/udev/rules.d/99-respeaker.rules > /dev/null << 'EOF'
# Права доступа к ReSpeaker USB
SUBSYSTEM=="usb", ATTR{idVendor}=="2886", MODE="0666", GROUP="plugdev"

# Отключить autosuspend для ReSpeaker (критично для стабильности!)
SUBSYSTEM=="usb", ATTR{idVendor}=="2886", ATTR{idProduct}=="0018", TEST=="power/control", ATTR{power/control}="on"
SUBSYSTEM=="usb", ATTR{idVendor}=="2886", ATTR{idProduct}=="0018", TEST=="power/autosuspend", ATTR{power/autosuspend}="-1"

# Автоматический запуск настройки DSP при подключении ReSpeaker
SUBSYSTEM=="usb", ATTR{idVendor}=="2886", ACTION=="add", RUN+="/bin/systemctl start respeaker-tune.service"
EOF

# Применить правила
sudo udevadm control --reload-rules
sudo udevadm trigger

# Или перезагрузить систему
sudo reboot
```

### Решение 3: Глобальное отключение USB autosuspend

Если проблема сохраняется, отключите autosuspend для всех USB устройств:

```bash
# Через udev правило
echo 'ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="on"' | \
  sudo tee /etc/udev/rules.d/99-usb-autosuspend-off.rules

# Применить
sudo udevadm control --reload-rules && sudo udevadm trigger
```

### Проверка исправления

После применения решения проверьте стабильность:

```bash
# Проверить логи пайплайна (не должно быть "No such device")
tail -f /var/log/birdnet-pipeline/errors.log

# Проверить статистику (uptime должен расти)
watch -n 5 'journalctl -u respeaker-loopback.service --no-pager --since "1 min ago" | tail -5'

# Проверить статус службы
systemctl status respeaker-loopback.service
```

**Ожидаемый результат:**
- Ошибки "No such device" исчезли
- Пайплайн работает стабильно (uptime > 10 минут)
- Только микроскопические underrun 0.01-0.02ms (норма для realtime аудио)

### Дополнительная информация

**Почему это происходит:**
- Linux ядро по умолчанию включает USB autosuspend для экономии энергии
- Для USB аудио устройств это критично, так как приводит к прерыванию потока
- ReSpeaker особенно чувствителен к autosuspend из-за realtime характера работы

**Другие устройства:**
- Эта проблема может затрагивать любые USB аудио устройства
- Для других устройств замените `idVendor` и `idProduct` в udev правилах

---

## Проблемы с получением IP через DHCP (MikroTik) {#dhcp-timeout}

### Проблема

Система не получает IP адрес через DHCP на MikroTik роутере, хотя линк мигает.

### Решение

Применить скрипт для увеличения DHCP таймаутов:

```bash
sudo bash scripts/fix_network_dhcp.sh
```

Скрипт:
- Увеличивает DHCP таймаут до 120 секунд (было 45 секунд)
- Увеличивает таймаут NetworkManager-wait-online до 180 секунд
- Отключает may-fail - система будет ждать получения IP адреса

**MAC адрес eth0:** `80:34:28:3c:c8:e8` - убедитесь, что на MikroTik настроена DHCP reservation для этого MAC адреса.

---

## Автоматическое обновление BirdNET-Go {#auto-update}

### Обзор

Автоматическое обновление BirdNET-Go настроено через **Watchtower** — специализированный контейнер для мониторинга и обновления Docker образов.

### Как работает Watchtower

Watchtower отслеживает изменения в образе `ghcr.io/tphakala/birdnet-go:nightly` и автоматически обновляет контейнер при появлении новой версии.

**Конфигурация:**
- Проверка обновлений: каждые 24 часа
- Автоматическая очистка старых образов
- Отслеживание контейнеров с label `com.centurylinklabs.watchtower.enable=true`
- Сохранение всех volumes и настроек контейнера

### Проверка статуса

```bash
# Проверка что Watchtower работает
docker ps | grep watchtower

# Логи Watchtower
docker logs watchtower | tail -20

# Когда следующая проверка обновлений
docker logs watchtower | grep "Scheduling first run"
```

### Ручное обновление

```bash
# Остановить контейнер
docker stop birdnet-go

# Получить последнюю версию
docker pull ghcr.io/tphakala/birdnet-go:nightly

# Перезапустить (systemd сервис пересоздаст контейнер автоматически)
systemctl restart birdnet-go
```

### Отключение автоматического обновления

```bash
# Остановить и удалить Watchtower
docker stop watchtower
docker rm watchtower
```

**Примечания:**
- При обновлении контейнер останавливается на несколько секунд
- Все данные и настройки сохраняются в Docker volumes
- Watchtower работает только с контейнерами, у которых есть label `com.centurylinklabs.watchtower.enable=true`

---

## Полезные ссылки

- [BirdNET-Go GitHub](https://github.com/tphakala/birdnet-go)
- [BirdNET-Go Wiki](https://github.com/tphakala/birdnet-go/wiki)
- [Issues на GitHub](https://github.com/tphakala/birdnet-go/issues)
- [Docker Network Documentation](https://docs.docker.com/network/)
- [Watchtower GitHub](https://github.com/containrrr/watchtower)

---

*Последнее обновление: 2025-11-23*

