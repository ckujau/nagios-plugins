#!/bin/sh
##################
# February 25st, 2019
# Version 1.1
# Author:  Brandon McCorkle
# Purpose:  Checks the memory on a FreeBSD System
# Changelog:
#	* 2/25/19 - Initial Release
##############################
VERSION="check_mem v1.1 by Brandon McCorkle for FreeBSD"

# Copyright (c) 2019, Brandon McCorkle <brandon.mccorkle@gmail.com>
# All rights reserved.

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#	* Redistributions of source code must retain the above copyright
#	  notice, this list of conditions and the following disclaimer.
#	* Redistributions in binary form must reproduce the above copyright
#	  notice, this list of conditions and the following disclaimer in the
#	  documentation and/or other materials provided with the distribution.
#	* Neither the name of the <organization> nor the
#	  names of its contributors may be used to endorse or promote products
#	  derived from this software without specific prior written permission.

# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL BRANDON MCCORKLE BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.



#####
#ICINGA2 STATUS CODES:
#####
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3



#####
#SET INITIAL VALUES
#####
#unset memory_used
#unset memory_free
#unset memory_active
#unset memory_inactive
#unset memory_wired
#unset RETURN_MSG
#unset PERF_DATA
#unset crit_used
#unset crit_percent
#unset warn_used
#unset warn_percent



#####
#HELP MESSAGE:
#####
display_help()
{
cat << EOF


>>>>>>>>>>>>>>>>>>>>>>>
usage: $0 [ -h ] [-c OPT]|[-w OPT] [-p OPT ] [-r OPT ] [ -V ]

This script checks memory usage and optionally verifies if the used memory
is ABOVE defined threshhold from Avail Memory (See DEFINITIONs)

OPTIONS:
   -h   Help
   -c   CRIT: Used Memory in MB or Percent (end with %)
   -w   WARN: Used Memory in MB or Percent (end with %)
   -p	Additional Perf Data to Record.  Combine as needed
	(a)ctive, (i)nactive, (w)ired, (f)ree, (c)ache
   -r	Additional Return Msg items to Display.  Combine as needed
        (a)ctive, (i)nactive, (w)ired, (f)ree, (c)ache
	* Multiline.  Only visible under service details *
   -u	UNITS: [MB] [GB] (Default: MB)
   -V   Version

DEFINITIONS...
  (a)ctive:      Memory currently used by a process
  (i)nactive:    Memory still cached.  Can be freed
  (w)ired:       Memory in use by the Kernel. Cannot be swapped out
  (f)ree:        Memory free (according to BSD) and ready to use. 
  (c)ached:      Memory being used to cache data.  Can be freed 

  Free Memory = Free + Inactive + Cached
  Used Memory = Active + Wired
  Avail Memory = Available for use minus BIOS, Video, etc
  Total Memory = Size of memory physically installed
<<<<<<<<<<<<<<<<<<<<<<<

EOF
}


while getopts hc:p:r:w:u:V OPTION
do
     case $OPTION in
        h)
           display_help
           exit $STATE_UNKNOWN
	   ;;
	c)
	   CRIT_THRESHOLD=`echo $OPTARG | LC_ALL=C grep -v "^-"`
	   [ ! "$?" = 0 ] && echo "Error: missing or illegal option value" && \
	   exit $STATE_UNKNOWN
	   ;;
	w)
	   WARN_THRESHOLD=`echo $OPTARG | LC_ALL=C grep -v "^-"`
	   [ ! "$?" = 0 ] && echo "Error: missing or illegal option value" && \
	   exit $STATE_UNKNOWN
	   ;;
        p)
           PERF_ITEMS=`echo $OPTARG | LC_ALL=C grep -v "^-"`
           [ ! "$?" = 0 ] && echo "Error: missing or illegal option value" && \
           exit $STATE_UNKNOWN
	   ;;
        r)
           RETURN_ITEMS=`echo $OPTARG | LC_ALL=C grep -v "^-"`
           [ ! "$?" = 0 ] && echo "Error: missing or illegal option value" && \
           exit $STATE_UNKNOWN
	   ;;
        u)
           UNITS=`echo $OPTARG | LC_ALL=C grep -v "^-"`
           [ ! "$?" = 0 ] && echo "Error: missing or illegal option value" && \
           exit $STATE_UNKNOWN
          ;;
	V)
	   echo $VERSION
	   exit $STATE_OK
	   ;;
	?)
	   display_help
	   exit $STATE_UNKNOWN
	   ;;
     esac
done



#####
#GET OUR RAW DATA (Numbers in bytes)
#####

## Page Size
page_size=`sysctl -e vm.stats.vm.v_page_size | cut -d '=' -f 2`

