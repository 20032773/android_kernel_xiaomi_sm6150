#!/system/bin/sh
# Early-boot I/O scheduler tweak (before heavy I/O / zygote).
MODDIR=${0%/*}
FEAT_IOSCHED=1; IOSCHED=deadline
[ -f "$MODDIR/config.sh" ] && . "$MODDIR/config.sh"
if [ "$FEAT_IOSCHED" = 1 ]; then
	for q in /sys/block/sd*/queue/scheduler; do
		chmod 0664 "$q" 2>/dev/null
		echo "$IOSCHED" > "$q" 2>/dev/null
	done
fi
