# Исправление ошибки DNS timeout при загрузке на BirdWeather

## Проблема

Ошибка при загрузке звуковых ландшафтов на BirdWeather:
```
BirdWeather soundscape upload timeout: Post "https://app.birdweather.com/api/v1/stations/.../soundscapes": dial tcp: lookup app.birdweather.com on 192.168.1.1:53: read udp 172.17.0.3:53462->192.168.1.1:53: i/o timeout
```

## Причина

Контейнер BirdNET-Go использует DNS-сервер роутера (192.168.1.1), который может:
- Не отвечать на DNS-запросы
- Отвечать слишком медленно
- Быть недоступным в определенные моменты

## Решение

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

## Проверка

После пересоздания контейнера проверьте DNS-настройки:

```bash
docker exec birdnet-go cat /etc/resolv.conf
```

Должны быть видны все три DNS-сервера:
```
nameserver 8.8.8.8
nameserver 1.1.1.1
nameserver 192.168.1.1
```

## Применение исправления

Если контейнер уже запущен, его нужно пересоздать:

```bash
# 1. Остановить и удалить контейнер (volumes сохранятся)
docker stop birdnet-go
docker rm birdnet-go

# 2. Определить volumes старого контейнера (если нужно)
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

## Альтернативное решение: Настройка DNS для всех контейнеров

Можно настроить DNS по умолчанию для всех Docker контейнеров через `/etc/docker/daemon.json`:

```bash
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "dns": ["8.8.8.8", "1.1.1.1", "192.168.1.1"]
}
EOF

sudo systemctl restart docker
```

После этого все новые контейнеры будут использовать эти DNS-серверы по умолчанию.

## Проверка работы

После применения исправления проверьте логи на наличие ошибок DNS:

```bash
docker logs birdnet-go | grep -i "dns\|timeout\|birdweather"
```

Ошибки DNS timeout должны исчезнуть, и загрузка на BirdWeather должна работать стабильно.

