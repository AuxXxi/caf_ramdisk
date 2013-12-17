#!/system/xbin/busybox sh

BB=/system/xbin/busybox

# mount partitions to begin optimization
$BB mount -t rootfs -o remount,rw rootfs;
$BB mount -o remount,rw /system;
$BB mount -o remount,rw /;

# Avoid random freq behavior, apply stock freq behavior to begin with
echo "300000" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
echo "2265600" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
echo "interactive" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# remove previous bootcheck file
$BB rm -f /data/.bootcheck 2> /dev/null;
$BB ln -s /system/bin /bin
$BB ln -s /system/lib /lib

$BB mkdir /tmp;

# fix permissions for tmp init files
$BB chown -R root:system /tmp/;
$BB chmod -R 777 /tmp/;
$BB chmod 6755 /sbin/ext/*;
$BB chmod -R 777 /res/;

# oom and mem perm fix
$BB chmod 666 /sys/module/lowmemorykiller/parameters/cost;
$BB chmod 666 /sys/module/lowmemorykiller/parameters/adj;

# protect init from oom
echo "-1000" > /proc/1/oom_score_adj;

# set sysrq to 2 = enable control of console logging level
echo "2" > /proc/sys/kernel/sysrq;

PIDOFINIT=`pgrep -f "/sbin/ext/post-init.sh"`;
for i in $PIDOFINIT; do
	echo "-600" > /proc/${i}/oom_score_adj;
done;

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

# disable sysctl.conf to prevent ROM interference with tunables
[ -e /system/etc/sysctl.conf ] && mv /system/etc/sysctl.conf /system/etc/sysctl.conf.bak;

[ ! -f /data/.siyah/default.profile ] && cp -a /res/customconfig/default.profile /data/.siyah/default.profile;

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
	if [ "$frandom_module" == "on" ]; then
		echo "Loading FRANDOM Module" >> /data/nx_modules.log;
		$BB insmod /lib/modules/frandom.ko >> /data/nx_modules.log 2>&1;
		$BB chmod 644 /dev/frandom >> /data/nx_modules.log 2>&1;
		$BB chmod 644 /dev/erandom >> /data/nx_modules.log 2>&1;
		mv /dev/random /dev/random.ori >> /data/nx_modules.log 2>&1;
		mv /dev/urandom /dev/urandom.ori >> /data/nx_modules.log 2>&1;
		ln /dev/frandom /dev/random >> /data/nx_modules.log 2>&1;
		$BB chmod 644 /dev/random >> /data/nx_modules.log 2>&1;
		ln /dev/erandom /dev/urandom >> /data/nx_modules.log 2>&1;
		$BB chmod 644 /dev/urandom >> /data/nx_modules.log 2>&1;
	fi;
	if [ "$eds_module" == "on" ]; then
		insmod /lib/modules/eds.ko;
	fi;
	sleep 20;
	$BB date > /data/nx_modules.log
	echo " " >>  /data/nx_modules.log;
	# order of modules load is important
	if [ "$exfat_module" == "on" ]; then
		echo "Loading EXFAT Modules" >> /data/nx_modules.log;
		$BB insmod /lib/modules/exfat_fs.ko >> /data/nx_modules.log 2>&1;
		$BB insmod /lib/modules/exfat_core.ko >> /data/nx_modules.log 2>&1;
	fi;
	if [ "$frandom_module" == "on" ]; then
		echo "Loading FRANDOM Module" >> /data/nx_modules.log;
		$BB insmod /lib/modules/frandom.ko >> /data/nx_modules.log 2>&1;
		$BB chmod 644 /dev/frandom >> /data/nx_modules.log 2>&1;
		$BB chmod 644 /dev/erandom >> /data/nx_modules.log 2>&1;
		mv /dev/random /dev/random.ori >> /data/nx_modules.log 2>&1;
		mv /dev/urandom /dev/urandom.ori >> /data/nx_modules.log 2>&1;
		ln /dev/frandom /dev/random >> /data/nx_modules.log 2>&1;
		$BB chmod 644 /dev/random >> /data/nx_modules.log 2>&1;
		ln /dev/erandom /dev/urandom >> /data/nx_modules.log 2>&1;
		$BB chmod 644 /dev/urandom >> /data/nx_modules.log 2>&1;
	fi;
	if [ "$eds_module" == "on" ]; then
		insmod /lib/modules/eds.ko;
	fi;
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

# Apps Install
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
	UCI_PID=`pgrep -f "/res/uci.sh"`;
	echo "-800" > /proc/$UCI_PID/oom_score_adj;
	echo "1" > /tmp/uci_done;

	# restore all the PUSH Button Actions back to there location
	$BB mount -o remount,rw rootfs;
	$BB mv /res/no-push-on-boot/* /res/customconfig/actions/push-actions/;
	pkill -f "com.gokhanmoral.stweaks.app";
	$BB rm -f /data/.siyah/booting;

	COUNTER=0;
	while [ ! `cat /proc/loadavg | cut -c1-4` \< "3.50" ]; do
		if [ "$COUNTER" -ge "12" ]; then
			break;
		fi;
		echo "Waiting for CPU to cool down";
		sleep 10;
		COUNTER=$(($COUNTER+1));
	done;

	# correct oom tuning, if changed by apps/rom
	$BB sh /res/uci.sh oom_config_screen_on $oom_config_screen_on;
	$BB sh /res/uci.sh oom_config_screen_off $oom_config_screen_off;

	# Restart thermal engine and set correct frequencies;
	stop thermal-engine
	echo "$scaling_governor" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
	echo "$scaling_min_frequency" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq	
	echo "$scaling_max_frequency" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
	sleep 2
	start thermal-engine

	# mark boot completion
	$BB touch /data/.bootcheck;
	$BB echo "Boot completed on $(date)" > /data/.bootcheck;
)&

(
	# cleaning
	$BB rm -rf /cache/lost+found/* 2> /dev/null;
	$BB rm -rf /data/lost+found/* 2> /dev/null;
	$BB rm -rf /data/tombstones/* 2> /dev/null;
	$BB rm -rf /data/anr/* 2> /dev/null;

)&
