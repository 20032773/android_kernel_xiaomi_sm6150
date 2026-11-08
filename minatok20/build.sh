#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# minatok20 build script for Xiaomi Mi 9T (davinci)
# Used by both GitHub Actions and local builds.
#
# Environment variables:
#   CLANG_DIR   Path to an AOSP clang prebuilt (required)
#   OUT         Output directory (default: ./out)
#   KSU         true/false  Integrate BakaSU (formerly ReSukiSU) (default: true)
#   KSU_REF     BakaSU branch/tag/commit (default: main)
#   SUSFS       true/false  Use SUSFS inline hook; false = KSU manual hook (default: true)
#   JOBS        Parallel jobs (default: nproc)
#   USE_CCACHE  true/false (default: true if ccache is installed)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

: "${CLANG_DIR:?CLANG_DIR must point to an AOSP clang prebuilt}"
OUT="${OUT:-$ROOT/out}"
KSU="${KSU:-true}"
KSU_REF="${KSU_REF:-main}"
SUSFS="${SUSFS:-true}"
JOBS="${JOBS:-$(nproc)}"
if [ -z "${USE_CCACHE:-}" ]; then
	command -v ccache >/dev/null && USE_CCACHE=true || USE_CCACHE=false
fi

export PATH="$CLANG_DIR/bin:$PATH"
export KBUILD_BUILD_USER="minatok20"
export KBUILD_BUILD_HOST="github-actions"

echo "== clang: $(clang --version | head -n1)"
echo "== KSU=$KSU KSU_REF=$KSU_REF SUSFS=$SUSFS JOBS=$JOBS CCACHE=$USE_CCACHE"

# Fixed version suffix (avoids "-dirty" from KernelSU setup touching drivers/)
echo "-g$(git rev-parse --short=12 HEAD)" > .scmversion

# ---------------------------------------------------------------------------
# BakaSU (formerly ReSukiSU): official setup.sh, tracking the given ref
# ---------------------------------------------------------------------------
if [ "$KSU" = "true" ]; then
	if [ ! -d KernelSU ]; then
		curl -LSs "https://raw.githubusercontent.com/Baka-SU/BakaSU/main/kernel/setup.sh" | bash -s "$KSU_REF"
	else
		echo "== KernelSU already present, checking out $KSU_REF"
		git -C KernelSU fetch --tags origin
		git -C KernelSU checkout -q "$KSU_REF"
		git -C KernelSU pull -q --ff-only || true
	fi
	echo "== BakaSU commit: $(git -C KernelSU rev-parse HEAD)"
fi

# ---------------------------------------------------------------------------
# Toolchain flags (same style as LineageOS: LLVM=1 LLVM_IAS=1)
# ---------------------------------------------------------------------------
CC_BIN="clang"
[ "$USE_CCACHE" = "true" ] && CC_BIN="ccache clang"

MAKE_ARGS=(
	-C "$ROOT"
	O="$OUT"
	ARCH=arm64
	LLVM=1
	LLVM_IAS=1
	CC="$CC_BIN"
	HOSTCC=clang
	HOSTCXX=clang++
	CROSS_COMPILE=aarch64-linux-gnu-
	CROSS_COMPILE_ARM32=arm-linux-gnueabi-
	CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
	CLANG_TRIPLE=aarch64-linux-gnu-
)

mkdir -p "$OUT"
DEFCONFIGS="vendor/sdmsteppe-perf_defconfig vendor/davinci.config vendor/minatok20.config vendor/minatok20_stage2.config"
# The SUSFS feature flags live in a fragment so the exact feature set is
# pinned (and sus_kstat/sus_map/open_redirect stay off on 4.14).
if [ "$KSU" = "true" ] && [ "$SUSFS" = "true" ]; then
	DEFCONFIGS="$DEFCONFIGS vendor/minatok20_susfs.config"
fi
make "${MAKE_ARGS[@]}" $DEFCONFIGS

CFG="$ROOT/scripts/config --file $OUT/.config"
if [ "$KSU" = "true" ]; then
	$CFG -e KSU
	if [ "$SUSFS" = "true" ]; then
		$CFG -d KSU_MANUAL_HOOK -e KSU_SUSFS
	else
		$CFG -d KSU_SUSFS -e KSU_MANUAL_HOOK
	fi
else
	$CFG -d KSU
fi
make "${MAKE_ARGS[@]}" olddefconfig

# Verify the selected options survived olddefconfig
if [ "$KSU" = "true" ]; then
	grep -q '^CONFIG_KSU=y' "$OUT/.config" || { echo "CONFIG_KSU not enabled"; exit 1; }
	if [ "$SUSFS" = "true" ]; then
		grep -q '^CONFIG_KSU_SUSFS=y' "$OUT/.config" || { echo "CONFIG_KSU_SUSFS not enabled"; exit 1; }
	else
		grep -q '^CONFIG_KSU_MANUAL_HOOK=y' "$OUT/.config" || { echo "CONFIG_KSU_MANUAL_HOOK not enabled"; exit 1; }
	fi
fi
for opt in AUDIT KALLSYMS KALLSYMS_ALL; do
	grep -q "^CONFIG_${opt}=y" "$OUT/.config" || { echo "CONFIG_${opt} must stay enabled"; exit 1; }
done
if grep -q '^CONFIG_ZRAM_WRITEBACK=y' "$OUT/.config"; then
	echo "CONFIG_ZRAM_WRITEBACK must stay disabled"; exit 1
fi

make "${MAKE_ARGS[@]}" -j"$JOBS"

ls -l "$OUT/arch/arm64/boot/Image.gz"
echo "== Kernel release: $(cat "$OUT/include/config/kernel.release")"
