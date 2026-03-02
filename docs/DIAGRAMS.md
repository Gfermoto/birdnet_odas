# Диаграммы проекта

Профессиональные диаграммы для визуализации архитектуры и процессов системы BirdNET-ODAS.

---

## 1. Архитектура системы (общая)

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'fontSize':'15px', 'fontFamily':'system-ui, -apple-system, "Segoe UI", Roboto, sans-serif'}}}%%
graph TB
    subgraph HW["<b>⚡ АППАРАТНЫЙ СЛОЙ</b>"]
        A["<b>🎤 ReSpeaker USB 4 Mic Array</b><br/><small>4× MEMS микрофона<br/>USB Audio Class 1.0<br/>Beamforming · AGC · DSP</small>"]
        B["<b>🖥️ Одноплатный компьютер</b><br/><small>Raspberry Pi 4/5 · NanoPi M4B<br/>ARM64 · 4GB RAM · Docker</small>"]
    end
    
    subgraph SW["<b>🔧 ПРОГРАММНЫЙ СЛОЙ</b>"]
        C["<b>📊 ALSA + DSP</b><br/><small>HPF 180Hz · AGC<br/>Noise Reduction</small>"]
        D["<b>🔬 Log-MMSE Processor</b><br/><small>Python 3.8+<br/>MIN_GAIN: 0.15<br/>STFT 1024</small>"]
        E["<b>⚙️ SoX Resample</b><br/><small>16→48 kHz<br/>Gain +8dB<br/>HQ Algorithm</small>"]
        F["<b>🔄 ALSA Loopback</b><br/><small>Virtual Audio Device<br/>snd-aloop module</small>"]
        G["<b>🧠 BirdNET-Go</b><br/><small>Docker Container<br/>Neural Network<br/>6K+ Species</small>"]
    end
    
    subgraph OUT["<b>📤 ВЫХОДНОЙ СЛОЙ</b>"]
        H["<b>🌐 Веб-интерфейс</b><br/><small>:8080 · Dashboard</small>"]
        I["<b>📡 MQTT</b><br/><small>Home Assistant</small>"]
        J["<b>🌍 BirdWeather</b><br/><small>Публичная станция</small>"]
        K["<b>💾 SQLite DB</b><br/><small>История детекций</small>"]
    end
    
    A -->|"<small>USB Audio</small>"| B
    B -->|"<small>arecord 16kHz 6ch</small>"| C
    C -->|"<small>pipe</small>"| D
    D -->|"<small>16kHz mono</small>"| E
    E -->|"<small>48kHz mono</small>"| F
    F -->|"<small>hw:2,0,0</small>"| G
    G -.->|"<small>HTTP</small>"| H
    G -.->|"<small>publish</small>"| I
    G -.->|"<small>upload</small>"| J
    G -.->|"<small>write</small>"| K
    
    classDef hardware fill:#FF6B6B,stroke:#C92A2A,stroke-width:3px,color:#fff,rx:10,ry:10
    classDef dsp fill:#4ECDC4,stroke:#2A9D8F,stroke-width:3px,color:#000,rx:10,ry:10
    classDef core fill:#FFE66D,stroke:#F4A261,stroke-width:4px,color:#000,rx:10,ry:10
    classDef ai fill:#95E1D3,stroke:#38A169,stroke-width:4px,color:#000,rx:10,ry:10
    classDef output fill:#A8DADC,stroke:#457B9D,stroke-width:2px,color:#000,rx:10,ry:10
    
    class A,B hardware
    class C,E,F dsp
    class D core
    class G ai
    class H,I,J,K output
