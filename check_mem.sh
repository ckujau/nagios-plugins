#!/bin/sh
#
# (c)2017 Christian Kujau <lists@nerdbynature.de>
#
# Nagios plugin to monitor the memory usage.
#
# There are plenty of Nagios plugins available that are tracking
# memory usage, all with various features and limits, see below.
# Since not every system had Perl installed, I basically needed
# a bourne shell version of check_mem.pl :-)
#
# * check_memory from nagios-plugins-contrib supports only
#   Linux and needs Perl and Nagios::Plugin to be installed.
#   https://repo.or.cz/thomas_code.git/blob/HEAD:/nagios/plugins/check_memory
#
# * check_memory.py supports only Linux and needs Python.
#   https://exchange.nagios.org/directory/Plugins/System-Metrics/Memory/Check_Memory-2Epy/details
#
# * check_mem.sh supports only Linux but needs only a Bourne shell to run.
#   https://exchange.nagios.org/directory/Plugins/System-Metrics/Memory/Check-mem-%28by-Nestor%40Toronto%29/details
#
# * check_memory.sh supports only Linux but needs only a Bourne shell to run.
#   https://exchange.nagios.org/directory/Plugins/Operating-Systems/Linux/check_memory-2Esh/details
#
# * check_mem supports only Linux and needs Perl and Nagios::Plugin to be installed.
#   https://github.com/jasonhancock/nagios-memory
#
# * check_mem.pl supports multiple operating systems but needs Perl installed.
#   https://github.com/justintime/nagios-plugins
#
# TODO:
# - Make it portable across as many systems as possible
# - Rework arguments passing
# - Fix performance data
#
if [ "$1" = "-w" ] && [ "$2" -gt "0" ] && [ "$3" = "-c" ] && [ "$4" -gt "0" ]; then
	warn=$2
	crit=$4
else
        echo "Usage: $(basename "$0") -w [percent] -c [percent]"
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
	 memUsed_kb=$((  memTotal_kb - memBuff_kb - memCache_kb))
	  memUsed_p=$((( memUsed_kb * 100) / memTotal_kb))
	else
	#
	# Also, since Linux 3.14 a new field "MemAvailable" has been introduced
	# into /proc/meminfo, so we could make use of that too.
	#
	# > MemAvailable metric for Linux kernels before 3.14 in /proc/meminfo
	# > https://blog.famzah.net/2014/09/24/memavailable-metric-for-linux-kernels-before-3-14-in-procmeminfo/
	#
	memAvail_kb=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
	 memUsed_kb=$((  memTotal_kb - memAvail_kb))
	  memUsed_p=$((( memUsed_kb * 100) / memTotal_kb))
	fi

	# Generate output and performance data
	O="Total: $(( memTotal_kb / 1024)) MB - Used: $(( memUsed_kb / 1024)) MB - $memUsed_p% used"
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
	memTotal_kb=$( $(/usr/sbin/sysctl -n hw.memsize) / 1024)
	  page_size=$(/usr/sbin/sysctl -n hw.pagesize)

	# As per the description above, we'll just assume that "used" memory is "active" memory.
	# The check_mem.pl script uses another metric (memTotal - memFree), but I don't care
	# for "free" memory, as this number should be close to zero anyway.
	 memUsed_kb=$(vm_stat | awk "/^Pages active:/     {print \$NF * $page_size / 1024}")
	  memUsed_p=$(( (memUsed_kb * 100) / memTotal_kb))

	  memAct_kb=$memUsed_kb
	memInact_kb=$(vm_stat | awk "/^Pages inactive:/   {print \$NF * $page_size / 1024}")
	memWired_kb=$(vm_stat | awk "/^Pages wired down:/ {print \$NF * $page_size / 1024}")
	 memFree_kb=$(vm_stat | awk "/^Pages free:/       {print \$NF * $page_size / 1024}")

	# Generate output and performance data
	O="Total: $(( memTotal_kb / 1024)) MB - Used: $(( memUsed_kb / 1024)) MB - $memUsed_p% used / Active: $(( memAct_kb / 1024)) MB / Inactive: $(( memInact_kb / 1024)) MB / Wired: $(( memWired_kb / 1024)) MB / Free: $(( memFree_kb / 1024)) MB"
	P="TOTAL=$memTotal_kb;;;; USED=$memUsed_kb;;;; ACTIVE=$memAct_kb;;;; INACTIVE=$memInact_kb;;;; WIRED=$memWired_kb;;;; FREE=$memFree_kb;;;;"
	;;

	*)
	echo "UNKNOWN: OS not supported: $(uname -s)"
	exit 3
	;;
esac

# DEBUG
# echo "memTotal_kb: $memTotal_kb - memBuff_kb: $memBuff_kb - memCache_kb: $memCache_kb - memUsed_kb: $memUsed_kb - memUsed_p: $memUsed_p"
# echo "memInact_kb: $memInact_kb - memInact_kb: $memInact_kb - memWired_kb: $memWired_kb - memFree_kb: $memFree_kb" 
# exit 100

# Check against thresholds
if   [ "$memUsed_p" -ge "$crit" ]; then
	echo "CRITICAL: $O|$P"
	exit 2

elif [ "$memUsed_p" -ge "$warn" ]; then
	echo "WARNING: $O|$P"
	exit 1

elif [ "$memUsed_p" -lt "$warn" ]; then
	echo "OK: $O|$P"
	exit 0
else
	echo "UNKNOWN: $O|$P"
	exit 3
fi
