#!/bin/bash
# Системные оптимизации (универсальные)
set -euo pipefail

source "$(dirname "$0")/colors.sh"

print_step "Оптимизация системы"

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
| sudo tee /etc/udev/rules.d/99-usb-autosuspend-off.rules >/dev/null
sudo udevadm control --reload-rules && sudo udevadm trigger

print_success "Оптимизация завершена"
