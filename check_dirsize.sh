#!/bin/sh
#
# (c)2015 Christian Kujau <lists@nerdbynature.de>
# Check on the size of a directory
#
usage() {
	echo "Usage: $0 [-w KB] [-c KB] [-d <directory>]"
	exit 3
}

while getopts "w:c:d:h" opt; do
        case $opt in
        w)
	warn=${OPTARG}
	;;

	c)
	crit=${OPTARG}
	;;

	d)
	 dir=${OPTARG}
	;;
	esac
done

# Sanity checks
[ -z "$warn" ] || [ -z "$crit" ] || [ ! -d "$dir" ] && usage

# FIXME: Can we make the call to du(1) portable across multiple platforms?
SIZE=$(du -skx "$dir" 2>/dev/null | awk '{print $1}')

if   [ $SIZE -le $crit ]; then
	echo "CRITICAL: directory $dir is smaller than $crit KB! ($SIZE KB)"
	exit 2

elif [ $SIZE -le $warn ]; then
	echo "WARNING: directory $dir is smaller than $warn KB! ($SIZE KB)"
	exit 1

elif [ $SIZE -gt $warn ]; then
	echo "OK: directory $dir is big enough. ($SIZE KB)"
	exit 0

else
	echo "UNKNOWN: directory $dir has an unknown size: $SIZE KB"
	exit 3
fi
