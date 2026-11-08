### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers
## minatok20 for Xiaomi Mi 9T / Redmi K20 (davinci), LineageOS 23.2

### AnyKernel setup
# global properties
properties() { '
kernel.string=minatok20 kernel for Xiaomi Mi 9T (davinci)
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=davinci
device.name2=
device.name3=
device.name4=
device.name5=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties


### AnyKernel install
# boot shell variables
BLOCK=boot;
IS_SLOT_DEVICE=0;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# boot install: replace kernel (Image.gz) and dtb only, keep the stock ramdisk untouched
split_boot;
flash_boot;

# dtbo (built from the same kernel source)
flash_generic dtbo;
## end boot install
