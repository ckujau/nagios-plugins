# Monitoring Plugins

Some monitoring-plugins that didn't exist on Nagios Exchange or elsewhere. Content
is available under [GNU General Public License](https://www.gnu.org/licenses/gpl-2.0.html "GNU General Public License, version 2") unless otherwise noted.

Plugin				| Description
--------------------------------|---------------------------------------------------
**check_bsd_mem.sh**		| From [check_bsd_mem](https://github.com/bmccorkle/check_bsd_mem "Monitoring Plugin to check Memory Usage on FreeBSD") (BSD 3-Clause)
**check_crashplan_backup.sh**	| Checks the last complete CrashPlan backup
**check_dirsize.sh**		| Checks that a directory is at least [KB] big
**check_entropy.sh**		| Checks kernel.random.entropy_avail (Linux only)
**check_file_age_size.sh**	| Checks mtime & size of a (log) file
**check_ipns.sh**		| Check if our IP name space is not leaking traffic
**check_mem.sh**		| Checks the memory usage (TBD)
**check_mem.pl**		| From [check_mem.pl](https://github.com/justintime/nagios-plugins/blob/master/check_mem/check_mem.pl "Revision of check_mem.pl that splits out cache memory from application memory") (MIT License)
**check_oc_backup.sh**		| Checks the number of entries of an address book and calender on an Owncloud instance
**check_rsnapshot-completed.sh**| Checks that all configured rsnapshot hosts have a current backup
**check_sensors_adt7467.sh**	| Checks the adt7467 sensor in Macintosh systems
**check_socket.sh**		| Checks for the existence of a particular socket
**check_softwareupdate.sh**	| Checks for (OS) software updates
**check_vbox_snapshot_age.sh**	| Checks for old VirtualBox snapshots
