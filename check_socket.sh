#!/bin/sh
#
# (c)2019 Christian Kujau <lists@nerdbynature.de>
#
# Similar to check_tcp and check_udp, we want to check if a UNIX domain socket
# is listening for connections. There is check_sockets.pl, but that only
# checks on the number of open sockets, not for a particular open socket.
#
if [ -z "$2" ]; then
	echo "Usage: $(basename $0) [path] [min] [max]"
	exit 1
else
	P="$1"			# We need the canonical path here.
	MIN="$2"
	MAX="$3"
fi

# Netstat (from net-tools) is obsolete, so let's use ss (from iproute2) now.
COUNT=$(ss -Hlx src $P | grep -c LISTEN)		# EOL printing in misc/ss.c workaround

# Needs more logic :-\
if   [ $COUNT -ge $MAX ]; then
	echo "CRITICAL: $COUNT sockets listening in $P"
	exit 2

elif [ $COUNT -lt $MIN ]; then
	echo "WARNING: $COUNT sockets listening in $P"
	exit 1

else
	echo "OK: $COUNT sockets listening in $P"
	exit 0
fi
