#!/bin/bash
# Установка BirdNET-Go (универсальная)
set -euo pipefail

source "$(dirname "$0")/colors.sh"

print_step "Установка BirdNET-Go"

cd "$HOME"
curl -fsSL https://github.com/tphakala/birdnet-go/raw/main/install.sh -o install.sh
bash ./install.sh

# Проверка
sleep 2
if systemctl is-active --quiet birdnet-go 2>/dev/null; then
    print_success "BirdNET-Go запущен"
else
    print_warning "BirdNET-Go не активен. Проверьте: systemctl status birdnet-go"
fi

print_info "Web GUI доступен на: http://$(hostname -I | awk '{print $1}'):8080"
