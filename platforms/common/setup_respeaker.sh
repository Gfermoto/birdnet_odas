#!/bin/bash
# Настройка ReSpeaker USB 4 Mic Array (универсальная)
set -euo pipefail

source "$(dirname "$0")/colors.sh"

print_step "Настройка ReSpeaker USB 4 Mic Array"

# Проверка наличия микрофона по VID/PID (Seeed 2886:0018 и варианты)
detect_respeaker() {
    lsusb | grep -Ei "2886:0018|2886:0001|2886:0003|seeed"
}

if ! detect_respeaker >/dev/null; then
    print_info "ReSpeaker USB не обнаружен (пропуск). Проверьте lsusb и arecord -l."
    exit 0
fi

print_info "Обнаружен ReSpeaker USB (VID/PID match)"

# Клонирование репозитория
cd "$HOME"
if [[ ! -d "usb_4_mic_array" ]]; then
    git clone https://github.com/respeaker/usb_4_mic_array.git
fi
cd usb_4_mic_array

# Фикс tuning.py для Python 3.10+
sed -i 's/response.tostring()/response.tobytes()/' tuning.py 2>/dev/null || true

# udev правила
sudo tee /etc/udev/rules.d/99-respeaker.rules >/dev/null <<'EOF'
# Права доступа к ReSpeaker USB
SUBSYSTEM=="usb", ATTR{idVendor}=="2886", MODE="0666", GROUP="plugdev"

# Отключить autosuspend для ReSpeaker
SUBSYSTEM=="usb", ATTR{idVendor}=="2886", ATTR{idProduct}=="0018", TEST=="power/control", ATTR{power/control}="on"
SUBSYSTEM=="usb", ATTR{idVendor}=="2886", ATTR{idProduct}=="0018", TEST=="power/autosuspend", ATTR{power/autosuspend}="-1"

# Автоматический запуск настройки DSP при подключении
SUBSYSTEM=="usb", ATTR{idVendor}=="2886", ACTION=="add", RUN+="/bin/systemctl start respeaker-tune.service"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger

USER_NAME=${SUDO_USER:-$USER}
sudo usermod -aG plugdev "$USER_NAME"

# Зависимости Python
sudo apt-get install -y python3-usb python3-click || python3 -m pip install --break-system-packages pyusb click

# Установка библиотеки pixel-ring
print_info "Установка библиотеки pixel-ring для управления LED..."
pip3 install pixel-ring 2>/dev/null || python3 -m pip install --break-system-packages pixel-ring || print_warning "Не удалось установить pixel-ring"

print_success "ReSpeaker настроен"
