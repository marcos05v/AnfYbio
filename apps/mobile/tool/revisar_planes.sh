#!/bin/sh
# Revisa qué tan bien lee la app los planes en PDF, sin subirlos a ningún
# lado ni copiarlos al repositorio (ADR-0021). Acepta PDFs sueltos, carpetas
# con PDFs o una mezcla:
#
#   tool/revisar_planes.sh ~/Downloads/"Plan de alimentación Dany 7.pdf"
#   tool/revisar_planes.sh ~/Downloads/planes
#
# El texto se extrae en una carpeta temporal que se borra al terminar.
set -eu

if [ $# -eq 0 ]; then
  echo "Uso: tool/revisar_planes.sh <PDF o carpeta> [más PDFs o carpetas]" >&2
  exit 1
fi

TOOL_DIR="$(cd "$(dirname "$0")" && pwd)"
TEXTS="$(mktemp -d)"
trap 'rm -rf "$TEXTS"' EXIT

found=0
extract() {
  name="$(basename "$1" .pdf)"
  swift "$TOOL_DIR/pdf_text.swift" "$1" > "$TEXTS/$name.txt"
  found=1
}

for arg in "$@"; do
  if [ -d "$arg" ]; then
    for pdf in "$arg"/*.pdf; do
      [ -e "$pdf" ] && extract "$pdf"
    done
  elif [ -f "$arg" ]; then
    extract "$arg"
  else
    echo "No existe: $arg" >&2
    echo "(Ojo: ~ ya es tu carpeta de usuario; escribe ~/Downloads/…," \
      "no ~/Users/…)" >&2
    exit 1
  fi
done
if [ "$found" -eq 0 ]; then
  echo "No encontré PDFs en lo que indicaste." >&2
  exit 1
fi

cd "$TOOL_DIR/.."
ANFYBIO_PLANS_DIR="$TEXTS" flutter test test/import/private_plans_test.dart \
  --reporter expanded 2>&1 | grep -E "→|No se pudieron leer|Some tests failed"
