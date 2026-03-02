# BirdNET-ODAS: Система распознавания птиц с направленным слухом

**Интеграция BirdNET с ReSpeaker USB 4 Mic Array для точного распознавания птиц**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 🎯 О проекте

BirdNET-ODAS - это система автоматического распознавания птиц по звуку, объединяющая:
- **BirdNET-Go** - нейросетевая модель для идентификации птиц
- **ReSpeaker 4 Mic Array** - микрофонная решетка для качественного захвата звука
- **Log-MMSE шумоподавление** - алгоритм для фильтрации фонового шума
- **ALSA Loopback** - аудио пайплайн для обработки в реальном времени

### Возможности

- ✅ **Распознавание 6000+ видов птиц** из модели BirdNET GLOBAL 6K V2.4
- ✅ **Шумоподавление в реальном времени** с помощью Log-MMSE
- ✅ **Веб-интерфейс** для мониторинга и анализа
- ✅ **Автоматическое сохранение** аудиоклипов с детекциями
- ✅ **MQTT интеграция** для Home Assistant
- ✅ **Географическая фильтрация** видов по региону
- ✅ **Круглосуточная работа** с автовосстановлением

## 📋 Требования

### Оборудование
- Raspberry Pi 4/5 (4GB+ RAM) или NanoPi M4B
- [ReSpeaker USB Mic Array v2.0](https://www.seeedstudio.com/ReSpeaker-Mic-Array-v2-0.html)
- MicroSD карта 16GB+ (рекомендуется 32GB+)
- Стабильное питание 5V/3A

### Программное обеспечение
- Linux (Debian/Ubuntu)
- Docker и Docker Compose
- ALSA утилиты
- Python 3.8+
- SoX аудио процессор

## 🚀 Быстрый старт

### 1. Клонирование репозитория

```bash
git clone https://github.com/Gfermoto/birdnet_odas.git
cd birdnet_odas
```

### 2. Выбор платформы и запуск установки

**Для Raspberry Pi:**
```bash
cd platforms/raspberry-pi
sudo bash setup.sh
```

**Для NanoPi M4B:**
```bash
cd platforms/nanopi-m4b  
sudo bash setup.sh
```

Скрипт автоматически:
- Установит Docker и зависимости
- Настроит ReSpeaker
- Создаст аудио пайплайн
- Запустит BirdNET-Go
- Настроит автозапуск всех сервисов

### 3. Доступ к веб-интерфейсу

После установки откройте в браузере:
```
http://<IP-адрес-устройства>:8080
```

## 📖 Документация

- [Установка и настройка](docs/INSTALLATION.md)
- [Конфигурация](docs/CONFIGURATION.md)
- [Решение проблем](docs/troubleshooting.md)
- [Настройка ReSpeaker](docs/respeaker_usb4mic_setup.md)
- [Аудио пайплайн](docs/audio_pipeline.md)
- [BirdNET-Go](docs/birdnet_go_setup.md)

## 🏗️ Архитектура

```
ReSpeaker USB (16kHz, 6ch)
    ↓ arecord
Log-MMSE Processor (шумоподавление)
    ↓ python3
SoX (ресемплинг 48kHz + gain)
    ↓ sox
ALSA Loopback (48kHz, 1ch)
    ↓ hw:2,0,0
BirdNET-Go (распознавание)
    ↓
Веб-интерфейс / MQTT / API
```

## 🔧 Основные компоненты

### Аудио пайплайн
- **Buffer size:** 32768 samples (стабильность)
- **Gain:** 8.0 dB (усиление сигнала)
- **MIN_GAIN:** 0.15 (оптимальное шумоподавление)
- **Частота:** 16kHz → 48kHz ресемплинг

### BirdNET-Go
- **Модель:** BirdNET GLOBAL 6K V2.4
- **Threshold:** 0.65 (баланс точность/чувствительность)
- **Overlap:** 1.5 секунд
- **Retention:** 30 дней, автоочистка при 80% диска

## 🛠️ Обслуживание

### Проверка статуса
```bash
# Аудио пайплайн
systemctl status respeaker-loopback.service

# Docker контейнер
docker ps

# Процессы пайплайна (должно быть 4)
ps aux | grep -E "arecord|log_mmse|sox|aplay" | grep -v grep
```

### Просмотр логов
```bash
# Systemd сервис
journalctl -fu respeaker-loopback.service

# Docker контейнер
docker logs -f birdnet-go

# Ошибки пайплайна
tail -f /var/log/birdnet-pipeline/errors.log
```

### Перезапуск
```bash
# Аудио пайплайн
sudo systemctl restart respeaker-loopback.service

# BirdNET-Go
docker compose restart
```

## 📊 Производительность

- **CPU:** 20-30% (Raspberry Pi 4)
- **RAM:** 400-600 MB
- **Задержка обработки:** <500ms
- **Точность распознавания:** 85-95% (зависит от условий)

## 🤝 Вклад в проект

Приветствуются:
- Отчеты об ошибках
- Предложения улучшений
- Pull requests
- Документация

## 📝 Лицензия

MIT License - см. [LICENSE](LICENSE)

## 🙏 Благодарности

- [BirdNET-Go](https://github.com/tphakala/birdnet-go) - система распознавания птиц
- [Seeed Studio](https://www.seeedstudio.com/) - ReSpeaker микрофонная решетка
- Ephraim & Malah - алгоритм Log-MMSE

## 📧 Контакты

Вопросы и предложения: [Issues](https://github.com/Gfermoto/birdnet_odas/issues)

---

**Статья о проекте:** [article.md](article.md)
