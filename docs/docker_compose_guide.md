# Руководство по использованию Docker Compose

## Обзор

Docker Compose упрощает управление контейнером BirdNET-Go, позволяя хранить всю конфигурацию в одном файле и управлять контейнером простыми командами.

## Быстрый старт

### 1. Подготовка

```bash
# Скопировать пример конфигурации
cp env.example .env

# Отредактировать .env при необходимости
nano .env
```

### 2. Запуск

```bash
# Запустить контейнер в фоновом режиме
docker-compose up -d

# Проверить статус
docker-compose ps

# Просмотр логов
docker-compose logs -f birdnet-go
```

## Основные команды

### Управление контейнером

```bash
# Запуск
docker-compose up -d

# Остановка
docker-compose down

# Перезапуск
docker-compose restart

# Остановка и удаление контейнера (volumes сохранятся)
docker-compose down

# Остановка и удаление контейнера с volumes (ОСТОРОЖНО!)
docker-compose down -v
```

### Просмотр информации

```bash
# Список контейнеров
docker-compose ps

# Логи в реальном времени
docker-compose logs -f

# Логи конкретного сервиса
docker-compose logs -f birdnet-go

# Последние 100 строк логов
docker-compose logs --tail=100 birdnet-go

# Использование ресурсов
docker-compose top
```

### Выполнение команд в контейнере

```bash
# Войти в контейнер
docker-compose exec birdnet-go sh

# Выполнить команду
docker-compose exec birdnet-go ls -la /data

# Проверить настройки
docker-compose exec birdnet-go cat /config/config.yaml
```

### Обновление

```bash
# Получить последнюю версию образа
docker-compose pull

# Пересоздать контейнер с новым образом
docker-compose up -d

# Или одной командой
docker-compose pull && docker-compose up -d
```

## Конфигурация

### Файл docker-compose.yml

Основная конфигурация находится в `docker-compose.yml`:

```yaml
version: '3.8'

services:
  birdnet-go:
    image: ghcr.io/tphakala/birdnet-go:${BIRDNET_IMAGE_TAG:-nightly}
    container_name: birdnet-go
    restart: unless-stopped
    network_mode: host
    dns:
      - 8.8.8.8
      - 1.1.1.1
      - 192.168.1.1
    devices:
      - /dev/snd:/dev/snd
    volumes:
      - birdnet-go-config:/config
      - birdnet-go-data:/data
      - /etc/localtime:/etc/localtime:ro
    environment:
      - TZ=${TZ:-Europe/Moscow}
    command: birdnet-go realtime
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
```

### Файл .env

Переменные окружения настраиваются в файле `.env`:

```bash
# Версия образа
BIRDNET_IMAGE_TAG=nightly

# Часовой пояс
TZ=Europe/Moscow
```

**Важно:** Файл `.env` не должен попадать в git (уже в .gitignore). Используйте `env.example` как шаблон.

## Миграция с существующего контейнера

Если у вас уже есть контейнер, созданный через `docker run`, можно мигрировать на Docker Compose:

### Вариант 1: Использовать существующие volumes

```bash
# 1. Определить volumes текущего контейнера
docker inspect birdnet-go | grep -A 5 "Mounts"

# 2. Остановить старый контейнер
docker stop birdnet-go
docker rm birdnet-go

# 3. Отредактировать docker-compose.yml, изменив секцию volumes:
# volumes:
#   birdnet-go-config:
#     external: true
#     name: 3fad40c5083b7fce2a598d24433e9378258e69ab6c3e2709e01425ea15a9a070
#   birdnet-go-data:
#     external: true
#     name: 14219d166d01ec1ff5b8983b6b62fe9377216660b00732cf8fca9706059938ad

# 4. Запустить через docker-compose
docker-compose up -d
```

### Вариант 2: Мигрировать на именованные volumes

```bash
# 1. Создать backup
docker exec birdnet-go tar -czf /tmp/backup.tar.gz /config /data
docker cp birdnet-go:/tmp/backup.tar.gz ./backup-$(date +%Y%m%d).tar.gz

# 2. Остановить старый контейнер
docker stop birdnet-go
docker rm birdnet-go

# 3. Запустить через docker-compose (создаст новые volumes)
docker-compose up -d

# 4. Восстановить данные
docker cp backup-*.tar.gz birdnet-go:/tmp/
docker-compose exec birdnet-go tar -xzf /tmp/backup-*.tar.gz -C /

# 5. Перезапустить
docker-compose restart
```

## Преимущества Docker Compose

1. **Простота управления** - все команды в одном месте
2. **Версионирование конфигурации** - можно хранить в git
3. **Переменные окружения** - легко менять настройки через .env
4. **Масштабируемость** - легко добавить другие сервисы (мониторинг, backup)
5. **Документированность** - вся конфигурация видна в одном файле

## Дополнительные сервисы

Можно легко добавить другие сервисы в `docker-compose.yml`:

```yaml
services:
  birdnet-go:
    # ... существующая конфигурация ...

  # Пример: добавление watchtower
  watchtower:
    image: containrrr/watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --cleanup --interval 86400
    restart: unless-stopped
```

## Troubleshooting

### Контейнер не запускается

```bash
# Проверить конфигурацию
docker-compose config

# Проверить логи
docker-compose logs birdnet-go

# Проверить volumes
docker volume ls | grep birdnet
```

### Проблемы с volumes

```bash
# Проверить существующие volumes
docker volume ls

# Удалить volumes (ОСТОРОЖНО - удалит данные!)
docker-compose down -v
```

### Обновление конфигурации

```bash
# После изменения docker-compose.yml
docker-compose up -d --force-recreate
```

## Сравнение: docker run vs docker-compose

| Операция | docker run | docker-compose |
|----------|------------|----------------|
| Запуск | `docker run -d ...` | `docker-compose up -d` |
| Остановка | `docker stop birdnet-go` | `docker-compose down` |
| Логи | `docker logs birdnet-go` | `docker-compose logs` |
| Обновление | Ручное пересоздание | `docker-compose pull && up -d` |
| Конфигурация | Длинная команда | Файл YAML |

## Рекомендации

1. **Используйте именованные volumes** - проще управлять
2. **Храните .env в .gitignore** - не коммитьте чувствительные данные
3. **Документируйте изменения** - коммитьте изменения в docker-compose.yml
4. **Делайте backup перед изменениями** - особенно при миграции volumes

---

*Последнее обновление: 2025-11-23*

