# Contributing to BirdNET-ODAS

Спасибо за интерес к проекту! Приветствуются любые формы участия.

## Как внести вклад

### Отчеты об ошибках

При создании issue укажите:
- Модель устройства (Raspberry Pi, NanoPi, etc.)
- Версия ОС
- Версия BirdNET-Go (`docker exec birdnet-go cat /app/version.txt`)
- Логи:
  ```bash
  journalctl -n 100 --no-pager -u respeaker-loopback > logs.txt
  docker logs birdnet-go 2>&1 | tail -100 >> logs.txt
  ```
- Шаги воспроизведения

### Предложения улучшений

Создайте issue с описанием:
- Проблема, которую решает предложение
- Предлагаемое решение
- Альтернативы, если есть

### Pull Requests

1. Форкните репозиторий
2. Создайте feature branch (`git checkout -b feature/amazing-feature`)
3. Коммитьте изменения (`git commit -m 'Add amazing feature'`)
4. Пушьте в branch (`git push origin feature/amazing-feature`)
5. Откройте Pull Request

**Требования к PR:**
- Описание изменений
- Тестирование на реальном устройстве
- Обновление документации, если необходимо
- Код соответствует существующему стилю

### Документация

Помощь с документацией всегда нужна:
- Исправления опечаток
- Улучшение ясности
- Добавление примеров
- Перевод (русский/английский)

## Стиль кода

### Bash Scripts

```bash
#!/bin/bash
# Комментарий о назначении скрипта

# Константы в верхнем регистре
readonly DEVICE="hw:ArrayUAC10,0"

# Функции с описанием
check_device() {
    local device=$1
    # ...
}

# Основной код
main() {
    check_device "$DEVICE"
}

main "$@"
```

### Python Scripts

```python
#!/usr/bin/env python3
"""Module docstring."""

import sys
from typing import Optional

# Константы
SAMPLE_RATE = 16000
MIN_GAIN = 0.15

def process_audio(data: np.ndarray) -> np.ndarray:
    """Process audio with noise suppression."""
    # ...
    return processed
```

### Commit Messages

Формат: `<type>: <description>`

Types:
- `feat`: новая функция
- `fix`: исправление ошибки
- `docs`: изменения документации
- `refactor`: рефакторинг кода
- `perf`: оптимизация производительности
- `test`: добавление тестов
- `chore`: обслуживание (зависимости, CI, etc.)

Примеры:
```
feat: add automatic gain control
fix: resolve USB autosuspend issue
docs: update ReSpeaker setup guide
refactor: simplify audio pipeline script
```

## Тестирование

### Локальное тестирование

1. **Audio Pipeline:**
```bash
sudo systemctl restart respeaker-loopback.service
sleep 5
ps aux | grep -E "arecord|log_mmse|sox|aplay" | grep -v grep
# Должно быть 4 процесса
```

2. **BirdNET-Go:**
```bash
docker compose down
docker compose up -d
sleep 10
curl -s http://localhost:8080/api/health
```

3. **End-to-end:**
```bash
# Запись тестового клипа
arecord -D hw:2,0,0 -f S16_LE -r 48000 -c 1 -d 10 test.wav
# Проверка детекций
curl -s http://localhost:8080/api/detections/latest?limit=5
```

### Чек-лист перед PR

- [ ] Код протестирован на реальном устройстве
- [ ] Нет лишних файлов (логи, бэкапы, временные файлы)
- [ ] Документация обновлена
- [ ] Скрипты имеют executable permissions
- [ ] Commit message соответствует формату
- [ ] Изменения не ломают существующую функциональность

## Структура проекта

См. [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) для понимания организации файлов.

## Вопросы?

Создайте [Discussion](https://github.com/yourusername/birdnet-odas/discussions) или откройте issue.

## Лицензия

Внося вклад, вы соглашаетесь, что ваши изменения будут лицензированы под MIT License.
