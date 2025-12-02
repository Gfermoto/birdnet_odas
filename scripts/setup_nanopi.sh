#!/bin/bash
# NanoPi M4B + BirdNET-Go Auto Setup
# Версия: 1.0

set -euo pipefail

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_step() { echo -e "${GREEN}[*] $1${NC}"; }
print_info() { echo -e "${CYAN}[i] $1${NC}"; }
print_success() { echo -e "${GREEN}[+] $1${NC}"; }
print_error() { echo -e "${RED}[-] $1${NC}"; }
print_warning() { echo -e "${YELLOW}[!] $1${NC}"; }

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  NanoPi M4B + BirdNET-Go Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo

# 1. Проверка системы
print_step "1. Проверка системы"
if [[ $(uname -m) != "aarch64" ]]; then
    print_warning "Не ARM64 архитектура: $(uname -m)"
fi
print_info "ОС: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"
print_info "Ядро: $(uname -r)"

# 2. Установка базовых зависимостей
print_step "2. Установка базовых пакетов"
sudo apt-get update
sudo apt-get install -y curl ca-certificates wget netcat-openbsd git alsa-utils sox python3 python3-pip python3-scipy python3-numpy libusb-1.0-0

# 3. Установка Docker с фиксами для M4B
print_step "3. Установка Docker"
if command -v docker &>/dev/null; then
    print_info "Docker уже установлен: $(docker --version)"
else
    curl -fsSL https://get.docker.com | sh
    sudo systemctl enable --now docker
    print_success "Docker установлен"
fi

# Фиксы для NanoPi M4B
print_info "Применение фиксов для NanoPi M4B..."
sudo apt install -y fuse-overlayfs iptables

# iptables-legacy
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy 2>/dev/null || \
  sudo update-alternatives --install /usr/sbin/iptables iptables /usr/sbin/iptables-legacy 10
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy 2>/dev/null || \
  sudo update-alternatives --install /usr/sbin/ip6tables ip6tables /usr/sbin/ip6tables-legacy 10

# Docker daemon.json
sudo mkdir -p /etc/docker
cat <<'DOCKERJSON' | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {"max-size": "10m", "max-file": "3"},
  "storage-driver": "fuse-overlayfs"
}
DOCKERJSON

sudo systemctl daemon-reload
sudo systemctl enable --now containerd
sudo systemctl restart docker

print_info "Проверка Docker..."
if sudo docker run --rm alpine echo ok; then
    print_success "Docker работает"
else
    print_error "Docker не работает! Проверьте: sudo journalctl -xeu docker.service"
    exit 1
fi

# Группа docker
USER_NAME=${SUDO_USER:-$USER}
sudo usermod -aG docker "$USER_NAME"
print_info "Пользователь $USER_NAME добавлен в группу docker (нужен релогин)"

# 4. Установка BirdNET-Go
print_step "4. Установка BirdNET-Go"
cd "$HOME"
curl -fsSL https://github.com/tphakala/birdnet-go/raw/main/install.sh -o install.sh
bash ./install.sh

print_info "Проверка BirdNET-Go..."
sleep 2
if systemctl is-active --quiet birdnet-go 2>/dev/null; then
    print_success "BirdNET-Go запущен"
else
    print_warning "BirdNET-Go не активен. Проверьте: systemctl status birdnet-go"
fi

