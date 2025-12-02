#!/bin/bash
# Скрипт для исправления проблем с получением IP через DHCP на MikroTik
# Увеличивает таймауты и настраивает более надежное получение IP

set -euo pipefail

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() { echo -e "${CYAN}[i] $1${NC}"; }
print_success() { echo -e "${GREEN}[+] $1${NC}"; }
print_error() { echo -e "${RED}[-] $1${NC}"; }
print_warning() { echo -e "${YELLOW}[!] $1${NC}"; }

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    print_error "Запустите скрипт с правами root: sudo $0"
    exit 1
fi

print_info "Исправление настроек DHCP для надежной работы с MikroTik"
echo ""

# 1. Настройка NetworkManager для более надежного DHCP
print_info "1. Настройка NetworkManager DHCP таймаутов..."

# Создать директорию для конфигурации, если не существует
mkdir -p /etc/NetworkManager/conf.d

# Увеличить таймаут DHCP и добавить retry
cat > /etc/NetworkManager/conf.d/dhcp-timeout.conf <<'EOF'
[connection]
# Увеличить таймаут DHCP до 120 секунд (для медленных роутеров)
ipv4.dhcp-timeout=120

# Включить retry при неудаче
ipv4.dhcp-send-hostname=true
ipv4.may-fail=false
EOF

print_success "Конфигурация NetworkManager создана"

# 2. Настройка NetworkManager-wait-online для ожидания реального IP
print_info "2. Настройка NetworkManager-wait-online..."

# Создать override для NetworkManager-wait-online
mkdir -p /etc/systemd/system/NetworkManager-wait-online.service.d

cat > /etc/systemd/system/NetworkManager-wait-online.service.d/override.conf <<'EOF'
[Service]
# Увеличить таймаут до 180 секунд (3 минуты)
# Это даст время MikroTik ответить на DHCP запрос
TimeoutStartSec=180

# Ждать реального IP адреса, а не только подключения кабеля
ExecStart=
ExecStart=/usr/bin/nm-online -s --timeout=180
EOF

print_success "Override для NetworkManager-wait-online создан"

# 3. Настройка конкретного подключения eth0
print_info "3. Настройка подключения eth0..."

# Найти UUID подключения eth0
CONNECTION_UUID=$(nmcli -t -f UUID,DEVICE connection show | grep ":eth0$" | cut -d: -f1 | head -1)

if [ -z "$CONNECTION_UUID" ]; then
    # Если подключение не найдено, создать новое
    print_warning "Подключение eth0 не найдено, создание нового..."
    CONNECTION_UUID=$(nmcli connection add type ethernet ifname eth0 con-name "Wired connection eth0" 2>&1 | grep -oP "connection '\K[^']+" || echo "")
    if [ -z "$CONNECTION_UUID" ]; then
        CONNECTION_UUID=$(nmcli -t -f UUID connection show "Wired connection eth0" 2>&1 | head -1)
    fi
fi

if [ -n "$CONNECTION_UUID" ]; then
    print_info "Настройка подключения: $CONNECTION_UUID"
    
    # Увеличить таймаут DHCP для этого подключения
    nmcli connection modify "$CONNECTION_UUID" \
        ipv4.dhcp-timeout 120 \
        ipv4.may-fail false \
        connection.autoconnect yes \
        connection.autoconnect-priority 10
    
    print_success "Подключение eth0 настроено"
else
    print_warning "Не удалось найти или создать подключение eth0"
fi

# 4. Перезагрузка NetworkManager
print_info "4. Перезагрузка NetworkManager..."
systemctl daemon-reload
systemctl restart NetworkManager

# Небольшая задержка для применения настроек
sleep 2

print_success "NetworkManager перезагружен"

# 5. Проверка текущей конфигурации
echo ""
print_info "5. Проверка текущей конфигурации:"
echo ""
echo "MAC адрес eth0: $(ip link show eth0 | grep 'link/ether' | awk '{print $2}')"
echo "Текущий IP: $(ip addr show eth0 | grep 'inet ' | awk '{print $2}' || echo 'не назначен')"
echo ""
echo "Настройки NetworkManager:"
nmcli connection show "$CONNECTION_UUID" 2>/dev/null | grep -E "ipv4.dhcp-timeout|ipv4.may-fail" || echo "Используются настройки по умолчанию"

echo ""
print_success "Настройки применены!"
echo ""
print_info "Изменения:"
echo "  • DHCP таймаут увеличен до 120 секунд"
echo "  • NetworkManager-wait-online ждет до 180 секунд"
echo "  • Отключен may-fail (система будет ждать IP)"
echo ""
print_warning "ВАЖНО: После перезагрузки система будет ждать получения IP до 3 минут"
print_warning "Убедитесь, что на MikroTik настроена привязка MAC $CONNECTION_UUID к IP адресу"

