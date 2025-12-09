#!/bin/bash
# Настройка Log-MMSE аудио-пайплайна (универсальная)
set -euo pipefail

source "$(dirname "$0")/colors.sh"

print_step "Настройка Log-MMSE аудио-пайплайна"

# Проверка наличия микрофона по VID:PID
detect_respeaker() {
    lsusb | grep -Ei "2886:0018|2886:0001|2886:0003|seeed"
}

if ! detect_respeaker >/dev/null; then
    print_info "ReSpeaker USB не обнаружен (пропуск). Проверьте lsusb и arecord -l."
    exit 0
fi

# Настройка ALSA loopback
print_info "Настройка ALSA loopback..."
echo "snd-aloop" | sudo tee /etc/modules-load.d/snd-aloop.conf >/dev/null
echo "options snd-aloop id=ACapture index=2" | sudo tee /etc/modprobe.d/snd-aloop.conf >/dev/null
sudo modprobe snd-aloop

# Определение директории скриптов (находим корень проекта)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../scripts" && pwd)"

# Копирование скриптов
print_info "Копирование скриптов..."

# Log-MMSE процессор
if [[ -f "$SCRIPT_DIR/log_mmse_processor.py" ]]; then
    sudo cp "$SCRIPT_DIR/log_mmse_processor.py" /usr/local/bin/
    sudo chmod +x /usr/local/bin/log_mmse_processor.py
    print_success "Log-MMSE процессор установлен"
else
    print_error "log_mmse_processor.py не найден в $SCRIPT_DIR"
    exit 1
fi

# Скрипт отключения LED кольца
if [[ -f "$SCRIPT_DIR/disable_led_ring.py" ]]; then
    sudo cp "$SCRIPT_DIR/disable_led_ring.py" /usr/local/bin/
    sudo chmod +x /usr/local/bin/disable_led_ring.py
    print_success "Скрипт отключения LED установлен"
fi

# Скрипт настройки DSP
if [[ -f "$SCRIPT_DIR/respeaker-tune.sh" ]]; then
    sudo cp "$SCRIPT_DIR/respeaker-tune.sh" /usr/local/bin/
    sudo chmod +x /usr/local/bin/respeaker-tune.sh
    sudo mkdir -p /var/log
    print_success "Скрипт настройки DSP установлен"
    
    # Создание systemd сервиса
    sudo tee /etc/systemd/system/respeaker-tune.service >/dev/null <<'EOF'
[Unit]
Description=Apply ReSpeaker USB Mic DSP tuning at boot and on USB connect
After=sound.target multi-user.target sys-subsystem-usb-devices.target
Wants=sound.target

[Service]
Type=oneshot
User=root
ExecStart=/usr/local/bin/respeaker-tune.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable respeaker-tune.service
    print_success "Systemd сервис respeaker-tune.service создан"
fi

# Скрипт respeaker_loopback.sh
if [[ -f "$SCRIPT_DIR/respeaker_loopback.sh" ]]; then
    sudo cp "$SCRIPT_DIR/respeaker_loopback.sh" /usr/local/bin/
    sudo chmod +x /usr/local/bin/respeaker_loopback.sh
    print_success "Скрипт respeaker_loopback.sh установлен"
fi

# Создание systemd сервиса для аудио-пайплайна
sudo tee /etc/systemd/system/respeaker-loopback.service >/dev/null <<'EOF'
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

# Оптимизация производительности (без RT, безопасно)
Nice=-10
IOWeight=100
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable respeaker-loopback.service
print_success "Systemd сервис respeaker-loopback.service создан"
print_info "Запуск: sudo systemctl start respeaker-loopback.service"
