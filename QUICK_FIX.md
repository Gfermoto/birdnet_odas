# БЫСТРОЕ ИСПРАВЛЕНИЕ - Шпаргалка

## Что нужно сделать (минимум)

### 1. Открой sysctl.conf на eMMC
- Путь: `E:\etc\sysctl.conf` (или другая буква диска)
- Сделай резервную копию!

### 2. Удали эти строки (КРИТИЧНО!):

```
kernel.sched_rt_runtime_us = 950000
kernel.sched_rt_period_us = 1000000
kernel.sched_migration_cost_ns = 5000000
```

### 3. Удали эти строки (ВАЖНО):

```
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.netdev_max_backlog = 5000
net.core.rmem_default = 262144
net.core.wmem_default = 262144
```

### 4. Удали файл:
- `E:\etc\systemd\system\set-cpu-governor.service`

### 5. Сохрани все и вставь eMMC обратно

## Если не работает

Попробуй найти и использовать резервную копию:
- `E:\etc\sysctl.conf.backup`

## Подробная инструкция

См. `FIX_EMMC_STEP_BY_STEP.md`