```

---

## 2. Аудио пайплайн (детальный)

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'fontSize':'14px', 'fontFamily':'system-ui, -apple-system, "Segoe UI", Roboto, sans-serif'}}}%%
flowchart LR
    subgraph IN["<b>📥 INPUT</b>"]
        direction TB
        A["<b>🎤 ReSpeaker USB</b><br/><small>16 kHz<br/>6 channels<br/>interleaved</small>"]
    end
    
    subgraph PROC["<b>⚙️ PROCESSING PIPELINE</b>"]
        direction TB
        B["<b>1️⃣ arecord</b><br/><small>Audio Capture<br/>buffer: 32768</small>"]
        C["<b>2️⃣ Log-MMSE</b><br/><small>Noise Reduction<br/>STFT 1024<br/>MIN_GAIN: 0.15</small>"]
        D["<b>3️⃣ SoX</b><br/><small>Resample 48kHz<br/>Gain: +8dB<br/>Quality: VHQ</small>"]
        E["<b>4️⃣ aplay</b><br/><small>Loopback Write<br/>hw:2,1,0</small>"]
    end
    
    subgraph LOOP["<b>🔄 VIRTUAL</b>"]
        direction TB
        F["<b>🔁 ALSA Loopback</b><br/><small>snd-aloop<br/>48 kHz · mono</small>"]
    end
    
    subgraph AI["<b>🧠 RECOGNITION</b>"]
        direction TB
        G["<b>🤖 BirdNET-Go</b><br/><small>Docker<br/>Threshold: 0.7<br/>Overlap: 1.5s</small>"]
    end
    
    subgraph OUTDATA["<b>📤 OUTPUT</b>"]
        direction TB
        H["<b>📊 Детекции</b><br/><small>+ clips<br/>+ spectrograms</small>"]
    end
    
    A ==>|"<small>pipe</small>"| B
    B ==>|"<small>stdout</small>"| C
    C ==>|"<small>stdout</small>"| D
    D ==>|"<small>stdout</small>"| E
    E ==>|"<small>write</small>"| F
    F ==>|"<small>hw:2,0,0</small>"| G
    G ==>|"<small>save</small>"| H
    
    classDef input fill:#667EEA,stroke:#5A67D8,stroke-width:3px,color:#fff,rx:12,ry:12
    classDef capture fill:#48BB78,stroke:#38A169,stroke-width:3px,color:#fff,rx:12,ry:12
    classDef core fill:#F6AD55,stroke:#DD6B20,stroke-width:4px,color:#000,rx:12,ry:12
    classDef convert fill:#FC8181,stroke:#E53E3E,stroke-width:3px,color:#fff,rx:12,ry:12
    classDef virtual fill:#4FD1C5,stroke:#319795,stroke-width:3px,color:#000,rx:12,ry:12
    classDef ai fill:#9F7AEA,stroke:#805AD5,stroke-width:4px,color:#fff,rx:12,ry:12
    classDef output fill:#68D391,stroke:#48BB78,stroke-width:3px,color:#000,rx:12,ry:12
    
    class A input
    class B capture
    class C core
    class D convert
    class E capture
    class F virtual
    class G ai
    class H output
```

---

## 3. Log-MMSE алгоритм

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'fontSize':'14px', 'fontFamily':'system-ui, -apple-system, "Segoe UI", Roboto, sans-serif'}}}%%
flowchart TD
    START["<b>▶️ Входной аудиосигнал</b><br/><small>16 kHz · mono</small>"]
    STFT["<b>📊 STFT</b><br/><small>Hann Window<br/>Frame: 1024<br/>Hop: 512</small>"]
    CHECK{{"<b>⚡ Обучение?</b><br/><small>Первые 15 кадров</small>"}}
    NOISE["<b>🔍 Оценка шума</b><br/><small>λ(ω) = mean(|Y(ω,t)|²)</small>"]
    SNR["<b>📈 SNR расчет</b><br/><small>γ = |Y|² / λ<br/>ξ = α×G²×γ + (1-α)×max(γ-1,0)</small>"]
    GAIN["<b>🎯 Log-MMSE Gain</b><br/><small>G = (ξ/(1+ξ)) × exp(0.5×E₁(ν))</small>"]
    APPLY["<b>✨ Применение</b><br/><small>Ŷ = G × Y</small>"]
    LIMIT["<b>🛡️ Soft Limiter</b><br/><small>tanh(x × 0.95)</small>"]
    ISTFT["<b>🔄 ISTFT</b><br/><small>Overlap-add<br/>Нормализация</small>"]
    END["<b>✅ Выходной сигнал</b><br/><small>16 kHz · mono</small>"]
    
    START ==> STFT
    STFT ==> CHECK
    CHECK ==>|"<small>ДА</small>"| NOISE
    CHECK ==>|"<small>НЕТ</small>"| SNR
    NOISE ==> SNR
    SNR ==> GAIN
    GAIN ==> APPLY
    APPLY ==> LIMIT
    LIMIT ==> ISTFT
    ISTFT ==> END
    
    classDef start fill:#667EEA,stroke:#5A67D8,stroke-width:3px,color:#fff,rx:12,ry:12
    classDef process fill:#48BB78,stroke:#38A169,stroke-width:3px,color:#fff,rx:12,ry:12
    classDef decision fill:#F6AD55,stroke:#DD6B20,stroke-width:3px,color:#000,rx:12,ry:12
    classDef core fill:#FC8181,stroke:#E53E3E,stroke-width:4px,color:#fff,rx:12,ry:12
    classDef protect fill:#9F7AEA,stroke:#805AD5,stroke-width:3px,color:#fff,rx:12,ry:12
    classDef end fill:#68D391,stroke:#48BB78,stroke-width:3px,color:#000,rx:12,ry:12
    
    class START start
    class STFT,NOISE,SNR,APPLY,ISTFT process
    class CHECK decision
    class GAIN core
    class LIMIT protect
    class END end
