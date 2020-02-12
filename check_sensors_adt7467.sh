#!/bin/sh
#
# (c)2015 Christian Kujau <lists@nerdbynature.de>
# Check adt7467 sensor, which isn't supported by lm_sensors.
#
if [ $# -ne 6 ]; then
	echo "Usage: $(basename "$0") [fan_warn] [fan_crit] [s1_warn] [s1_crit] [s2_warn] [s2_crit]"
	exit 1
else
	FANSPEED_WARN=$1	#  max: 9000 (raw: 255)
	FANSPEED_CRIT=$2
	 SENSOR1_WARN=$3	# warn: 65, CPU TOPSIDE
	 SENSOR1_CRIT=$4	# crit: 70
	 SENSOR2_WARN=$5	# warn: 65, GPU ON DIE
	 SENSOR2_CRIT=$6	# crit: 70
fi

# This changed in Linux 3.19
LINUX_VERSION=$(uname -r | awk -F\. '{print $1.$2}' | cut -c-2)
if [ "$LINUX_VERSION" -lt 31 ]; then
	cd /sys/devices/temperatures || exit 3
else
	cd /sys/devices/platform/temperatures || exit 3
fi

FANSPEED=$(awk '{print $2}' sensor1_fan_speed | sed 's/^(//')	# RPM = ~35 * FANSPEED
 SENSOR1=$(cat sensor1_temperature)
 SENSOR2=$(cat sensor2_temperature)

### TODO: build $s_{WARN|CRIT} via shell magic, so that we can do:
#
# for s in FANSPEED SENSOR1 SENSOR2; do
#	if [ $s_WARN -lt ... ]
#

### FANSPEED
if   [ "${FANSPEED}" -ge "${FANSPEED_CRIT}" ]; then
	printf "%s" "CRITICAL: fanspeed=${FANSPEED} "
	ERROR_FANSPEED=2

elif [ "${FANSPEED}" -ge "${FANSPEED_WARN}" ]; then
	printf "%s" "WARNING: fanspeed=${FANSPEED} "
	ERROR_FANSPEED=1

elif [ "${FANSPEED}" -lt "${FANSPEED_WARN}" ]; then
	printf "%s" "OK: fanspeed=${FANSPEED} "
	ERROR_FANSPEED=0

else
	# We should never get here
	printf "%s" "UNKNOWN: fanspeed=${FANSPEED} "
	ERROR_FANSPEED=3
fi

### SENSOR1
if   [ "${SENSOR1}" -ge "${SENSOR1_CRIT}" ]; then
	printf "%s" "CRITICAL: sensor1=${SENSOR1} "
	ERROR_SENSOR1=2

elif [ "${SENSOR1}" -ge "${SENSOR1_WARN}" ]; then
	printf "%s" "WARNING: sensor1=${SENSOR1} "
	ERROR_SENSOR1=1

elif [ "${SENSOR1}" -lt "${SENSOR1_WARN}" ]; then
	printf "%s" "OK: sensor1=${SENSOR1} "
	ERROR_SENSOR1=0

else
	# We should never get here
	printf "%s" "UNKNOWN: sensor1=${SENSOR1} "
	ERROR_SENSOR1=3
fi

### SENSOR2
if   [ "${SENSOR2}" -ge "${SENSOR2_CRIT}" ]; then
	printf "%s" "CRITICAL: sensor2=${SENSOR2} "
	ERROR_SENSOR2=2

elif [ "${SENSOR2}" -ge "${SENSOR2_WARN}" ]; then
	printf "%s" "WARNING: sensor2=${SENSOR2} "
	ERROR_SENSOR2=1

elif [ "${SENSOR2}" -lt "${SENSOR2_WARN}" ]; then
	printf "%s" "OK: sensor2=${SENSOR2} "
	ERROR_SENSOR2=0

else
	# We should never get here
	printf "%s" "UNKNOWN: sensor2=${SENSOR2} "
	ERROR_SENSOR2=3
fi

### OUTPUT
printf "%s" ";|fanspeed=${FANSPEED}rpm;${FANSPEED_WARN};${FANSPEED_CRIT};0;9000 "
printf "%s"    "sensor1=${SENSOR1}C;${SENSOR1_WARN};${SENSOR1_CRIT};0;100 "
printf "%s"    "sensor2=${SENSOR2}C;${SENSOR2_WARN};${SENSOR2_CRIT};0;100\n"

#### ERROR handling
ERROR=$(printf "%s" $ERROR_FANSPEED $ERROR_SENSOR1 $ERROR_SENSOR2 | xargs -n1 | sort -n | tail -1)
exit "$ERROR"
