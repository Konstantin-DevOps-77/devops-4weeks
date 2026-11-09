#!/bin/bash
# health.sh [порог_диска_в_%]  — проверка диска, памяти и ssh
set -euo pipefail

THRESHOLD="${1:-80}"        #  Определяем пороги значений
MIN_MEM_MB=200
fail=0                      # станет 1, если хоть одна проверка провалилась(условие по ТЗ)

log() {
  echo "$(date '+%F %T') $*"
}

# Порог должен быть числом, иначе сравнение ниже сломается
if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]]; then
  echo "Использование: $0 [порог_в_процентах]" >&2
  exit 2
fi

# 1. Диск
disk=$(df --output=pcent / | tail -1 | tr -dc '0-9')
if [ "$disk" -le "$THRESHOLD" ]; then
  log "OK disk ${disk}%"
else
  log "FAIL disk ${disk}% > ${THRESHOLD}%"
  fail=1
fi

# 2. Память (колонка available в free -m)
mem=$(free -m | awk '/^Mem:/ {print $7}')
if [ "$mem" -ge "$MIN_MEM_MB" ]; then
  log "OK mem ${mem}MB available"
else
  log "FAIL mem ${mem}MB available < ${MIN_MEM_MB}MB"
  fail=1
fi

# 3. Служба ssh
if systemctl is-active --quiet ssh; then
  log "OK ssh active"
else
  log "FAIL ssh not active"
  fail=1
fi

exit "$fail"
