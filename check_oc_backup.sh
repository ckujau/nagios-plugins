#!/bin/sh
#
# (c)2016 Christian Kujau <lists@nerdbynature.de>
#
# Check if our daily Owncloud Exports are somewhat complete and we're not too
# many records short, for various meanings of "too many".
#
# For this Nagios check to work, the export files are expected to look like this:
# - calendar-YYYY-mm-dd_NAME.ics
# - contacts-YYYY-mm-dd.vcf
#
# The Nagios user also needs permission to enter the backup directory:
# - setfacl -m u:naemon:x  ~user/{,misc/{,oc_backup}}
# - setfacl -m u:naemon:r  ~user/misc/oc_backup/*.{ics,vcf}		# Not needed for umask=0022
#

# FIXME: don't hard code our calendar names :-\
CALENDARS="default consol"

# Kill it with fire
_die() {
	echo "$1"
	exit "$2"
}

# FIXME: should this be parameterized?
STATEDIR=/var/lib/naemon/check_oc_backup
[ -d "$STATEDIR" ] || mkdir -m0700 "$STATEDIR" || _die "$STATEDIR could not be created!" 3

# Parsing options
while getopts "d:w:c:vuh" opt; do
	case $opt in
		d)
		DIR="$OPTARG"
		;;

		w)
		WARN="$OPTARG"
		;;

		c)
		CRIT="$OPTARG"
		;;

		v)
		VERBOSE=1
		;;

		u)
		UPDATE=1
		;;

		h)
		echo "$(basename $0) -d [dir] -w [deviate%] -c [deviate%] [-v] [-u]"
		;;
	esac
done

# Sanity checks
[ ! -d "$DIR" ] || [ -z "$WARN" ] || [ -z "$CRIT"  ] && _die "Missing arguments, bailing out." 3

# Initialze error values
ERR_CRIT=0
ERR_WARN=0

# Calendars
for CAL in $CALENDARS; do
	# Check if the .ics file exist, bail out if it doesn't.
	FILE="$DIR"/calendar-$(date +%Y-%m-%d)_"$CAL".ics
	[ -s "$FILE" ] && NUM=$(egrep -c '^BEGIN:VEVENT' "$FILE") || _die "Calendar "$FILE" not found!" 3
	if [ -f "$STATEDIR"/calendar_"$CAL".state ]; then
		OLDNUM=$(cat "$STATEDIR"/calendar_"$CAL".state)
		  DIFF=$(echo "scale=5; ($NUM - $OLDNUM) / $OLDNUM * 100" | bc -l | sed 's/^-//;s/^\./0./;s/\.[0-9]*//')
		[ "$VERBOSE" = "1" ] && echo "CAL: $CAL OLDNUM: $OLDNUM NUM: $NUM DIFF: $DIFF%"

		# Check if the difference is within our thresholds.
		if   [ $DIFF -ge $CRIT ]; then
			ERR_CRIT=$((ERR_CRIT+1))
			OUTPUT="${OUTPUT}cal: ${CAL} / old: ${OLDNUM} curr: ${NUM} diff: ${DIFF} "
		elif [ $DIFF -ge $WARN ]; then
			ERR_WARN=$((ERR_WARN+1))
			OUTPUT="${OUTPUT}cal: ${CAL} / old: ${OLDNUM} curr: ${NUM} diff: ${DIFF} "
		else
			:
		fi

		# Update state file with current value, if requested with -u
		if [ "$UPDATE" = "1" ]; then
			echo "Updating state file "$STATEDIR"/calendar_"$CAL".state as requested."
			echo "$NUM" > "$STATEDIR"/calendar_"$CAL".state
		fi
	else
		# Create a state file on the initial run
		echo "$NUM" > "$STATEDIR"/calendar_"$CAL".state || ERR_WARN=-100
	fi
done

# Contacts
# Note: we're only supporting ONE addressbook now.
for p in "$DIR"/contacts-$(date +%Y-%m-%d).vcf; do
	# Check if the .vcf file exist, bail out if it doesn't.
	[ -s "$p" ] && NUM=$(egrep -c '^FN' "$p") || _die "Contacts "$p" not found!" 3
	if [ -f "$STATEDIR"/contacts.state ]; then
		OLDNUM=$(cat "$STATEDIR"/contacts.state)
		  DIFF=$(echo "scale=5; ($NUM - $OLDNUM) / $OLDNUM * 100" | bc -l | sed 's/^-//;s/^\./0./;s/\.[0-9]*//')
		[ "$VERBOSE" = "1" ] && echo "CONTACTS: OLDNUM: $OLDNUM NUM: $NUM DIFF: $DIFF%"

		# Check if the difference is within our thresholds.
		if   [ $DIFF -ge $CRIT ]; then
			ERR_CRIT=$((ERR_CRIT+1))
			OUTPUT="${OUTPUT}contacts / old: ${OLDNUM} curr: ${NUM} diff: ${DIFF} "
		elif [ $DIFF -ge $WARN ]; then
			ERR_WARN=$((ERR_WARN+1))
			OUTPUT="${OUTPUT}contacts / old: ${OLDNUM} curr: ${NUM} diff: ${DIFF} "
		else
			:
		fi
		# Update state file with current value, if requested with -u
		if [ "$UPDATE" = "1" ]; then
			echo "$NUM" > "$STATEDIR"/contacts.state
			echo "Updating state file "$STATEDIR"/contacts.state as requested."
		fi
	else
		echo "$NUM" > "$STATEDIR"/contacts.state || ERR_WARN=-100
	fi
done

# Results
if   [ $ERR_CRIT -gt 0 ]; then
	echo "CRITICAL: $CRIT% threshold reached! - $OUTPUT"
	exit 2

elif [ $ERR_WARN -gt 0 ]; then
	echo "WARNING: $WARN% threshold reached! - $OUTPUT"
	exit 1

elif [ $ERR_CRIT -eq 0 ] && [ $ERR_WARN -eq 0 ]; then
	echo "OK: Thresholds are within expected levels."
	exit 0

else
	echo "UNKNOWN: Something wicked happened, bailing out!"
	exit 3
fi
