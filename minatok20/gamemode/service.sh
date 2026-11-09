#!/system/bin/sh
# minatok20 Game Mode service.
# Watches the foreground app; applies a performance profile (higher floors,
# faster big-core migration, touch game mode) for games listed in games.txt
# and reverts to the stock values on exit. No maximum frequency is changed.

MODDIR=${0%/*}
GAMES="$MODDIR/games.txt"
STATE_DIR="$MODDIR/.state"
POLL=4            # seconds between foreground checks

# --- tunable game-mode targets (floors only; maxima are never touched) -------
CPU_BIG="/sys/devices/system/cpu/cpu6/cpufreq"   # A76 big cluster policy
CPU_BIG_MIN_GAME=1324800                          # 1.3 GHz floor while gaming
GPU="/sys/class/kgsl/kgsl-3d0"
GPU_MIN_GAME=430000000                            # 430 MHz GPU floor
GPU_IDLE_TIMER_GAME=64                            # faster GPU idle -> ramp
SCHED_UP_GAME=85                                  # was ~95: migrate to big sooner
SCHED_DOWN_GAME=75                                # was ~80
TOPAPP="/dev/stune/top-app"
TOPAPP_BOOST_GAME=10
LLCC_DDR="/sys/class/devfreq/soc:qcom,cpu-llcc-ddr-bw"
LLCC_DDR_MIN_GAME=5161                            # mid-high DDR bandwidth floor
# ----------------------------------------------------------------------------

mkdir -p "$STATE_DIR"

w() { [ -e "$1" ] || return; chmod 0664 "$1" 2>/dev/null; echo "$2" > "$1" 2>/dev/null; }
r() { cat "$1" 2>/dev/null; }

save_stock() {
	# Snapshot the current (stock) values once, so revert is exact.
	[ -f "$STATE_DIR/saved" ] && return
	r "$CPU_BIG/scaling_min_freq"      > "$STATE_DIR/cpu_big_min"
	r "$GPU/devfreq/min_freq"          > "$STATE_DIR/gpu_min"
	r "$GPU/idle_timer"                > "$STATE_DIR/gpu_idle"
	r /proc/sys/kernel/sched_upmigrate > "$STATE_DIR/sched_up"
	r /proc/sys/kernel/sched_downmigrate > "$STATE_DIR/sched_down"
	r "$TOPAPP/schedtune.boost"        > "$STATE_DIR/ta_boost"
	r "$TOPAPP/schedtune.prefer_idle"  > "$STATE_DIR/ta_prefer"
	r "$LLCC_DDR/min_freq"             > "$STATE_DIR/llcc_min"
	touch "$STATE_DIR/saved"
}

apply_game() {
	save_stock
	w "$CPU_BIG/scaling_min_freq" "$CPU_BIG_MIN_GAME"
	w "$GPU/devfreq/min_freq" "$GPU_MIN_GAME"
	w "$GPU/idle_timer" "$GPU_IDLE_TIMER_GAME"
	w /proc/sys/kernel/sched_upmigrate "$SCHED_UP_GAME"
	w /proc/sys/kernel/sched_downmigrate "$SCHED_DOWN_GAME"
	w "$TOPAPP/schedtune.boost" "$TOPAPP_BOOST_GAME"
	w "$TOPAPP/schedtune.prefer_idle" "1"
	w "$LLCC_DDR/min_freq" "$LLCC_DDR_MIN_GAME"
	# hardware touch game mode + higher report rate (stock vendor capability)
	w /sys/devices/platform/soc/soc:xiaomi_touch/touch_mode "0 1"
	w /sys/devices/platform/soc/soc:xiaomi_touch/touch_mode "9 1"
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
	w /sys/devices/platform/soc/soc:xiaomi_touch/touch_mode "0 0"
	w /sys/devices/platform/soc/soc:xiaomi_touch/touch_mode "9 0"
}

foreground_pkg() {
	# Resolve the currently focused app's package name.
	pkg=$(dumpsys activity activities 2>/dev/null \
		| grep -m1 -E 'mResumedActivity|topResumedActivity' \
		| grep -oE '[a-zA-Z0-9._]+/[a-zA-Z0-9._]+' | cut -d/ -f1)
	[ -n "$pkg" ] && { echo "$pkg"; return; }
	dumpsys window windows 2>/dev/null | grep -m1 'mCurrentFocus' \
		| grep -oE '[a-zA-Z0-9._]+/[a-zA-Z0-9._]+' | cut -d/ -f1
}

is_game() {
	grep -q "^$1\$" "$GAMES" 2>/dev/null
}

# wait for boot to settle
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done
sleep 20

MODE=balanced
while true; do
	fg=$(foreground_pkg)
	if [ -n "$fg" ] && is_game "$fg"; then
		[ "$MODE" = game ] || { apply_game; MODE=game; }
	else
		[ "$MODE" = balanced ] || { apply_balanced; MODE=balanced; }
	fi
	sleep "$POLL"
done
