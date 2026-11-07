# Redmi K20 / Mi 9T (`davinci`) — LineageOS 23.2 Custom Performance Kernel
### Snapdragon 730 (`SM7150-AA`) · Android 16 · Linux 4.14 Non-GKI · Adreno 618 825MHz · CASS · MGLRU · SukiSU-Ultra · SUSFS v1.5.5

[![License: GPL v2](https://img.shields.io/badge/License-GPL%20v2-blue.svg)](COPYING)
[![Build Davinci Kernel](https://github.com/20032773/android_kernel_xiaomi_sm6150/actions/workflows/build_davinci.yml/badge.svg)](https://github.com/20032773/android_kernel_xiaomi_sm6150/actions/workflows/build_davinci.yml)

---

## 1. 專案簡介 | Project Overview

**[繁體中文]**
本專案是專為 **Xiaomi Redmi K20 / Mi 9T（代號：`davinci` / `davinciin`，搭載高通 Snapdragon 730 `SM7150-AA` / `sdmmagpie` 平台）** 打造的深度優化自定義內核，基於 **LineageOS 23.2（Android 16，Linux 4.14 Non-GKI）** 官方內核基底開發。
設計核心聚焦於 **「原廠安全邊界內的硬體滿血解鎖 + 跨世代核心演算法移植 + 零耗損內核級 Root 與隱藏方案」**：在不超壓、不超頻螢幕刷新率、不犧牲待機續航（完整保留 KGSL 深度休眠）的前提下，釋放 Snapdragon 730G 原廠規格潛能並徹底消除滑動掉幀與 I/O 卡頓。

**[English]**
An optimized custom Linux 4.14 Non-GKI kernel for the **Xiaomi Redmi K20 / Mi 9T (`davinci` / `davinciin`, Qualcomm Snapdragon 730 `SM7150-AA` / `sdmmagpie`)** running **LineageOS 23.2 (Android 16)**.
Engineered around **safe hardware spec unlocking within Qualcomm factory voltage rails, next-generation scheduler/memory subsystem backports, and zero-overhead kernel root & filesystem stealth**—delivering smoother frame pacing, faster ZRAM/F2FS throughput, and uncompromised screen-off deep sleep battery life.

---

## 2. 修改與優化特性清單 | Features & Modifications (GPLv2 Disclosure)

依據 GNU GPLv2 第 2 條修改揭露規範，本倉庫相較於上游 `LineageOS/android_kernel_xiaomi_sm6150 (lineage-23.2)` 所作之完整架構與源碼修改如下：
In compliance with Section 2 of the GNU General Public License v2.0, all source, Device Tree, and configuration modifications over upstream `LineageOS/android_kernel_xiaomi_sm6150 (lineage-23.2)` are itemized below:

### A. Root 權限與內核級隱藏 | Root & Kernel-Level Hiding
- **SukiSU-Ultra (`v3.2.0` / `KSU_VERSION=13375`) Zero-Overhead Manual Hooks**：
  - 停用高開銷的 `KPROBES` 動態探針（`# CONFIG_KSU_KPROBES_HOOK is not set`），改於 `fs/exec.c`、`fs/open.c`、`fs/read_write.c`、`fs/stat.c` 與 `drivers/input/input.c` 實作原生零耗損 `CONFIG_KSU_MANUAL_HOOK=y`，並相容 LineageOS 23.2 (Android 16) 多重 LSM 安全模組堆疊架構。
  - Replaced dynamic `KPROBES` hooks with zero-overhead native C call-site Manual Hooks across VFS and input subsystems, adapted for LineageOS 23.2's stacked LSM credential model.
- **SUSFS `v1.5.5` (`kernel-4.14` branch)**：
  - 完整整合內核級隱藏框架（`CONFIG_KSU_SUSFS=y`），支援可疑路徑隱藏（`SUS_PATH`）、掛載點隱藏（`SUS_MOUNT`）、`kstat` 偽裝（`SUS_KSTAT`）、自動 `try_umount`、`uname` 與 `/proc/cmdline` 偽裝，以及自動隱藏 `/proc/kallsyms` 內核符號。
  - Integrated `susfs4ksu` (`v1.5.5`) supporting `SUS_PATH`, `SUS_MOUNT`, `SUS_KSTAT`, `TRY_UMOUNT`, `SPOOF_UNAME`, `/proc/cmdline` spoofing, and `/proc/kallsyms` symbol hiding.

### B. 安全邊界內的 GPU / CPU / DDR 設備樹與顯示管線調校 | Safe GPU, CPU, DDR & Display Pipeline Tuning
- **Adreno 618 解鎖 Snapdragon 730G (`SM7150-AB`) 原廠滿血規格 (825MHz)**：
  - 於 `arch/arm64/boot/dts/qcom/sdmmagpie-gpu.dtsi` 與 `davinci-sdmmagpie.dtsi` 解鎖高通原廠 `gpucc-sdmmagpie` 時脈表內建之 **750MHz (`TURBO`)** 與 **825MHz (`TURBO_L1`)** 檔位，嚴格遵循高通原廠安全電壓規範（絕不超壓、不超螢幕刷新率）。
  - 移除易造成桌面動畫起步掉幀的 `180MHz` 超低廢頻，將最低運作頻率提升至 **`267MHz` (`LOW_SVS`)**。
  - **完整保留 GPU 深度休眠 (`KGSL SLUMBER`)**，關屏待機零額外耗電；僅將 `idle-timeout` 由 `80ms` 微調至 **`64ms`**（約 4 幀緩衝），避免連續動畫期間 GPU 頻繁睡醒。
  - Unlocked Qualcomm's factory `SM7150-AB` (S730G) **750MHz (`TURBO`)** and **825MHz (`TURBO_L1`)** Adreno 618 OPPs using stock `gpucc-sdmmagpie` voltage corners, removed the `180MHz` stutter state (`267MHz` minimum active floor), preserved KGSL `SLUMBER` deep sleep, and tuned `idle-timeout` to `64ms`.
- **SDE 顯示合成執行緒即時優先級 (`SCHED_FIFO`)**：
  - 提升 `drivers/gpu/drm/msm/msm_drv.c` 中 `crtc_commit` 與 `crtc_event` 執行緒之 `SCHED_FIFO` 即時排程優先級（`20`），確保 VSync 畫面提交不受背景負載搶佔。
  - Elevated `crtc_commit` and `crtc_event` kthreads to `SCHED_FIFO` priority `20` for deterministic frame commit latency.
- **觸控輸入 CPU + LPDDR4X 記憶體頻寬同步喚醒 (`CPU & DDR Input Boost`)**：
  - 觸控互動瞬間提供 `64ms` 精準短脈衝：小核（CPU0–5, Cortex-A55）拉升至 `1.61GHz`、大核（CPU6–7, Cortex-A76）拉升至 `1.84GHz`，並同步喚醒 `qcom,cpu-llcc-ddr-bw` 記憶體匯流排至 `3879 MB/s`（對應 LPDDR4X `1017MHz`），脈衝結束立即釋放投票，絕不鎖死最高頻。
  - Synchronized 64ms touch boost (`1.61GHz` Little / `1.84GHz` Big + `3879 MB/s` `qcom,cpu-llcc-ddr-bw` DDR vote) with tuned compute-monitor DDR latency floors.

### C. 跨世代核心演算法與子系統優化 | Next-Gen Core Subsystems
- **Sultan's CASS 排程器 (`CONFIG_SCHED_CASS=y`)**：
  - 於 `kernel/sched/cass.c` 植入 Capacity Aware Superset Scheduler，針對 Kryo 470（2x Cortex-A76 + 6x Cortex-A55）將大小核視為單一容量標準化超集進行負載分配，兼顧低延遲與能效。
  - Ported Sultan's Capacity Aware Superset Scheduler (`kernel/sched/cass.c`) for unified big.LITTLE capacity-normalized task placement on Kryo 470.
- **MGLRU 多世代頁面回收 (`CONFIG_LRU_GEN=y`, `CONFIG_LRU_GEN_ENABLED=y`) & LZ4 ZRAM (`CONFIG_ZRAM_DEF_COMP_LZ4=y`)**：
  - 為 `mm/vmscan.c` 導入多世代頁面老化、`min_ttl_ms` 工作集防抖保護與 PID 缺頁回彈成本平衡模型，並提供 `/sys/kernel/mm/lru_gen/{enabled,min_ttl_ms}` 介面與 Android 16 `lmkd` 協同運作。
  - 將 ZRAM 預設壓縮演算法由 `lzo` 升級為極速 **`lz4`**，大幅降低小核 Swap 解壓縮延遲與 UFS 2.1 I/O 壓力。
  - Implemented Multi-Gen LRU aging, `min_ttl_ms` thrash protection, `/sys/kernel/mm/lru_gen` sysfs interface, and switched ZRAM's default compressor to `lz4`.
- **ARM64 CE 硬體加密加速、300Hz 計時器、TCP BBR 與 I/O 減負**：
  - 啟用 `CONFIG_CRYPTO_AES_ARM64_CE_BLK=y`、`CONFIG_CRYPTO_SHA2_ARM64_CE=y`、`CONFIG_CRYPTO_CHACHA20_NEON=y` 硬體指令集加速 F2FS 檔案加密讀寫。
  - 預設啟用 **300Hz Timer (`CONFIG_HZ_300=y`)** 與 **Google TCP BBR (`CONFIG_DEFAULT_BBR=y` + `FQ`)** 擁塞控制。
  - 預設關閉區塊裝置 `QUEUE_FLAG_IO_STAT` / `QUEUE_FLAG_ADD_RANDOM` 統計鎖開銷與 Binder 熱路徑除錯輸出。
  - Enabled ARMv8 Crypto Extensions + ChaCha20-NEON, 300Hz tick timer, TCP BBR + Fair Queueing, and disabled per-request block I/O stat accounting & hot-path Binder debug logging.

### D. 編譯器極限優化與拔除 Debug / Audit 追蹤開銷 | Compiler Optimization & Debug Stripping
- **Clang 20 + ThinLTO + Kryo 470 微架構調校**：
  - 啟用 `CONFIG_LTO_CLANG=y`、`CONFIG_THINLTO=y`、`CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y`，並搭配 `-O3 -mcpu=cortex-a76.cortex-a55 -mtune=cortex-a76.cortex-a55` 針對 Kryo 470 指令管線最佳化。
- **徹底拔除 Debug 與 Audit 開銷（完整保留 SELinux 與 Wi-Fi/DRM 所需之 `DEBUG_FS`）**：
  - 解耦 `SECURITY_SELINUX` 對 `AUDIT` 的依賴，在確保 Android 16 SELinux 正常運作的前提下，徹底關閉 `CONFIG_AUDIT`、`CONFIG_SLUB_DEBUG`、`CONFIG_FTRACE`、`CONFIG_KPROBES`、`CONFIG_SCHED_DEBUG`、`CONFIG_SCHEDSTATS`、`CONFIG_DEBUG_PREEMPT`、`CONFIG_CORESIGHT`、`CONFIG_BLK_DEV_IO_TRACE`、`CONFIG_MSM_TZ_LOG`、`CONFIG_PAGE_OWNER`、`CONFIG_LOCK_STAT`、`CONFIG_PROFILING` 與 `CONFIG_DEBUG_INFO`。

---

## 3. 免責聲明 | Disclaimer

```c
/*
 * Your warranty is now void.
 *
 * I am not responsible for bricked devices, dead SD cards,
 * thermonuclear war, or you getting fired because the alarm app failed. Please
 * do some research if you have any concerns about features included in this kernel
 * before flashing it! YOU are choosing to make these modifications, and if
 * you point the finger at me for messing up your device, I will laugh at you.
 */
```

**[繁體中文]**
刷入第三方自定義內核將使您的原廠保固失效。儘管本專案所有硬體頻率與電壓設定皆嚴格限制於高通原廠規範之安全邊界內，刷機仍具有潛在風險（包含但不限於無法開機、資料遺失或系統異常）。請在刷入前務必備份重要資料與原始 `boot.img` / `dtbo.img`，所有刷入與使用風險均由使用者自行承擔。

---

## 4. 開源協議聲明 | GPLv2 License & Compliance

**[繁體中文]**
本內核專案嚴格遵循 **GNU General Public License v2.0 (GPLv2)** 開源協議發布。根目錄下保留完整且未經修改之 [`COPYING`](COPYING) 授權條款全文。本專案用於建構刷機包（`Davinci-LOS23.2-825MHz-SukiSU-SUSFS.zip`）的所有核心源碼、驅動修改、Device Tree（`.dts` / `.dtsi`）、內核配置（`arch/arm64/configs/vendor/davinci.config`）及自動化編譯腳本皆完整且公開託管於本 GitHub 倉庫中，任何人皆可自由檢視、修改與重現編譯。

**[English]**
This kernel is distributed under the terms of the **GNU General Public License version 2 (GPL-2.0)** as published by the Free Software Foundation. The original, unmodified [`COPYING`](COPYING) license text is preserved in the root directory of this repository. All modified kernel sources, Device Tree sources, configuration fragments, and build scripts corresponding to distributed binaries are publicly available in full within this repository.

---

## 5. 致謝名單與上游連結 | Credits & Acknowledgments

本專案站在眾多優秀開源開發者與社群團隊的肩膀上完成，特此致上誠摯感謝：
Special thanks and full credit to the upstream projects and developers whose work made this kernel possible:

- **[LineageOS Team](https://github.com/LineageOS) & Xiaomi SM6150 Maintainers ([ArianK16a](https://github.com/ArianK16a), et al.)** — 提供穩定完善的 [`android_kernel_xiaomi_sm6150` (`lineage-23.2`)](https://github.com/LineageOS/android_kernel_xiaomi_sm6150) Android 16 內核基底與設備維護。
- **[Qualcomm (CAF / CodeLinaro CLO)](https://git.codelinaro.org/) & [OpenELA](https://openela.org/)** — 提供 Linux 4.14 LTS 內核維護與高通 `sdmmagpie` (`SM7150`) 底層硬體驅動支援。
- **[SukiSU-Ultra Developers](https://github.com/SukiSU-Ultra/SukiSU-Ultra) & [weishu (KernelSU)](https://github.com/tiann/KernelSU)** — 提供強大的內核級 Root 架構與針對 Non-GKI 4.14 內核的零耗損 Manual Hook 解決方案。
- **[simonpunk](https://gitlab.com/simonpunk/susfs4ksu)** — 提供 [`susfs4ksu` (SUSFS)](https://gitlab.com/simonpunk/susfs4ksu) 強大且精巧的內核級檔案系統與掛載隱藏補丁。
- **[Sultan (`kerneltoast`)](https://github.com/kerneltoast)** — 提供 Capacity Aware Superset Scheduler (CASS) 排程器演算法與行動平台效能調校靈感。
- **[osm0sis](https://github.com/osm0sis/AnyKernel3)** — 提供業界標準的 [`AnyKernel3`](https://github.com/osm0sis/AnyKernel3) 刷機包封裝框架。
- **[ZyCromerZ](https://github.com/ZyCromerZ/Clang)** — 提供預編譯最佳化的 [`ZyCromerZ Clang 20`](https://github.com/ZyCromerZ/Clang/releases) LLVM 工具鏈。

---

## 6. 編譯方式說明 | How to Build

### 方式一：GitHub Actions 雲端一鍵自動編譯（推薦 | Recommended）
本倉庫已內建完整的 GitHub Actions 雲端工作流 [`.github/workflows/build_davinci.yml`](.github/workflows/build_davinci.yml)：
1. Fork 本倉庫後，每當推送（`push`）至 `lineage-23.2` 分支，或前往 GitHub 頁面頂端 **Actions** 分頁選擇 **Build Redmi K20 (davinci) LOS 23.2 Kernel** 點擊 **Run workflow**（`workflow_dispatch`），即可自動在 `ubuntu-22.04` 雲端環境拉取 **ZyCromerZ Clang 20** 完成編譯。
2. 編譯完成後，於該次 Action 執行紀錄底部的 **Artifacts** 區塊即可直接下載可直接透過 Recovery（TWRP / OrangeFox）或 Kernel Flasher 刷入的 **`Davinci-LOS23.2-825MHz-SukiSU-SUSFS.zip`**。

### 方式二：本地 Linux 環境重現編譯（Local Reproducible Build）
```bash
# 1. Clone source
git clone --depth=1 -b lineage-23.2 https://github.com/20032773/android_kernel_xiaomi_sm6150.git
cd android_kernel_xiaomi_sm6150

# 2. Generate merged davinci configuration
make O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 CC=clang \
  CLANG_TRIPLE=aarch64-linux-gnu- \
  CROSS_COMPILE=aarch64-linux-gnu- \
  CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
  vendor/sdmsteppe-perf_defconfig vendor/davinci.config

# 3. Compile with Clang 20 + ThinLTO + Kryo 470 (-O3) flags
make -j$(nproc --all) O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 CC=clang \
  CLANG_TRIPLE=aarch64-linux-gnu- \
  CROSS_COMPILE=aarch64-linux-gnu- \
  CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
  KCFLAGS="-O3 -mcpu=cortex-a76.cortex-a55 -mtune=cortex-a76.cortex-a55 -Wno-error" \
  CFLAGS_KERNEL="-Wno-error" CFLAGS_MODULE="-Wno-error" \
  dtbs Image.gz
```
