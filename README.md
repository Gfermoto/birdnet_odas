# BirdNET-ODAS: Система автоматического распознавания птиц на NanoPi M4B

Автоматическая система мониторинга птиц на базе BirdNET-Go и ReSpeaker USB 4 Mic Array для полевых исследований.

## Онлайн-доступ к станции

- Станция на общей карте BirdWeather: [https://app.birdweather.com/stations/18409/](https://app.birdweather.com/stations/18409/)
- Интерфейс станции BirdNET-Go: [https://birdnet.eyera.info](https://birdnet.eyera.info)

## Описание

Система автоматического распознавания и мониторинга птиц в полевых условиях. Построена на базе:

- **NanoPi M4B** (ARM64, Ubuntu 24.04) — одноплатный компьютер для автономной работы
- **BirdNET-Go** — система распознавания птиц на основе машинного обучения
- **ReSpeaker USB 4 Mic Array** — многоканальный USB-микрофон с beamforming и DSP обработкой

### Возможности

- Автоматическое распознавание видов птиц в реальном времени
- Запись и сохранение аудио с обнаруженными птицами
- Web-интерфейс для мониторинга и управления
- Оптимизация для полевых условий (низкое энергопотребление, автономная работа)
- Настройка DSP для улучшения качества записи птиц
- Автоматический запуск при загрузке системы

### Изображения

Фотографии устройства, скриншоты дашборда и результаты обработки звука: [images/README.md](images/README.md)

В галерее представлены сравнения спектрограмм, демонстрирующие улучшение качества записи при использовании многоуровневой фильтрации (Log-MMSE + DSP) по сравнению с обычным микрофоном.

## Быстрый старт

### Автоматическая установка

```bash
git clone <repository-url>
cd birdnet_odas
sudo bash scripts/setup_nanopi.sh
```

Скрипт выполняет:
1. Проверку системы и установку зависимостей
2. Установку Docker с фиксами для NanoPi M4B
3. Установку и настройку BirdNET-Go
4. Настройку ReSpeaker USB (если подключен)
5. Оптимизацию системы для полевых условий

### Ручная установка

Подробные инструкции:
- [Установка BirdNET-Go](docs/birdnet_go_setup.md)
- [Настройка ReSpeaker USB](docs/respeaker_usb4mic_setup.md)

### Установка через Docker Compose

```bash
cp env.example .env
nano .env  # опционально
docker-compose up -d
docker-compose logs -f birdnet-go
```

Подробнее: [Docker Compose](docs/docker_compose_guide.md)

## Структура проекта

```
birdnet_odas/
├── README.md
├── docker-compose.yml
├── env.example
├── docs/
│   ├── README.md
│   ├── birdnet_go_setup.md
│   ├── respeaker_usb4mic_setup.md
│   ├── audio_pipeline.md
│   ├── docker_compose_guide.md
│   ├── troubleshooting.md
│   └── usb_isolator_power.md
├── images/
│   └── README.md
└── scripts/
    ├── README.md
    ├── setup_nanopi.sh
    ├── respeaker-tune.sh
    ├── respeaker_loopback.sh
    ├── log_mmse_processor.py
    ├── disable_led_ring.py
    ├── check_audio_devices.sh
    ├── check_gain.sh
    ├── diagnose_clicks.sh
    ├── optimize_performance.sh
    ├── collect_metrics.sh
    ├── install_metrics_service.sh
    ├── fix_birdnet_device.sh
    └── fix_network_dhcp.sh
```

## Требования

### Аппаратные

- NanoPi M4B (или совместимая ARM64 платформа)
- ReSpeaker USB 4 Mic Array (опционально, но рекомендуется)
- USB-изолятор B505S (рекомендуется для снижения электромагнитных помех и гальванической развязки)
- SD-карта минимум 32 GB (рекомендуется 64 GB+ для данных)
- Источник питания 5V/3A
- Сетевое подключение (Wi-Fi или Ethernet) для первоначальной настройки

### Программные

- Ubuntu 24.04 (или совместимая Linux система)
- Docker (устанавливается автоматически)
- Python 3.6+ (для управления ReSpeaker)
- ALSA (для работы с аудио)

### Конфигурация хранения

Система оптимизирована для продления срока службы SD карты:

- **SD карта:** Система (2GB) + данные BirdNET (остальное пространство)
- **eMMC:** Логи и временные файлы (защита SD от износа)
- **Docker:** Данные в `/data` на SD карте

## Документация

1. **[docs/birdnet_go_setup.md](docs/birdnet_go_setup.md)**
   - Установка BirdNET-Go
   - Фиксы для NanoPi M4B (iptables-legacy, fuse-overlayfs)
   - Настройка Web GUI
   - Устранение неполадок
   - Оптимизация для полевых условий

2. **[docs/respeaker_usb4mic_setup.md](docs/respeaker_usb4mic_setup.md)**
   - Прошивка 6-канальной firmware
   - Настройка DSP для записи птиц
   - Интеграция с BirdNET-Go
   - Автоматическое применение настроек при загрузке

3. **[docs/README.md](docs/README.md)**
   - Обзор документации
   - Быстрые команды для старта

## Использование

### Первый запуск

1. Установите систему (см. раздел "Быстрый старт")

2. Откройте Web GUI:
   ```
   http://IP_АДРЕС:8080
   ```
   Где `IP_АДРЕС` — IP-адрес вашего NanoPi M4B

3. Настройте параметры:
   - Location Settings: укажите координаты места установки
   - Audio Settings: выберите источник аудио (ReSpeaker или встроенный микрофон)
   - Detection Settings: установите порог уверенности (рекомендуется 0.7)

4. Проверьте работу:
   ```bash
   systemctl status birdnet-go
   docker logs -f birdnet-go
   ~/test_mic.sh
   ```

### Управление службой

```bash
sudo systemctl start birdnet-go
sudo systemctl stop birdnet-go
sudo systemctl restart birdnet-go
sudo systemctl status birdnet-go
sudo systemctl enable birdnet-go
```

### Доступ к результатам

```bash
docker exec -it birdnet-go ls -la /app/data/
docker cp birdnet-go:/app/data/ ./birdnet-results/
```

## Настройка

### Рекомендуемые настройки BirdNET-Go

#### Для полевых условий (экономия ресурсов)

- Confidence Threshold: 0.8 (меньше ложных срабатываний)
- Buffer Size: 2048 (стабильность)
- Save Audio: No (экономия места)
- Sample Rate: 48000 Hz
- Channels: 1 (Mono)

#### Для стационарной работы (максимум данных)

- Confidence Threshold: 0.6 (больше обнаружений)
- Buffer Size: 1024 (быстрота)
- Save Audio: Yes (полная запись)
- Save Spectrograms: Yes

### Настройка ReSpeaker для птиц

Оптимальные DSP параметры для полевых записей:

- HPF (High-Pass Filter): 180 Гц (отсечка ветра)
- Шумоподавление: Включено (стационарный + нестационарный)
- AGC (Auto Gain Control): Включено с ограничением усиления
- Beamforming: Включено (адаптивный)

Подробности: [respeaker_usb4mic_setup.md](docs/respeaker_usb4mic_setup.md)

## Устранение неполадок

### Docker не запускается

```bash
sudo journalctl -xeu docker.service --no-pager | tail -50
sudo apt install -y fuse-overlayfs iptables
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo systemctl restart docker
```

### Web GUI недоступен

```bash
ss -tulpn | grep -E ":8080|:8081"
docker ps | grep birdnet-go
docker restart birdnet-go
```

### Проблемы с аудио

```bash
arecord -l
arecord -D plughw:ArrayUAC10,0 -f S16_LE -r 48000 -c 1 -d 5 test.wav
aplay test.wav
```

### ReSpeaker не определяется

```bash
lsusb | grep -i seeed
# Переподключите USB кабель
groups | grep plugdev || sudo usermod -aG plugdev $USER
```

Подробные инструкции: [troubleshooting.md](docs/troubleshooting.md)

## Оптимизация для полевых условий

### Оптимизация производительности

Для максимальной производительности аудио пайплайна рекомендуется применить системные оптимизации:

```bash
sudo /usr/local/bin/optimize_performance.sh
```

**Что оптимизируется (только безопасные параметры):**
- I/O scheduler: `deadline` для всех дисков
- Лимиты файловых дескрипторов: 65536

**Отключено для безопасности:**
- CPU governor (может вызвать проблемы)
- vm.swappiness и vm.dirty_ratio (могут вызвать проблемы на медленных дисках)
- Сетевые параметры (вызывали проблемы с сетью)
- Параметры ядра для реального времени (блокировали загрузку)

**Важно:** После применения оптимизаций рекомендуется перезагрузить систему.

### Автообновление

Система автоматически обновляет BirdNET-Go через Watchtower:

```bash
# Проверка статуса
docker ps | grep watchtower
docker logs watchtower | tail -20

# Проверка обновлений раз в 24 часа автоматически
```

Подробнее: [troubleshooting.md](docs/troubleshooting.md#auto-update)

### Энергосбережение

```bash
sudo systemctl stop bluetooth
sudo systemctl disable bluetooth
sudo rfkill block bluetooth

echo 'ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="on"' \
  | sudo tee /etc/udev/rules.d/99-usb-autosuspend-off.rules
sudo udevadm control --reload-rules
```

### Настройка времени

```bash
sudo timedatectl set-timezone Europe/Moscow
sudo timedatectl set-ntp true
timedatectl status
```

### Очистка логов

```bash
sudo journalctl --vacuum-time=7d
```

## Мониторинг

### Web-интерфейс

После запуска система доступна по адресам:
- BirdNET-Go Web UI: `http://IP_АДРЕС:8080`
- API: `http://IP_АДРЕС:8081`

### Мониторинг ресурсов

```bash
docker stats
docker system df
docker logs -f birdnet-go
```

### Метрики производительности

Система автоматически собирает метрики производительности каждые 5 минут:

```bash
# Статистика пайплайна
cat /var/log/birdnet-pipeline/pipeline_stats.json

# Метрики производительности (по дням)
ls /var/log/birdnet-pipeline/metrics/
cat /var/log/birdnet-pipeline/metrics/$(date +%Y%m%d).json | tail -1

# Ошибки пайплайна
tail -f /var/log/birdnet-pipeline/errors.log

# Статус сбора метрик
systemctl status collect-metrics.timer
```

**Собираемые метрики:**
- CPU использование (общее и по процессам)
- Использование памяти
- Load average
- Статистика пайплайна (restarts, errors, uptime)

## Docker Compose

Для упрощения управления контейнером можно использовать Docker Compose.

### Быстрый старт

```bash
cp env.example .env
nano .env  # опционально
docker-compose up -d
docker-compose ps
docker-compose logs -f birdnet-go
```

### Управление

```bash
docker-compose up -d
docker-compose down
docker-compose restart
docker-compose pull && docker-compose up -d
docker-compose logs -f
docker-compose exec birdnet-go sh
```

### Преимущества

- Все настройки в одном файле (`docker-compose.yml`)
- Переменные окружения в `.env` файле
- Простое управление (up/down/restart)
- Легко версионировать конфигурацию
- Удобно для разработки и тестирования

**Примечание:** Docker Compose использует именованные volumes (`birdnet-go-config`, `birdnet-go-data`). Если у вас уже есть контейнер с хешированными volumes, см. инструкции по миграции в [docker_compose_guide.md](docs/docker_compose_guide.md).

Подробное руководство: [docs/docker_compose_guide.md](docs/docker_compose_guide.md)

## Обновление

### Обновление BirdNET-Go

#### Через Docker Compose

```bash
docker-compose pull
docker-compose up -d
```

#### Через команды Docker

```bash
curl -fsSL https://github.com/tphakala/birdnet-go/raw/main/install.sh -o install.sh
bash ./install.sh --update
```

### Обновление системы

```bash
sudo apt update && sudo apt upgrade -y
sudo reboot  # при необходимости
```

## Дополнительные ресурсы

### Официальная документация

- [BirdNET-Go GitHub](https://github.com/tphakala/birdnet-go)
- [BirdNET-Go Wiki](https://github.com/tphakala/birdnet-go/wiki)
- [BirdNET Cornell Lab](https://birdnet.cornell.edu/)
- [ReSpeaker USB 4 Mic Array](https://github.com/respeaker/usb_4_mic_array)

### Полезные ссылки

- [eBird Database](https://ebird.org/) — база данных птиц
- [Xeno-canto](https://xeno-canto.org/) — аудио библиотека птиц
- [Merlin Bird ID](https://merlin.allaboutbirds.org/) — мобильное приложение

## Вклад в проект

Если вы нашли ошибку или хотите улучшить проект:
1. Создайте issue с описанием проблемы или предложения
2. Или отправьте pull request с исправлениями

## Лицензия

Проект использует открытое программное обеспечение:
- BirdNET-Go: [MIT License](https://github.com/tphakala/birdnet-go)
- ReSpeaker: [MIT License](https://github.com/respeaker/usb_4_mic_array)

## Благодарности

- BirdNET Team (Cornell Lab of Ornithology) — за создание системы распознавания птиц
- tphakala — за разработку BirdNET-Go
- Seeed Studio — за ReSpeaker USB 4 Mic Array

## Контакты

По вопросам использования и поддержки обращайтесь через issues в репозитории.

## Автор

**Stanley Wilson**

Проект разработан для полевых исследований и мониторинга птиц в естественных условиях.

*Последнее обновление: Декабрь 2025*
