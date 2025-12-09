#!/bin/bash
# Установка Docker (универсальная для всех платформ)
set -euo pipefail

source "$(dirname "$0")/../common/colors.sh" 2>/dev/null || {
    GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
    print_step() { echo -e "${GREEN}[*] $1${NC}"; }
    print_info() { echo -e "${CYAN}[i] $1${NC}"; }
    print_success() { echo -e "${GREEN}[+] $1${NC}"; }
    print_error() { echo -e "${RED}[-] $1${NC}"; }
}

print_step "Установка Docker"

if command -v docker &>/dev/null; then
    print_info "Docker уже установлен: $(docker --version)"
else
    curl -fsSL https://get.docker.com | sh
    sudo systemctl enable --now docker
    print_success "Docker установлен"
fi

# Добавление пользователя в группу docker
USER_NAME=${SUDO_USER:-$USER}
sudo usermod -aG docker "$USER_NAME"
print_info "Пользователь $USER_NAME добавлен в группу docker (требуется релогин)"

# Безопасное обновление /etc/docker/daemon.json (merge, без перезаписи)
print_step "Обновление /etc/docker/daemon.json (merge)"

sudo mkdir -p /etc/docker
TMP_JSON=$(mktemp)

# Скопировать текущий daemon.json, если есть
if sudo test -f /etc/docker/daemon.json; then
    sudo cp /etc/docker/daemon.json "$TMP_JSON"
else
    : > "$TMP_JSON"
fi

python3 - "$TMP_JSON" <<'PY'
import json, sys, os
tmp = sys.argv[1]
target = {
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {"max-size": "10m", "max-file": "3"},
    "storage-driver": "overlay2",
}
data = {}
if os.path.exists(tmp):
    try:
        with open(tmp, "r") as f:
            txt = f.read().strip()
            data = json.loads(txt) if txt else {}
    except Exception:
        data = {}
data.update(target)
with open(tmp, "w") as f:
    json.dump(data, f, indent=2)
PY

# Бэкап и установка
if sudo test -f /etc/docker/daemon.json; then
    sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
fi
sudo mv "$TMP_JSON" /etc/docker/daemon.json
sudo chmod 644 /etc/docker/daemon.json

print_success "/etc/docker/daemon.json обновлён (бэкап .bak если файл существовал)"
