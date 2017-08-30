#!/bin/sh
#
# (c)2017 Christian Kujau <lists@nerdbynature.de>
#
# Check if our IP name space is still up and running and not
# leaking traffic.
#
URL="https://what.is.my/ip.jsp"			# Must return a our own IP address!

if [ -z "$1" ]; then
	echo "Usage: $(basename $0) [namespace]"
	exit 3
else
	NS="$1"
fi

IP_REAL=$(                  curl --connect-timeout 20 --silent "$URL")
 IP_VPN=$(ip netns exec $NS curl --connect-timeout 20 --silent "$URL")

if [ -z "$IP_REAL" ] || [ -z "$IP_VPN" ]; then
	echo "UNKNOWN: Cannot determine IP address."
	exit 3
fi

if [ "$IP_REAL" = "$IP_VPN" ]; then
	echo "CRITICAL: IP_REAL ($IP_REAL) == IP_VPN ($IP_VPN)"
	exit 2

else
	echo "OK: IP_REAL ($IP_REAL) != IP_VPN ($IP_VPN)"
	exit 0
fi
