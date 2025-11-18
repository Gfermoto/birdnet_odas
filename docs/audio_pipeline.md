# Аудио пайплайн: ReSpeaker → Log-MMSE → BirdNET-Go

## Обзор

Данный документ описывает полный аудио пайплайн от ReSpeaker USB 4 Mic Array до BirdNET-Go, включая Log-MMSE шумоподавление и ресемплинг.

---

## Архитектура пайплайна

### Полный pipeline

```
┌─────────────┐     ┌──────────────┐     ┌──────────┐     ┌─────────────┐     ┌──────────────┐
│ ReSpeaker   │────▶│ Log-MMSE      │────▶│ SoX       │────▶│ ALSA        │────▶│ BirdNET-Go   │
│ USB Mic     │     │ Processor     │     │ Resample  │     │ Loopback    │     │              │
│             │     │               │     │           │     │             │     │              │
│ 16kHz, 6ch  │     │ 16kHz, 1ch    │     │ 48kHz,1ch │     │ 48kHz, 1ch  │     │ 48kHz, 1ch   │
│ interleaved │     │ mono          │     │ mono      │     │             │     │              │
└─────────────┘     └──────────────┘     └──────────┘     └─────────────┘     └──────────────┘
     │                    │                    │                  │                    │
     │                    │                    │                  │                    │
  arecord            python3              sox              aplay              docker
                     log_mmse_processor   (resample)       (loopback)         birdnet-go
```

### Компоненты

1. **ReSpeaker USB 4 Mic Array**
   - Выход: 16kHz, 6 каналов (interleaved)
   - Канал 0: beamformed (готовый для обработки)
   - Каналы 1-4: raw данные с микрофонов
   - Канал 5: playback (если есть)

2. **Log-MMSE Processor** (`log_mmse_processor.py`)
   - Вход: 16kHz, 6 каналов (interleaved, S16_LE)
   - Выход: 16kHz, 1 канал (моно, S16_LE)
   - Функции: извлечение канала 0, шумоподавление

3. **SoX Resampler**
   - Вход: 16kHz, 1 канал (S16_LE)
   - Выход: 48kHz, 1 канал (S16_LE)
   - Функция: качественный ресемплинг для BirdNET-Go

4. **ALSA Loopback**
   - Device 1 (playback): запись от SoX
   - Device 0 (capture): чтение BirdNET-Go
   - Функция: виртуальное устройство для связи

5. **BirdNET-Go**
   - Вход: 48kHz, 1 канал (S16_LE)
   - Функция: распознавание птиц

---

## Реализация пайплайна

### Скрипт `respeaker_loopback.sh`

```bash
#!/bin/bash
# Скрипт для передачи ReSpeaker через Log-MMSE и SoX в ALSA loopback
while true; do
    arecord -D hw:ArrayUAC10,0 -f S16_LE -r 16000 -c 6 -t raw 2>/dev/null | \
    python3 /usr/local/bin/log_mmse_processor.py | \
    sox -t raw -r 16000 -c 1 -e signed-integer -b 16 -L - \
        -t raw -r 48000 -c 1 -e signed-integer -b 16 -L - | \
    aplay -D hw:2,1,0 -f S16_LE -r 48000 -c 1 -t raw 2>/dev/null || sleep 1
done
```

### Команды по этапам

1. **Запись с ReSpeaker:**
   ```bash
   arecord -D hw:ArrayUAC10,0 -f S16_LE -r 16000 -c 6 -t raw
   ```
   - `hw:ArrayUAC10,0` - прямое подключение к ReSpeaker
   - `-f S16_LE` - signed 16-bit little-endian
   - `-r 16000` - частота дискретизации 16kHz
   - `-c 6` - 6 каналов
   - `-t raw` - raw формат (без заголовка)

2. **Log-MMSE обработка:**
   ```bash
   python3 /usr/local/bin/log_mmse_processor.py
   ```
   - Читает из stdin: 16kHz, 6ch, S16_LE
   - Выдает в stdout: 16kHz, 1ch, S16_LE

3. **Ресемплинг SoX:**
   ```bash
   sox -t raw -r 16000 -c 1 -e signed-integer -b 16 -L - \
       -t raw -r 48000 -c 1 -e signed-integer -b 16 -L -
   ```
   - Вход: 16kHz, 1ch, S16_LE
   - Выход: 48kHz, 1ch, S16_LE
   - Качественный ресемплинг (лучше чем ALSA plug)

4. **Запись в ALSA Loopback:**
   ```bash
   aplay -D hw:2,1,0 -f S16_LE -r 48000 -c 1 -t raw
   ```
   - `hw:2,1,0` - loopback card 2, device 1 (playback), subdevice 0
   - Записывает в виртуальное устройство

