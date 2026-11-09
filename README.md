# minatok20 — Xiaomi Mi 9T / Redmi K20 (davinci) 自訂內核

以 **LineageOS 23.2（Android 16）** 為基底的 Xiaomi Mi 9T / Redmi K20（代號 **davinci**，Snapdragon 730 / sm6150，kernel 4.14）自訂內核。
內建 Root 與 SUSFS、一批安全的效能優化，並附一個有 WebUI 的「遊戲模式」模組。

> **核心原則：不超頻、不放寬溫控。** CPU、GPU、螢幕刷新率都維持原廠上限；不改電壓表、不提高充電電流。所有「效能」優化都是在原廠範圍內拉高「下限」或改善反應，不是拉高天花板。

---

## 這適合誰

- 想在 **LineageOS 23.2** 上有 **Root（BakaSU / 原 ReSukiSU）+ SUSFS 隱藏**的人。
- 想要**穩定、省電取向**的日常使用，同時在重度遊戲時自動加速。
- **不想超頻**、重視穩定與資料安全的人（本專案刻意排除超頻與高風險改動）。

硬體：Xiaomi Mi 9T / Redmi K20 **國際版 davinci**。data 分區為 f2fs（硬體加密）。

---

## 分支

| 分支 | 內容 |
|---|---|
| **`minatok20-susfs`**（預設） | 完整功能的超集。GitHub Actions 的 `SUSFS` 開關可編出「有 SUSFS」或「無 SUSFS（manual hook）」兩種變體。 |
| `minatok20` | 純基線（無 SUSFS 程式碼），當退路用。 |

所有 susfs 與優化程式碼都用 `#ifdef` / Kconfig 包起來，**可個別關閉**。

---

## 功能總覽