## Page Count
page_cnt=`sysctl -e vm.stats.vm.v_page_count | cut -d '=' -f 2`

## Free Count
free_cnt=`sysctl -e vm.stats.vm.v_free_count | cut -d '=' -f 2`

## Active Count
active_cnt=`sysctl -e vm.stats.vm.v_active_count | cut -d '=' -f 2`

## Cache Count
cache_cnt=`sysctl -e vm.stats.vm.v_cache_count | cut -d '=' -f 2`

## Inactive Count
inactive_cnt=`sysctl -e vm.stats.vm.v_inactive_count | cut -d '=' -f 2`

## Wired Count
wired_cnt=`sysctl -e vm.stats.vm.v_wire_count | cut -d '=' -f 2`

## Physically Installed (bytes)
ram_installed=`sysctl -e hw.realmem | cut -d '=' -f 2`



#####
# FREEBSD MEMORY NOTES (AS I UNDERSTAND)
#####
##
## DEFINITIONS...
## Active:	Memory currently being used by a process
## Wired:       Memory in use by the Kernel. This memory cannot be swapped out
## Free:	Memory free and ready to use. Inactive, Cache and Buffers can become free if they are cleaned up.
## Inactive:    Memory freed but is still cached since it may be used again
## Cached:      Memory being used to cache data, can be freed immediately if required
##
## Free Memory = Free + Inactive + Cached
## Used Memory = Active + Wired
## Avail Memory = Available for use after BIOS, Shadowed RAM, Video, etc
## Total Memory = Amount of memory physically installed
##
## FORMULAS...
## Free Memory = (inactive_cnt + cache_cnt + free_cnt) * page_cnt
## Used Memory = (active_cnt + wired_cnt) * page_cnt
## Avail Memory = page_size * page_cnt
## Total Memory = hw.physmem
##
## SOME OTHER NOTES...
## hw.realmem = Memory size (bytes) before ANY adjustments (Installed Memory)
## hw.physmem = Memory size (bytes) from counting up USEABLE pages (Installed Memory - Adjustments from BIOS, Shadowed RAM, Video, etc)
## hw.usermem =
##



#####
#SET UNIT SCALE TO DISPLAY IN
#####

## Conversion Scale (MB=1024^2 GB=1024^3)
## RAM Scale/Units = Used in Physical Size calc since physical RAM is alway in GB
if [ "$UNITS" = GB ] ; then
        scale=1073741824
	ram_scale=1073741824
	RAM_UNITS="GB"
else
	scale=1048576
        UNITS="MB"
        ram_scale=1073741824
	RAM_UNITS="GB"
fi



#####
#CALC MEMORY STATISTICS
#####

## Get Free Memory
perf_memory_free=$(( (inactive_cnt + cache_cnt + free_cnt) * page_size ))
scaled_memory_free=$(echo "scale=3; $perf_memory_free / $scale" | bc -l)

## Get Used Memory
perf_memory_used=$(( (active_cnt + wired_cnt) * page_size ))
scaled_memory_used=$(echo "scale=3; $perf_memory_used / $scale" | bc -l)

## Get Available Memory - Preferred Method (page_cnt * page_size)
perf_memory_available=$(( page_cnt * page_size ))
scaled_memory_available=$(echo "scale=3; $perf_memory_available / $scale" | bc -l)

### Get Available Memory - Alternate Method (Free Mem + Used Mem)  Slighly different for some reason
### perf_memory_available=$(( perf_memory_free + perf_memory_used ))
### scaled_memory_available=$(echo "scale=3; $perf_memory_available / $scale" | bc -l)

## Percent Used Memory
percent_memory_used=$(printf '%.1f' $(echo "scale=3; ${perf_memory_used} * 100 / ${perf_memory_available}" | bc -l))

## Physically Installed Memory (Always return GB or Higher)
scaled_ram_installed=$(( ram_installed / ram_scale ))



#####
#CONVERT WARN/CRIT USED TO BYTES OR DETERMINE IF PERCENT
#####

if [ $CRIT_THRESHOLD ] && [ $( echo $CRIT_THRESHOLD | LC_ALL=C grep '%$' ) ] ; then
        crit_percent=$(echo "$CRIT_THRESHOLD" | tr -d "%")
	crit_used=$(printf '%.0f' $(echo "scale=3; ${crit_percent} /100 * ${perf_memory_available}" | bc -l))
elif [ $CRIT_THRESHOLD ] ; then
        crit_used=$(( $CRIT_THRESHOLD * 1048576 ))
	crit_percent=$(printf '%.1f' $(echo "scale=3; ${crit_used} / ${perf_memory_available} * 100" | bc -l))
