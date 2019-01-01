#!/bin/bash
# Generate AnyKernel2 Script

AK_DEV=$DEVICE

if [ "$AK_DEV" = "LMG710" ]; then
  DEV_NAME=JUDYLN
  DEV_NAME2=JUDY
fi

DEV_LOW=$(echo "$AK_DEV" | awk '{print tolower($0)}')
NAME_LOW=$(echo "$DEV_NAME" | awk '{print tolower($0)}')
NAME_LOW2=$(echo "$DEV_NAME2" | awk '{print tolower($0)}')

cat << EOF
# AnyKernel2 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() { '
kernel.string=$DEVICE mk2000
do.devicecheck=1
do.droidcheck=0
do.modules=1
do.ssdtrim=0
do.cleanup=1
do.cleanuponabort=0
device.name1=$AK_DEV
device.name2=$DEV_LOW
device.name3=$DEV_NAME
device.name4=$NAME_LOW
device.name5=$DEV_NAME2
device.name6=$NAME_LOW2
'; } # end properties

# shell variables
block=/dev/block/bootdevice/by-name/boot;
is_slot_device=0;
ramdisk_compression=auto;

## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. /tmp/anykernel/tools/ak2-core.sh;

## AnyKernel file attributes
# set permissions/ownership for included ramdisk files
chmod -R 750 \$ramdisk/*;
chown -R root:root \$ramdisk/*;

## AnyKernel install
dump_boot;

## Ramdisk modifications
# make sure adb is working, add mktweaks
patch_prop default.prop "ro.secure" "1";
patch_prop default.prop "ro.adb.secure" "1";
append_file init.rc mktweaks "init_rc-mod";

## System modifications
# disable rctd
mount -o rw,remount -t auto /system;
remove_section /vendor/etc/init/init.lge.rc "service rctd" " ";
mount -o ro,remount -t auto /system;

write_boot;
## end install
EOF