### 基礎
- 基底：LineageOS `lineage-23.2`，kernel **4.14.357-openela**（4.14 最新 LTS）。
- **Root：[BakaSU](https://github.com/Baka-SU/BakaSU)（原 ReSukiSU）**，追 `main`。
- **SUSFS v2.4.0**（手動 backport 到 4.14）：`sus_path`、`spoof_uname`、`spoof_cmdline`、`hide_ksu_susfs_symbols`、`enable_log`；掛載隱藏走 BakaSU 的 `try_umount`（backport 的 `path_umount`）。
- 保留 `CONFIG_AUDIT` / `CONFIG_KALLSYMS` / `CONFIG_KALLSYMS_ALL`；關 `CONFIG_ZRAM_WRITEBACK`。

### 安全優化（每項可獨立關閉，皆不超頻）
- **TCP BBR** 設為預設 + fq qdisc（WireGuard 本來就內建）。
- **zram 預設 lz4**（更快）。
- 關閉 **IPC logging**（降負擔；AUDIT/KALLSYMS/FTRACE 保留）。
- **Sultan `cpu_input_boost` + `devfreq_boost`**：觸控/亮螢幕時把 CPU 各 cluster 與 DDR 頻寬拉到**原廠滿速**（`min(freq, policy->max)` 夾限，不超頻）。
- **KCAL**：sysfs RGB/PCC 色彩校正（`/sys/class/kcal`…）。

### 遊戲模式模組（Magisk/KSU，有 WebUI）
位於 [`minatok20/gamemode/`](minatok20/gamemode)。偵測前景 App，對清單中的遊戲自動套用效能設定、退出還原（先快照原廠值再精準還原）：
- 大核 CPU / GPU / DDR 頻寬**下限**拉高（最高不動）。
- 降低 WALT `sched_upmigrate`/`downmigrate`，主執行緒更快上 A76 大核。
- top-app `schedtune.boost` + `prefer_idle`。
- GPU `idle_timer` 調低，負載上升更快拉頻。
- 硬體**觸控遊戲模式 / 高回報率**（透過新增的 `xiaomi_touch touch_mode` 節點）。
- 開機微調：**I/O 排程 `deadline`**（取代對快閃不利的 cfq）、**zram 3GB**（多工更少重載）。
- **WebUI**：勾選要當遊戲的 App、逐項開關功能、看目前狀態（BakaSU 管理器點模組即可開）。

---

## 主要改動與修正紀錄

### 內核端改動
- `ARM64: configs`：新增 `minatok20` / `minatok20_stage2` / `minatok20_susfs` config fragment。
- `fs/namespace`：backport `path_umount()`（來自 5.9）。
- `fs, kernel`：KSU manual hook 與 SUSFS inline hook（execveat / stat / faccessat / sys_read / setresuid / sys_reboot / input）。
- `fs/namei`：SUSFS `sus_path` hook（4.14 ENOENT 模型）。
- `fs/susfs.c` 等：SUSFS v2.4.0 核心端 backport 到 4.14（thread_info/i_mapping flags，無需新增 KABI 欄位）。
- `cpufreq / devfreq`：Sultan boost 驅動 + per-cluster cpu mask。
- `drm/msm/sde`：KCAL（PCC/RGB）。
- `input: xiaomi_touch`：新增 `touch_mode` sysfs 節點，讓腳本能開硬體遊戲模式/回報率（位於 `/sys/class/touch/touch_dev/touch_mode`）。

### 修過的 bug
- **SUSFS cmdline bootloop**：`cmdline.c` 誤用 1.5.8 的呼叫慣例呼叫 2.4.0 的 `susfs_spoof_cmdline_or_bootconfig`（void + static key），開機讀 `/proc/cmdline` 時 NULL deref → bootloop。已改為正確守衛。
- **AnyKernel3 刷機中止**：`supported.versions` 留空，停用在 Lineage Recovery sideload 會誤判的 Android 版本檢查。
- **管理器版本不符**：內核追 `main`，管理器 APK 需取自同一個 `main` CI build（官方 tag release 會落後）。
- **devfreq_boost 相依**：補 `struct devfreq` 的 `is_boost_device`/`max_boost`，並把缺少的 `kthread_run_perf_critical` 退回標準 kthread。
- **遊戲模組觸控路徑**：節點實際在 `touch_dev` class device 而非 platform device，已修正。

### 刻意不做（高風險 / 低效益，已評估）
- 超頻、放寬溫控、改電壓/充電電流（硬性限制）。
- **ThinLTO**：此 4.14 樹的舊式 gold-LTO 與 clang-21/lld 不相容。
- **SUSFS sus_kstat / sus_map / open_redirect / sus_mount 偽造模型**：4.14 的 `struct kstat` 無 `mnt_id`、mount 改寫易 bootloop。
- **f2fs-stable backport**：現有 f2fs 已穩定運作（含硬體加密），backport 風險是**資料損毀**，不划算。
- **MGLRU**：4.14 無上游、改動深、風險高、收益中等。
- **充電上限、音效增益、全局 Vulkan（HWUI skiavk）**：見 commit / 討論中的理由。

---

## 編譯（GitHub Actions）

`Build minatok20` workflow（`workflow_dispatch`）以 **AOSP clang-r563880c**（LineageOS 23.2 同版）編譯，附 ccache，用 **AnyKernel3** 打包成可 sideload 的 zip，可選發布 Release。輸入選項：BakaSU ref、SUSFS 開關、是否發布 Release。產物會附上對應原始碼 commit。

---

## 刷機（LineageOS Recovery）

davinci 為 **A-only**（單一 `boot` + 獨立 `dtbo`）。本內核只換 boot 內的內核與 dtb、刷 dtbo，**不動原廠 ramdisk**。

**先備份原廠 `boot.img` 與 `dtbo.img`。**

```bash
adb reboot recovery          # 或 電源 + 音量上
# Recovery: Apply update -> Apply from ADB
adb sideload minatok20-davinci-<variant>-<date>-<sha>.zip
```
Recovery 會提示簽章驗證失敗（自訂 zip 正常現象），繼續即可。刷完裝對應版本的 **BakaSU 管理器** 管理 root，再從管理器安裝 `minatok20-gamemode` 模組。

### 備份與還原
```bash
adb shell su -c "dd if=/dev/block/bootdevice/by-name/boot of=/sdcard/boot-stock.img"
adb shell su -c "dd if=/dev/block/bootdevice/by-name/dtbo of=/sdcard/dtbo-stock.img"
# 出問題時（fastboot）:
fastboot flash boot boot-stock.img
fastboot flash dtbo dtbo-stock.img
```

---

## Credits

- [LineageOS](https://github.com/LineageOS) — 內核源碼與 device tree
- [BakaSU / ReSukiSU](https://github.com/Baka-SU/BakaSU)、[SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra)、[KernelSU](https://github.com/tiann/KernelSU) — Root
- [SUSFS](https://gitlab.com/simonpunk/susfs4ksu)（simonpunk）— Root 隱藏
- [AnyKernel3](https://github.com/osm0sis/AnyKernel3)（osm0sis）— 打包
- Sultan Alsawaf（kerneltoast）— `cpu_input_boost` / `devfreq_boost`
- [kernel_xiaomi_surya](https://github.com/stormbreaker-project/kernel_xiaomi_surya)、[vantoman/kernel_xiaomi_sm6150](https://github.com/vantoman/kernel_xiaomi_sm6150) — boost / KCAL 移植參考

## 授權

Linux 內核與本專案的內核改動以 **GPL-2.0** 授權（見 [`COPYING`](COPYING)）。各元件保留其原始授權（AnyKernel3：MIT；KernelSU/BakaSU 與 SUSFS：GPL-2.0）。所有原始 copyright/授權標頭皆保留。
