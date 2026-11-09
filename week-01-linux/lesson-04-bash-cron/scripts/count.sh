#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Использование: $0 <каталог>" >&2
  exit 1
fi

dir="$1"
if [ ! -d "$dir" ]; then
  echo "Ошибка: $dir не каталог" >&2
  exit 1
fi

count=0
for f in "$dir"/*; do
  if [ -f "$f" ]; then
    count=$((count + 1))
  fi
done
echo "$count"
