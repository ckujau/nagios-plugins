#!/bin/sh
#
# FeeBSD Memory Plugin for Nagios
# 
# Copyright 2011 - eimar.koort@gmail.com
# Version: 0.7
# Date: 2013-02-12
#
# Based on: FBSD top command source code and 
# "OpenBSD Memory Plugin for Nagios"
# check_openbsd_mem.sh
# Copyright 2008 - patrick@pahem.de
#
# Description:
# This plugin checks the FreeBSD memory usage.
# You can set warningand critical 
# integer/precentage(%) values 
# with -w and -c. With -p you can output
# performance data and with -s generate alerts using 
# swap usage
#
# Install:
# Install the nagios-plugins package, copy
# the script to /usr/local/libexec/nagios/
# and set the executable bit.
#
# Example usage:
# /usr/local/libexec/nagios/check_fbsd_mem.sh -p -w 10% -c 15% swap
# Will produce following output:
# OK - Total: 2047M Used: 506M Active: 35M Inact: 156M  Wired: 239M Cache: 0M Buf: 213M Swap: 4096M SwUsed: 0M |FBSD_MEM=2047;506;35;156;239;0;213;4096;0
# 
# If using nagiosgraph then add something like that into map file:
## Service type: freebsd memory
## output: Total: 2047M Used: 508M Active: 35M Inact: 158M  Wired: 239M Cache: 0M Buf: 213M Swap: 4096M SwUsed: 0M
## perfdata: FBSD_MEM=2047;508;35;158;239;0;213;4096;0
#/perfdata:FBSD_MEM=([\d]+);([\d]+);([\d]+);([\d]+);([\d]+);([\d]+);([\d]+);\d+;([\d]+)/
#and push @s, [ 'ram',
#                [ 'total', GAUGE, $1*1024**2 ],
#                [ 'used', GAUGE, $2*1024**2 ],
#                [ 'act', GAUGE, $3*1024**2 ],
#                [ 'inact', GAUGE, $4*1024**2 ],
#                [ 'wired', GAUGE, $5*1024**2 ],
#                [ 'cache', GAUGE, $6*1024**2 ],
#                [ 'buf', GAUGE, $7*1024**2 ] ],
#        [ 'swap',
#                [ 'used', GAUGE, $8*1024**2 ],
#                ];
################################################
SYSCTL="/sbin/sysctl"
NAWK="/usr/bin/nawk"
GREP="/usr/bin/grep"
SED="/usr/bin/sed"
TOP="/usr/bin/top"
PSTAT="/usr/sbin/pstat"
#
PAGESIZE="`/usr/bin/pagesize`"
PROGNAME=$(echo $0 | ${NAWK} -F\/ '{ print $NF }')
LIBEXEC="/usr/local/libexec/nagios"
. $LIBEXEC/utils.sh

print_usage()
	{
	echo "Usage: $0 [-p] [-w <value>] [-c <value>] [swap]"
	echo "Usage: $0 -h"
	echo ""
	echo "Arguments:"
	echo "  -p"
	echo "    Output performance data"
	echo "  -w <value>"
	echo "    Generate warning state if used memory more than integer/percentage(%) value"
	echo "  -c <value>"
	echo "    Generate critical state if used memory more than integer/percentage(%) value"
	echo "  swap"
	echo "    alerts based on swap usage"
	echo " Note: <integer> values are in MB"
	echo ""
	}
print_help()
{
	echo "FeeBSD memory status plugin for Nagios"
	echo ""
	print_usage
}

while test -n "$1"; do
	case "$1" in
	-h)
		print_help
		exit $STATE_OK
	;;
	-w)
		if [ $(echo $2 | ${GREP} "%$") ]; then
			percent_warn=$2 
		else
			int_warn=$2
		fi
		shift
	;;
	-c)
		if [ $(echo $2 | ${GREP} "%$") ]; then
			percent_crit=$2 
		else
			int_crit=$2
		fi
		shift
	;;
	-p)
		perf=1
	;;
	swap) 
		measure_swap=1
	;;
	*)
		echo "Unknown argument: $1"
		print_usage
		exit $STATE_UNKNOWN
	;;
	esac
	shift
done

