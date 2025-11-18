#!/usr/bin/env python3
"""
Log-MMSE шумоподавление для записи птиц.

Реализация алгоритма Log-MMSE (Minimum Mean-Square Error Log-Spectral
Amplitude Estimator) по Ephraim & Malah (1985).

Алгоритм:
---------
1. Извлечение канала 0 из 6-канального interleaved потока
2. STFT с frame_size=1024, hop_size=512, Hann window
3. Оценка шума (адаптивная, первые 10 frames)
4. Вычисление a posteriori SNR: γ = |Y|² / λ
5. Вычисление a priori SNR (Decision-Directed): ξ = α×G²×γ_prev + (1-α)×max(γ-1,0)
6. Log-MMSE gain: G = (ξ/(1+ξ)) × exp(0.5 × E₁(ν)), где ν = (ξ/(1+ξ)) × γ
7. Применение gain: S_enhanced = G × Y
8. ISTFT и overlap-add восстановление

Форматы данных:
---------------
Вход:  S16_LE, 16kHz, 6 каналов (interleaved)
Выход: S16_LE, 16kHz, 1 канал (моно)

Параметры:
----------
FRAME_SIZE = 1024    # Размер FFT frame (оптимально для птиц 1-8 kHz)
HOP_SIZE = 512       # Шаг между frames (50% overlap)
ALPHA = 0.50         # Decision-Directed smoothing (минимальное подавление: шум слышен постоянно, фильтр почти не работает)
NOISE_FRAMES = 10    # Количество frames для оценки шума (быстрая адаптация к изменениям)

Использование:
-------------
# В pipeline:
arecord ... | python3 log_mmse_processor.py | sox ... | aplay ...

# Для файлов:
python3 log_mmse_processor.py < input.raw > output.raw

Зависимости:
-----------
- numpy
- scipy.fft (fft, ifft)
- scipy.special (exp1)
- scipy.signal.windows (hann)

Ссылки:
------
Ephraim, Y., & Malah, D. (1985). "Speech Enhancement Using a Minimum
Mean-Square Error Log-Spectral Amplitude Estimator". IEEE Transactions
on Acoustics, Speech, and Signal Processing, 33(2), 443-445.
"""

import sys
import numpy as np
from scipy.fft import fft, ifft
from scipy.special import exp1
from scipy.signal.windows import hann

# Параметры STFT
FRAME_SIZE = 1024  # Лучшее частотное разрешение для птиц (1-8 kHz)
HOP_SIZE = 512     # 50% overlap для плавного восстановления
FS = 16000         # Частота дискретизации
N_FFT = FRAME_SIZE

# Параметры Log-MMSE
ALPHA = 0.50       # Decision-Directed smoothing (минимальное подавление: шум слышен постоянно, фильтр почти не работает)
NOISE_FRAMES = 10  # Количество frames для начальной оценки шума (быстрая адаптация к изменениям)


def extract_channel_0(audio_6ch):
    """
    Извлекает канал 0 из 6-канального interleaved потока.

    Parameters:
    -----------
    audio_6ch : ndarray, shape (N*6,)
        6-канальный interleaved поток
        Формат: [ch0, ch1, ch2, ch3, ch4, ch5, ch0, ch1, ...]

    Returns:
    --------
    channel_0 : ndarray, shape (N,)
        Канал 0 (beamformed), каждый 6-й sample начиная с индекса 0

    Examples:
    --------
    >>> audio = np.array([0, 1, 2, 3, 4, 5, 0, 1, 2, 3, 4, 5])
    >>> extract_channel_0(audio)
    array([0, 0])  # Каждый 6-й элемент
    """
    return audio_6ch[0::6]


