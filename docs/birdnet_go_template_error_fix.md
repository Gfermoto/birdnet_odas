# Исправление ошибки template_renderer в BirdNET-Go

## Проблема

Ошибка в веб-интерфейсе BirdNET-Go:
```
ERROR (TemplateRenderer): Error executing template birdsTable: template: birdsTable.html:44:202: executing "birdsTable" at <title .Note.CommonName>: error calling title: runtime error: slice bounds out of range [40:10]
```

## Причина

Ошибка возникает при обработке названий птиц функцией `title` в Go шаблоне. Проблема может быть связана с:
1. Пустыми или некорректными значениями `CommonName` в базе данных
2. Проблемами с кодировкой (русские названия птиц)
3. Багом в функции `title` при обработке определенных строк

## Решения

### Решение 1: Обновление до последней версии (рекомендуется)

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

### Решение 2: Очистка некорректных записей в базе данных

Если обновление не помогло, можно попробовать очистить некорректные записи:

```bash
# Войти в контейнер
docker exec -it birdnet-go sh

# Установить sqlite3 (если доступно)
# apk add sqlite (для Alpine) или apt-get install sqlite3 (для Debian)

# Или использовать Python для работы с базой
python3 << 'EOF'
import sqlite3
conn = sqlite3.connect('/data/birdnet.db')
cursor = conn.cursor()

# Найти записи с пустыми или некорректными CommonName
cursor.execute("SELECT id, common_name FROM detections WHERE common_name IS NULL OR common_name = '' OR LENGTH(common_name) = 0")
empty_names = cursor.fetchall()
print(f"Найдено записей с пустыми названиями: {len(empty_names)}")

# Удалить или исправить некорректные записи
# ВАЖНО: Сделайте backup перед удалением!
# cursor.execute("DELETE FROM detections WHERE common_name IS NULL OR common_name = '' OR LENGTH(common_name) = 0")
# conn.commit()

conn.close()
EOF
```

### Решение 3: Временное решение - перезапуск контейнера

Иногда простая перезагрузка помогает:

```bash
docker restart birdnet-go
```

### Решение 4: Проверка и исправление через API

Можно попробовать очистить кеш через API:

```bash
# Перезапуск веб-сервера (если доступно)
curl -X POST http://localhost:8081/api/restart
```

## Профилактика

1. **Регулярные обновления**: Обновляйте BirdNET-Go до последней версии
2. **Мониторинг логов**: Следите за логами на наличие подобных ошибок
3. **Backup базы данных**: Регулярно делайте backup базы данных

## Проверка исправления

После применения решения проверьте:

```bash
# Проверить логи
docker logs birdnet-go | grep -i error

# Проверить веб-интерфейс
curl -I http://localhost:8080
```

## Ссылки

- [BirdNET-Go GitHub](https://github.com/tphakala/birdnet-go)
- [Issues на GitHub](https://github.com/tphakala/birdnet-go/issues)