5. **Чтение BirdNET-Go:**
   - Читает из `hw:2,0,0` (loopback card 2, device 0, capture)
   - Автоматически выбирается после перезагрузки

---

## Log-MMSE алгоритм шумоподавления

### Обзор

Log-MMSE (Minimum Mean-Square Error Log-Spectral Amplitude Estimator) - алгоритм шумоподавления, разработанный Ephraim & Malah (1985). Оптимизирован для нестационарного шума (ветер, дождь) и сохранения слабых сигналов (пение птиц).

### Математические основы

#### 1. STFT анализ

Преобразование сигнала в частотную область:

```
Y(ω,t) = FFT[x(t) × w(t)]
```

где:
- `x(t)` - входной сигнал (канал 0)
- `w(t)` - Hann window
- `Y(ω,t)` - комплексный спектр

**Параметры:**
- Frame size: 1024 samples (лучшее частотное разрешение для птиц)
- Hop size: 512 samples (50% overlap)
- Window: Hann window

#### 2. Оценка шума

Power Spectral Density (PSD) шума оценивается адаптивно:

```
λ(ω) = mean(|Y(ω,t)|²) для t ∈ [0, NOISE_FRAMES]
```

**Адаптивное обновление (первые 2×NOISE_FRAMES):**
```
λ(ω,t) = 0.98 × λ(ω,t-1) + 0.02 × |Y(ω,t)|²
```

#### 3. A Posteriori SNR

Отношение сигнал/шум после наблюдения:

```
γ(ω,t) = |Y(ω,t)|² / λ(ω)
```

#### 4. A Priori SNR (Decision-Directed)

Оценка отношения сигнал/шум до наблюдения:

```
ξ(ω,t) = α × G²(ω,t-1) × γ(ω,t-1) + (1-α) × max(γ(ω,t) - 1, 0)
```

где:
- `α = 0.95` - smoothing factor (для нестационарного шума)
- `G(ω,t-1)` - gain из предыдущего frame
- `γ(ω,t-1)` - a posteriori SNR предыдущего frame

#### 5. Log-MMSE Gain

Вычисление gain mask:

```
G(ω) = (ξ / (1+ξ)) × exp(0.5 × E₁(ν))
```

где:
- `ν = (ξ / (1+ξ)) × γ`
- `E₁(ν)` - exponential integral первого порядка

#### 6. Применение gain

```
S_enhanced(ω,t) = G(ω) × Y(ω,t)
```

#### 7. ISTFT и Overlap-Add

Восстановление сигнала во временной области:

```
s_enhanced(t) = IFFT[S_enhanced(ω,t)]
s_windowed(t) = s_enhanced(t) × w(t)
```

Overlap-add с нормализацией:
```
output(t) = Σ s_windowed(t) / norm(t)
```

где `norm(t)` учитывает overlap window².

### Параметры алгоритма

| Параметр | Значение | Обоснование |
|----------|---------|-------------|
| `FRAME_SIZE` | 1024 | Лучшее частотное разрешение для птиц (1-8 kHz) |
| `HOP_SIZE` | 512 | 50% overlap для плавного восстановления |
| `ALPHA` | 0.95 | Оптимально для нестационарного шума (ветер) |
| `NOISE_FRAMES` | 10 | Достаточно для начальной оценки шума |
| Частота обработки | 16kHz | Меньше данных, быстрее обработка |

### Преимущества Log-MMSE

1. **Подавление нестационарного шума**
   - Ветер (низкочастотный, нестационарный)
   - Дождь (широкополосный)
   - Фоновые звуки

2. **Сохранение слабых сигналов**
   - Пение птиц (1-8 kHz)
   - Слабые компоненты не подавляются

3. **Низкий musical noise**
   - Лучше чем Spectral Subtraction
   - Плавное восстановление сигнала

4. **Оптимизация для птиц**
   - Обработка на 16kHz (меньше данных)
   - Frame size 1024 (лучшее разрешение)
   - Alpha 0.95 (для нестационарного шума)

---

## Ресемплинг SoX

### Зачем нужен ресемплинг

BirdNET-Go требует входной сигнал на 48kHz, а ReSpeaker выдает 16kHz. Ресемплинг выполняется через SoX для обеспечения высокого качества.

### Параметры ресемплинга

```bash
sox -t raw -r 16000 -c 1 -e signed-integer -b 16 -L - \
    -t raw -r 48000 -c 1 -e signed-integer -b 16 -L -
```

- **Вход:** 16kHz, 1 канал, S16_LE
- **Выход:** 48kHz, 1 канал, S16_LE
- **Алгоритм:** Высококачественный ресемплинг SoX (лучше чем ALSA plug)

