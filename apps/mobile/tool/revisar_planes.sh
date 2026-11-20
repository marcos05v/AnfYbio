#!/bin/sh
# Revisa qué tan bien lee la app los planes en PDF de una carpeta, sin
# subirlos a ningún lado ni copiarlos al repositorio (ADR-0021).
#
#   tool/revisar_planes.sh ~/Downloads/planes
#
# El texto se extrae en una carpeta temporal que se borra al terminar.
set -eu
cd "$(dirname "$0")/.."

if [ $# -ne 1 ] || [ ! -d "$1" ]; then
  echo "Uso: tool/revisar_planes.sh <carpeta con PDFs>" >&2
  exit 1
fi

TEXTS="$(mktemp -d)"
trap 'rm -rf "$TEXTS"' EXIT

found=0
for pdf in "$1"/*.pdf; do
  [ -e "$pdf" ] || continue
  found=1
  name="$(basename "$pdf" .pdf)"
  swift tool/pdf_text.swift "$pdf" > "$TEXTS/$name.txt"
done
if [ "$found" -eq 0 ]; then
  echo "No hay PDFs en $1" >&2
  exit 1
fi

ANFYBIO_PLANS_DIR="$TEXTS" flutter test test/import/private_plans_test.dart \
  --reporter expanded
