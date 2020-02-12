#!/bin/sh
#
# (c)2014 Christian Kujau <lists@nerdbynature.de>
# check_swap for macOS
#
usage() {
	echo "Usage: $(basename "$0") -w WARN% -c CRIT%"
	exit "$1"
}

while getopts ":h:w:c:" opt; do
	case $opt in
	h) usage 0 ;;
	w) WARN="$OPTARG" ;;
	c) CRIT="$OPTARG" ;;
	:|*) echo "Option -$OPTARG requires an argument." && usage 2 ;;
	esac
done

# Are we on macOS at all?
[ "$(uname -s)" = "Darwin" ] || exit 3

# Both options need an argument
[ -z "$WARN" ] || [ -z "$CRIT" ] && usage 2

# vm_stat prints its output in pages, so we need the page size
PAGE_SIZE=$(getconf PAGE_SIZE)

# From the vm_stat(1) man page:
#
# Pages free     - the total number of free pages in the system.
# Pages active   - the total number of pages currently in use and pageable.
# Pages inactive - the total number of pages on the inactive list.
# Pages wired    - the total number of pages wired down. That is, pages that cannot be paged out.
#

# vm_stat parsed, in MB
# TODO: use awk(1) to parse those outputs!
eval "$(vm_stat | awk "/^Pages (free|active|inactive|wired)/ {print \$2, \$NF * $PAGE_SIZE / 1024 / 1024}" | sed 's/://;s/ /=/')"

# total memory installed, in MB
memsize=$(sysctl hw.memsize | awk '{print $2/1024/1024 }')

# save a summary
summary="free: $free MB, active: $active MB, inactive: $inactive MB, wired: $wired MB, memsize: $memsize MB"

#
# FIXME: Now we have all the values, but how much "free" memory is too little? How much
# "wired" memory is too much? Let's just add active+inactive+wired and see how much
# "free" memory is left.
#
# p_free=$(echo "scale=2; $free / ( $active + $inactive + $wired) * 100" | bc -l)
#
# Update #1: Of course, we don't care about "free" memory ("free memory is wasted memory"), but
# we might care about how much memory is "active" in relation to the system's total available
# memory.
#
# p_used=$(echo "scale=2; $active / $memsize * 100" | bc -l)
#
# Update #2: As it turns out, the "active" memory is unusable nowadays and we'll try again with
# how much memory is "wired" in relation to the system's total available memory.
#
p_used=$(echo "scale=2; $wired / $memsize * 100" | bc -l)

# Less than 0% used memory?
if   [ "$(echo "$p_used" \<= 0 | bc)" = 1 ]; then
	echo "UNKNOWN: ${p_used}% used memory - $summary"
	exit 3

# Less than WARN% used memory?
elif [ "$(echo "$p_used" \< "$WARN" | bc)" = 1 ]; then
	echo "OK: ${p_used}% used memory - $summary"
	exit 0

# Less than CRIT% used memory?
elif [ "$(echo "$p_used" \< "$CRIT" | bc)" = 1 ]; then
	echo "WARNING: ${p_used}% used memory - $summary"
	exit 1

# More than CRIT% used memory?
elif [ "$(echo "$p_used" \>= "$CRIT" | bc)" = 1 ]; then
	echo "CRITICAL: ${p_used}% used memory - $summary"
	exit 2
fi
