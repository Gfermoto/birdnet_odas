# Changelog

## [2.0.0] - 2024-12-09

### Multi-Platform Support

Проект реорганизован для поддержки нескольких ARM64-платформ.

### Добавлено

**Raspberry Pi:**
- Поддержка CM4, Pi 4, Pi 5
- Установочный скрипт: `platforms/raspberry-pi/setup.sh`
- Docker работает без фиксов

**Модульная архитектура:**
- `platforms/common/` — универсальные скрипты
- `platforms/raspberry-pi/` — Raspberry Pi setup
- `platforms/nanopi-m4b/` — NanoPi M4B setup (legacy)

### Изменено

**Структура:**
```
scripts/setup_nanopi.sh  →  platforms/nanopi-m4b/setup.sh
(нет Pi поддержки)       →  platforms/raspberry-pi/setup.sh
                         +  platforms/common/*.sh
```

**Документация:**
- README сокращен (511 → 130 строк)
- Удалены дубликаты
- Убраны эмодзи и AI-паттерны

### Устарело

NanoPi M4B больше не рекомендуется:
- Хрупкая плата
- Требует Docker фиксы
- Малое сообщество

Рекомендуется Raspberry Pi CM4.

### Технические детали

**Raspberry Pi преимущества:**
- overlay2 storage driver (без фиксов)
- Стандартный iptables
- eMMC в CM4
- Качественная PCB

**Обратная совместимость:**
- Утилиты scripts/ не изменены
- ReSpeaker настройки идентичны
- Аудио-пайплайн совместим

---

## [1.0.0] - 2024-08

### Initial Release

- Поддержка NanoPi M4B
- BirdNET-Go интеграция
- ReSpeaker USB 4 Mic Array
- Log-MMSE шумоподавление
- Docker Compose setup
