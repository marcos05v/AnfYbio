#!/bin/sh
# Pone el ícono de la app en todos los tamaños que piden iOS y Android.
#
#   tool/app_icon.sh               dibuja el logo de AnfYbio (tool/app_icon.swift)
#   tool/app_icon.sh mi_logo.png   usa tu propia imagen
#
# La imagen debe ser cuadrada, de al menos 1024 × 1024 y sin transparencia
# (iOS pone un fondo negro donde haya transparencia). iOS redondea las
# esquinas solo: no las redondees en la imagen.
set -eu
cd "$(dirname "$0")/.."

ICONS=ios/Runner/Assets.xcassets/AppIcon.appiconset
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [ $# -ge 1 ]; then
  SOURCE="$1"
else
  SOURCE="$WORK/logo.png"
  swift tool/app_icon.swift "$SOURCE"
fi

# Sin canal alfa: se convierte a JPEG y de vuelta a PNG.
sips -s format jpeg "$SOURCE" --out "$WORK/flat.jpg" >/dev/null
sips -s format png -z 1024 1024 "$WORK/flat.jpg" --out "$WORK/master.png" >/dev/null

for entry in 20x20@1x:20 20x20@2x:40 20x20@3x:60 29x29@1x:29 29x29@2x:58 \
  29x29@3x:87 40x40@1x:40 40x40@2x:80 40x40@3x:120 60x60@2x:120 \
  60x60@3x:180 76x76@1x:76 76x76@2x:152 83.5x83.5@2x:167 1024x1024@1x:1024; do
  name="${entry%%:*}"
  pixels="${entry##*:}"
  sips -z "$pixels" "$pixels" "$WORK/master.png" \
    --out "$ICONS/Icon-App-$name.png" >/dev/null
done
# Android: un ícono por densidad de pantalla.
ANDROID_RES=android/app/src/main/res
if [ -d "$ANDROID_RES" ]; then
  for entry in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
    density="${entry%%:*}"
    pixels="${entry##*:}"
    sips -z "$pixels" "$pixels" "$WORK/master.png" \
      --out "$ANDROID_RES/mipmap-$density/ic_launcher.png" >/dev/null
  done
fi
echo "Ícono actualizado en $ICONS y en $ANDROID_RES"
