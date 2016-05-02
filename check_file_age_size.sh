#!/bin/sh
#
# (c)2015 Christian Kujau <lists@nerdbynature.de>
# Nagios plugin to check the age and the size of a file.
#
if [ $# -lt 9 ]; then
	# NOTE: Bash "getopts" does not support multi-character arguments, so we have to make up
	# stupid letters like "-e" or "-z" when I really want to use "-ac" or "-sc". GNU/getopts
	# seems to support --long options but this may not be installed on other platforms.
	echo "Usage: $(basename $0) [-f file] [-a age_warning] [-e age_critical] [-s size_warning] [-z size_critical]"
	echo
	echo "*  age_warning and  age_critical in seconds or suffixed with [mhdw] (minutes, hours, days weeks)"
	echo "* size_warning and size_critical in bytes or suffixed with [KMG] (KB, MB, GB)"
	echo
	echo "Note: for now, this script assumes that \"age\" should be LESS than the specified"
	echo "margins and \"size\" should be ABOVE the specified margins."
	echo
	echo "Example: check if \"foo.log\" is no more than 1 hour old (max: 2 hours) and"
	echo "         no smaller than 2 MB in size (min: 1 MB)"
	echo
	echo "     \$ $(basename $0) -f foo.log -a 3600 -e 7200 -s 2097152 -z 1048576"
	echo
	exit 1
fi

_convert_time() {
case $1 in
	*m) TIME=$(expr ${1%%m} \* 60);;
	*h) TIME=$(expr ${1%%h} \* 60 \* 60);;
	*d) TIME=$(expr ${1%%d} \* 60 \* 60 \* 24);;
	*w) TIME=$(expr ${1%%w} \* 60 \* 60 \* 24);;
	 *) TIME=$1;;
esac
}

_convert_size() {
case $1 in
	*K) SIZE=$(expr ${1%%K} \* 1024);;
	*M) SIZE=$(expr ${1%%M} \* 1024 \* 1024);;
	*G) SIZE=$(expr ${1%%G} \* 1024 \* 1024 \* 1024);;
	 *) SIZE=$1;;
esac
}

while getopts "a:e:s:z:f:" opt; do
	case $opt in
	f)
	file=$OPTARG
	;;

	a)
	_convert_time $OPTARG
	age_warning=$TIME
	;;

	e)
	_convert_time $OPTARG
	age_critical=$TIME
	;;

	s)
	_convert_size $OPTARG
	size_warning=$SIZE
	;;

	z)
	_convert_size $OPTARG
	size_critical=$SIZE
	;;
	esac
done

# Sanity check
if [ ! -f "$file" ]; then
	echo "File $file cannot be found!"
	exit 3
else
	# Get current file size, modification time & age
	file_size=$(stat -c %s $file)
	file_time=$(stat -c %Y $file)
	 file_age=$(expr $(date +%s) - $file_time)
fi

# Convert age & size into human readable units
# FIXME: this needs to be done per $age_* variable. And more elegantly too.
# if [ $age_critical -gt 600 ]; then
#	age_critical_h=$(expr $age_critical / 60)
##	echo "$age_critical_h min"
#	if [ $age_critical_h -gt 48 ]; then
#		age_critical_h=$(expr $age_critical_h / 60)
##		echo "$age_critical_h hrs"
#		if [ $age_critical_h -gt 240 ]; then
#			age_critical_h=$(expr $age_critical_h / 24)
##			echo "$age_critical_h days"
#			if [ $age_critical_h -gt 14 ]; then
#				age_critical_h=$(expr $age_critical_h / 7)
##				echo "$age_critical_h weeks"
#				if [ $age_critical_h -gt 8 ]; then
#					age_critical_h=$(expr $age_critical_h / 4)
##					echo "$age_critical_h months"
#				fi
#			fi
#		fi
#	fi
#fi

# File age
if   [ $file_age -gt $age_critical ]; then
	AGE_ERROR=2
	AGE_MSG="CRITICAL: $file is older than $age_critical seconds!"

elif [ $file_age -gt $age_warning  ]; then
	AGE_ERROR=1
	AGE_MSG="WARNING: $file is older than $age_warning seconds!"
else
	AGE_ERROR=0
	AGE_MSG="OK: $file is newer than $age_warning seconds."
fi

# File size
if   [ $file_size -lt $size_critical ]; then
	SIZE_ERROR=2
	SIZE_MSG="CRITICAL: $file is smaller than $size_critical bytes!"

elif [ $file_size -lt $size_warning  ]; then
	SIZE_ERROR=1
	SIZE_MSG="WARNING: $file is smaller than $size_warning bytes!"
else
	SIZE_ERROR=0
	SIZE_MSG="OK: $file is larger than $size_warning bytes."
fi

# DEBUG
# echo "AGE_ERROR: $AGE_ERROR SIZE_ERROR: $SIZE_ERROR"

# FIXME: surely, there must be a better way, no?
ERROR=$(printf "$AGE_ERROR $SIZE_ERROR" | xargs -n1 | sort -n | tail -1)

# Leave a message before the beep
echo "$AGE_MSG - $SIZE_MSG"
exit $ERROR
