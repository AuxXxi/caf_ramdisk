#!/system/xbin/busybox sh

BB=/system/xbin/busybox

$BB mount -t rootfs -o remount,rw rootfs;
$BB mount -o remount,rw /system;

# set sysrq to 2 = enable control of console logging level
echo "2" > /proc/sys/kernel/sysrq;

# enable kmem interface for everyone
echo "0" > /proc/sys/kernel/kptr_restrict;

(
	$BB sh /sbin/ext/run-init-scripts.sh;
)&
