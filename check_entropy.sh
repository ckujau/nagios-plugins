#!/bin/sh
#
# (c)2014 Christian Kujau <lists@nerdbynature.de>
# Nagios plugin to check kernel.random.entropy_avail
#
# Similar plugins exist, but all seemed overly complicated and a bourne shell
# version is nice because it doesn't need Perl or Python installed.
#
#   Perl: https://www.unixadm.org/software/nagios-stuff/checks/check_entropy
# Python: https://salsa.debian.org/dsa-team/mirror/dsa-nagios/blob/master/dsa-nagios-checks/checks/dsa-check-entropy
#
while getopts ":w:c:" opt; do
	case $opt in
		w) warn=$OPTARG ;;
		c) crit=$OPTARG ;;
		*) exit 3 ;;
	esac
done

# Both warn and crit are needed
if [ -z "$warn" ] || [ -z "$crit" ]; then
	echo "Usage: $(basename "$0") -w num -c num"
	exit 3
fi

# warn should be greater than crit	
if [ "$warn" -lt "$crit" ]; then
	echo "UNKNOWN: warn ($warn) < crit ($crit)"
	exit 3
fi

# TODO: how about other operating systems?
ENTROPY=$(/sbin/sysctl -n kernel.random.entropy_avail)
if [ "$ENTROPY" -lt "$crit" ]; then
	echo "CRITICAL: Too little entropy ($ENTROPY) in the pool (warn: $warn, crit: $crit)"
	exit 2
elif [ "$ENTROPY" -lt "$warn" ]; then
	echo "WARNING: Too little entropy ($ENTROPY) in the pool (warn: $warn, crit: $crit)"
	exit 2
else
	echo "OK: $ENTROPY bytes in the pool."
	exit 0
fi
