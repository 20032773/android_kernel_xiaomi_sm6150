#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Build dtb (for boot.img, header v2) and dtbo.img the same way
# LineageOS does for sm6150-common (no BOARD_DTB_CFG / BOARD_DTBO_CFG):
#   dtb      = all built *.dtb, sorted, concatenated
#   dtbo.img = mkdtboimg create --page_size=4096 <all built *.dtbo, sorted>
#
# Usage: mkdtb.sh <kernel out dir> <path to mkdtboimg.py>

set -euo pipefail

OUT="$(cd "$1" && pwd)"
MKDTBOIMG="$2"
DTS="$OUT/arch/arm64/boot/dts"
DEST="$OUT/minatok20"

mkdir -p "$DEST"

mapfile -t DTBS < <(find "$DTS" -type f -name '*.dtb' | sort)
mapfile -t DTBOS < <(find "$DTS" -type f -name '*.dtbo' | sort)

[ "${#DTBS[@]}" -gt 0 ] || { echo "no .dtb files found in $DTS"; exit 1; }
[ "${#DTBOS[@]}" -gt 0 ] || { echo "no .dtbo files found in $DTS"; exit 1; }

echo "== dtb (${#DTBS[@]} files):"
printf '   %s\n' "${DTBS[@]#$DTS/}"
cat "${DTBS[@]}" > "$DEST/dtb"

echo "== dtbo (${#DTBOS[@]} files):"
printf '   %s\n' "${DTBOS[@]#$DTS/}"
python3 "$MKDTBOIMG" create "$DEST/dtbo.img" --page_size=4096 "${DTBOS[@]}"

ls -l "$DEST"