# 5. Настройка USB-микрофона (опционально)
print_step "5. Настройка USB-микрофона (ReSpeaker)"
if lsusb | grep -qi "seeed"; then
    print_info "Обнаружен ReSpeaker USB"
    
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
SUBSYSTEM=="usb", ATTR{idVendor}=="2886", MODE="0666", GROUP="plugdev"
EOF
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    sudo usermod -aG plugdev "$USER_NAME"
    
    # Зависимости Python
    sudo apt-get install -y python3-usb python3-click || python3 -m pip install --break-system-packages pyusb click
    
    # Установка библиотеки для управления LED кольцом
    print_info "Установка библиотеки pixel-ring для управления LED..."
    pip3 install pixel-ring 2>/dev/null || python3 -m pip install --break-system-packages pixel-ring || print_warning "Не удалось установить pixel-ring (можно установить позже: pip3 install pixel-ring)"
    
    print_success "ReSpeaker готов к настройке DSP (см. respeaker_usb4mic_setup.md)"
    
    # Настройка Log-MMSE пайплайна
    print_info "Настройка Log-MMSE пайплайна..."
    
    # Зависимости для Log-MMSE уже установлены в шаге 2
    
    # Настройка ALSA loopback
    echo "snd-aloop" | sudo tee /etc/modules-load.d/snd-aloop.conf >/dev/null
    echo "options snd-aloop id=ACapture index=2" | sudo tee /etc/modprobe.d/snd-aloop.conf >/dev/null
    sudo modprobe snd-aloop
    
    # Копирование скриптов
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Log-MMSE процессор
    if [[ -f "$SCRIPT_DIR/log_mmse_processor.py" ]]; then
        sudo cp "$SCRIPT_DIR/log_mmse_processor.py" /usr/local/bin/
        sudo chmod +x /usr/local/bin/log_mmse_processor.py
        print_success "Log-MMSE процессор установлен"
    else
        print_warning "log_mmse_processor.py не найден в $SCRIPT_DIR"
        print_info "Скопируйте его вручную: cp scripts/log_mmse_processor.py /usr/local/bin/"
    fi
    
    # Скрипт отключения LED кольца
    if [[ -f "$SCRIPT_DIR/disable_led_ring.py" ]]; then
        sudo cp "$SCRIPT_DIR/disable_led_ring.py" /usr/local/bin/
        sudo chmod +x /usr/local/bin/disable_led_ring.py
        print_success "Скрипт отключения LED кольца установлен"
    else
        print_warning "disable_led_ring.py не найден в $SCRIPT_DIR"
    fi
    
    # Скрипт настройки DSP
    if [[ -f "$SCRIPT_DIR/respeaker-tune.sh" ]]; then
        sudo cp "$SCRIPT_DIR/respeaker-tune.sh" /usr/local/bin/
        sudo chmod +x /usr/local/bin/respeaker-tune.sh
        print_success "Скрипт настройки DSP установлен"
        
        # Создание systemd сервиса для автоматической настройки DSP при загрузке
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
        sudo systemctl daemon-reload
        sudo systemctl enable respeaker-tune.service
        print_success "Systemd сервис respeaker-tune.service создан и включен"
    else
        print_warning "respeaker-tune.sh не найден в $SCRIPT_DIR"
    fi
    
    # Создание скрипта respeaker_loopback.sh
    if [[ -f "$SCRIPT_DIR/respeaker_loopback.sh" ]]; then
        sudo cp "$SCRIPT_DIR/respeaker_loopback.sh" /usr/local/bin/
        sudo chmod +x /usr/local/bin/respeaker_loopback.sh
        print_success "Скрипт respeaker_loopback.sh установлен"
    else
        print_warning "respeaker_loopback.sh не найден, создаю из шаблона..."
        sudo tee /usr/local/bin/respeaker_loopback.sh >/dev/null <<'EOF'
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
        sudo chmod +x /usr/local/bin/respeaker_loopback.sh
    fi
    
    # Создание systemd сервиса с оптимизацией производительности
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

# Оптимизация производительности
Nice=-10
CPUSchedulingPolicy=fifo
CPUSchedulingPriority=50
IOWeight=100
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable respeaker-loopback.service
    print_success "Systemd сервис respeaker-loopback.service создан и включен"
    print_info "Сервис будет запущен после перезагрузки или вручную: sudo systemctl start respeaker-loopback.service"
else
    print_info "ReSpeaker USB не обнаружен (пропуск)"
fi

# 6. Оптимизация для полевых условий
print_step "6. Оптимизация системы"

# Часовой пояс и NTP
print_info "Настройка времени..."
sudo timedatectl set-ntp true

# Отключение Bluetooth
print_info "Отключение Bluetooth..."
sudo systemctl stop bluetooth 2>/dev/null || true
sudo systemctl disable bluetooth 2>/dev/null || true
sudo rfkill block bluetooth 2>/dev/null || true

# USB autosuspend off
print_info "Отключение USB autosuspend..."
echo 'ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="on"' \
| sudo tee /etc/udev/rules.d/99-usb-autosuspend-off.rules
sudo udevadm control --reload-rules && sudo udevadm trigger

# 7. Создание утилит
print_step "7. Создание утилит"

# test_mic.sh
cat > "$HOME/test_mic.sh" <<'TESTMIC'
#!/bin/bash
# Тест USB-микрофона
MIC=$(arecord -l | awk '/ArrayUAC10/{print "hw:"$2",0"}' | tr -d ':' | head -1)
if [[ -z "$MIC" ]]; then
    echo "ReSpeaker не найден, используем устройство по умолчанию"
    MIC="plughw:0,0"
fi
echo "Запись 5с с $MIC..."
arecord -D "$MIC" -f S16_LE -r 48000 -c 1 -d 5 test_mic.wav
echo "Готово: test_mic.wav"
aplay test_mic.wav
TESTMIC
chmod +x "$HOME/test_mic.sh"

print_success "Установка завершена"
echo
echo -e "${GREEN}========================================${NC}"
echo -e "${CYAN}Следующие шаги:${NC}"
echo
echo "1. Перелогиньтесь для применения группы docker"
echo "2. Откройте Web GUI: http://$(hostname -I | awk '{print $1}'):8080"
echo "3. Настройте координаты и confidence в Settings"
if lsusb | grep -qi "seeed"; then
    echo "4. ReSpeaker обнаружен:"
    echo "   - Log-MMSE пайплайн настроен"
    echo "   - После перезагрузки выберите Loopback устройство в BirdNET-Go"
    echo "   - Проверка: systemctl status respeaker-loopback.service"
fi
echo "5. Проверка микрофона: ~/test_mic.sh"
echo "6. Управление:"
echo "   systemctl status birdnet-go"
echo "   systemctl status respeaker-loopback.service"
echo "   docker logs -f birdnet-go"
echo
echo -e "${GREEN}========================================${NC}"