def log_mmse_gain(xi, gamma):
    """
    Вычисляет Log-MMSE gain function.

    Формула: G(ω) = (ξ / (1+ξ)) × exp(0.5 × E₁(ν))
    где ν = (ξ / (1+ξ)) × γ

    Parameters:
    -----------
    xi : ndarray, shape (N_FFT,)
        A priori SNR для каждой частоты

    gamma : ndarray, shape (N_FFT,)
        A posteriori SNR для каждой частоты

    Returns:
    --------
    G : ndarray, shape (N_FFT,)
        Gain mask в диапазоне [0, 1]

    Notes:
    -----
    - E₁(ν) - exponential integral первого порядка (scipy.special.exp1)
    - Численная стабильность: ν >= 1e-10
    - Gain ограничен к [0, 1] для предотвращения усиления шума
    """
    # ν = (ξ/(1+ξ)) × γ
    nu = (xi / (1 + xi)) * gamma
    nu = np.maximum(nu, 1e-10)  # Численная стабильность

    # Exponential integral E₁(ν)
    e1_nu = exp1(nu)

    # Log-MMSE gain
    G = (xi / (1 + xi)) * np.exp(0.5 * e1_nu)

    # Clip к [0, 1]
    G = np.clip(G, 0, 1)

    return G


def estimate_a_priori_snr_dd(gamma_post, prev_gain, prev_gamma_post,
                              alpha=ALPHA):
    """
    Оценивает A priori SNR методом Decision-Directed (Ephraim & Malah, 1985).

    Формула: ξ(k,n) = α × G²(k,n-1) × γ(k,n-1) + (1-α) × max(γ(k,n) - 1, 0)

    Parameters:
    -----------
    gamma_post : ndarray, shape (N_FFT,)
        A posteriori SNR текущего frame
    prev_gain : ndarray or None, shape (N_FFT,)
        Gain из предыдущего frame
    prev_gamma_post : ndarray or None, shape (N_FFT,)
        A posteriori SNR предыдущего frame
    alpha : float, default=0.95
        Smoothing factor (0.95 для нестационарного шума, 0.98 для стационарного)

    Returns:
    --------
    xi : ndarray, shape (N_FFT,)
        A priori SNR

    Notes:
    -----
    - Для первого frame используется maximum likelihood estimate
    - alpha=0.95 оптимален для нестационарного шума (ветер, дождь)
    - xi ограничен снизу 1e-10 для численной стабильности
    """
    # Maximum likelihood estimate
    xi_ml = np.maximum(gamma_post - 1, 0)

    if prev_gain is None or prev_gamma_post is None:
        # Первый frame
        xi = xi_ml
    else:
        # Decision-directed формула:
        # ξ = α × |G(k,n-1) × Y(k,n-1)|² / λ(k) + (1-α) × max(γ-1, 0)
        # |G(k,n-1) × Y(k,n-1)|² / λ(k) = G²(k,n-1) × γ(k,n-1)
        xi_prev_term = alpha * (prev_gain ** 2) * prev_gamma_post
        xi = xi_prev_term + (1 - alpha) * xi_ml

    # Ограничить снизу
    xi = np.maximum(xi, 1e-10)

    return xi


