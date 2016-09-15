#!/bin/sh
#
# (c)2016 Christian Kujau <lists@nerdbynature.de>
# Nagios plugin to monitor the age of VirtualBox snapshots
#
# Note: Use sudo(1) to run this script for the user that uses VirtualBox machines!
#
# For example, if the user "alice" is using VirtualBox machines, the
# following rule will do the job in sudoers(1):
#
# nagios ALL=(alice) NOPASSWD: /usr/local/bin/check_vbox_snapshot_age.sh
#
if [ $# -lt 4 ]; then
	echo "Usage: $(basename $0) [-w days] [-c days]"
	exit 0
else
	# Convert days to seconds
	WARN="$(expr $2 \* 24 \* 60 \* 60)"
	CRIT="$(expr $4 \* 24 \* 60 \* 60)"
	 NOW=$(date +%s)
fi

CRITICAL=0
 WARNING=0
 UNKNOWN=0
      VM=0			# VM counter

for vm in $(vboxmanage list vms | awk '{print $1}' | sed 's|"||g'); do
	VM=$((VM+1))
	DIR=$(vboxmanage showvminfo "$vm" | awk '/^Snapshot folder/ {print $NF}')
	FILE=$(ls -t "$DIR"/*.sav 2>/dev/null | tail -1)	# Get the oldest snapshot

	# Go to the next VM if there's no snapshot to be found.	
	[ -f "$FILE" ] || continue

	MTIME=$(stat -c %Y "$FILE")
	  AGE=$(expr $NOW - $MTIME)
	 DAYS=$(expr $AGE / 60 / 60 / 24)			# Convert back to days

	# See if the file's age is within limits
	if   [ $AGE -ge $CRIT ]; then
		echo "CRITICAL: Snapshot for $vm ($FILE) is $DAYS days old!"
		CRITICAL=$((CRITICAL+1))

	elif [ $AGE -ge $WARN ]; then
		echo "WARNING: Snapshot for $vm ($FILE) is $DAYS days old!"
		 WARNING=$((WARNING+1))

	elif [ $AGE -lt $WARN ]; then
		echo "OK: Snapshot for $vm is $DAYS days old."
	
	else
		echo "UNKNOWN: Snapshot age for $vm ($FILE) could not be determined!"
		UNKNOWN=$((UNKNOWN+1))
	fi
done

# Sanity check
if [ $VM -eq 0 ]; then
	echo "UNKNOWN: no virtual machines were found!"
	exit 3
fi

# Nagios exit codes - order matters!
[ $CRITICAL -gt 0 ] && exit 2
[ $WARNING  -gt 0 ] && exit 1
[ $UNKNOWN  -gt 0 ] && exit 3

echo "OK: No old snapshots found."
exit 0
