#!/bin/bash
# Установка systemd сервиса и таймера для сбора метрик

set -e

echo "=== Установка сервиса сбора метрик ==="

# Создать systemd сервис
sudo tee /etc/systemd/system/collect-metrics.service > /dev/null <<'EOF'
[Unit]
Description=Collect BirdNET Pipeline Metrics
After=respeaker-loopback.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/collect_metrics.sh
StandardOutput=journal
StandardError=journal
User=root
EOF

# Создать systemd таймер
sudo tee /etc/systemd/system/collect-metrics.timer > /dev/null <<'EOF'
[Unit]
Description=Collect BirdNET Pipeline Metrics Timer
Requires=collect-metrics.service

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
AccuracySec=1s

[Install]
WantedBy=timers.target
EOF

# Перезагрузить systemd и включить таймер
sudo systemctl daemon-reload
sudo systemctl enable collect-metrics.timer
sudo systemctl start collect-metrics.timer

echo "✓ Сервис collect-metrics.service создан"
echo "✓ Таймер collect-metrics.timer создан и запущен"
echo ""
echo "Статус таймера:"
systemctl status collect-metrics.timer --no-pager -l | head -10

