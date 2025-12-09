#!/bin/bash
# Настройка внешнего USB накопителя для хранения данных BirdNET
set -euo pipefail

# Загрузка colors.sh (может быть в разных местах)
if [[ -f "$(dirname "$0")/colors.sh" ]]; then
    source "$(dirname "$0")/colors.sh"
elif [[ -f "$HOME/birdnet_odas/platforms/common/colors.sh" ]]; then
    source "$HOME/birdnet_odas/platforms/common/colors.sh"
else
    # Fallback: определить функции напрямую
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
    print_step() { echo -e "${GREEN}[*] $1${NC}"; }
    print_info() { echo -e "${CYAN}[i] $1${NC}"; }
    print_success() { echo -e "${GREEN}[+] $1${NC}"; }
    print_error() { echo -e "${RED}[-] $1${NC}"; }
    print_warning() { echo -e "${YELLOW}[!] $1${NC}"; }
fi

print_step "Настройка внешнего накопителя для данных BirdNET"

# Предупреждение
print_warning "Внимание: не выбирайте системный диск (/, /boot). Будет изменён /etc/fstab."

# Поиск дисков
print_info "Доступные диски/разделы:"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E "disk|part"

echo
read -p "Введите устройство для данных (например, /dev/mmcblk1p1 или /dev/sda1): " DEVICE

if [[ ! -b "$DEVICE" ]]; then
    print_error "Устройство $DEVICE не найдено"
    exit 1
fi

# Защита от выбора системного диска
ROOT_DEV=$(df / | tail -1 | awk '{print $1}')
if [[ "$DEVICE" == "$ROOT_DEV" || "$DEVICE" == "${ROOT_DEV%p?}" ]]; then
    print_error "Нельзя использовать системный диск: $DEVICE"
    exit 1
fi

# Точка монтирования
MOUNT_POINT="/mnt/birdnet-data"
sudo mkdir -p "$MOUNT_POINT"

# Определение UUID
UUID=$(sudo blkid -s UUID -o value "$DEVICE")
if [[ -z "$UUID" ]]; then
    print_error "Не удалось определить UUID для $DEVICE"
    exit 1
fi

print_info "UUID: $UUID"

# Определение файловой системы
FSTYPE=$(sudo blkid -s TYPE -o value "$DEVICE")
print_info "Файловая система: $FSTYPE"

# Бэкап fstab
sudo cp /etc/fstab /etc/fstab.bak.$(date +%Y%m%d%H%M%S)

# Временное монтирование для проверки
TEMP_MP=$(mktemp -d)
if ! sudo mount "$DEVICE" "$TEMP_MP"; then
    print_error "Не удалось смонтировать $DEVICE. Прервёмся."
    rmdir "$TEMP_MP"
    exit 1
fi
sudo umount "$TEMP_MP"
rmdir "$TEMP_MP"

# Добавление в /etc/fstab (если записи нет)
if grep -q "$UUID" /etc/fstab; then
    print_warning "Запись для $UUID уже существует в /etc/fstab"
else
    echo "UUID=$UUID $MOUNT_POINT $FSTYPE defaults,noatime 0 2" | sudo tee -a /etc/fstab
    print_success "Добавлена запись в /etc/fstab"
fi

# Монтирование
sudo mount -a
if mountpoint -q "$MOUNT_POINT"; then
    print_success "Накопитель смонтирован: $MOUNT_POINT"
else
    print_error "Не удалось смонтировать накопитель"
    exit 1
fi

# Создание директорий для BirdNET
sudo mkdir -p "$MOUNT_POINT/birdnet-clips"
sudo mkdir -p "$MOUNT_POINT/birdnet-db"
sudo chown -R $(whoami):$(whoami) "$MOUNT_POINT/birdnet-clips" "$MOUNT_POINT/birdnet-db"

print_success "Внешний накопитель настроен"
print_info "Директории:"
print_info "  - Клипы: $MOUNT_POINT/birdnet-clips"
print_info "  - База данных: $MOUNT_POINT/birdnet-db"
print_info ""
print_info "Настройте BirdNET-Go для использования этих директорий в config.yaml"
