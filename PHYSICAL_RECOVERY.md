# ВОССТАНОВЛЕНИЕ УСТРОЙСТВА ЧЕРЕЗ ФИЗИЧЕСКИЙ ДОСТУП

## Ситуация
Устройство не загружается после применения оптимизаций. Нужен физический доступ (монитор + клавиатура или консоль).

## Шаг 1: Войти в систему

### Вариант A: Если система загружается частично
- Нажмите Ctrl+Alt+F1 (или F2-F6) для переключения на консоль
- Войдите как root

### Вариант B: Если система не загружается
- При загрузке нажмите и удерживайте Shift (или Esc для некоторых систем)
- Выберите "Advanced options" → "Recovery mode"
- Выберите "root" или "Drop to root shell"

### Вариант C: Через GRUB
- При загрузке нажмите Esc или Shift
- Выберите строку загрузки, нажмите 'e' для редактирования
- Добавьте в конец строки `linux`: `systemd.unit=rescue.target`
- Нажмите Ctrl+X для загрузки
- Войдите как root

## Шаг 2: Отключить проблемные сервисы

```bash
# Отключить сервис CPU governor (может блокировать загрузку)
systemctl disable set-cpu-governor.service
systemctl stop set-cpu-governor.service
rm /etc/systemd/system/set-cpu-governor.service

# Перезагрузить systemd
systemctl daemon-reload
```

## Шаг 3: Удалить проблемные параметры из sysctl.conf

```bash
# Создать резервную копию
cp /etc/sysctl.conf /etc/sysctl.conf.backup

# Удалить ВСЕ добавленные параметры
# Удалить сетевые параметры (если есть)
sed -i '/# Оптимизация для аудио пайплайна/,/net.core.wmem_default = 262144/d' /etc/sysctl.conf

# Удалить параметры ядра для реального времени
sed -i '/# Оптимизация для реального времени/,/kernel.sched_migration_cost_ns = 5000000/d' /etc/sysctl.conf

# Удалить swappiness и dirty_ratio (вернуть к defaults)
sed -i '/vm.swappiness=1/d' /etc/sysctl.conf
sed -i '/vm.dirty_ratio=10/d' /etc/sysctl.conf
sed -i '/vm.dirty_background_ratio=5/d' /etc/sysctl.conf

# Применить изменения
sysctl -p
```

## Шаг 4: Восстановить сетевые сервисы

```bash
# Перезапустить сеть
systemctl restart NetworkManager
# или если используется systemd-networkd:
systemctl restart systemd-networkd

# Поднять сетевой интерфейс
ip link set eth0 up
dhclient eth0

# Проверить сеть
ip addr show
ping -c 3 8.8.8.8
```

## Шаг 5: Проверить и исправить systemd сервисы

```bash
# Проверить статус всех сервисов
systemctl list-units --failed

# Если respeaker-loopback.service блокирует загрузку
systemctl disable respeaker-loopback.service
systemctl stop respeaker-loopback.service

# Проверить зависимости
systemctl list-dependencies multi-user.target
```

## Шаг 6: Восстановить базовую конфигурацию

```bash
# Вернуть CPU governor в ondemand (если поддерживается)
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [ -f "$cpu" ] && echo ondemand > "$cpu" 2>/dev/null || true
done

# Вернуть I/O scheduler в mq-deadline (если был изменен)
for disk in /sys/block/mmcblk*/queue/scheduler; do
    [ -f "$disk" ] && echo mq-deadline > "$disk" 2>/dev/null || true
done
```

## Шаг 7: Перезагрузить систему

```bash
# Проверить, что все исправлено
systemctl status
ip addr show

# Перезагрузить
reboot
```

## После восстановления

1. **Проверить подключение:**
```bash
ssh root@192.168.1.136
```

2. **Удалить проблемные скрипты:**
```bash
# Удалить скрипт оптимизации (или исправить его)
rm /usr/local/bin/optimize_performance.sh
# Или обновить его из репозитория (безопасная версия уже создана)
```

3. **Проверить работу сервисов:**
```bash
systemctl status respeaker-loopback.service
systemctl status birdnet-go
```

## Если ничего не помогает

### Полный откат изменений

```bash
# Удалить все созданные файлы
rm /etc/systemd/system/set-cpu-governor.service
rm /etc/systemd/system/collect-metrics.service
rm /etc/systemd/system/collect-metrics.timer
rm /etc/security/limits.d/99-audio-pipeline.conf

# Восстановить sysctl.conf из резервной копии (если есть)
cp /etc/sysctl.conf.backup /etc/sysctl.conf

# Перезагрузить systemd
systemctl daemon-reload
systemctl reset-failed

# Перезагрузить
reboot
```

## Извинения

Приношу глубокие извинения за возникшую проблему. Все проблемные изменения были удалены из скриптов для предотвращения подобных ситуаций в будущем.

