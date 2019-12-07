#!/bin/sh
#
# (c)2015 Christian Kujau <lists@nerdbynature.de>
# Nagios plugin to check for completed backups created with rsnapshot-wrapper.
#
# TODO: Check that enough hosts are being backed up!
#
CONFDIR="/etc/rsnapshot"
LOGFILE="/var/log/rsnapshot/rsnapshot-wrapper.log"

if [ -z "$1" ]; then
	echo "Usage: $(basename $0) [days]"
	exit 3
else
	DAYS="$1"
fi

# Let's create the date(1) strings to search for. It's messy, but it works
# with GNU/date
SEARCH=$(for i in `seq 0 $DAYS`; do
	date -d "${i} days ago" +%Y-%m-%d
done | xargs echo | sed 's/ /|/g')

ERR=0
for f in "$CONFDIR"/*.conf; do
	# Skip hosts where missing backups can be ignored.
	fgrep -q '##Nagios:check_rsnapshot-completed:ignore' "$f" && continue
	unset HOST NAME
	eval `awk -F\# '/^##HOST=/ {print $3}' "$f" | sed 's/PORT.*//'`

	# Sometimes NAME != HOST in the configuration file
	if [ -n "$NAME" ]; then
		host="$NAME"
	else
		host="$HOST"
	fi

	grep "$host" "$LOGFILE" | egrep 'finished|already has a daily backup from today' | egrep -q "^(${SEARCH})"
	if [ $? -ne 0 ]; then
		MSG="${MSG}$host "
		ERR=$((ERR+1))
	fi
done

IGN=" ($(fgrep -l '##Nagios:check_rsnapshot-completed:ignore' "$CONFDIR"/*.conf | wc -l) hosts ignored)"
case $ERR in
	0)
	echo "OK - Every host made a backup in the last $DAYS days.${IGN}"
	exit 0
	;;

	[1-9]*)
	echo "NOK: No backups found for the last $DAYS days for: $MSG ${IGN}"
	exit 2
	;;

	*)
	echo "UNKNOWN"
	;;
esac
