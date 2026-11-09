# minatok20 Game Mode configuration.
# Edited by the module's WebUI, or by hand. service.sh sources this file.
# 1 = enabled, 0 = disabled.

# Master switch for the whole game-mode service.
ENABLE_GAMEMODE=1

# Per-feature toggles.
FEAT_CPU_FLOOR=1      # raise big-cluster CPU min while gaming
FEAT_GPU_FLOOR=1      # raise GPU min + faster GPU ramp
FEAT_SCHED_MIGRATE=1  # lower WALT up/down-migrate thresholds
FEAT_SCHEDTUNE=1      # top-app schedtune boost + prefer_idle
FEAT_DDR_FLOOR=1      # raise DDR/LLCC bandwidth floor
FEAT_TOUCH=1          # hardware touch game mode + higher report rate

# Profile values (floors only; maxima are never changed).
CPU_BIG_MIN_GAME=1324800
GPU_MIN_GAME=430000000
GPU_IDLE_TIMER_GAME=64
SCHED_UP_GAME=85
SCHED_DOWN_GAME=75
TOPAPP_BOOST_GAME=10
LLCC_DDR_MIN_GAME=5161
POLL=4

# Boot-time storage/memory tweaks (applied once per boot).
FEAT_IOSCHED=1      # set UFS I/O scheduler to $IOSCHED
IOSCHED=deadline
ZRAM_SIZE_GB=3      # resize zram to this many GB (0 = leave as-is)
