#!/system/xbin/busybox sh

# Give device sufficient time to complete crucial loading
sleep 25;

BB=/system/xbin/busybox

$BB mount -t rootfs -o remount,rw rootfs;
$BB mount -o remount,rw /system;
$BB mount -o remount,rw,nosuid,nodev /cache;
$BB mount -o remount,rw,nosuid,nodev /data;
$BB mount -o remount,rw /;

$BB ln -s /system/xbin/busybox /sbin/busybox
$BB ln -s /system/bin /bin
$BB ln -s /system/lib /lib

# fix permissions for tmp init files
$BB chown -R root:system /tmp/;
$BB chmod -R 777 /tmp/;
$BB chmod 6755 /sbin/ext/*;
$BB chmod -R 777 /res/;

# set sysrq to 2 = enable control of console logging level
echo "2" > /proc/sys/kernel/sysrq;

# enable kmem interface for everyone
echo "0" > /proc/sys/kernel/kptr_restrict;

(
	$BB sh /sbin/ext/run-init-scripts.sh;
)&

if [ ! -d /data/.siyah ]; then
	$BB mkdir -p /data/.siyah;
fi;

# reset config-backup-restore
if [ -f /data/.siyah/restore_running ]; then
	rm -f /data/.siyah/restore_running;
fi;

ccxmlsum=`md5sum /res/customconfig/customconfig.xml | awk '{print $1}'`
if [ "a$ccxmlsum" != "a`cat /data/.siyah/.ccxmlsum`" ]; then
	rm -f /data/.siyah/*.profile;
	echo "$ccxmlsum" > /data/.siyah/.ccxmlsum;
fi;

[ ! -f /data/.siyah/default.profile ] && cp -a /res/customconfig/default.profile /data/.siyah/default.profile;
[ ! -f /data/.siyah/battery.profile ] && cp -a /res/customconfig/battery.profile /data/.siyah/battery.profile;
[ ! -f /data/.siyah/performance.profile ] && cp -a /res/customconfig/performance.profile /data/.siyah/performance.profile;
[ ! -f /data/.siyah/extreme_performance.profile ] && cp -a /res/customconfig/extreme_performance.profile /data/.siyah/extreme_performance.profile;
[ ! -f /data/.siyah/extreme_battery.profile ] && cp -a /res/customconfig/extreme_battery.profile /data/.siyah/extreme_battery.profile;

$BB chmod -R 0777 /data/.siyah/;

. /res/customconfig/customconfig-helper;
read_defaults;
read_config;

######################################
# Loading Modules
######################################
$BB chmod -R 755 /system/lib;

(
	sleep 10;
	$BB date > /data/nx_modules.log
	echo " " >>  /data/nx_modules.log;
	# order of modules load is important
	if [ "$exfat_module" == "on" ]; then
		echo "Loading EXFAT Modules" >> /data/nx_modules.log;
		$BB insmod /lib/modules/exfat_fs.ko >> /data/nx_modules.log 2>&1;
		$BB insmod /lib/modules/exfat_core.ko >> /data/nx_modules.log 2>&1;
	fi;
#	if [ "$frandom_module" == "on" ]; then
#		echo "Loading FRANDOM Module" >> /data/nx_modules.log;
#		$BB insmod /lib/modules/frandom.ko >> /data/nx_modules.log 2>&1;
#		$BB chmod 644 /dev/frandom >> /data/nx_modules.log 2>&1;
#		$BB chmod 644 /dev/erandom >> /data/nx_modules.log 2>&1;
#		mv /dev/random /dev/random.ori >> /data/nx_modules.log 2>&1;
#		mv /dev/urandom /dev/urandom.ori >> /data/nx_modules.log 2>&1;
#		ln /dev/frandom /dev/random >> /data/nx_modules.log 2>&1;
#		$BB chmod 644 /dev/random >> /data/nx_modules.log 2>&1;
#		ln /dev/erandom /dev/urandom >> /data/nx_modules.log 2>&1;
#		$BB chmod 644 /dev/urandom >> /data/nx_modules.log 2>&1;
#	fi;
	sleep 30;
	$BB date > /data/nx_modules.log
	echo " " >>  /data/nx_modules.log;
	# order of modules load is important
	if [ "$exfat_module" == "on" ]; then
		echo "Loading EXFAT Modules" >> /data/nx_modules.log;
		$BB insmod /lib/modules/exfat_fs.ko >> /data/nx_modules.log 2>&1;
		$BB insmod /lib/modules/exfat_core.ko >> /data/nx_modules.log 2>&1;
	fi;
#	if [ "$frandom_module" == "on" ]; then
#		echo "Loading FRANDOM Module" >> /data/nx_modules.log;
#		$BB insmod /lib/modules/frandom.ko >> /data/nx_modules.log 2>&1;
#		$BB chmod 644 /dev/frandom >> /data/nx_modules.log 2>&1;
#		$BB chmod 644 /dev/erandom >> /data/nx_modules.log 2>&1;
#		mv /dev/random /dev/random.ori >> /data/nx_modules.log 2>&1;
#		mv /dev/urandom /dev/urandom.ori >> /data/nx_modules.log 2>&1;
#		ln /dev/frandom /dev/random >> /data/nx_modules.log 2>&1;
#		$BB chmod 644 /dev/random >> /data/nx_modules.log 2>&1;
#		ln /dev/erandom /dev/urandom >> /data/nx_modules.log 2>&1;
#		$BB chmod 644 /dev/urandom >> /data/nx_modules.log 2>&1;
#	fi;
	echo " " >>  /data/nx_modules.log;
	echo " " >>  /data/nx_modules.log;
	echo "Loaded Modules on boot:" >> /data/nx_modules.log;
	echo " " >>  /data/nx_modules.log;
	$BB lsmod >> /data/nx_modules.log
)&


(
	if [ "$uksm_control" == "on" ]; then
		echo "1" > sys/kernel/mm/uksm/run
		echo "500" > /sys/kernel/mm/uksm/sleep_millisecs; # max: 1000
#		echo "quiet" > /sys/kernel/mm/uksm/cpu_governor;
		echo "UKSM IS ACTIVE";
	else
		echo "0" > sys/kernel/mm/uksm/run
		echo "UKSM IS DISABLED";
	fi;

)&

(
	sleep 35;
	if [ "$intelli_plug_active" == "1" ]; then
		echo "Intelliplug is active. Disabling mpdecision.";
		stop mpdecision;
	else
		echo "Intelliplug is inactive. Enabling mpdecision.";
#		stop mpdecision;
#		start mpdecision;
	fi;
)&

# Apps Install
# $BB sh /sbin/ext/install.sh;
chmod 755 /system/priv-app/NXTweaks.apk;

echo "0" > /tmp/uci_done;
chmod 666 /tmp/uci_done;

(
	# stop uci.sh from running all the PUSH Buttons in stweaks on boot
	$BB mount -o remount,rw rootfs;
	$BB chown -R root:system /res/customconfig/actions/;
	$BB chmod -R 6755 /res/customconfig/actions/;
	$BB mv /res/customconfig/actions/push-actions/* /res/no-push-on-boot/;
	$BB chmod 6755 /res/no-push-on-boot/*;

	# apply NXTweaks settings
	echo "booting" > /data/.siyah/booting;
	chmod 777 /data/.siyah/booting;
	pkill -f "com.gokhanmoral.stweaks.app";
	nohup $BB sh /res/uci.sh restore;
	echo "1" > /tmp/uci_done;

	# restore all the PUSH Button Actions back to there location
	$BB mount -o remount,rw rootfs;
	$BB mv /res/no-push-on-boot/* /res/customconfig/actions/push-actions/;
	pkill -f "com.gokhanmoral.stweaks.app";
	$BB rm -f /data/.siyah/booting;

	mount -o remount,rw /system;
	mount -o remount,rw /;

	# mark boot completion
	$BB touch /data/.bootcheck;
	$BB echo "Boot completed on $(date)" > /data/.bootcheck;
)&

# cleaning
$BB rm -rf /cache/lost+found/* 2> /dev/null;
$BB rm -rf /data/lost+found/* 2> /dev/null;
$BB rm -rf /data/tombstones/* 2> /dev/null;
$BB rm -rf /data/anr/* 2> /dev/null;
