# Диаграммы для статьи

## Архитектура системы (общая)

```mermaid
graph TB
    subgraph Hardware["🔧 Аппаратная часть"]
        A[ReSpeaker USB 4 Mic Array<br/>4 микрофона, USB Audio Class 1.0]
        B[Одноплатный компьютер<br/>Raspberry Pi 4/5 или NanoPi M4B<br/>4GB RAM, Docker]
    end
    
    subgraph Software["💻 Программная часть"]
        C[ALSA + DSP настройки<br/>HPF 180Hz, AGC, Шумоподавление]
        D[Log-MMSE Processor<br/>Python, MIN_GAIN=0.15]
        E[SoX Resample<br/>16kHz → 48kHz, gain +8dB]
        F[ALSA Loopback<br/>Виртуальное аудиоустройство]
        G[BirdNET-Go<br/>Docker, Neural Network]
    end
    
    subgraph Output["📊 Выходные данные"]
        H[Веб-интерфейс<br/>:8080]
        I[MQTT<br/>Home Assistant]
        J[BirdWeather<br/>Публичная станция]
        K[SQLite DB<br/>История детекций]
    end
    
    A -->|USB Audio| B
    B -->|arecord 16kHz 6ch| C
    C -->|pipe| D
    D -->|16kHz 1ch| E
    E -->|48kHz 1ch| F
    F -->|hw:2,0,0| G
    G --> H
    G --> I
    G --> J
    G --> K
    
    style A fill:#e1f5ff,stroke:#333,stroke-width:2px
    style B fill:#ffe1f5,stroke:#333,stroke-width:2px
    style D fill:#fff4e1,stroke:#333,stroke-width:3px
    style G fill:#f5e1ff,stroke:#333,stroke-width:3px
    style H fill:#e1ffe1,stroke:#333,stroke-width:2px
```

## Аудио пайплайн (детальный)

```mermaid
flowchart LR
    subgraph Input["📥 Вход"]
        A[ReSpeaker USB<br/>16 kHz<br/>6 каналов<br/>interleaved]
    end
    
    subgraph Processing["⚙️ Обработка"]
        B[arecord<br/>Захват аудио<br/>buffer: 32768]
        C[Log-MMSE<br/>Шумоподавление<br/>STFT 1024<br/>MIN_GAIN: 0.15]
        D[SoX<br/>Resample 48kHz<br/>Gain: +8dB<br/>Quality: very high]
        E[aplay<br/>Loopback write<br/>hw:2,1,0]
    end
    
    subgraph Loopback["🔄 Loopback"]
        F[ALSA Loopback<br/>snd-aloop<br/>48 kHz<br/>mono]
    end
    
    subgraph Recognition["🧠 Распознавание"]
        G[BirdNET-Go<br/>Docker<br/>Threshold: 0.7<br/>Overlap: 1.5s]
    end
    
    subgraph Output["📤 Выход"]
        H[Детекции<br/>+ аудиоклипы<br/>+ спектрограммы]
    end
    
    A -->|pipe| B
    B -->|stdout| C
    C -->|stdout| D
    D -->|stdout| E
    E -->|write| F
    F -->|hw:2,0,0| G
    G --> H
    
    style A fill:#e1f5ff,stroke:#333,stroke-width:2px
    style C fill:#fff4e1,stroke:#333,stroke-width:3px
    style D fill:#ffe1e1,stroke:#333,stroke-width:2px
    style F fill:#e1ffe1,stroke:#333,stroke-width:2px
    style G fill:#f5e1ff,stroke:#333,stroke-width:3px
    style H fill:#e1f5e1,stroke:#333,stroke-width:2px
```

## Log-MMSE алгоритм (упрощенно)

```mermaid
flowchart TD
    A[Входной аудиосигнал<br/>16 kHz, mono] --> B[STFT<br/>Окно Ханна<br/>Frame: 1024<br/>Hop: 512]
    B --> C{Обучение?<br/>Первые 15 кадров}
    C -->|Да| D[Оценка PSD шума<br/>λ&#40;ω&#41; = mean&#40;|Y&#40;ω,t&#41;|²&#41;]
    C -->|Нет| E[Вычисление SNR<br/>γ = |Y|² / λ<br/>ξ = α×G²×γ + &#40;1-α&#41;×max&#40;γ-1, 0&#41;]
    D --> E
    E --> F[Log-MMSE Gain<br/>G = &#40;ξ/&#40;1+ξ&#41;&#41; × exp&#40;0.5×E₁&#40;ν&#41;&#41;]
    F --> G[Применение усиления<br/>Ŷ = G × Y]
    G --> H[Soft Limiter<br/>tanh&#40;x × 0.95&#41;]
    H --> I[ISTFT<br/>Overlap-add<br/>Нормализация]
    I --> J[Выходной сигнал<br/>16 kHz, mono]
    
    style A fill:#e1f5ff,stroke:#333,stroke-width:2px
    style B fill:#ffe1f5,stroke:#333,stroke-width:2px
    style F fill:#fff4e1,stroke:#333,stroke-width:3px
    style H fill:#ffe1e1,stroke:#333,stroke-width:2px
    style J fill:#e1ffe1,stroke:#333,stroke-width:2px
```

