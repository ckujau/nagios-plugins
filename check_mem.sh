#!/bin/sh
#
# (c)2017 Christian Kujau <lists@nerdbynature.de>
# (c)2012 Lukasz Gogolin <lukasz.gogolin@gmail.com>
#
# Nagios plugin to monitor the memory usage.
#
# TODO:
# - Documentation
# - Make it portable across as many systems as possible
# - Rework arguments passing
# - Fix performance data
#
if [ "$1" = "-w" ] && [ "$2" -gt "0" ] && [ "$3" = "-c" ] && [ "$4" -gt "0" ]; then
	warn=$2
	crit=$4
else
        echo "Usage: $(basename $0) -w [percent] -c [percent]"
        exit 3
fi

# Gather memory usage
case $(uname -s) in
	Linux)
	#
	# Memory usage is a complicated topic and Linux is no exception. While I
	# don't like parsing /proc files directly when we have a userspace
	# utility, it doesn't help when said utility changes its output:
	#
	# > free: remove -/+ buffers/cache
	# > https://gitlab.com/procps-ng/procps/commit/f47001c9e91a1e9b12db4497051a212cf49a87b1
	# memTotal_b=$(free -b | awk '/^Mem/ {print $2}')
	#  memBuff_b=$(free -b | awk '/^Mem/ {print $6}')
	# memCache_b=$(free -b | awk '/^Mem/ {print $7}')
	#
	# But since free(1) is only parsing /proc/meminfo too, we just cut out
	# the middleman here. Of course, if /proc/meminfo changes, we're screwed.
	#
	memTotal_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
	 memBuff_kb=$(awk '/^Buffers:/  {print $2}' /proc/meminfo)
	memCache_kb=$(awk '/^Cached:/   {print $2}' /proc/meminfo)

	if ! grep -q 'MemAvailable:' /proc/meminfo; then
	# Instead of using $3 from the free(1) output above, we'll calculate
	# the used memory ourselves:
	 memUsed_kb=$(($memTotal_kb - $memBuff_kb - $memCache_kb))
	  memUsed_p=$((($memUsed_kb * 100) / $memTotal_kb))
	else
	#
	# Also, since Linux 3.14 a new field "MemAvailable" has been introduced
	# into /proc/meminfo, so we could make use of that too.
	#
	# > MemAvailable metric for Linux kernels before 3.14 in /proc/meminfo
	# > https://blog.famzah.net/2014/09/24/memavailable-metric-for-linux-kernels-before-3-14-in-procmeminfo/
	#
	memAvail_kb=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
	 memUsed_kb=$(($memTotal_kb - $memAvail_kb))
	  memUsed_p=$((($memUsed_kb * 100) / $memTotal_kb))
	fi

	# Generate output and performance data
	O="Total: $(($memTotal_kb / 1024)) MB - Used: $(($memUsed_kb / 1024)) MB - $memUsed_p% used"
	P="TOTAL=$memTotal_kb;;;; USED=$memUsed_kb;;;; CACHE=$memCache_kb;;;; BUFFER=$memBuff_kb;;;;"
	;;

	Darwin)
	#
	# MacOS memory usage is explained in two articles:
	#
	# > Use Activity Monitor to read system memory and determine how much
	# > RAM is being used (OS X Mountain Lion and earlier)
	# > https://support.apple.com/en-us/HT201538
	#
	# > Use Activity Monitor on your Mac
	# > https://support.apple.com/en-us/HT201464
	#
	# A short summary of these entities would be:
	#
	# Free		- Amount of memory not being used.
	# Wired		- Memory that can't be swapped out.
	# Active	- Memory that has recently been used.
	# Inactive	- Memory that isn't actively used, though it was recently used.
	# Used		- Total amount of memory used.
	# VM size	- Total amount of virtual memory for all processes.
	# Page ins/outs	- Amount of memory swapped in/out (cumulative)
	# Swap used	- Amount of swapped out memory.
	#
	# We can use vm_stat(1) and top(1) to read out these values, in
	# particular:
	#
	# $ vm_stat 
	# [...]
	# Pages free:                          38944.
	# Pages active:                       279376.
	# Pages inactive:                     101957.
	# Pages wired down:                   101205.
	#
	# $ top -l 1 -n 1 | head 
	# MemRegions: 25772 total, 1066M resident, 12M private, 143M shared.
	# PhysMem: 396M wired, 1131M active, 372M inactive, 1899M used, 146M free.
	#
	memTotal_kb=$(expr $(/usr/sbin/sysctl -n hw.memsize) / 1024)
	  page_size=$(/usr/sbin/sysctl -n hw.pagesize)
	 memUsed_kb=$(vm_stat | awk "/^Pages active:/ {print \$NF * $page_size / 1024}")
	  memUsed_p=$((($memUsed_kb * 100) / $memTotal_kb))

	# FIXME!
	# Generate output and performance data
	O="Total: $(($memTotal_kb / 1024)) MB - Used: $(($memUsed_kb / 1024)) MB - $memUsed_p% used"
	P="TOTAL=$memTotal_kb;;;; USED=$memUsed_kb;;;; ACTIVE=$memActive_kb;;;; INACTIVE=$memInactive_kb;;;; WIRED=$memWired_kb;;;;"
	;;

	*)
	echo "UNKNOWN: OS not supported: $(uname -s)"
	exit 3
	;;
esac

# DEBUG
# echo "memTotal_kb: $memTotal_kb - memBuff_kb: $memBuff_kb - memCache_kb: $memCache_kb - memUsed_kb: $memUsed_kb - memUsed_p: $memUsed_p"
# exit 100

# Check against thresholds
if   [ "$memUsed_p" -ge "$4" ]; then
	echo "CRITICAL: $O|$P"
	exit 2

elif [ "$memUsed_p" -ge "$2" ]; then
	echo "WARNING: $O|$P"
	exit 1
elif [ "$memUsed_p" -lt "$2" ]; then
	echo "OK: $O|$P"
	exit 0
else
	echo "UNKNOWN: $O|$P"
	exit 3
fi