fi
if [ $WARN_THRESHOLD ] && [ $( echo $WARN_THRESHOLD | LC_ALL=C grep '%$' ) ] ; then
        warn_percent=$(echo "$WARN_THRESHOLD" | tr -d "%")
	warn_used=$(printf '%.0f' $(echo "scale=3; ${warn_percent} /100 * ${perf_memory_available}" | bc -l))
elif [ $WARN_THRESHOLD ] ; then
        warn_used=$(( $WARN_THRESHOLD * 1048576 ))
        warn_percent=$(printf '%.1f' $(echo "scale=3; ${warn_used} / ${perf_memory_available} * 100" | bc -l))
fi



#####
#RETRIEVE PERFORMANCE DATA AND RETURN MESSAGE OPTIONS
#####
if [ $PERF_ITEMS ] ; then
	if [ "$(echo "$PERF_ITEMS" | LC_ALL=C grep -o "a")" = a ] ; then
		FLAG_PF_A=1
	fi
        if [ "$(echo "$PERF_ITEMS" | LC_ALL=C grep -o "i")" = i ] ; then
                FLAG_PF_I=1
        fi
	if [ "$(echo "$PERF_ITEMS" | LC_ALL=C grep -o "w")" = w ] ; then
                FLAG_PF_W=1
        fi
        if [ "$(echo "$PERF_ITEMS" | LC_ALL=C grep -o "f")" = f ] ; then
                FLAG_PF_F=1
        fi
        if [ "$(echo "$PERF_ITEMS" | LC_ALL=C grep -o "c")" = c ] ; then
                FLAG_PF_C=1
        fi
fi	

if [ $RETURN_ITEMS ] ; then
	if [ "$(echo "$RETURN_ITEMS" | LC_ALL=C grep -o "a")" = a ] ; then
		FLAG_RM_A=1
	fi
        if [ "$(echo "$RETURN_ITEMS" | LC_ALL=C grep -o "i")" = i ] ; then
                FLAG_RM_I=1
        fi
        if [ "$(echo "$RETURN_ITEMS" | LC_ALL=C grep -o "w")" = w ] ; then
                FLAG_RM_W=1
        fi
        if [ "$(echo "$RETURN_ITEMS" | LC_ALL=C grep -o "f")" = f ] ; then
                FLAG_RM_F=1
        fi
        if [ "$(echo "$RETURN_ITEMS" | LC_ALL=C grep -o "c")" = c ] ; then
                FLAG_RM_C=1
        fi
fi



#####
#FORMAT RETURN MSG / PERFORMANCE DATA (TRY TO MATCH NSCLIENT++)
#CALC OPTIONAL ITEMS AT THE SAME TIME
#####

#Set Initial Return Message (Free and Used Memory).  Try to Match NSCLIENT++
RETURN_MSG="${RETURN_MSG} physical free: ${scaled_memory_free}${UNITS}  used: ${scaled_memory_used}${UNITS}  size: ${scaled_ram_installed}${RAM_UNITS} (${scaled_memory_available}${UNITS} Avail)"

#Set Initial Perf Data (Physical & Percent Used)
PERF_DATA="'physical'=${perf_memory_used}B;${warn_used};${crit_used};0;${perf_memory_available} 'physical %'=${percent_memory_used}%;${warn_percent};${crit_percent};0;100"

