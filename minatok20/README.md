# minatok20 — custom kernel for Xiaomi Mi 9T / Redmi K20 (davinci)

A LineageOS-based custom kernel for the Xiaomi Mi 9T / Redmi K20 (codename
**davinci**, Snapdragon 730 / sm6150, kernel 4.14), built for **LineageOS 23.2
(Android 16)**.

> This branch (`minatok20`) is based on the official
> [LineageOS/android_kernel_xiaomi_sm6150](https://github.com/LineageOS/android_kernel_xiaomi_sm6150)
> `lineage-23.2` branch. It is **not** overclocked and does not relax any
> thermal, charging or voltage limits — see [Design limits](#design-limits).

## Features

Stage 1 (this release):

- **Base:** LineageOS `lineage-23.2`, kernel `4.14.357-openela` (latest 4.14 LTS).
- **Root:** [BakaSU](https://github.com/Baka-SU/BakaSU) (formerly **ReSukiSU**),
  tracking `main`. Two build variants, selectable per build:
  - **manual hook** (no SUSFS) — the default, validated variant.
  - **SUSFS inline hook** — experimental on 4.14 (see
    [SUSFS status](#susfs-status)).
- `path_umount()` backported from 5.9 (needed by the root module umount).
- `CONFIG_ZRAM_WRITEBACK` disabled (no extra UFS wear).
- `CONFIG_AUDIT`, `CONFIG_KALLSYMS`, `CONFIG_KALLSYMS_ALL` kept enabled.

Already present upstream (not re-added): `CONFIG_HZ=300`, PSI, WireGuard.

## Download

Builds are produced by the **Build minatok20** GitHub Actions workflow
(`workflow_dispatch`). Each run uploads an AnyKernel3 flashable zip plus a
`.sha256`, and can optionally publish a GitHub Release. The zip name encodes the
variant (`susfs` / `nosusfs`), date and source commit, e.g.
`minatok20-davinci-nosusfs-YYYYMMDD-<sha>.zip`. Each zip contains
`minatok20-build-info.txt` recording the exact source commit, BakaSU commit,
clang and AnyKernel3 versions.

## Flashing (LineageOS Recovery)

davinci is an **A-only** device (single `boot` partition, separate `dtbo`). This
kernel replaces only the kernel image and dtb in `boot`, and flashes `dtbo`; the
stock ramdisk is left untouched.

**Back up first (see [below](#backup-and-restore)).**

1. Reboot to recovery: `adb reboot recovery`, or hold **Power + Volume Up**.
2. In LineageOS Recovery: **Apply update → Apply from ADB**.
3. On the PC:
   ```bash
   adb sideload minatok20-davinci-<variant>-<date>-<sha>.zip
   ```
4. Recovery may warn about signature verification — that is expected for a custom
   zip; continue.
5. Reboot. First boot after a kernel change can take a few minutes.

After flashing root, install the **BakaSU manager** app to manage root.

## Backup and restore

Always keep a copy of your **stock `boot.img` and `dtbo.img`** so you can revert.

Back up (device booted, root or adb):
```bash
adb shell su -c "dd if=/dev/block/bootdevice/by-name/boot of=/sdcard/boot-stock.img"
adb shell su -c "dd if=/dev/block/bootdevice/by-name/dtbo of=/sdcard/dtbo-stock.img"
adb pull /sdcard/boot-stock.img
adb pull /sdcard/dtbo-stock.img
```

Restore (in fastboot) if something goes wrong:
```bash
fastboot flash boot boot-stock.img
fastboot flash dtbo dtbo-stock.img
fastboot reboot
```
The simplest full revert is to re-flash (dirty) the same LineageOS 23.2 build
you are on — that restores the stock kernel, dtb and dtbo.

## What to verify after flashing

- Boots to system.
- BakaSU manager shows the kernel as rooted (Working).
- Wi-Fi, mobile data / calls, camera, fingerprint all work.
- Standby battery drain is normal overnight.

## Design limits

Deliberately **not** changed, by request:

- No overclocking of CPU, GPU (GPU stays at stock, not the 730G 825 MHz) or
  display refresh rate.
- No relaxed thermal limits, no raised charge current, no voltage-table edits.
- No zram writeback; no swapfile on UFS.
- `CONFIG_AUDIT` / `CONFIG_KALLSYMS` / `CONFIG_KALLSYMS_ALL` kept.
- KGSL, qcacld-3.0 and other blob/firmware-coupled drivers are left on the ROM's
  versions (not upgraded).

## SUSFS status

BakaSU's SUSFS support targets the **SUSFS 2.4.0** kernel-side interface, which
upstream only ships for kernel **5.10+**. There is **no official or community
SUSFS 2.4.0 backport for 4.14**, so the kernel side was backported to this tree
specifically. It is **build-verified but not boot-verified** — treat the SUSFS
variant as experimental and keep the non-SUSFS zip as a fallback.

SUSFS 2.4.0 uses `thread_info.flags` and `address_space.flags` bits (64-bit on
arm64), so no new struct/KABI fields are needed.

Ported and enabled in the SUSFS variant:

- **sus_path** — hide user-defined files/paths from lookup.
- **spoof_uname** — spoof `uname`.
- **spoof_cmdline** — spoof `/proc/cmdline`.
- **hide_ksu_susfs_symbols** — hide ksu/susfs symbols from `/proc/kallsyms`.
- **enable_log**.
- Module/overlay mount hiding via BakaSU **try_umount** (backported
  `path_umount()`), instead of the sus_mount display-spoofing.

Intentionally left off on 4.14 (need a 4.14 kstat/statx or mount-namespace
reimplementation that is too bootloop-prone to ship unverified):

- **sus_kstat** (4.14 `struct kstat` has no `mnt_id`), **sus_map**,
  **open_redirect**, and the full **sus_mount** mnt_id-spoofing model.

## Credits

- [LineageOS](https://github.com/LineageOS) — kernel source and device trees.
- [BakaSU / ReSukiSU](https://github.com/Baka-SU/BakaSU),
  [SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra),
  [KernelSU](https://github.com/tiann/KernelSU) — root solution.
- [SUSFS](https://gitlab.com/simonpunk/susfs4ksu) by simonpunk — root hiding.
- [AnyKernel3](https://github.com/osm0sis/AnyKernel3) by osm0sis — flashable
  packaging.
- Sultan Alsawaf (kerneltoast) — performance/power patches (later stages).

## License

The Linux kernel and this project's kernel changes are licensed under
**GPL-2.0**; see [`COPYING`](../COPYING). Bundled components keep their own
licenses (AnyKernel3: MIT; KernelSU/BakaSU and SUSFS: GPL-2.0). All original
copyright and license headers are preserved.
