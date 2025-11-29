# Восстановление сетевого подключения после перезагрузки

## Проблема

После перезагрузки устройство недоступно по сети (SSH не отвечает, ping не проходит).

## Возможные причины

1. Изменения в сетевых параметрах sysctl могли повлиять на работу сети
2. Проблемы с загрузкой сетевых интерфейсов
3. Проблемы с NetworkManager или systemd-networkd

## Решения

### Решение 1: Физический доступ к устройству

Если есть физический доступ (монитор, клавиатура, или консоль):

```bash
# 1. Проверить статус сети
ip addr show
systemctl status NetworkManager
# или
systemctl status systemd-networkd

# 2. Проверить сетевые интерфейсы
ip link show

# 3. Попробовать перезапустить сеть
sudo systemctl restart NetworkManager
# или
sudo systemctl restart systemd-networkd

# 4. Проверить маршруты
ip route show
```

### Решение 2: Откат сетевых параметров sysctl

Если проблема в сетевых параметрах, которые мы добавили:

```bash
# Отредактировать /etc/sysctl.conf
sudo nano /etc/sysctl.conf

# Закомментировать или удалить строки:
# net.core.rmem_max = 16777216
# net.core.wmem_max = 16777216
# net.ipv4.tcp_rmem = 4096 87380 16777216
# net.ipv4.tcp_wmem = 4096 65536 16777216
# net.core.netdev_max_backlog = 5000
# net.core.rmem_default = 262144
# net.core.wmem_default = 262144

# Применить изменения
sudo sysctl -p
```

### Решение 3: Проверка через консоль (если доступна)

```bash
# Проверить, что сетевой интерфейс поднят
sudo ip link set eth0 up
# или для Wi-Fi
sudo ip link set wlan0 up

# Проверить получение IP адреса
sudo dhclient eth0
# или
sudo systemctl restart NetworkManager
```

### Решение 4: Временное отключение оптимизаций

Если проблема в оптимизациях производительности:

```bash
# Отключить CPU governor сервис
sudo systemctl disable set-cpu-governor.service
sudo systemctl stop set-cpu-governor.service

# Вернуть CPU governor в ondemand
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [ -f "$cpu" ] && echo ondemand | sudo tee "$cpu" > /dev/null
done
```

### Решение 5: Проверка через другой интерфейс

Если есть Wi-Fi или другой сетевой интерфейс:

```bash
# Проверить доступные интерфейсы
ip addr show

# Подключиться через другой интерфейс
# (если есть Wi-Fi или другой Ethernet порт)
```

## Профилактика

Для предотвращения проблем в будущем:

1. **Перед применением сетевых изменений:**
   - Создать резервную копию `/etc/sysctl.conf`
   - Протестировать изменения на тестовой системе

2. **Использовать более консервативные сетевые параметры:**
   - Не изменять параметры, критичные для базовой работы сети
   - Оставлять значения по умолчанию для основных сетевых параметров

3. **Настроить альтернативный способ доступа:**
   - ZeroTier VPN (если был настроен)
   - Serial console
   - Локальный доступ через монитор/клавиатуру

## Восстановление работоспособности

После восстановления подключения:

1. Проверить, что все сервисы работают:
```bash
systemctl status respeaker-loopback.service
systemctl status birdnet-go
systemctl status collect-metrics.timer
```

2. Проверить логи на наличие ошибок:
```bash
journalctl -xe | tail -50
dmesg | tail -50
```

3. При необходимости скорректировать оптимизации:
```bash
# Проверить текущие сетевые параметры
sysctl -a | grep net.core
sysctl -a | grep net.ipv4.tcp
```

