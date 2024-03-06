#!/usr/local/bin/bash

set -uo pipefail

clear_log()
{
	echo "" > $LOG
	echo "" > $LOG
}

util_check_library()
{
    O1=`find "/usr/local/lib" "/usr/lib" "/lib" -name *$1*`
    if [ -z "$O1" ]; then
	echo "Library $1 not present locally, please install"
    fi

}

util_check_binary()
{
    BIN_VAR=`which $1`
    if [ -z $BIN_VAR ]; then
	echo "Binary $1 not present locally, please install"
	exit 1
    else
	return
    fi
}


check_completed()
{
	if [ -f $1 ]; then
		COUNT=$(wc -l < $1)
		if [ "$COUNT" -eq "0" ]; then
			return 1
		fi
		return 0
	else
		return 1
	fi
}

util_setup_root()
{
	FSMNT=$1

	echo "[Aurora `date +'%T'`] Creating the root and installing packages"
	MNT=$FSMNT installroot
#	cp /etc/resolv.conf $FSMNT/etc/resolv.conf
#	cp -r packages $FSMNT/packages
#	chroot $FSMNT /bin/sh -c 'ASSUME_ALWAYS_YES=yes pkg add /packages/*'

	echo "[Aurora `date +'%T'`] Copying over necessary files"
	mkdir -p $FSMNT/usr/lib/debug/boot/modules >/dev/null
	mkdir -p $FSMNT/usr/aurora/tests/posix > /dev/null
	cd $SRCROOT
	DESTDIR=$FSMNT make install > /dev/null 
	cd -
}

util_setup_aurora()
{
	FSMNT=$1
	INFREQUENT=$(( 10 * 1000 ))

	echo "[Aurora `date +'%T'`] Loading the Aurora module"
	MNT=$FSMNT aurteardown > $LOG 2> $LOG
	MNT=$FSMNT aursetup

	if [ $# -eq 2 ]; then
		sysctl aurora_slos.checkpointtime=$2 >/dev/null 2>/dev/null
	else
		sysctl aurora_slos.checkpointtime=$INFREQUENT >/dev/null 2>/dev/null
	fi

}


util_teardown_aurora()
{
	FSMNT=$1

	sleep 2
	MNT=$FSMNT aurteardown > /dev/null 2> /dev/null
	# We pass in DISKPATH cause destroymd requires it but aurunstripe does not require
	# any arguments so does not use it.
}

util_setup_zfs()
{
	FSMNT=$1 
	shift

	set -- $@
	ZFS_DISKS=""
	while [ "$#" -ne 0 ];
	do
	   ZFS_DISKS="/dev/$1 ${ZFS_DISKS}"
	   shift
	done

	zpool create -f benchmark $ZFS_DISKS
	zfs create benchmark/testmnt

	zfs set mountpoint=$FSMNT benchmark/testmnt
	zfs set recordsize=64k benchmark

	zfs set sync=standard benchmark
	zfs set checksum=off benchmark/testmnt

	mkdir -p $FSMNT/dev
	mkdir -p $FSMNT/proc
	mount -t devfs devfs $FSMNT/dev
	mount -t fdescfs fdesc $FSMNT/dev/fd
	mount -t procfs proc $FSMNT/proc
}

util_teardown_zfs()
{
	FSMNT=$1 

	umount $FSMNT/dev/fd
	umount $FSMNT/dev
	umount $FSMNT/proc
	sync

	zfs destroy -r benchmark/testmnt 
	zpool destroy benchmark
}

util_setup_ffs()
{
	FSMNT=$1 
	FFSDISK=$2

	newfs $FFSDISK > /dev/null

	mount -t ufs $FFSDISK $FSMNT
	mkdir -p $FSMNT/dev
	mkdir -p $FSMNT/proc
	mount -t devfs devfs $FSMNT/dev
	mount -t fdescfs fdesc $FSMNT/dev/fd
	mount -t procfs proc $FSMNT/proc

}

util_teardown_ffs()
{
	FSMNT=$1 

	umount $FSMNT/dev/fd
	umount $FSMNT/dev
	umount $FSMNT/proc
	sync

	umount $FSMNT
}

util_start_dtrace()
{
	DTRACEOUT="$1"
	DTRACESCRIPT="$2"
	PID="$3"

	if [ ! -z $PID ]; then
		$DTRACESCRIPT $PID > $DTRACEOUT 2> $DTRACEOUT &
	else
		$DTRACESCRIPT > $DTRACEOUT 2> $DTRACEOUT &
	fi
}

util_stop_dtrace()
{
	pkill dtrace
}

util_setup_pmcstat()
{
	# Set up the performance counter module
	kldload hwpmc
	ln -s /boot/modules/sls.ko /boot/kernel/sls.ko
	ln -s /boot/modules/slos.ko /boot/kernel/slos.ko
}

util_start_pmcstat()
{
	PMCFILE=$1

	pmcstat -S inst_retired.any -O $PMCFILE -n 4096 &
}

util_stop_pmcstat()
{
	pkill pmcstat
	sleep 1
}

util_start_pmcstat_args()
{
	PMCOUT=$1
  	PMCARG=$2

	pmcstat -S "$2" -O $PMCOUT -n 4096 &
}

util_stop_pmcstat_args()
{
	PMCOUT=$1
	GMONOUT=$2

	pkill pmcstat
	sleep 1

	pmcstat -g -R $PMCOUT
	mv "$3" $GMONOUT
}


util_process_pmcstat()
{
	GMONDIR=$1
	PMCFILE=$2
	PMCTXT=$3
	PMCGRAPH=$4
	PMCSTACK=$5

	pmcstat -g -R $PMCFILE
	mv inst_retired.any $GMONDIR

	# WARNING: $PMCTXT does not tell the whole story because it ignores
	# all non-kernel, non-SLS objects. The $PMCGRAPH and $PMCSTACK 
	# outputs are more accurate.
	touch $PMCTXT
	echo "======================SLS=======================" >> $PMCTXT
	gprof /boot/modules/sls.ko $GMONDIR/sls.ko.gmon >> $PMCTXT
	echo "======================SLOS======================" >> $PMCTXT
	gprof /boot/modules/slos.ko $GMONDIR/slos.ko.gmon >> $PMCTXT
	echo "=====================KERNEL=====================" >> $PMCTXT
	gprof /boot/kernel/kernel $GMONDIR/kernel.gmon >> $PMCTXT

	# Create a deep stack trace file to get an accurate flame graph
	pmcstat -R $PMCFILE -z100 -G $PMCSTACK
	~/FlameGraph/stackcollapse-pmc.pl $PMCSTACK | ~/FlameGraph/flamegraph.pl > $PMCGRAPH
	rm -r $PMCSTACK

	# Get a less deep file for stack tracing
	pmcstat -R $PMCFILE -z5 -G $PMCSTACK
}

util_start_rusage() {
	RUFILE=$1
	PID=$2

	touch $RUFILE
	while true; do
		procstat rusage $2 >> $RUFILE
		sleep 1
	done
}

util_stop_rusage() {
	RUPID=$1

	kill -SIGTERM $RUPID
}


util_start_sysctl() {
	SYSCTLFILE=$1

	touch $SYSCTLFILE
	while true; do
		sysctl aurora >> $SYSCTLFILE
		sleep 1
	done
}

util_stop_sysctl() {
	SYSCTLPID=$1
	kill -SIGTERM $SYSCTLPID
}