if [ $RETURN_ITEMS ] || [ $PERF_ITEMS ] ; then
	## Active Memory
        if [ $FLAG_PF_A ] || [ $FLAG_RM_A ] ; then
                perf_memory_active=$(( active_cnt * page_size ))
		if [ $FLAG_PF_A ] ; then
	                PERF_DATA="${PERF_DATA} 'active'=${perf_memory_active}B;;;;"
		fi
		if [ $FLAG_RM_A ] ; then
	                scaled_memory_active=$(echo "scale=3; $perf_memory_active / $scale" | bc -l)
			RETURN_MSG_2A="\nActive:   "
			RETURN_MSG_2B="${scaled_memory_active}${UNITS}"
		fi
        fi

	## Inactive Memory
        if [ $FLAG_PF_I ] || [ $FLAG_RM_I ] ; then
		perf_memory_inactive=$(( inactive_cnt * page_size ))
                if [ $FLAG_PF_I ] ; then
	                PERF_DATA="${PERF_DATA} 'inactive'=${perf_memory_inactive}B;;;;"
		fi
		if [ $FLAG_RM_I ] ; then
			scaled_memory_inactive=$(echo "scale=3; $perf_memory_inactive / $scale" | bc -l)
			RETURN_MSG_3A="\nInactive: "
			RETURN_MSG_3B="${scaled_memory_inactive}${UNITS}"
		fi
	fi

	## Wired Memory
        if [ $FLAG_PF_W ] || [ $FLAG_RM_W ] ; then
		perf_memory_wired=$(( wired_cnt * page_size ))
		if [ $FLAG_PF_W ] ; then
			PERF_DATA="${PERF_DATA} 'wired'=${perf_memory_wired}B;;;;"
		fi
		if [ $FLAG_RM_W ] ; then
			scaled_memory_wired=$(echo "scale=3; $perf_memory_wired / $scale" | bc -l)
			RETURN_MSG_4A="\nWired:    "
			RETURN_MSG_4B="${scaled_memory_wired}${UNITS}"
		fi
	fi

	## Free Memory (Actually Free According to BSD)
	if [ $FLAG_PF_F ] || [ $FLAG_RM_F ] ; then
		perf_memory_free2BSD=$(( free_cnt * page_size ))
		if [ $FLAG_PF_F ] ; then
			PERF_DATA="${PERF_DATA} 'free2BSD'=${perf_memory_free2BSD}B;;;;"
		fi
		if [ $FLAG_RM_F ] ; then
			scaled_memory_free2BSD=$(echo "scale=3; $perf_memory_free2BSD / $scale" | bc -l)
			RETURN_MSG_5A="\nFree:     "
			RETURN_MSG_5B="${scaled_memory_free2BSD}${UNITS}"
		fi
	fi

	## Cached Memory
	if [ $FLAG_PF_C ] || [ $FLAG_RM_C ] ; then
		perf_memory_cached=$(( cached_cnt * page_size ))
		if [ $FLAG_PF_C ] ; then
			PERF_DATA="${PERF_DATA} 'cached'=${perf_memory_cached}B;;;;"
		fi
		if [ $FLAG_RM_C ] ; then
			scaled_memory_cached=$(echo "scale=3; $perf_memory_cached / $scale" | bc -l)
			RETURN_MSG_6A="\nCached:   "
			RETURN_MSG_6B="${scaled_memory_cached}${UNITS}"
		fi
	fi
fi



#####
#RETURN MEMORY MSG/STATUS AND EXIT  
#####

if ( [ $crit_used ] && [ $perf_memory_used -gt $crit_used ] ) || ( [ $crit_percent ] && [ $(echo "$percent_memory_used > $crit_percent" | bc) -eq 1 ] ) ; then
	printf '%b' "CRITICAL: $RETURN_MSG | $PERF_DATA"
        printf '%b' "$RETURN_MSG_2A"
        printf '%10.10s' "$RETURN_MSG_2B"
        printf '%b' "$RETURN_MSG_3A"
        printf '%10.10s' "$RETURN_MSG_3B"
        printf '%b' "$RETURN_MSG_4A"
        printf '%10.10s' "$RETURN_MSG_4B"
        printf '%b' "$RETURN_MSG_5A"
        printf '%10.10s' "$RETURN_MSG_5B"
        printf '%b' "$RETURN_MSG_6A"
        printf '%10.10s' "$RETURN_MSG_6B"
	exit $STATE_CRITICAL
elif ( [ $warn_used ] && [ $perf_memory_used -gt $warn_used ] ) || ( [ $warn_percent ] && [ $(echo "$percent_memory_used > $warn_percent" | bc) -eq 1 ] ) ; then
	printf '%b' "WARNING: $RETURN_MSG | $PERF_DATA"
        printf '%b' "$RETURN_MSG_2A"
        printf '%10.10s' "$RETURN_MSG_2B"
        printf '%b' "$RETURN_MSG_3A"
        printf '%10.10s' "$RETURN_MSG_3B"
        printf '%b' "$RETURN_MSG_4A"
        printf '%10.10s' "$RETURN_MSG_4B"
        printf '%b' "$RETURN_MSG_5A"
        printf '%10.10s' "$RETURN_MSG_5B"
        printf '%b' "$RETURN_MSG_6A"
        printf '%10.10s' "$RETURN_MSG_6B"
	exit $STATE_WARNING
else
	printf '%b' "$RETURN_MSG | $PERF_DATA"
        printf '%b' "$RETURN_MSG_2A"
        printf '%10.10s' "$RETURN_MSG_2B"
        printf '%b' "$RETURN_MSG_3A"
        printf '%10.10s' "$RETURN_MSG_3B"
        printf '%b' "$RETURN_MSG_4A"
        printf '%10.10s' "$RETURN_MSG_4B"
        printf '%b' "$RETURN_MSG_5A"
        printf '%10.10s' "$RETURN_MSG_5B"
	printf '%b' "$RETURN_MSG_6A"
	printf '%10.10s' "$RETURN_MSG_6B"
	exit $STATE_OK
fi
