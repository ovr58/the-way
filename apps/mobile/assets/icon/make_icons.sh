#!/usr/bin/env bash
# Иконка приложения: логотип-пин на зелёном фоне. Запуск из apps/mobile: bash assets/icon/make_icons.sh
# Нужен ffmpeg. Цвет фона — токен accent.primary (design/tokens/colors.json) = values/ic_launcher_background.xml.
set -euo pipefail
RES=android/app/src/main/res
SRC=../../design/images/image-27-ace7.webp
BG=0x1eb74d
# обрезка пина из исходника 1254x1254 (прозрачные поля убраны) -> исходник иконки
ffmpeg -v error -y -i "$SRC" -vf "crop=910:1150:170:50" assets/icon/pin.png
# адаптивный передний план: 108dp, пин высотой 66 % (безопасная зона), по центру
for d in mdpi:108 hdpi:162 xhdpi:216 xxhdpi:324 xxxhdpi:432; do
  n=${d%%:*}; s=${d##*:}; h=$((s*66/100))
  ffmpeg -v error -y -i assets/icon/pin.png -vf "scale=-2:$h:flags=lanczos,pad=$s:$s:(ow-iw)/2:(oh-ih)/2:color=0x00000000" "$RES/mipmap-$n/ic_launcher_foreground.png"
done
# обычная иконка для старых Android: зелёный квадрат со скруглением, пин высотой 80 %
for d in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  n=${d%%:*}; s=${d##*:}; h=$((s*80/100)); r=$((s*22/100))
  ffmpeg -v error -y -f lavfi -i "color=c=$BG:s=${s}x${s},format=rgba" -i assets/icon/pin.png \
    -filter_complex "[1]scale=-2:$h:flags=lanczos[p];[0][p]overlay=(W-w)/2:(H-h)/2,format=rgba,geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':a='if(gt(abs(X-$s/2+0.5),$s/2-$r)*gt(abs(Y-$s/2+0.5),$s/2-$r)*gt(hypot(abs(X-$s/2+0.5)-($s/2-$r),abs(Y-$s/2+0.5)-($s/2-$r)),$r),0,255)'" \
    -frames:v 1 "$RES/mipmap-$n/ic_launcher.png"
done
