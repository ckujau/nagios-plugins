#!/bin/sh
#
# (c)2016 Christian Kujau <lists@nerdbynature.de>
# Check for the last completed Crashplan Backup
#
# ACLs needed:
# > setfacl -m u:nrpe:x /opt/crashplan{,/cache{,/42}}
# > setfacl -m u:nrpe:r /opt/crashplan/cache/42/cp.properties
#
while getopts "f:w:c:" opt; do
	case $opt in
	f) file="$OPTARG" ;;
	w) warn="$OPTARG" ;;
	c) crit="$OPTARG" ;;
	esac
done

# Sanity checks
if [ ! -f "$file" ] || [ -z "$warn" ] || [ -z "$crit" ]; then
	echo "Usage: $(basename $0) -f [cp.properties] -w [hours] -c [hours]"
	exit 3
fi

# The cp.properties file appears to provide some status information, but
# it's not documented by Code42 nor does it seem to be well structured:
# $ cat ../cp.properties
# [...]
# lastCompletedBackupTimestamp_1=2017-02-14T23\:34\:26\:582
# lastCompletedBackupTimestamp=2017-02-14T23\:34\:26\:582
# lastBackupTimestamp=2017-02-14T23\:34\:26\:582
# lastBackupTimestamp_1=2017-02-14T23\:34\:26\:582
#
# Let's use "lastCompletedBackupTimestamp" for now, until it breaks.
last=$(date -d "$(awk -F= '/^lastCompletedBackupTimestamp=/ {print $2}' $file | sed 's|T| |;s|\\||g;s|:[0-9]*$||')" +%s)

# Get the current time & date in epoch time
curr=$(date +%s)

# Difference in hours (rounded down, w/o decimals)
diff=$((($curr - $last) / 60 / 60))

if   [ $diff -ge $crit ]; then
	echo "CRITICAL: Last backup completed $diff hours ago! ($(date -d @$last))"
	exit 2

elif [ $diff -ge $warn ]; then
	echo "WARNING: Last backup completed $diff hours ago! ($(date -d @$last))"
	exit 1

else
	echo "OK: Last backup completed $diff hours ago. ($(date -d @$last))"
	exit 0
fi
