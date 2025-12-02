<!-- markdownlint-disable MD022 MD031 MD032 MD036 MD024 -->
# ReSpeaker USB 4 Mic Array Setup Guide

## Подключение, прошивка и настройка для полевых записей птиц

**Цель**: Настройка ReSpeaker USB 4 Mic Array для качественной записи птиц  
**Прошивка**: 6-канальная прошивка для beamforming и raw данных  
**Оптимизация**: DSP настройки для полевых условий

---

## Требования

### Аппаратные требования

- **ReSpeaker USB 4 Mic Array** (UAC1.0)
- **USB-изолятор B505S** (рекомендуется для снижения электромагнитных помех и гальванической развязки)
- **Компьютер** с USB портом (Linux/Windows/macOS)
- **Python 3.6+** для управления DSP параметрами
- **ALSA** (Linux) или **Core Audio** (macOS) для записи

**Примечание:** USB-изолятор B505S имеет ограничение по току 250 мА. LED кольцо ReSpeaker автоматически отключается для снижения энергопотребления. 

**Важно:** ReSpeaker USB 4 Mic Array может потреблять 200-350 мА при активной работе. С отключенным LED кольцом потребление снижается до ~150-250 мА, что должно быть достаточно для работы через B505S. Если возникают проблемы с питанием (периодические отключения, искажения), см. [usb_isolator_power.md](usb_isolator_power.md).

### Поддерживаемые платформы

- **Linux**: Ubuntu 18.04+, Debian 10+, Raspberry Pi OS, NanoPI M4B
- **Windows**: Windows 10+ с драйверами Zadig
- **macOS**: macOS 10.14+ (нативная поддержка)

---

## Быстрая установка

### 1. Зависимости

#### Linux (Ubuntu/Debian/Raspberry Pi OS)

```bash
sudo apt update
sudo apt install -y python3 python3-pip libusb-1.0-0 git alsa-utils sox

# Установка pyusb и click (Ubuntu 24.04+)
sudo apt-get install -y python3-usb python3-click || python3 -m pip install --break-system-packages pyusb click
```

#### Windows

