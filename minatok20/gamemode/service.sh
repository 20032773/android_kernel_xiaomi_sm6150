#!/system/bin/sh
# minatok20 Game Mode service.
# Watches the foreground app; applies a performance profile (higher floors,
# faster big-core migration, touch game mode) for games listed in games.txt
# and reverts to the stock values on exit. No maximum frequency is changed.
# Settings come from config.sh (edited by the WebUI).

MODDIR=${0%/*}
GAMES="$MODDIR/games.txt"
CONFIG="$MODDIR/config.sh"
STATE_DIR="$MODDIR/.state"

CPU_BIG="/sys/devices/system/cpu/cpu6/cpufreq"
GPU="/sys/class/kgsl/kgsl-3d0"
TOPAPP="/dev/stune/top-app"
LLCC_DDR="/sys/class/devfreq/soc:qcom,cpu-llcc-ddr-bw"
TOUCH="/sys/class/touch/touch_dev/touch_mode"

mkdir -p "$STATE_DIR"

# defaults (overridden by config.sh)
ENABLE_GAMEMODE=1
FEAT_CPU_FLOOR=1; FEAT_GPU_FLOOR=1; FEAT_SCHED_MIGRATE=1
FEAT_SCHEDTUNE=1; FEAT_DDR_FLOOR=1; FEAT_TOUCH=1
CPU_BIG_MIN_GAME=1324800; GPU_MIN_GAME=430000000; GPU_IDLE_TIMER_GAME=64
SCHED_UP_GAME=85; SCHED_DOWN_GAME=75; TOPAPP_BOOST_GAME=10
LLCC_DDR_MIN_GAME=5161; POLL=4

load_config() { [ -f "$CONFIG" ] && . "$CONFIG"; }

w() { [ -e "$1" ] || return; chmod 0664 "$1" 2>/dev/null; echo "$2" > "$1" 2>/dev/null; }
r() { cat "$1" 2>/dev/null; }

save_stock() {
	[ -f "$STATE_DIR/saved" ] && return
	r "$CPU_BIG/scaling_min_freq"        > "$STATE_DIR/cpu_big_min"
	r "$GPU/devfreq/min_freq"            > "$STATE_DIR/gpu_min"
	r "$GPU/idle_timer"                  > "$STATE_DIR/gpu_idle"
	r /proc/sys/kernel/sched_upmigrate   > "$STATE_DIR/sched_up"
	r /proc/sys/kernel/sched_downmigrate > "$STATE_DIR/sched_down"
	r "$TOPAPP/schedtune.boost"          > "$STATE_DIR/ta_boost"
	r "$TOPAPP/schedtune.prefer_idle"    > "$STATE_DIR/ta_prefer"
	r "$LLCC_DDR/min_freq"               > "$STATE_DIR/llcc_min"
	touch "$STATE_DIR/saved"
}

apply_game() {
	save_stock
	[ "$FEAT_CPU_FLOOR" = 1 ]     && w "$CPU_BIG/scaling_min_freq" "$CPU_BIG_MIN_GAME"
	if [ "$FEAT_GPU_FLOOR" = 1 ]; then
		w "$GPU/devfreq/min_freq" "$GPU_MIN_GAME"
		w "$GPU/idle_timer" "$GPU_IDLE_TIMER_GAME"
	fi
	if [ "$FEAT_SCHED_MIGRATE" = 1 ]; then
		w /proc/sys/kernel/sched_upmigrate "$SCHED_UP_GAME"
		w /proc/sys/kernel/sched_downmigrate "$SCHED_DOWN_GAME"
	fi
	if [ "$FEAT_SCHEDTUNE" = 1 ]; then
		w "$TOPAPP/schedtune.boost" "$TOPAPP_BOOST_GAME"
		w "$TOPAPP/schedtune.prefer_idle" "1"
	fi
	[ "$FEAT_DDR_FLOOR" = 1 ]     && w "$LLCC_DDR/min_freq" "$LLCC_DDR_MIN_GAME"
	if [ "$FEAT_TOUCH" = 1 ]; then
		w "$TOUCH" "0 1"
		w "$TOUCH" "9 1"
	fi
	echo game > "$STATE_DIR/mode"
}

apply_balanced() {
	[ -f "$STATE_DIR/saved" ] || return
	w "$CPU_BIG/scaling_min_freq" "$(r "$STATE_DIR/cpu_big_min")"
	w "$GPU/devfreq/min_freq" "$(r "$STATE_DIR/gpu_min")"
	w "$GPU/idle_timer" "$(r "$STATE_DIR/gpu_idle")"
	w /proc/sys/kernel/sched_upmigrate "$(r "$STATE_DIR/sched_up")"
	w /proc/sys/kernel/sched_downmigrate "$(r "$STATE_DIR/sched_down")"
	w "$TOPAPP/schedtune.boost" "$(r "$STATE_DIR/ta_boost")"
	w "$TOPAPP/schedtune.prefer_idle" "$(r "$STATE_DIR/ta_prefer")"
	w "$LLCC_DDR/min_freq" "$(r "$STATE_DIR/llcc_min")"
	w "$TOUCH" "0 0"
	w "$TOUCH" "9 0"
	echo balanced > "$STATE_DIR/mode"
}

foreground_pkg() {
	pkg=$(dumpsys activity activities 2>/dev/null \
		| grep -m1 -E 'mResumedActivity|topResumedActivity' \
		| grep -oE '[a-zA-Z0-9._]+/[a-zA-Z0-9._]+' | cut -d/ -f1)
	[ -n "$pkg" ] && { echo "$pkg"; return; }
	dumpsys window windows 2>/dev/null | grep -m1 'mCurrentFocus' \
		| grep -oE '[a-zA-Z0-9._]+/[a-zA-Z0-9._]+' | cut -d/ -f1
}

is_game() { grep -q "^$1\$" "$GAMES" 2>/dev/null; }

apply_boot_tweaks() {
	# I/O scheduler (re-assert in case something changed it after post-fs-data)
	if [ "${FEAT_IOSCHED:-1}" = 1 ]; then
		for q in /sys/block/sd*/queue/scheduler; do
			chmod 0664 "$q" 2>/dev/null
			echo "${IOSCHED:-deadline}" > "$q" 2>/dev/null
		done
	fi
	# zram resize (only if the size differs; brief swapoff window)
	if [ "${ZRAM_SIZE_GB:-0}" -gt 0 ] && [ -e /sys/block/zram0/disksize ]; then
		want=$((ZRAM_SIZE_GB * 1073741824))
		cur=$(r /sys/block/zram0/disksize)
		if [ "$cur" != "$want" ]; then
			swapoff /dev/block/zram0 2>/dev/null
			echo 1 > /sys/block/zram0/reset 2>/dev/null
			echo "$want" > /sys/block/zram0/disksize 2>/dev/null
			mkswap /dev/block/zram0 >/dev/null 2>&1
			swapon /dev/block/zram0 2>/dev/null
		fi
	fi
}

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done
sleep 20

load_config
apply_boot_tweaks

echo balanced > "$STATE_DIR/mode"
MODE=balanced
while true; do
	load_config
	if [ "$ENABLE_GAMEMODE" != 1 ]; then
		[ "$MODE" = balanced ] || { apply_balanced; MODE=balanced; }
		sleep "$POLL"; continue
	fi
	fg=$(foreground_pkg)
	echo "$fg" > "$STATE_DIR/fg"
	if [ -n "$fg" ] && is_game "$fg"; then
		[ "$MODE" = game ] || { apply_game; MODE=game; }
	else
		[ "$MODE" = balanced ] || { apply_balanced; MODE=balanced; }
	fi
	sleep "$POLL"
done