```

---

## 4. Процесс установки

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'fontSize':'13px', 'fontFamily':'system-ui, -apple-system, "Segoe UI", Roboto, sans-serif'}}}%%
flowchart TD
    START(["<b>🚀 НАЧАЛО</b>"])
    CLONE["<b>📦 Клонирование</b><br/><small>git clone repo</small>"]
    CHOICE{{"<b>🖥️ Платформа?</b>"}}
    RPI["<b>🍓 Raspberry Pi</b><br/><small>cd platforms/raspberry-pi</small>"]
    NANO["<b>🔷 NanoPi M4B</b><br/><small>cd platforms/nanopi-m4b</small>"]
    SETUP["<b>⚙️ Запуск setup.sh</b><br/><small>sudo bash setup.sh</small>"]
    DEPS["<b>📥 Установка зависимостей</b><br/><small>Docker · Python · SoX · ALSA</small>"]
    CHECK{{"<b>🎤 ReSpeaker?</b>"}}
    RESP["<b>🔧 Настройка ReSpeaker</b><br/><small>DSP · Tuning · udev</small>"]
    SKIP["<b>⏭️ Пропуск</b>"]
    PIPE["<b>🔊 Аудио пайплайн</b><br/><small>Log-MMSE · SoX · Loopback</small>"]
    SRVS["<b>🔄 Systemd сервисы</b><br/><small>respeaker-tune<br/>respeaker-loopback</small>"]
    DOCKER["<b>🐳 BirdNET-Go Docker</b><br/><small>docker-compose up -d</small>"]
    OPT["<b>🎯 Оптимизация</b><br/><small>Permissions · USB · Timezone</small>"]
    RELOG{{"<b>🔄 Перелогин</b>"}}
    VERIFY["<b>✅ Проверка</b><br/><small>docker ps<br/>systemctl status</small>"]
    WORKS{{"<b>💚 Работает?</b>"}}
    SUCCESS(["<b>🎉 ГОТОВО!</b><br/><small>http://IP:8080</small>"])
    TROUBLE["<b>⚠️ Troubleshooting</b><br/><small>Логи · Диагностика</small>"]
    
    START ==> CLONE
    CLONE ==> CHOICE
    CHOICE ==>|"<small>RPI</small>"| RPI
    CHOICE ==>|"<small>Nano</small>"| NANO
    RPI ==> SETUP
    NANO ==> SETUP
    SETUP ==> DEPS
    DEPS ==> CHECK
    CHECK ==>|"<small>ДА</small>"| RESP
    CHECK ==>|"<small>НЕТ</small>"| SKIP
    RESP ==> PIPE
    SKIP ==> PIPE
    PIPE ==> SRVS
    SRVS ==> DOCKER
    DOCKER ==> OPT
    OPT ==> RELOG
    RELOG ==> VERIFY
    VERIFY ==> WORKS
    WORKS ==>|"<small>ДА</small>"| SUCCESS
    WORKS ==>|"<small>НЕТ</small>"| TROUBLE
    TROUBLE ==> VERIFY
    
    classDef start fill:#667EEA,stroke:#5A67D8,stroke-width:4px,color:#fff,rx:15,ry:15
    classDef action fill:#48BB78,stroke:#38A169,stroke-width:3px,color:#fff,rx:10,ry:10
    classDef decision fill:#F6AD55,stroke:#DD6B20,stroke-width:3px,color:#000,rx:10,ry:10
    classDef important fill:#FC8181,stroke:#E53E3E,stroke-width:3px,color:#fff,rx:10,ry:10
    classDef success fill:#68D391,stroke:#48BB78,stroke-width:4px,color:#000,rx:15,ry:15
    classDef trouble fill:#FBD38D,stroke:#D69E2E,stroke-width:3px,color:#000,rx:10,ry:10
    
    class START,SUCCESS start
    class CLONE,DEPS,PIPE,SRVS,OPT,VERIFY action
    class CHOICE,CHECK,RELOG,WORKS decision
    class RPI,NANO,RESP,SETUP,DOCKER important
    class SKIP,TROUBLE trouble
```

