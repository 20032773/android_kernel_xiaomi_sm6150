kernelsu-objs := ksu.o
kernelsu-objs += allowlist.o
kernelsu-objs += dynamic_manager.o
kernelsu-objs += apk_sign.o
kernelsu-objs += sucompat.o
kernelsu-objs += throne_tracker.o
kernelsu-objs += core_hook.o
kernelsu-objs += ksud.o
kernelsu-objs += embed_ksud.o
kernelsu-objs += kernel_compat.o
kernelsu-objs += throne_comm.o

ifeq ($(CONFIG_KSU_TRACEPOINT_HOOK), y)
kernelsu-objs += ksu_trace.o
endif

kernelsu-objs += selinux/selinux.o
kernelsu-objs += selinux/sepolicy.o
kernelsu-objs += selinux/rules.o
ccflags-y += -I$(srctree)/security/selinux -I$(srctree)/security/selinux/include
ccflags-y += -I$(objtree)/security/selinux -include $(srctree)/include/uapi/asm-generic/errno.h

obj-$(CONFIG_KSU) += kernelsu.o
obj-$(CONFIG_KSU_TRACEPOINT_HOOK) += ksu_trace_export.o

obj-$(CONFIG_KPM) += kpm/

KSU_VERSION := 13375
KSU_VERSION_FULL := v3.2.0-0af1ab28-susfs-v1.5.5
$(info -- SukiSU-Ultra version: $(KSU_VERSION) ($(KSU_VERSION_FULL)))

ccflags-y += -DKSU_VERSION=$(KSU_VERSION)
ccflags-y += -DKSU_VERSION_FULL=\"$(KSU_VERSION_FULL)\"

# Custom Signs
ifdef KSU_EXPECTED_SIZE
ccflags-y += -DEXPECTED_SIZE=$(KSU_EXPECTED_SIZE)
$(info -- Custom KernelSU Manager signature size: $(KSU_EXPECTED_SIZE))
endif

ifdef KSU_EXPECTED_HASH
ccflags-y += -DEXPECTED_HASH=\"$(KSU_EXPECTED_HASH)\"
$(info -- Custom KernelSU Manager signature hash: $(KSU_EXPECTED_HASH))
endif

ifdef KSU_MANAGER_PACKAGE
ccflags-y += -DKSU_MANAGER_PACKAGE=\"$(KSU_MANAGER_PACKAGE)\"
$(info -- SukiSU Manager package name: $(KSU_MANAGER_PACKAGE))
endif

ifeq ($(CONFIG_KSU_KPROBES_HOOK), y)
$(info -- SukiSU: CONFIG_KSU_KPROBES_HOOK)
else ifeq ($(CONFIG_KSU_TRACEPOINT_HOOK), y)
$(info -- SukiSU: CONFIG_KSU_TRACEPOINT_HOOK)
else ifeq ($(CONFIG_KSU_MANUAL_HOOK), y)
$(info -- SukiSU: CONFIG_KSU_MANUAL_HOOK)
endif

## For non-gki compatibility ##
ifeq ($(shell grep -q " current_sid(void)" $(srctree)/security/selinux/include/objsec.h; echo $$?),0)
ccflags-y += -DKSU_COMPAT_HAS_CURRENT_SID
endif

ifeq ($(shell grep -q "struct selinux_state " $(srctree)/security/selinux/include/security.h; echo $$?),0)
ccflags-y += -DKSU_COMPAT_HAS_SELINUX_STATE
endif

ccflags-y += -DKSU_UMOUNT

## For susfs stuff ##
ifeq ($(shell test -e $(srctree)/fs/susfs.c; echo $$?),0)
$(eval SUSFS_VERSION=$(shell grep -E '^#define SUSFS_VERSION' $(srctree)/include/linux/susfs.h | cut -d' ' -f3 | sed 's/"//g'))
$(info -- SUSFS_VERSION: $(SUSFS_VERSION))
endif

ccflags-y += -Wno-implicit-function-declaration -Wno-strict-prototypes -Wno-int-conversion -Wno-gcc-compat
ccflags-y += -Wno-declaration-after-statement -Wno-unused-function

# Keep a new line here!! Because someone may append config