# calculate to megabytes
TO_MB=$((1024*1024))
# get total memory
TOTAL_RAM=$((`${SYSCTL} hw.realmem | ${NAWK} '{ print $2 }'`/$TO_MB))
# get active mem:
AM_COUNT="`${SYSCTL} vm.stats.vm.v_active_count |${NAWK} '{ print $2 }'`"
ACTIVE_MEM=$(($AM_COUNT*$PAGESIZE/$TO_MB))
#
IA_COUNT="`${SYSCTL} vm.stats.vm.v_inactive_count |${NAWK} '{ print $2 }'`"
INACT_MEM=$(($IA_COUNT*$PAGESIZE/$TO_MB))
# 
WIRED_COUNT="`${SYSCTL} vm.stats.vm.v_wire_count |${NAWK} '{ print $2 }'`"
WIRED_MEM=$(($WIRED_COUNT*$PAGESIZE/$TO_MB))
#
CACHE_COUNT="`${SYSCTL} vm.stats.vm.v_cache_count |${NAWK} '{ print $2 }'`"
CACHE_MEM=$(($CACHE_COUNT*$PAGESIZE/$TO_MB))
#
BUF_COUNT="`${SYSCTL} vfs.bufspace |${NAWK} '{ print $2 }'`"
BUF_MEM=$(($BUF_COUNT/$TO_MB))
#
FREE_COUNT="`${SYSCTL} vm.stats.vm.v_free_count |${NAWK} '{ print $2 }'`"
FREE_MEM=$(($FREE_COUNT*$PAGESIZE/$TO_MB))
#
USED_RAM=$(($TOTAL_RAM-$FREE_MEM))
#
SWAP_TOTAL=$(${PSTAT} -s -m | ${GREP} -v Device |${NAWK} '{ print $2 }')
SWAP_USED=$(${PSTAT} -s -m | ${GREP} -v Device |${NAWK} '{ print $3 }')
#

# checks -w and -c parameter and transform input
# percentage warning
if [ -n "$percent_warn" ]; then
	percent_warn=$(echo $percent_warn | ${SED} 's/%//g')
	if [ $percent_warn -gt 100 ]; then
		echo "Error: Percentage of warning (-w) over 100%."
		exit $STATE_UNKNOWN
	else
		WARN=$(($TOTAL_RAM*$percent_warn/100))
	fi
fi
# percentage critical
if [ -n "$percent_crit" ]; then
	percent_crit=$(echo $percent_crit | ${SED} 's/%//g')
	if [ $percent_crit -gt 100 ]; then
		echo "Error: Percentage of critical (-c) over 100%."
		exit $STATE_UNKNOWN
	else
		CRIT=$(($TOTAL_RAM*$percent_crit/100))
	fi
fi
# integer warning
if [ -n "$int_warn" ]; then
	WARN="$int_warn"
fi
# integer critical 
if [ -n "$int_crit" ]; then
	CRIT="$int_crit"
fi

# output with or without performance data
if [ "$perf" = 1 ]; then
	OUTPUT="Total: "$TOTAL_RAM"M Used: "$USED_RAM"M Active: "$ACTIVE_MEM"M Inact: "$INACT_MEM"M "
	OUTPUT="$OUTPUT Wired: "$WIRED_MEM"M Cache: "$CACHE_MEM"M Buf: "$BUF_MEM"M Swap: "$SWAP_TOTAL"M SwUsed: "$SWAP_USED"M"
	OUTPUT="$OUTPUT |FBSD_MEM=$TOTAL_RAM;$USED_RAM;$ACTIVE_MEM;$INACT_MEM;$WIRED_MEM;$CACHE_MEM;$BUF_MEM;$SWAP_TOTAL;$SWAP_USED"
else
	OUTPUT="Total: "$TOTAL_RAM"M Used: "$USED_RAM"M Active: "$ACTIVE_MEM"M Inact: "$INACT_MEM"M "
	OUTPUT="$OUTPUT Wired: "$WIRED_MEM"M Cache: "$CACHE_MEM"M Buf: "$BUF_MEM"M Swap: "$SWAP_TOTAL"M SwUsed: "$SWAP_USED"M"
fi

if [ "$measure_swap" = 1 ]; then
	# checks critical parameter if any specified
	if [ -n "$CRIT" ]; then
		if [ $SWAP_USED -gt $CRIT ]; then
			echo -n "CRITICAL - $OUTPUT"
			exit $STATE_CRITICAL
		fi
	fi
        if [ -n "$WARN" ];then
                if [ $SWAP_USED -gt $WARN ]; then
                        echo -n "WARNING - $OUTPUT"
                        exit $STATE_WARNING
                fi
        fi

else
	# checks critical parameter if any specified
	if [ -n "$CRIT" ]; then
		if [ $USED_RAM -gt $CRIT ]; then
			echo -n "CRITICAL - $OUTPUT"
			exit $STATE_CRITICAL
		fi
	fi
	# checks warning parameter if any specified
	if [ -n "$WARN" ];then
		if [ $USED_RAM -gt $WARN ]; then
			echo -n "WARNING - $OUTPUT"
			exit $STATE_WARNING
		fi
	fi 
fi
# output for STATE_OK
echo -n "OK - $OUTPUT"
exit $STATE_OK