def log_mmse_filter_stream():
    """
    Потоковая обработка Log-MMSE шумоподавления.

    Реализует полный pipeline обработки:
    1. Чтение 6-канального interleaved потока из stdin
    2. Извлечение канала 0 (beamformed)
    3. STFT анализ
    4. Log-MMSE шумоподавление
    5. ISTFT синтез с overlap-add
    6. Вывод моно потока в stdout

    Форматы данных:
    ---------------
    Вход:  S16_LE, 16kHz, 6 каналов (interleaved)
    Выход: S16_LE, 16kHz, 1 канал (моно)

    Алгоритм обработки:
    -------------------
    1. Буферизация входных данных (HOP_SIZE * 6 samples)
    2. Для каждого frame (FRAME_SIZE samples):
       a. Извлечение канала 0
       b. Применение Hann window
       c. FFT
       d. Оценка шума (первые NOISE_FRAMES frames)
       e. Вычисление a posteriori SNR
       f. Вычисление a priori SNR (Decision-Directed)
       g. Вычисление Log-MMSE gain
       h. Применение gain к спектру
       i. IFFT
       j. Overlap-add восстановление
       k. Нормализация и вывод HOP_SIZE samples

    Overlap-Add:
    -----------
    - 50% overlap (HOP_SIZE = FRAME_SIZE / 2)
    - Нормализация: norm[i] = window²[i] + window²[i - HOP_SIZE]
    - Вывод: output_buffer[:HOP_SIZE] / norm[HOP_SIZE:FRAME_SIZE]

    Обработка ошибок:
    ----------------
    - KeyboardInterrupt: нормальное завершение
    - BrokenPipeError: нормальное завершение (закрыт stdout)
    - Другие исключения: вывод в stderr и exit(1)

    Производительность:
    ------------------
    - Латентность: ~30-50 мс (зависит от FRAME_SIZE)
    - CPU: умеренная нагрузка (оптимизировано для NanoPi M4B)
    - Память: минимальная (буферы фиксированного размера)
    """
    # Буфер для накопления входных данных (6 каналов)
    input_buffer = np.array([], dtype=np.int16)

    # Буфер для overlap-add восстановления (моно)
    # Размер FRAME_SIZE для накопления полного frame
    output_buffer = np.zeros(FRAME_SIZE, dtype=np.float32)

    # Переменные для Log-MMSE
    noise_psd = None
    prev_gain = None
    prev_gamma_post = None
    frame_count = 0

    # Hann window
    window = hann(FRAME_SIZE)
    window_squared = window ** 2

    # Нормализация для overlap-add (50% overlap)
    # Каждая точка участвует в 2 frames: текущем и предыдущем
    norm = np.zeros(FRAME_SIZE, dtype=np.float32)
    for i in range(FRAME_SIZE):
        # Вклад текущего frame
        norm[i] = window_squared[i]
        # Вклад предыдущего frame (overlap)
        if i >= HOP_SIZE:
            norm[i] += window_squared[i - HOP_SIZE]
    norm = np.maximum(norm, 1e-10)

    try:
        while True:
            # Читать данные из stdin (буфер размером HOP_SIZE * 6 каналов)
            chunk_size = HOP_SIZE * 6 * 2  # 2 bytes per sample
            chunk = sys.stdin.buffer.read(chunk_size)

            if not chunk:
                break

            # Преобразовать в numpy array
            audio_chunk = np.frombuffer(chunk, dtype=np.int16)

            # Добавить в буфер
            input_buffer = np.concatenate([input_buffer, audio_chunk])

            # Обрабатывать пока в буфере достаточно данных для одного frame
            while len(input_buffer) >= FRAME_SIZE * 6:
                # Извлечь один frame (6 каналов)
                frame_6ch = input_buffer[:FRAME_SIZE * 6]
                input_buffer = input_buffer[HOP_SIZE * 6:]  # Сдвиг на HOP_SIZE

                # Извлечь канал 0
                frame_ch0 = extract_channel_0(frame_6ch)

                # Преобразовать в float32 [-1, 1]
                frame_float = frame_ch0.astype(np.float32) / 32768.0

                # Применить window
                frame_windowed = frame_float * window

                # FFT
                Y = fft(frame_windowed, n=N_FFT)

                # Power Spectral Density
                Y_power = np.abs(Y) ** 2

                # Начальная оценка шума (первые NOISE_FRAMES frames)
                if noise_psd is None:
                    noise_psd = Y_power.copy()
                elif frame_count < NOISE_FRAMES * 2:
                    # Адаптивное обновление в начале
                    noise_psd = 0.98 * noise_psd + 0.02 * Y_power

                # A posteriori SNR
                gamma_post = Y_power / (noise_psd + 1e-10)

                # A priori SNR (Decision-Directed) - исправленная формула
                xi_priori = estimate_a_priori_snr_dd(
                    gamma_post, prev_gain, prev_gamma_post, ALPHA
                )

                # Log-MMSE gain
                G = log_mmse_gain(xi_priori, gamma_post)

                # Применить gain
                S_enhanced = G * Y

                # Сохранить для следующего frame
                prev_gain = G
                prev_gamma_post = gamma_post
                frame_count += 1

                # IFFT
                enhanced_frame = np.real(ifft(S_enhanced, n=N_FFT))

                # Применить window для overlap-add
                enhanced_windowed = enhanced_frame * window

                # Overlap-add: накопление в буфере
                # Первые HOP_SIZE элементов overlap-аются (складываются)
                output_buffer[:HOP_SIZE] += enhanced_windowed[:HOP_SIZE]
                # Остальные HOP_SIZE элементов - новые данные
                output_buffer[HOP_SIZE:] = enhanced_windowed[HOP_SIZE:]

                # Нормализовать и вывести первые HOP_SIZE элементов
                # Используем norm[HOP_SIZE:FRAME_SIZE], т.к. output_buffer[:HOP_SIZE]
                # после overlap-add содержит данные, соответствующие позициям
                # [HOP_SIZE:FRAME_SIZE] в полном frame
                output_normalized = output_buffer[:HOP_SIZE] / norm[HOP_SIZE:FRAME_SIZE]

                # Защита от clipping: мягкое ограничение (soft limiter)
                # tanh обеспечивает плавное ограничение без резких артефактов
                # 0.90 для большего запаса против перегрузок при сильном ветре
                output_normalized = np.tanh(output_normalized * 0.95)  # Мягкое ограничение для естественного звука

                # Преобразовать обратно в int16
                output_int16 = (output_normalized * 32768.0).astype(np.int16)

                # Записать в stdout
                sys.stdout.buffer.write(output_int16.tobytes())
                sys.stdout.buffer.flush()

                # Сдвинуть буфер: оставшиеся данные становятся началом следующего frame
                output_buffer[:FRAME_SIZE - HOP_SIZE] = output_buffer[HOP_SIZE:]
                output_buffer[FRAME_SIZE - HOP_SIZE:] = 0

        # Обработать остаток буфера (если есть)
        if len(input_buffer) > 0:
            # Дополнить нулями до FRAME_SIZE
            padding = np.zeros(FRAME_SIZE * 6 - len(input_buffer), dtype=np.int16)
            frame_6ch = np.concatenate([input_buffer, padding])

            # Извлечь канал 0
            frame_ch0 = extract_channel_0(frame_6ch)

            # Преобразовать в float32
            frame_float = frame_ch0.astype(np.float32) / 32768.0

            # Применить window
            frame_windowed = frame_float * window

            # FFT
            Y = fft(frame_windowed, n=N_FFT)

            # Power Spectral Density
            Y_power = np.abs(Y) ** 2

            # A posteriori SNR
            if noise_psd is not None:
                gamma_post = Y_power / (noise_psd + 1e-10)

                # A priori SNR
                xi_priori = estimate_a_priori_snr_dd(
                    gamma_post, prev_gain, prev_gamma_post, ALPHA
                )

                # Log-MMSE gain
                G = log_mmse_gain(xi_priori, gamma_post)

                # Применить gain
                S_enhanced = G * Y

                # IFFT
                enhanced_frame = np.real(ifft(S_enhanced, n=N_FFT))

                # Применить window
                enhanced_windowed = enhanced_frame * window

                # Overlap-add
                output_buffer[:HOP_SIZE] += enhanced_windowed[:HOP_SIZE]
                output_buffer[HOP_SIZE:] = enhanced_windowed[HOP_SIZE:]

                # Нормализация и вывод
                # Используем norm[HOP_SIZE:FRAME_SIZE] для правильной нормализации
                output_normalized = output_buffer[:HOP_SIZE] / norm[HOP_SIZE:FRAME_SIZE]

                # Защита от clipping: мягкое ограничение (soft limiter)
                # tanh обеспечивает плавное ограничение без резких артефактов
                # 0.90 для большего запаса против перегрузок при сильном ветре
                output_normalized = np.tanh(output_normalized * 0.95)  # Мягкое ограничение для естественного звука

                # Преобразовать обратно в int16
                output_int16 = (output_normalized * 32768.0).astype(np.int16)

                # Записать в stdout
                sys.stdout.buffer.write(output_int16.tobytes())
                sys.stdout.buffer.flush()

    except (KeyboardInterrupt, BrokenPipeError):
        # Нормальное завершение
        pass
    except Exception as e:
        print('Error: {}'.format(e), file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    log_mmse_filter_stream()
