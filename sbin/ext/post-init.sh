#!/system/xbin/busybox sh

BB=/system/xbin/busybox

$BB mount -t rootfs -o remount,rw rootfs;
$BB mount -o remount,rw /system;
$BB mount -o remount,rw,nosuid,nodev /cache;
$BB mount -o remount,rw,nosuid,nodev /data;
$BB mount -o remount,rw /;

# set sysrq to 2 = enable control of console logging level
echo "2" > /proc/sys/kernel/sysrq;

# enable kmem interface for everyone
echo "0" > /proc/sys/kernel/kptr_restrict;

(
	$BB sh /sbin/ext/run-init-scripts.sh;
)&

# cleaning
$BB rm -rf /cache/lost+found/* 2> /dev/null;
$BB rm -rf /data/lost+found/* 2> /dev/null;
$BB rm -rf /data/tombstones/* 2> /dev/null;
$BB rm -rf /data/anr/* 2> /dev/null;

# mark boot completion
$BB touch /data/.bootcheck;
$BB echo "$(date)" > /data/.bootcheck;
