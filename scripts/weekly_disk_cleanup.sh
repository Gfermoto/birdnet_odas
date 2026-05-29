#!/usr/bin/env bash
# Еженедельная безопасная очистка на хосте BirdNET-ODAS.
# По умолчанию не трогает клипы; при заполнении диска >85% удаляет самый старый месяц в clips/.
#
# Запуск: только от root (нужен доступ к volume Docker и journald).
# Cron (раз в неделю, воскресенье 04:15):
#   sudo cp scripts/weekly_disk_cleanup.sh /usr/local/bin/weekly_disk_cleanup.sh
#   sudo chmod +x /usr/local/bin/weekly_disk_cleanup.sh
#   echo '15 4 * * 0 root /usr/local/bin/weekly_disk_cleanup.sh' | sudo tee /etc/cron.d/birdnet-weekly-cleanup
#   sudo chmod 644 /etc/cron.d/birdnet-weekly-cleanup

set -u

readonly LOG="/var/log/birdnet-weekly-cleanup.log"
readonly BN_DATA="/var/lib/docker/volumes/birdnet-go-data/_data"
readonly BN_LOGS="${BN_DATA}/logs"
readonly METRICS_DIR="/var/log/birdnet-pipeline/metrics"

log() {
  echo "[$(date -Iseconds)] $*" | tee -a "$LOG" >&2
}

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Запустите от root: sudo $0" >&2
  exit 1
fi

mkdir -p "$(dirname "$LOG")"
touch "$LOG" || true

log "=== weekly_disk_cleanup start ==="
df -h / | tail -1 >>"$LOG" 2>&1 || true

removed=0

# 1) Ротированные логи BirdNET-Go (имя содержит дату YYYY-MM-DD), старше 14 дней.
#    Не трогаем access.log, application.log и т.д. без даты в имени.
if [[ -d "$BN_LOGS" ]]; then
  while IFS= read -r -d '' f; do
    base=$(basename "$f")
    if [[ "$base" =~ 20[0-9]{2}-[0-9]{2}-[0-9]{2} ]]; then
      rm -f -- "$f" && removed=$((removed + 1)) || true
    fi
  done < <(find "$BN_LOGS" -maxdepth 1 -type f -name '*.log' -mtime +14 -print0 2>/dev/null)
  log "BirdNET rotated logs removed (count): $removed"
else
  log "skip: $BN_LOGS not found"
fi

readonly BN_CLIPS="${BN_DATA}/clips"

disk_use_pct() {
  df / | awk 'NR==2 {gsub(/%/,"",$5); print $5}'
}

# 1b) Если диск >85%: обнулить крупные активные логи BirdNET (append-safe).
if [[ -d "$BN_LOGS" ]]; then
  use=$(disk_use_pct)
  if [[ -n "$use" && "$use" -gt 85 ]]; then
    log "disk ${use}% > 85%, truncating large active BirdNET logs"
    for f in access.log actions.log application.log auth.log birdweather.log audio.log spectrogram.log weather.log; do
      [[ -f "$BN_LOGS/$f" ]] && truncate -s 0 "$BN_LOGS/$f" 2>/dev/null || true
    done
  fi
fi

# 1c) Если диск >85%: удалить самый старый месяц клипов (clips/YYYY/MM).
if [[ -d "$BN_CLIPS" ]]; then
  use=$(disk_use_pct)
  if [[ -n "$use" && "$use" -gt 85 ]]; then
    oldest=$(find "$BN_CLIPS" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | sort | head -1)
    if [[ -n "$oldest" && "$oldest" != "$BN_CLIPS" ]]; then
      sz=$(du -sh "$oldest" 2>/dev/null | cut -f1)
      log "disk ${use}% > 85%, removing oldest clip month: $oldest ($sz)"
      rm -rf "$oldest"
    fi
  fi
fi

# 2) Старые дневные метрики пайплайна (JSON по дням), старше 90 дней.
if [[ -d "$METRICS_DIR" ]]; then
  m=$(find "$METRICS_DIR" -type f -name '*.json' -mtime +90 -print 2>/dev/null | wc -l)
  find "$METRICS_DIR" -type f -name '*.json' -mtime +90 -delete 2>/dev/null || true
  log "Pipeline metrics files removed (older 90d): $m"
fi

# 3) Journald — оставить примерно последние 30 дней (не трогает файлы BirdNET).
if command -v journalctl >/dev/null 2>&1; then
  journalctl --vacuum-time=30d >>"$LOG" 2>&1 || log "journalctl vacuum warning (non-fatal)"
fi

# 4) Кэш apt (без удаления пакетов).
if command -v apt-get >/dev/null 2>&1; then
  apt-get clean -y >>"$LOG" 2>&1 || true
  rm -rf /var/cache/apt/archives/partial/* 2>/dev/null || true
  log "apt clean done"
fi

# 5) Docker: только «висячие» образы (не используются контейнерами).
if command -v docker >/dev/null 2>&1; then
  docker image prune -f >>"$LOG" 2>&1 || log "docker image prune warning (non-fatal)"
fi

df -h / | tail -1 >>"$LOG" 2>&1 || true
log "=== weekly_disk_cleanup done ==="

exit 0