---

## 5. Архитектура микросервисов

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'fontSize':'13px', 'fontFamily':'system-ui, -apple-system, "Segoe UI", Roboto, sans-serif'}}}%%
graph TB
    subgraph EXT["<b>🌐 ВНЕШНИЕ СЕРВИСЫ</b>"]
        BW["<b>🌍 BirdWeather</b><br/><small>Публичная<br/>станция</small>"]
        MQTT["<b>📡 MQTT</b><br/><small>Home<br/>Assistant</small>"]
        NTP["<b>🕐 NTP</b><br/><small>Время</small>"]
    end
    
    subgraph HOST["<b>💻 ХОСТ-СИСТЕМА</b>"]
        subgraph SRV["<b>🔄 Systemd</b>"]
            S1["<b>🔧 respeaker-tune</b><br/><small>DSP config</small>"]
            S2["<b>🔊 respeaker-loopback</b><br/><small>Audio pipeline</small>"]
            S3["<b>💚 healthcheck</b><br/><small>Monitoring</small>"]
        end
        
        subgraph ALSA["<b>🔊 ALSA Layer</b>"]
            AL1["<b>hw:ArrayUAC10,0</b><br/><small>ReSpeaker Input</small>"]
            AL2["<b>hw:2,0,0</b><br/><small>Loop Output</small>"]
            AL3["<b>hw:2,1,0</b><br/><small>Loop Input</small>"]
        end
        
        subgraph DCK["<b>🐳 Docker</b>"]
            BN["<b>🧠 BirdNET-Go</b><br/><small>Container<br/>network: host</small>"]
            WT["<b>🔄 Watchtower</b><br/><small>Auto-update</small>"]
        end
    end
    
    subgraph STORE["<b>💾 ХРАНИЛИЩЕ</b>"]
        DB[("<b>🗄️ SQLite DB</b><br/><small>Детекции</small>")]
        CLIPS["<b>🎵 Clips</b><br/><small>.wav files</small>"]
        SPEC["<b>📊 Spectrograms</b><br/><small>.png files</small>"]
    end
    
    S1 -->|"<small>USB ctl</small>"| AL1
    AL1 -->|"<small>arecord</small>"| S2
    S2 -->|"<small>aplay</small>"| AL3
    AL2 -.->|"<small>read</small>"| BN
    BN ==> DB
    BN ==> CLIPS
    BN ==> SPEC
    BN ==>|"<small>upload</small>"| BW
    BN ==>|"<small>publish</small>"| MQTT
    S3 -.->|"<small>check</small>"| S2
    WT -.->|"<small>watch</small>"| BN
    NTP -.->|"<small>sync</small>"| HOST
    
    classDef external fill:#667EEA,stroke:#5A67D8,stroke-width:3px,color:#fff,rx:10,ry:10
    classDef service fill:#48BB78,stroke:#38A169,stroke-width:3px,color:#fff,rx:10,ry:10
    classDef alsa fill:#F6AD55,stroke:#DD6B20,stroke-width:2px,color:#000,rx:10,ry:10
    classDef docker fill:#4FD1C5,stroke:#319795,stroke-width:3px,color:#000,rx:10,ry:10
    classDef core fill:#FC8181,stroke:#E53E3E,stroke-width:4px,color:#fff,rx:10,ry:10
    classDef storage fill:#A8DADC,stroke:#457B9D,stroke-width:2px,color:#000,rx:10,ry:10
    
    class BW,MQTT,NTP external
    class S1,S3 service
    class S2 core
    class AL1,AL2,AL3 alsa
    class BN core
    class WT docker
    class DB,CLIPS,SPEC storage
```

---

## Использование

Эти диаграммы используются в следующих документах:

- **README.md** - упрощенная архитектура (диаграмма из README)
- **article.md** - общая архитектура и детальный пайплайн (диаграммы 1 и 2)
- **docs/audio_pipeline.md** - детальный пайплайн и Log-MMSE (диаграммы 2 и 3)
- **docs/INSTALLATION.md** - процесс установки (диаграмма 4)
- **docs/CONFIGURATION.md** - архитектура микросервисов (диаграмма 5)