1. Установите Python 3.6+ с [python.org](https://python.org)
2. Установите драйверы через [Zadig](https://zadig.akeo.ie/):
   - Выберите `SEEED DFU` и `SEEED Control`
   - Установите `libusb-win32` (НЕ WinUSB)
3. Установите зависимости:

```cmd
pip install pyusb click
```

#### macOS

```bash
brew install python3 libusb
pip3 install pyusb click
```

### 2. Клонирование репозитория

```bash
git clone https://github.com/respeaker/usb_4_mic_array.git
cd usb_4_mic_array
```

---

## Прошивка устройства

### Прошивка 6-канальной прошивки (рекомендуется)

```bash
# Прошивка (требует sudo на Linux)
sudo python3 dfu.py --download 6_channels_firmware.bin
```

**После прошивки:**

- Вытащите и вставьте USB кабель
- Устройство будет видно как `ArrayUAC10` в ALSA

### Проверка прошивки

```bash
# Linux: проверка ALSA устройств
arecord -l
# Должно показать: card X: ArrayUAC10 [ReSpeaker 4 Mic Array (UAC1.0)]

# Тест записи 6 каналов (16 kHz - нативная частота)
arecord -D hw:ArrayUAC10,0 -f S16_LE -r 16000 -c 6 -d 5 test_6ch.wav
```

---

## DSP настройка для полевых записей

### Исправление tuning.py для Python 3.10+

```bash
# Исправить ошибку tostring() -> tobytes()
sed -i 's/response.tostring()/response.tobytes()/' tuning.py
```

### Настройка прав доступа (Linux)

```bash
# Разрешить доступ без sudo
sudo tee /etc/udev/rules.d/99-respeaker.rules >/dev/null <<'EOF'
SUBSYSTEM=="usb", ATTR{idVendor}=="2886", MODE="0666", GROUP="plugdev"
EOF
sudo udevadm control --reload-rules
sudo udevadm trigger
sudo usermod -aG plugdev $USER
# Перелогиньтесь или выполните: newgrp plugdev
```

### Оптимальные настройки для птиц (оптимизировано по спектру тишины)

```bash
# Высокочастотный срез: 180 Гц (максимальное значение для подавления низкочастотного шума)
python3 tuning.py HPFONOFF 3

# Адаптивный бимформер включен
python3 tuning.py FREEZEONOFF 0

# Эхоподавление выключено (в поле не нужно)
python3 tuning.py ECHOONOFF 0
python3 tuning.py AECONOFF 0
python3 tuning.py AECFREEZEONOFF 0
python3 tuning.py NLAEC_MODE 0

# Шумоподавление: стационарный + нестационарный + транзиенты
python3 tuning.py STATNOISEONOFF 1
python3 tuning.py NONSTATNOISEONOFF 1
python3 tuning.py TRANSIENTONOFF 1

# Параметры шумоподавления (оптимизировано для ветрового шума)
python3 tuning.py GAMMA_NS_SR 2.5  # Усилено для стационарного шума
python3 tuning.py GAMMA_NN_SR 1.1  # Не изменяется (firmware limitation)
python3 tuning.py MIN_NS_SR 0.1    # Более глубокое подавление стационарного шума
python3 tuning.py MIN_NN_SR 0.1    # Более глубокое подавление нестационарного шума (ветер)

# AGC: включить с умеренным усилением (шум был из-за ресемплинга, а не усиления)
python3 tuning.py AGCONOFF 1
python3 tuning.py AGCMAXGAIN 6.0
python3 tuning.py AGCDESIREDLEVEL 0.005
python3 tuning.py AGCTIME 0.1  # Минимальное значение для быстрой реакции на изменения в пении птиц

# VAD: отключить (не нужен для птиц - записываем все звуки, не только "активность")
# GAMMAVAD_SR = 1000 означает очень высокий порог, фактически отключает VAD
# VAD предназначен для человеческой речи и может пропустить пение птиц
python3 tuning.py GAMMAVAD_SR 1000
```

**Изменения на основе анализа спектра (включая ветровой шум):**
- `HPFONOFF`: остаётся **3** (180 Гц - максимальное значение, лучшее подавление низкочастотного шума)
- `GAMMA_NS_SR`: 1.0 → **2.5** - усиленное шумоподавление для стационарного шума (диапазон: 0.0-3.0)
- `GAMMA_NN_SR`: **1.1** - не изменяется (ограничение firmware, диапазон: 0.0-3.0)
- `MIN_NS_SR`: 0.2 → **0.1** - более глубокое подавление стационарного шума (меньше = больше подавление)
- `MIN_NN_SR`: 0.3 → **0.1** - более глубокое подавление нестационарного шума (ветер) (меньше = больше подавление)
- `AGCMAXGAIN`: default 30dB → **6.0 dB** - консервативное усиление для улучшения чувствительности без усиления шума (диапазон: 0-60 dB)
- `AGCDESIREDLEVEL`: **0.005** - стандартное значение -23dBov, оптимально для полевых записей
- `AGCTIME`: **0.1 сек** (firmware преобразует в ~0.85 сек) - быстрое время реакции для записи птиц с резкими изменениями громкости (диапазон: 0.1-1.0 сек)

**Обоснование настроек AGC для записи птиц:**

1. **AGCMAXGAIN = 6.0 dB**: Консервативное усиление, достаточное для улучшения чувствительности к тихим звукам, но не настолько высокое, чтобы усиливать фоновый шум. После установки ветрозащиты можно увеличить до 8-10 dB.

2. **AGCDESIREDLEVEL = 0.005 (-23 dBov)**: Стандартное значение, обеспечивающее хороший баланс между громкостью и качеством. Не требует изменения.

3. **AGCTIME = 0.1 сек (реально ~0.85 сек)**: 
   - Птицы поют с быстрыми изменениями громкости (от тихого щебетания до громких трелей)
   - Медленная реакция AGC (>1 сек) может пропустить начало песни или не успеть за быстрыми изменениями
   - Firmware ReSpeaker использует внутреннее преобразование, поэтому заданное значение 0.1 сек преобразуется в ~0.85 сек, что является оптимальным компромиссом между быстрой реакцией и стабильностью
   - Значение 0.85 сек достаточно быстрое для записи птиц, но не настолько быстрое, чтобы вызывать "дыхание" или артефакты при обработке

**Важно**: Если после применения настроек AGCTIME показывает значение, отличающееся от ожидаемого (~0.85 сек), это нормально - firmware использует внутренние алгоритмы преобразования для обеспечения стабильности работы.

### Автоматическое применение настроек при загрузке

```bash
# Создать скрипт настройки
sudo tee /usr/local/bin/respeaker-tune.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -e
cd /root/usb_4_mic_array || exit 0
python3 tuning.py HPFONOFF 3
python3 tuning.py FREEZEONOFF 0
python3 tuning.py ECHOONOFF 0
python3 tuning.py AECONOFF 0
python3 tuning.py AECFREEZEONOFF 0
python3 tuning.py NLAEC_MODE 0
python3 tuning.py STATNOISEONOFF 1
python3 tuning.py NONSTATNOISEONOFF 1
python3 tuning.py TRANSIENTONOFF 1
python3 tuning.py GAMMA_NS_SR 2.5
python3 tuning.py GAMMA_NN_SR 1.1
python3 tuning.py MIN_NS_SR 0.1
python3 tuning.py MIN_NN_SR 0.1
python3 tuning.py AGCONOFF 1
python3 tuning.py AGCMAXGAIN 6.0
python3 tuning.py AGCDESIREDLEVEL 0.005
python3 tuning.py AGCTIME 0.1  # Минимальное значение для быстрой реакции на изменения в пении птиц
python3 tuning.py GAMMAVAD_SR 1000
EOF

sudo chmod +x /usr/local/bin/respeaker-tune.sh

# Создать systemd сервис
sudo tee /etc/systemd/system/respeaker-tune.service >/dev/null <<'EOF'
[Unit]
Description=Apply ReSpeaker USB Mic DSP tuning at boot
After=sound.target multi-user.target
Wants=sound.target

[Service]
Type=oneshot
User=root
ExecStart=/usr/local/bin/respeaker-tune.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable --now respeaker-tune.service
```

---

## Запись аудио

### Каналы устройства (6-канальная прошивка)

- **Канал 0**: Beamformed/ASR (обработанный, готовый для BirdNET-Go)
- **Каналы 1-4**: Raw данные с 4 микрофонов
- **Канал 5**: Playback (если есть)

### Запись beamformed канала (рекомендуется для BirdNET-Go)

#### Вариант 1: Прямая запись через ALSA (проще)

```bash
# Моно 48 kHz с авто-ресемплингом
arecord -D plughw:ArrayUAC10,0 -f S16_LE -r 48000 -c 1 -d 10 test_mono_48k.wav

# Поток в BirdNET-Go
arecord -D plughw:ArrayUAC10,0 -f S16_LE -r 48000 -c 1 -t raw \
| BirdNET-Go --format raw --sample-rate 48000 --channels 1 --bits 16
```

#### Вариант 2: Через SoX (контролируемый ресемплинг)

```bash
# 16 kHz → 48 kHz через SoX
arecord -D hw:ArrayUAC10,0 -f S16_LE -r 16000 -c 1 -t raw \
| sox -t raw -r 16000 -e signed -b 16 -c 1 - -t raw -r 48000 - \
| BirdNET-Go --format raw --sample-rate 48000 --channels 1 --bits 16
```

#### Вариант 3: ALSA PCM для канала 0 (если нужен явный контроль)

```bash
# Создать ALSA конфиг для канала 0
sudo tee /etc/asound.conf >/dev/null <<'EOF'
pcm.respeaker_ch0 {
  type route
  slave { pcm "hw:ArrayUAC10,0" channels 6 }
  ttable.0.0 1
}
pcm.birdnet_ch0 {
  type plug
  slave { pcm "respeaker_ch0" }
}
EOF

# Использование
arecord -D birdnet_ch0 -f S16_LE -r 48000 -c 1 -d 10 test_birdnet_ch0.wav
```

### Запись всех каналов (для анализа)

```bash
# 6 каналов, 16 kHz (нативная частота)
arecord -D hw:ArrayUAC10,0 -f S16_LE -r 16000 -c 6 -d 10 test_all_channels.wav

# Прослушивание отдельных каналов
aplay -D plughw:ArrayUAC10,0 -f S16_LE -r 16000 -c 1 test_all_channels.wav
```

---

## Интеграция с BirdNET-Go

### Рекомендуемое решение: SoX + ALSA Loopback (качественный ресемплинг)

Для оптимального качества звука рекомендуется использовать SoX для ресемплинга 16kHz → 48kHz через ALSA Loopback устройство.

#### Установка и настройка

```bash
# 1. Установить зависимости и настроить автозагрузку модуля loopback
apt-get install -y sox python3-scipy python3-numpy
echo "snd-aloop" > /etc/modules-load.d/snd-aloop.conf
# Переименование карты для различения устройств в BirdNET-Go
echo "options snd-aloop id=ACapture index=2" > /etc/modprobe.d/snd-aloop.conf
modprobe snd-aloop

# 2. Скопировать Log-MMSE процессор
cp scripts/log_mmse_processor.py /usr/local/bin/
chmod +x /usr/local/bin/log_mmse_processor.py

# 3. Создать скрипт для передачи аудио
cat > /usr/local/bin/respeaker_loopback.sh << 'EOF'
#!/bin/bash
# Скрипт для передачи ReSpeaker через Log-MMSE и SoX в ALSA loopback
while true; do
    arecord -D hw:ArrayUAC10,0 -f S16_LE -r 16000 -c 6 -t raw 2>/dev/null | \
    python3 /usr/local/bin/log_mmse_processor.py | \
    sox -t raw -r 16000 -c 1 -e signed-integer -b 16 -L - \
        -t raw -r 48000 -c 1 -e signed-integer -b 16 -L - gain -2.0 | \
    aplay -D hw:2,1,0 -f S16_LE -r 48000 -c 1 -t raw 2>/dev/null || sleep 1
done
EOF
chmod +x /usr/local/bin/respeaker_loopback.sh

# 4. Создать systemd сервис
cat > /etc/systemd/system/respeaker-loopback.service << 'EOF'
[Unit]
Description=ReSpeaker Audio Pipeline with Log-MMSE and SoX
After=sound.target
Wants=sound.target

[Service]
Type=simple
ExecStart=/usr/local/bin/respeaker_loopback.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# 5. ALSA конфигурация не требуется
# BirdNET-Go использует устройства напрямую через hw:Loopback,0,0
# Виртуальные PCM устройства не видны в списке BirdNET-Go

# 6. Запустить сервис
systemctl daemon-reload
systemctl enable respeaker-loopback.service
systemctl start respeaker-loopback.service

# 7. Проверка
systemctl status respeaker-loopback.service
arecord -D hw:2,0,0 -f S16_LE -r 48000 -c 1 -d 2 /tmp/test.wav

# 8. Перезагрузка (рекомендуется для применения всех изменений)
reboot
```

#### Настройка в BirdNET-Go Web GUI

1. Откройте BirdNET-Go Web GUI: `http://ВАШ_IP:8080`
2. Settings → Audio Settings → Audio Input Device
3. В списке будет 4 устройства (оба Loopback имеют одинаковые имена - это ограничение драйвера):
   - `realtek,rt5651-codec` (`:1,0`) - НЕ используйте
   - **`Loopback, Loopback PCM` (`:2,0`)** - **ИСПОЛЬЗУЙТЕ ЭТО** 
   - `Loopback, Loopback PCM` (`:2,1`) - НЕ используйте
   - `ReSpeaker 4 Mic Array (UAC1.0), USB Audio` (`:3,0`) - НЕ используйте
   
Оба Loopback устройства имеют одинаковые имена в списке (это ограничение драйвера ALSA и BirdNET-Go).
   
   **Как различить устройства в списке:**
   
   Порядок устройств в BirdNET-Go:
   1. `realtek,rt5651-codec` (`:1,0`) - НЕ используйте
   2. `Loopback, Loopback PCM` (`:2,1`) - НЕ используйте (второе устройство в списке)
   3. **`Loopback, Loopback PCM` (`:2,0`)** - **ИСПОЛЬЗУЙТЕ ЭТО** (третье устройство в списке)
   4. `ReSpeaker 4 Mic Array (UAC1.0), USB Audio` (`:3,0`) - НЕ используйте
   
   **ПРАВИЛО:** Всегда выбирайте **ТРЕТЬЕ устройство в списке** - это `Loopback, Loopback PCM` с индексом `:2,0`
   
После перезагрузки BirdNET-Go автоматически выбирает правильное устройство (`:2,0`).
   Если выбрано неправильное устройство - выберите **ТРЕТЬЕ устройство** в списке.
   
   **Важно:** 
   - Device 0 (`:2,0`) - это capture устройство, из которого BirdNET-Go читает данные
   - Device 1 (`:2,1`) - это playback устройство, куда скрипт `respeaker-loopback` пишет данные
   - BirdNET-Go должен читать из device 0 (`:2,0`), который отображается как **третье устройство** в списке
   - После перезагрузки BirdNET-Go автоматически выбирает правильное устройство (`:2,0`)

#### Log-MMSE шумоподавление

В текущей реализации pipeline включает Log-MMSE шумоподавление для улучшения качества записи птиц в условиях ветра и фонового шума.

**Подробное описание:** См. [audio_pipeline.md](audio_pipeline.md)

**Краткая информация:**
- Алгоритм: Log-MMSE (Ephraim & Malah, 1985)
- Скрипт: `/usr/local/bin/log_mmse_processor.py`
- Pipeline: ReSpeaker → Log-MMSE → SoX → Loopback → BirdNET-Go

#### Преимущества этого решения

- Качественный ресемплинг через SoX (лучше чем ALSA plug)
- Log-MMSE шумоподавление для полевых условий
- Извлечение только канала 0 (beamformed)
- Автоматический запуск при загрузке системы
- Стабильная работа в фоновом режиме

#### Перезагрузка устройства

После настройки рекомендуется перезагрузить устройство для:
- Автоматической загрузки модуля `snd-aloop`
- Применения ALSA конфигурации `/etc/asound.conf`
- Автоматического запуска сервиса `respeaker-loopback`

После перезагрузки проверьте:
```bash
# Проверка модуля
lsmod | grep snd_aloop

# Проверка сервиса
systemctl status respeaker-loopback.service

# Проверка устройства
arecord -D hw:LoopbackRespeak,0,0 -f S16_LE -r 48000 -c 1 -d 2 /tmp/test.wav
```

---

### Альтернативные варианты

#### Вариант 1: Прямое подключение через plughw (простой, но хуже качество)

1. Откройте BirdNET-Go Web GUI
2. Settings → Audio Input → выберите:
   - `plughw:ArrayUAC10,0` (автоматический ресемплинг через ALSA plug)

### Прямое подключение через Docker

```bash
# Если BirdNET-Go в Docker
arecord -D plughw:ArrayUAC10,0 -f S16_LE -r 48000 -c 1 -t raw \
| docker exec -i birdnet-go python app.py \
  --format raw --sample-rate 48000 --channels 1 --bits 16 \
  --lat ВАША_ШИРОТА --lon ВАША_ДОЛГОТА
```

---

## Устранение неполадок

### Проблема: "Device or resource busy"

```bash
# Освободить устройство
sudo systemctl stop birdnet-go 2>/dev/null || true
docker ps -q --filter name=birdnet | xargs -r docker stop
sudo pkill -9 arecord 2>/dev/null || true

# Проверка
arecord -D plughw:ArrayUAC10,0 -f S16_LE -r 48000 -c 1 -d 3 /dev/null
```

### Проблема: "Access denied" при настройке DSP

```bash
# Проверить права USB
lsusb | grep -i seeed
sudo usermod -aG plugdev $USER
newgrp plugdev

# Или использовать sudo
sudo python3 tuning.py AGCONOFF 1
```

### Проблема: Устройство не видно в ALSA

```bash
# Проверить подключение
lsusb | grep -i seeed
dmesg | tail -20

# Переподключить USB
# Вытащить и вставить кабель
```

### Проблема: Нет звука в записи

```bash
# Проверить уровни
arecord -D plughw:ArrayUAC10,0 -f S16_LE -r 48000 -c 1 -d 5 test.wav
aplay test.wav

# Проверить настройки DSP
python3 tuning.py AGCONOFF
python3 tuning.py AGCMAXGAIN
```

### Проблема: Фоновый шум в записи

Если характер шума указывает на физические источники помех, рекомендуется:

#### 1. Ветрозащита (меховой чехол)

**Проблема:** Низкочастотный шум от ветра, движения воздуха

**Решение:**
- Использовать меховой ветрозащитный чехол (deadcat/windshield) на микрофон
- Подходит для полевых условий, особенно на открытом воздухе
- Подавляет низкочастотные шумы от ветра и движения воздуха

**Где приобрести:**
- Специализированные магазины аудио оборудования
- Онлайн-магазины (AliExpress, Amazon)
- Универсальные ветрозащиты для USB-микрофонов

#### 2. Электромагнитные помехи от ЛЭП (высоковольтных линий)

**Проблема:** Низкочастотный гул от высоковольтных линий электропередачи (ЛЭП)

**Характеристики помех от ЛЭП:**
- **Частота сети:** 50 Гц (Россия) или 60 Гц
- **Гармоники:** 100 Гц, 150 Гц, 200 Гц, 250 Гц...
- **Типичные проявления:**
  - Низкочастотный гул (50/60 Гц и гармоники)
  - Пики в спектре на 50, 100, 150, 200 Гц
  - Высокий уровень шума в диапазоне 50-500 Гц
  - Наводки на кабели (особенно незаземленные)

**Пример из анализа спектра:**
- Пик на **93.8 Гц при -56.4 дБ** может быть связан с ЛЭП
- 93.8 Гц ≈ 2-я гармоника 50 Гц (100 Гц) с небольшим отклонением
- Высокий уровень шума до 200 Гц типичен для ЛЭП 110 кВ

**Защита от ЛЭП:**

1. **Заземление микрофона** (уже реализовано)
   - Критически важно для подавления наводок
   - Обеспечивает безопасность и снижает помехи

2. **Ферритовый фильтр на USB-кабель** (рекомендуется)
   - Установить ферритовый фильтр (ferrite bead/choke) на USB-кабель
   - Фильтр должен быть как можно ближе к микрофону
   - Подавляет высокочастотные электромагнитные помехи и гармоники
   - **Типы:** Защелкивающиеся (snap-on) или встроенные в кабель

3. **Экранированный USB-кабель** (рекомендуется)
   - Использовать качественный экранированный USB-кабель
   - Экранирование снижает наводки от электромагнитного поля ЛЭП

4. **Прокладка кабеля** (важно)
   - Избегать прокладки кабеля параллельно ЛЭП
   - Прокладывать кабель перпендикулярно к ЛЭП (если возможно)
   - Минимизировать длину кабеля

5. **Log-MMSE шумоподавление** (уже реализовано)
   - HPF на 180 Гц (микрофон) подавляет 50/60 Гц и первые гармоники
   - HPF на 300 Гц (BirdNET-Go) дополнительно подавляет гармоники до 300 Гц
   - Log-MMSE эффективно подавляет стационарный шум от ЛЭП
   - См. [audio_pipeline.md](audio_pipeline.md) для подробностей

**Где приобрести ферритовые фильтры:**
- Радиомагазины
- Онлайн-магазины (AliExpress, eBay)
- Искать "ferrite bead USB" или "ferrite choke USB"

#### 3. Ферритовый фильтр на кабель питания

**Проблема:** Электромагнитные помехи от блока питания, наводки по USB-кабелю

**Решение:**
- Установить ферритовый фильтр (ferrite bead/choke) на USB-кабель питания
- Фильтр должен быть как можно ближе к микрофону
- Подавляет высокочастотные электромагнитные помехи

**Типы ферритовых фильтров:**
- Защелкивающиеся (snap-on) - удобны для установки на существующий кабель
- Встроенные в кабель - более надежное решение

**Где приобрести:**
- Радиомагазины
- Онлайн-магазины (AliExpress, eBay)
- Искать "ferrite bead USB" или "ferrite choke USB"

#### 4. Дополнительные рекомендации

- Использовать качественный экранированный USB-кабель
- Избегать прокладки кабеля рядом с источниками помех (блоки питания, трансформаторы)
- Использовать отдельный USB-порт, не через USB-хаб
- Проверить заземление системы (критично для ЛЭП)

---

## Мониторинг и диагностика

### Проверка текущих настроек DSP

```bash
# Основные параметры
python3 tuning.py HPFONOFF
python3 tuning.py AGCONOFF
python3 tuning.py STATNOISEONOFF
python3 tuning.py NONSTATNOISEONOFF
python3 tuning.py GAMMAVAD_SR
```

### Тест качества записи

```bash
# Запись тестового файла
arecord -D plughw:ArrayUAC10,0 -f S16_LE -r 48000 -c 1 -d 30 field_test.wav

# Анализ спектра (если установлен sox)
sox field_test.wav -n spectrogram -o spectrogram.png
```

### Мониторинг в реальном времени

```bash
# Просмотр уровней
arecord -D plughw:ArrayUAC10,0 -f S16_LE -r 48000 -c 1 -t raw | od -A d -t d1 | head -20
```

---

## Управление LED кольцом

### Автоматическое отключение LED

LED кольцо автоматически отключается при загрузке системы через скрипт `respeaker-tune.sh`. Это делается для:
- **Снижения энергопотребления** (критично при использовании USB-изолятора B505S с ограниченным током 250 мА)
- **Уменьшения электромагнитных помех** от ШИМ-управления светодиодами, которые могут вызывать щелчки в аудио

### Установка библиотеки

Для работы скрипта отключения LED необходимо установить библиотеку:

```bash
pip3 install pixel-ring
```

### Базовые команды

```python
from pixel_ring import PixelRing
p = PixelRing()

# Выключить все LED
p.off()

# Установить цвет (R, G, B)
p.set_color(0, 255, 0)  # зелёный
p.set_color(255, 0, 0)  # красный
p.set_color(0, 0, 255)  # синий

# Анимации
p.think()
p.listen()
p.speak()
p.wait()
```

### Ручное управление

Если нужно включить LED кольцо обратно:

```bash
python3 -c "from pixel_ring import PixelRing; PixelRing().set_color(0, 255, 0)"
```

Или отключить вручную:

```bash
python3 /usr/local/bin/disable_led_ring.py
```

---

## Дополнительные ресурсы

### Официальная документация

- [ReSpeaker USB 4 Mic Array GitHub](https://github.com/respeaker/usb_4_mic_array)
- [ReSpeaker Pixel Ring](https://github.com/respeaker/pixel_ring)
- [Seeed Studio Product Page](https://www.seeedstudio.com/ReSpeaker-Mic-Array-v2.0-p-3053.html)

### Полезные ссылки

- [ALSA Configuration](https://alsa-project.org/wiki/Configuration)
- [SoX Documentation](http://sox.sourceforge.net/Docs/Documentation)
- [USB Audio Class Specification](https://www.usb.org/sites/default/files/documents/audio10.pdf)

---


