#!/bin/bash
# Raspberry Pi (CM4/Pi4/Pi5) + BirdNET-Go Setup
# Версия: 2.0 (multi-platform)

set -euo pipefail

# Определение директорий
PLATFORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$PLATFORM_DIR/../common"
PROJECT_ROOT="$(cd "$PLATFORM_DIR/../.." && pwd)"

# Загрузка конфигурации и функций
source "$PLATFORM_DIR/config.env"
source "$COMMON_DIR/colors.sh"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  $PLATFORM_NAME + BirdNET-Go Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo

# Проверка системы
print_step "1. Проверка системы"
if [[ $(uname -m) != "$PLATFORM_ARCH" ]]; then
    print_warning "Не $PLATFORM_ARCH архитектура: $(uname -m)"
fi
print_info "ОС: $(lsb_release -d 2>/dev/null | cut -f2 || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
print_info "Ядро: $(uname -r)"
print_info "Модель: $(cat /proc/device-tree/model 2>/dev/null || echo 'Unknown')"

# Установка базовых пакетов
print_step "2. Установка базовых пакетов"
sudo apt-get update
sudo apt-get install -y $BASE_PACKAGES

# Установка Docker
print_step "3. Установка Docker"
bash "$COMMON_DIR/install_docker.sh"

# Настройка Docker daemon (Raspberry Pi использует стандартный overlay2)
print_info "Настройка Docker daemon..."
sudo mkdir -p /etc/docker
cat <<'DOCKERJSON' | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {"max-size": "10m", "max-file": "3"},
  "storage-driver": "overlay2"
}
DOCKERJSON

sudo systemctl daemon-reload
sudo systemctl restart docker

print_info "Проверка Docker..."
if sudo docker run --rm alpine echo ok; then
    print_success "Docker работает"
else
    print_error "Docker не работает! Проверьте: sudo journalctl -xeu docker.service"
    exit 1
fi

# Установка BirdNET-Go
print_step "4. Установка BirdNET-Go"
bash "$COMMON_DIR/install_birdnet.sh"

# Настройка ReSpeaker (опционально)
print_step "5. Настройка USB-микрофона (ReSpeaker)"
if lsusb | grep -qi "seeed"; then
    bash "$COMMON_DIR/setup_respeaker.sh"
    
    # Настройка Log-MMSE пайплайна
    print_step "5.1. Настройка Log-MMSE аудио-пайплайна"
    bash "$COMMON_DIR/setup_audio_pipeline.sh"
else
    print_info "ReSpeaker USB не обнаружен (пропуск)"
    print_info "Подключите микрофон позже и запустите:"
    print_info "  bash $COMMON_DIR/setup_respeaker.sh"
    print_info "  bash $COMMON_DIR/setup_audio_pipeline.sh"
fi

# Оптимизация системы
print_step "6. Оптимизация системы"
bash "$COMMON_DIR/system_optimization.sh"

# Создание утилит
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

# Утилита настройки внешнего накопителя
print_info "Создание утилиты setup_storage.sh..."
cp "$COMMON_DIR/setup_external_storage.sh" "$HOME/setup_storage.sh"
chmod +x "$HOME/setup_storage.sh"

print_success "Установка завершена"
echo
echo -e "${GREEN}========================================${NC}"
echo -e "${CYAN}Следующие шаги:${NC}"
echo
echo "1. Перелогиньтесь для применения группы docker:"
echo "   exit"
echo "   ssh $(whoami)@$(hostname -I | awk '{print $1}')"
echo
echo "2. Откройте Web GUI: http://$(hostname -I | awk '{print $1}'):8080"
echo
echo "3. Настройте координаты и confidence в Settings"
echo
if lsusb | grep -qi "seeed"; then
    echo "4. ReSpeaker обнаружен:"
    echo "   - Log-MMSE пайплайн настроен"
    echo "   - После перезагрузки выберите Loopback устройство в BirdNET-Go"
    echo "   - Проверка: systemctl status respeaker-loopback.service"
    echo "   - Запуск: sudo systemctl start respeaker-loopback.service"
    echo
else
    echo "4. ReSpeaker не подключен:"
    echo "   - Подключите микрофон позже"
    echo "   - Запустите: bash $COMMON_DIR/setup_respeaker.sh"
    echo "   - Затем: bash $COMMON_DIR/setup_audio_pipeline.sh"
    echo
fi
echo "5. Настройка внешнего накопителя для данных:"
echo "   ~/setup_storage.sh"
echo
echo "6. Проверка микрофона: ~/test_mic.sh"
echo
echo "7. Управление:"
echo "   systemctl status birdnet-go"
echo "   systemctl status respeaker-loopback.service"
echo "   journalctl -fu birdnet-go"
echo
echo -e "${GREEN}========================================${NC}"
