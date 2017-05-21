#!/bin/sh
#
# (c)2015 Christian Kujau <lists@nerdbynature.de>
# Nagios check for software updates with various package managers.
#
RESULT=$(mktemp 2>/dev/null || mktemp -t check_softwareupdate)		# MacOS prior to 10.11 needs an argument.
trap "rm -f $RESULT" EXIT INT TERM HUP

ERR=3
case $1 in
	dnf)
	# FIXME: This check isn't working right now, probably due to
	# RH# 1422381 / https://bugzilla.redhat.com/show_bug.cgi?id=1422381
#	echo "ENV" && env && echo "SET" && set && date
	#
	# This will need the following sudoers(5) rule:
	# > nrpe    ALL=(ALL) NOPASSWD: /usr/bin/dnf check-update
	#
	# When using SELinux, we need to set the security context for this script:
	# > /sbin/restorecon -v ../check_softwareupdate.sh
	#
	sudo /usr/bin/dnf check-update > "$RESULT"
	case $? in
		0)
		ERR=0
		;;

		100)
		sed '/^Last metadata expiration/d;/^$/d' -i "$RESULT"
		ERR=1
		;;

		*)
		ERR=3
		;;
	esac
	;;

	homebrew)
	# This will need the following sudoers(5) rules:
	# > nagios  ALL=(admin) NOPASSWD:SETENV: /usr/local/bin/brew update
	# > nagios  ALL=(admin) NOPASSWD:SETENV: /usr/local/bin/brew outdated
	sudo -u admin /usr/local/bin/brew update > /dev/null || exit 3
	sudo -u admin /usr/local/bin/brew outdated > "$RESULT"
	grep -q "[[:alnum:]]" "$RESULT" && ERR=1 || ERR=0
	;;

	macports)
	# This will need the following sudoers(5) rule:
	# > nagios  ALL=(ALL) NOPASSWD: /opt/local/bin/port sync
	sudo /opt/local/bin/port sync > /dev/null || exit 3
	#
	# We need to set HOME here, because:
	#
	# MacPorts provider needs to set HOME while running `port` command.
	# https://projects.puppetlabs.com/issues/13284
	# Fixed by: 
	# Bug #13284 - missing env vars during provider command execution #606
	# https://github.com/puppetlabs/puppet/pull/606
	#
	HOME=/var/lib/nagios /opt/local/bin/port echo outdated > "$RESULT" || exit 3
	egrep -q "[[:alnum:]]" "$RESULT" && ERR=1 || ERR=0
	;;

	opkg)
	#
	# NOTE: "opkg update" can only be run as "root", but we don't want to install
	# the sudo(8) or su(1) package on the router for obvious reasons. Also, we
	# don't want to store a second set of package lists in a different directory,
	# as we may be already low on disk space and don't want to waste any more space.
	# Instead, we will create a root cronjob to regularly run "opkg update" to
	# update the list of available packages and then run  "opkg list-upgradable" as
	# the nagios user.
	#
	# What we can do however, is to check if the packages lists in /var/opkg-lists
	# have been updated recently, for various definitions of "recently". A default
	# time of 10 days sounds reasonable.
	#
	# Note: we have to make sure that /var/lock is writable by the "nagios" user.
	# Later versions of opkg will honor the lock_file directive, but in our case
	# we'll just create two cronjobs similar to:
	#
	# > 0 12 * * 1 /bin/opkg update 2>&1 | /usr/bin/logger -t CRON
	# > 0 12 * * * /bin/chown root:nagios /var/lock/ && /bin/chmod 0775 /var/lock/
	#
	# Our Busybox/find doesn't have "mtime" yet (see OpenWRT #20583) and we don't
	# have stat(1) either, so the following may look a bit weird, you better cover
	# your eyes.
	#
	PLIST=/var/opkg-lists/*base
	[ -f $PLIST ] || exit 3
	TIMEDIFF=864000					# Should be no older than 10 days.
	T_PACKAGE=$(date -r $PLIST +%s)
	    T_NOW=$(date +%s)
	MIN_PKGS=4000					# We expect ~4000 packages.
	CNT_PKGS=$(opkg list | wc -l)

	# Check if our package lists are somewhat complete.
	if [ $CNT_PKGS -lt $MIN_PKGS ]; then
		echo "Our package lists may not be complete!" > "$RESULT"
		ERR=3
	fi

	# Check if our package lists are somewhat current.
	if [ $(expr $T_NOW - $TIMEDIFF ) -gt $T_PACKAGE ]; then
		echo "Package lists are too old!" > "$RESULT"
		ERR=3
	else
		opkg list-upgradable > "$RESULT" || exit 3
		sed '/Multiple packages .* providing same name/d' -i "$RESULT"
		egrep -q "[[:alnum:]]" "$RESULT" && ERR=1 || ERR=0
	fi
	;;

	osx)
	# This will need the following sudoers(5) rule:
	# > nagios  ALL=(ALL) NOPASSWD: /usr/sbin/softwareupdate -l
	sudo /usr/sbin/softwareupdate -l > "$RESULT" 2>&1 || exit 3
	grep -q "No new software available." "$RESULT"
	ERR=$?
	;;

	pacman)
	sudo /usr/bin/pacman --sync --refresh --sysupgrade --print > "$RESULT" || exit 3
	sed -i '/^http/!d' "$RESULT" || exit 3
	egrep -q '^http' "$RESULT" && ERR=1 || ERR=0
	;;

	*)
	echo "Usage: $(basename $0) [dnf|homebrew|macports|opkg|osx|pacman]"
	exit 3
	;;
esac

# Process the results.
case $ERR in
	0)
	echo "OK: No software updates available."
	exit 0
	;;

	1)
	echo "WARNING: Software update available! $(cat "$RESULT")"
	exit 1
	;;

	2)
	# TODO: what would constitute a CRITICAL status?
	exit 2
	;;

	3)
	echo "UNKNOWN: something wicked happened, bailing out. $(cat "$RESULT")"
	exit 3
	;;
esac
