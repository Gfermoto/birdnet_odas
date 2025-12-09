#!/bin/bash
# Docker fixes для NanoPi M4B
set -euo pipefail

source "$(dirname "$0")/../common/colors.sh"

print_step "Применение фиксов Docker для NanoPi M4B"

# Установка зависимостей
print_info "Установка fuse-overlayfs и iptables..."
sudo apt install -y fuse-overlayfs iptables

# Переключение на iptables-legacy
print_info "Переключение на iptables-legacy..."
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy 2>/dev/null || \
  sudo update-alternatives --install /usr/sbin/iptables iptables /usr/sbin/iptables-legacy 10
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy 2>/dev/null || \
  sudo update-alternatives --install /usr/sbin/ip6tables ip6tables /usr/sbin/ip6tables-legacy 10

# Настройка Docker daemon
print_info "Настройка Docker daemon.json..."
sudo mkdir -p /etc/docker
cat <<'DOCKERJSON' | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {"max-size": "10m", "max-file": "3"},
  "storage-driver": "fuse-overlayfs"
}
DOCKERJSON

# Перезапуск Docker
print_info "Перезапуск Docker..."
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
sudo systemctl restart docker

# Проверка
print_info "Проверка Docker..."
if sudo docker run --rm alpine echo ok; then
    print_success "Docker работает с fuse-overlayfs"
else
    print_error "Docker не работает! Проверьте: sudo journalctl -xeu docker.service"
    exit 1
fi

print_success "Фиксы применены успешно"