## Процесс установки

```mermaid
flowchart TD
    Start[Начало] --> A[Клонирование<br/>git clone]
    A --> B{Выбор<br/>платформы}
    B -->|Raspberry Pi| C1[cd platforms/raspberry-pi]
    B -->|NanoPi M4B| C2[cd platforms/nanopi-m4b]
    C1 --> D[sudo bash setup.sh]
    C2 --> D
    
    D --> E[Установка Docker<br/>+ зависимостей]
    E --> F{ReSpeaker<br/>подключен?}
    F -->|Да| G[Настройка<br/>ReSpeaker]
    F -->|Нет| H[Пропуск]
    G --> I[Создание<br/>аудио пайплайна]
    H --> I
    
    I --> J[Настройка<br/>systemd сервисов]
    J --> K[Запуск<br/>BirdNET-Go<br/>Docker]
    K --> L[Оптимизация<br/>системы]
    L --> M{Перелогин}
    M --> N[Проверка<br/>docker ps]
    N --> O{Работает?}
    O -->|Да| P[✅ Готово!<br/>http://IP:8080]
    O -->|Нет| Q[Troubleshooting]
    Q --> N
    
    style Start fill:#e1f5ff,stroke:#333,stroke-width:2px
    style D fill:#fff4e1,stroke:#333,stroke-width:2px
    style G fill:#ffe1f5,stroke:#333,stroke-width:2px
    style K fill:#f5e1ff,stroke:#333,stroke-width:2px
    style P fill:#e1ffe1,stroke:#333,stroke-width:3px
    style Q fill:#ffe1e1,stroke:#333,stroke-width:2px
```

## Архитектура микросервисов

```mermaid
graph TB
    subgraph External["🌐 Внешние сервисы"]
        BW[BirdWeather<br/>Публичная станция]
        MQTT[MQTT Broker<br/>Home Assistant]
        NTP[NTP Server<br/>Синхронизация времени]
    end
    
    subgraph Host["💻 Хост-система"]
        subgraph Services["⚙️ Systemd Services"]
            S1[respeaker-tune<br/>DSP настройки]
            S2[respeaker-loopback<br/>Аудио пайплайн]
            S3[healthcheck.timer<br/>Мониторинг]
        end
        
        subgraph ALSA["🔊 ALSA"]
            AL1[hw:ArrayUAC10,0<br/>ReSpeaker input]
            AL2[hw:2,0,0<br/>Loopback output]
            AL3[hw:2,1,0<br/>Loopback input]
        end
        
        subgraph Docker["🐳 Docker"]
            BN[BirdNET-Go<br/>container<br/>network: host]
            WT[Watchtower<br/>Auto-update]
        end
    end
    
    subgraph Storage["💾 Хранилище"]
        DB[(SQLite DB<br/>Детекции)]
        CLIPS[Аудиоклипы<br/>.wav files]
        SPEC[Спектрограммы<br/>.png files]
    end
    
    S1 -->|USB control| AL1
    AL1 -->|arecord| S2
    S2 -->|aplay| AL3
    AL2 -.->|read| BN
    BN --> DB
    BN --> CLIPS
    BN --> SPEC
    BN -->|upload| BW
    BN -->|publish| MQTT
    S3 -.->|monitor| S2
    WT -.->|watch| BN
    NTP -.->|sync| Host
    
    style S2 fill:#fff4e1,stroke:#333,stroke-width:3px
    style BN fill:#f5e1ff,stroke:#333,stroke-width:3px
    style DB fill:#e1ffe1,stroke:#333,stroke-width:2px
```

Эти диаграммы можно использовать в:
- README.md (общая архитектура)
- article.md (все диаграммы)
- docs/audio_pipeline.md (детальный пайплайн)
- docs/INSTALLATION.md (процесс установки)
