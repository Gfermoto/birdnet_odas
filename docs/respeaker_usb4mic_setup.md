<!-- markdownlint-disable MD022 MD031 MD032 MD036 MD024 -->
# ReSpeaker USB 4 Mic Array Setup Guide

## Подключение, прошивка и настройка для полевых записей птиц

> 🎤 **Цель**: Настройка ReSpeaker USB 4 Mic Array для качественной записи птиц  
> 🔧 **Прошивка**: 6-канальная прошивка для beamforming и raw данных  
> 🐦 **Оптимизация**: DSP настройки для полевых условий

---

## 📋 Требования

### Аппаратные требования

- **ReSpeaker USB 4 Mic Array** (UAC1.0)
- **Компьютер** с USB портом (Linux/Windows/macOS)
- **Python 3.6+** для управления DSP параметрами
- **ALSA** (Linux) или **Core Audio** (macOS) для записи

### Поддерживаемые платформы

- **Linux**: Ubuntu 18.04+, Debian 10+, Raspberry Pi OS, NanoPI M4B
- **Windows**: Windows 10+ с драйверами Zadig
- **macOS**: macOS 10.14+ (нативная поддержка)

---

## 🚀 Быстрая установка

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

## 🔧 Прошивка устройства

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

## ⚙️ DSP настройка для полевых записей

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

### Оптимальные настройки для птиц

```bash
# Высокочастотный срез от ветра: 180 Гц
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

# Параметры шумоподавления (агрессивнее для птиц)
python3 tuning.py GAMMA_NS_SR 1.2
python3 tuning.py GAMMA_NN_SR 1.3
python3 tuning.py MIN_NS_SR 0.2
python3 tuning.py MIN_NN_SR 0.3

# AGC: включить, но ограничить усиление
python3 tuning.py AGCONOFF 1
python3 tuning.py AGCMAXGAIN 10.0
python3 tuning.py AGCDESIREDLEVEL 0.005
python3 tuning.py AGCTIME 0.3

# VAD: отключить (не нужен для птиц)
python3 tuning.py GAMMAVAD_SR 1000
```

### Автоматическое применение настроек при загрузке

```bash
# Создать скрипт настройки
sudo tee /usr/local/bin/respeaker-tune.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -e
cd /home/$SUDO_USER/usb_4_mic_array || exit 0
python3 tuning.py HPFONOFF 3
python3 tuning.py FREEZEONOFF 0
python3 tuning.py ECHOONOFF 0
python3 tuning.py AECONOFF 0
python3 tuning.py AECFREEZEONOFF 0
python3 tuning.py NLAEC_MODE 0
python3 tuning.py STATNOISEONOFF 1
python3 tuning.py NONSTATNOISEONOFF 1
python3 tuning.py TRANSIENTONOFF 1
python3 tuning.py GAMMA_NS_SR 1.2
python3 tuning.py GAMMA_NN_SR 1.3
python3 tuning.py MIN_NS_SR 0.2
python3 tuning.py MIN_NN_SR 0.3
python3 tuning.py AGCONOFF 1
python3 tuning.py AGCMAXGAIN 10.0
python3 tuning.py AGCDESIREDLEVEL 0.005
python3 tuning.py AGCTIME 0.3
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

## 🎵 Запись аудио

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

## 🔧 Интеграция с BirdNET-Go

### Настройка в Web GUI

1. Откройте BirdNET-Go Web GUI
2. Settings → Audio Input → выберите:
   - `plughw:ArrayUAC10,0` (простой вариант)
   - `birdnet_ch0` (если создали ALSA конфиг)

### Прямое подключение через Docker

```bash
# Если BirdNET-Go в Docker
arecord -D plughw:ArrayUAC10,0 -f S16_LE -r 48000 -c 1 -t raw \
| docker exec -i birdnet-go python app.py \
  --format raw --sample-rate 48000 --channels 1 --bits 16 \
  --lat ВАША_ШИРОТА --lon ВАША_ДОЛГОТА
```

---

## 🚨 Устранение неполадок

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

---

## 📊 Мониторинг и диагностика

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

## 🎨 Управление LED кольцом

### Установка библиотеки

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

---

## 📚 Дополнительные ресурсы

### Официальная документация

- [ReSpeaker USB 4 Mic Array GitHub](https://github.com/respeaker/usb_4_mic_array)
- [ReSpeaker Pixel Ring](https://github.com/respeaker/pixel_ring)
- [Seeed Studio Product Page](https://www.seeedstudio.com/ReSpeaker-Mic-Array-v2.0-p-3053.html)

### Полезные ссылки

- [ALSA Configuration](https://alsa-project.org/wiki/Configuration)
- [SoX Documentation](http://sox.sourceforge.net/Docs/Documentation)
- [USB Audio Class Specification](https://www.usb.org/sites/default/files/documents/audio10.pdf)

---

*Документ создан для проекта ODAS + ReSpeaker 6-Mic*  
*Последнее обновление: $(date +%Y-%m-%d)*