### Почему SoX, а не ALSA plug

- ✅ Лучшее качество ресемплинга
- ✅ Явный контроль параметров
- ✅ Меньше артефактов
- ✅ Оптимизирован для аудио обработки

---

## ALSA Loopback устройство

### Назначение

ALSA Loopback создает виртуальное аудио устройство для связи между скриптом обработки и BirdNET-Go.

### Структура устройства

```
Loopback Card 2 (index=2)
├── Device 0 (capture)  ← BirdNET-Go читает отсюда
└── Device 1 (playback) ← Скрипт пишет сюда
```

### Настройка

```bash
# Загрузка модуля
modprobe snd-aloop

# Автозагрузка
echo "snd-aloop" > /etc/modules-load.d/snd-aloop.conf

# Переименование для идентификации
echo "options snd-aloop id=ACapture index=2" > /etc/modprobe.d/snd-aloop.conf
```

### Использование в BirdNET-Go

В Web GUI выбирается устройство:
- **Третье устройство в списке** - `Loopback, Loopback PCM` (`:2,0`)
- Это device 0 (capture), из которого BirdNET-Go читает данные

**Важно:** После перезагрузки BirdNET-Go автоматически выбирает правильное устройство (`:2,0`).

---

## Производительность

### Латентность

- **Log-MMSE обработка:** ~30-50 мс (зависит от FRAME_SIZE)
- **Ресемплинг SoX:** ~10-20 мс
- **Общая латентность:** ~40-70 мс

### CPU нагрузка

- **Log-MMSE:** Умеренная (FFT/IFFT на 1024 точек)
- **SoX:** Низкая (качественный ресемплинг)
- **Общая нагрузка:** Приемлема для NanoPi M4B

### Память

- **Буферы фиксированного размера:**
  - Input buffer: ~6 KB (HOP_SIZE × 6 × 2 bytes)
  - Output buffer: ~4 KB (FRAME_SIZE × 4 bytes)
  - STFT буферы: ~8 KB
  - **Общая память:** < 20 KB

---

## Устранение неполадок

### Проблема: Нет звука в BirdNET-Go

**Проверка:**
```bash
# Проверка занятых устройств
/usr/local/bin/check_audio_devices.sh

# Проверка процесса
ps aux | grep log_mmse_processor
ps aux | grep sox
ps aux | grep aplay
```

**Решение:**
- Убедитесь, что выбран правильный loopback device (`:2,0` - третье в списке)
- Проверьте логи: `journalctl -u respeaker-loopback.service`

### Проблема: Артефакты в звуке

**Возможные причины:**
- Неправильная нормализация overlap-add
- Проблемы с ресемплингом
- Перегрузка CPU

**Решение:**
- Проверьте параметры STFT (FRAME_SIZE, HOP_SIZE)
- Убедитесь, что используется правильная нормализация
- Мониторинг CPU: `top` или `htop`

### Проблема: Высокая задержка

**Решение:**
- Уменьшить FRAME_SIZE (но ухудшит качество)
- Оптимизировать код (numba, Cython)
- Использовать более мощное устройство

---

## Оптимизация

### Текущие настройки

Оптимизированы для баланса качества и производительности на NanoPi M4B:

- **FRAME_SIZE = 1024** - оптимально для птиц
- **HOP_SIZE = 512** - 50% overlap (стандарт)
- **ALPHA = 0.95** - для нестационарного шума
- **Обработка на 16kHz** - меньше данных

### Возможные улучшения

1. **Использование numba:**
   ```python
   from numba import jit
   @jit(nopython=True)
   def log_mmse_gain(xi, gamma):
       # ...
   ```

2. **Оптимизация памяти:**
   - Pre-allocated буферы
   - Избежание копий (views вместо copies)

3. **Параллелизация:**
   - Обработка нескольких frames параллельно
   - Использование multiprocessing

---

## Ссылки

- Ephraim, Y., & Malah, D. (1985). "Speech Enhancement Using a Minimum Mean-Square Error Log-Spectral Amplitude Estimator". IEEE Transactions on Acoustics, Speech, and Signal Processing, 33(2), 443-445.
- SoX - Sound eXchange: http://sox.sourceforge.net/
- ALSA Loopback: https://www.alsa-project.org/wiki/Matrix:Module-aloop
- BirdNET-Go: https://github.com/tphakala/birdnet-go

---

## Связанные документы

- [respeaker_usb4mic_setup.md](respeaker_usb4mic_setup.md) - Настройка ReSpeaker USB Mic Array
- [birdnet_go_setup.md](birdnet_go_setup.md) - Установка и настройка BirdNET-Go

