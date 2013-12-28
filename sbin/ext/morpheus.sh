#!/sbin/busybox sh

mount -o remount,rw /;
chmod -R 777 /tmp/;

# ==============================================================
# GLOBAL VARIABLES || without "local" also a variable in a function is global
# ==============================================================

FILE_NAME=$0;
NOW_CALL_STATE=0;
TELE_DATA=init;
DATA_DIR=/data/.siyah;

# ==============================================================
# INITIATE
# ==============================================================

# get values from profile
PROFILE=$(cat $DATA_DIR/.active.profile);
. "$DATA_DIR"/"$PROFILE".profile;

# check if dumpsys exist in ROM
if [ -e /system/bin/dumpsys ]; then
	DUMPSYS_STATE=1;
else
	DUMPSYS_STATE=0;
fi;

CALL_STATE()
{
	if [ "$DUMPSYS_STATE" -eq "1" ]; then

		# check the call state, not on call = 0, on call = 2
		local state_tmp=$(echo "$TELE_DATA" | awk '/mCallState/ {print $1}');

		if [ "$state_tmp" != "mCallState=0" ]; then
			NOW_CALL_STATE=1;
		else
			NOW_CALL_STATE=0;
		fi;

		log -p i -t "$FILE_NAME" "*** CALL_STATE: $NOW_CALL_STATE ***";
	else
		NOW_CALL_STATE=0;
	fi;
}

CPUFREQ_FIX()
{
	local state="$1";

	if [ "$state" == "awake" ]; then
		echo "$scaling_governor" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
		echo "$scaling_min_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
		if [ "$scaling_max_freq" -eq "2265600" ] && [ "$scaling_max_freq_oc" -gt "2265600" ]; then
			MAX_FREQ="$scaling_max_freq_oc";	
		else
			MAX_FREQ="$scaling_max_freq";
		fi;
		echo "$MAX_FREQ" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
		echo "$scheduler" > /sys/block/mmcblk0/queue/scheduler
	elif [ "$state" == "sleep" ]; then
		echo "$scaling_suspend_governor" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
		echo "$scaling_min_suspend_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq	
		echo "$scaling_max_suspend_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
		echo "$suspend_scheduler" > /sys/block/mmcblk0/queue/scheduler
	fi;

	log -p i -t "$FILE_NAME" "*** CPU FREQ IMMUNIZED FOR $state MODE ***";
}

THERMAL_FIX()
{
	local state="$1";

	echo "$freq_step" > /sys/module/msm_thermal/parameters/freq_step

	if [ "$state" == "awake" ]; then
		echo "$limit_temp" > /sys/module/msm_thermal/parameters/limit_temp
		echo "$core_limit_temp" > /sys/module/msm_thermal/parameters/core_limit_temp	
	elif [ "$state" == "sleep" ]; then
		echo "$limit_temp_suspend" > /sys/module/msm_thermal/parameters/limit_temp
		echo "$core_limit_temp_suspend" > /sys/module/msm_thermal/parameters/core_limit_temp	
	fi;

	echo "$temp_hysteresis" > /sys/module/msm_thermal/parameters/temp_hysteresis
	echo "$core_temp_hysteresis" > /sys/module/msm_thermal/parameters/core_temp_hysteresis

	log -p i -t "$FILE_NAME" "*** THERMAL CONTROL IMMUNIZED FOR $state MODE ***";
}

# disable/enable ipv6
IPV6()
{
	local state='';

	if [ -e /data/data/com.cisco.anyconnec* ]; then
		local CISCO_VPN=1;
	else
		local CISCO_VPN=0;
	fi;

	if [ "$morpheus_ipv6" == "on" ] || [ "$CISCO_VPN" -eq "1" ]; then
		echo "0" > /proc/sys/net/ipv6/conf/wlan0/disable_ipv6;
		sysctl -w net.ipv6.conf.all.disable_ipv6=0 > /dev/null;
		local state="enabled";
	else
		echo "1" > /proc/sys/net/ipv6/conf/wlan0/disable_ipv6;
		sysctl -w net.ipv6.conf.all.disable_ipv6=1 > /dev/null;
		local state="disabled";
	fi;

	log -p i -t "$FILE_NAME" "*** IPV6 ***: $state";
}

UKSMCTL()
{
	local state="$1";
	local uksm_run_tmp="/sys/kernel/mm/uksm/run";
	if [ ! -e "$uksm_run_tmp" ]; then
		uksm_run_tmp="/dev/null";
	fi;

	if [ "$uksm_control" == "on" ] && [ "$uksm_run_tmp" != "/dev/null" ]; then
		echo "1" > "$uksm_run_tmp";
		renice -n 10 -p "$(pidof uksmd)";

		if [ "$state" == "awake" ]; then
			echo "500" > /sys/kernel/mm/uksm/sleep_millisecs; # max: 1000

			log -p i -t "$FILE_NAME" "*** uksm: awake mode ***";

		elif [ "$state" == "sleep" ]; then
			echo "1000" > /sys/kernel/mm/uksm/sleep_millisecs; # max: 1000

			log -p i -t "$FILE_NAME" "*** uksm: sleep mode ***";
		fi;
	else
		echo "0" > "$uksm_run_tmp";
	fi;
}


# ==============================================================
# TWEAKS: if Screen-ON
# ==============================================================
AWAKE_MODE()
{
	# Do not touch this
#	CALL_STATE;
	CPUFREQ_FIX "awake";
	THERMAL_FIX "awake";
	UKSMCTL "awake";
}

# ==============================================================
# TWEAKS: if Screen-OFF
# ==============================================================
SLEEP_MODE()
{

	# we only read the config when the screen turns off
	PROFILE=$(cat "$DATA_DIR"/.active.profile);
	. "$DATA_DIR"/"$PROFILE".profile;

	# Do not touch this
#	CALL_STATE;
	CPUFREQ_FIX "sleep";
	THERMAL_FIX "sleep";
	IPV6;
	UKSMCTL "sleep";
}


# ==============================================================
# Background process to check screen state
# ==============================================================

# Dynamic value do not change/delete
morpheus_background_process=1;

if [ "$morpheus_background_process" -eq "1" ] && [ "$(pgrep -f "/sbin/ext/morpheus.sh" | wc -l)" -eq "2" ]; then
	(while true; do
		while [ "$(cat /sys/kernel/power_suspend/power_suspend_state)" != "0" ]; do
			sleep "2";
		done;
		# AWAKE State. All system ON
		AWAKE_MODE;

		while [ "$(cat /sys/kernel/power_suspend/power_suspend_state)" != "1" ]; do
			sleep "2";
		done;
		# SLEEP state. All system to power save
		SLEEP_MODE;
	done &);
else
	if [ "$morpheus_background_process" -eq "0" ]; then
		echo "Morpheus mode disabled!"
	else
		echo "Morpheus is watching you!";
	fi;
fi;

