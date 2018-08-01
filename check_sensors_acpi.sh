#!/bin/sh
#
# (c)2018 Christian Kujau <lists@nerdbynature.de>
#
# When lm_sensors is unable to find any sensors:
#
# > yes | sensors-detect
#  [...]
#  Sorry, no sensors were detected.
#  This is relatively common on laptops, where thermal management is
#  handled by ACPI rather than the OS.
#
#
if [ $# -ne 6 ]; then
	echo "Usage: $(basename $0) [batt_warn] [batt_crit] [pwr_warn] [pwr_crit] [temp_warn] [temp_crit]"
	echo "   Ex: $(basename $0) 30 20 on-line on-line 30 35"
	exit 1
else
	BATT_WARN="$1"
	BATT_CRIT="$2"
	 PWR_WARN="$3"
	 PWR_CRIT="$4"
	TEMP_WARN="$5"
	TEMP_CRIT="$6"
fi

# statefile
TEMP=$(mktemp)
trap "rm -f $TEMP" EXIT INT TERM HUP

# Grab ACPI output
acpi -V > "$TEMP" || exit 3

# Battery / Adapter / Thermal
BATT_STATE=$(awk '/^Battery.*last full/ {print $NF}' $TEMP | sed 's/%//')
 PWR_STATE=$(awk '/Adapter/ {print $NF}' $TEMP)
TEMP_STATE=$(awk '/Thermal/ {print $4}' $TEMP | head -1 | sed 's/\.[0-9]$//')

# DEBUG
# echo "batt: $BATT_STATE pwr: $PWR_STATE temp: $TEMP_STATE"

# Battery
if   [ "$BATT_STATE" -lt "$BATT_CRIT" ]; then
	printf "CRITICAL: battery=$BATT_STATE "
	ERROR_BATTERY=2

elif [ "$BATT_STATE" -lt "$BATT_WARN" ]; then
	printf "WARNING: battery=$BATT_STATE "
	ERROR_BATTERY=1
else
	printf "OK: battery=$BATT_STATE "
	ERROR_BATTERY=0
fi

# Adapter (no WARNING?)
if   [ "$PWR_STATE" != "on-line" ]; then
	printf "CRITICAL: adapter=$PWR_STATE "
	ERROR_ADAPTER=2
else
	printf "OK: adapter=$PWR_STATE "
	ERROR_ADAPTER=0
fi

# Temperature
if   [ "$TEMP_STATE" -gt "$TEMP_CRIT" ]; then
	printf "CRITICAL: temperature=$TEMP_STATE "
	ERROR_TEMP=2

elif [ "$TEMP_STATE" -gt "$TEMP_WARN" ]; then
	printf "WARNING: temperature=$TEMP_STATE "
	ERROR_TEMP=1
else
	printf "OK: temperature=$TEMP_STATE "
	ERROR_TEMP=0
fi

echo
# Error handling
ERROR=$(echo $ERROR_BATTERY $ERROR_ADAPTER $ERROR_TEMP | xargs -n1 | sort -n | tail -1)
exit $ERROR
