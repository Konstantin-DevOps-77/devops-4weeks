#!/bin/bash
# greet.sh
if [ $# -lt 1 ]; then
  echo "Использование: $0 <имя>" >&2
  exit 1
fi
echo "Привет, $1"
