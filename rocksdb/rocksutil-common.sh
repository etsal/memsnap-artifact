rocksutil_runbenchmark()
{
    CONFIG="$1"
    CMDLINE="$2"
    DTRACESCRIPT="$3"
    DIR="$OUT/rocksdb/$CONFIG"
    EXECNAME="db_bench"
    ITER=0

    mkdir -p $DIR

    TMP="/tmp/out"
    OUTFILE="$DIR/$ITER.out"
    
    if check_completed $OUTFILE; then
        continue
    fi
    
    echo "[Aurora `date +'%T'`] Running Rocksdb: $CONFIG, Iteration $ITER"
    
    DTRACEOUT="$DIR/dtrace.$ITER"
    IDFILE="$DIR/$NAME.$ITER.done"
    SYSCTLFILE="$DIR/sysctl.$ITER"
    RUFILE="$DIR/rusage.$ITER"
    
    chroot $AURMNT /bin/sh -c "$EXECNAME $CMDLINE | tee > $TMP 2> $TMP " &
    FUNC_PID="$!"
    util_start_dtrace $DTRACEOUT $DTRACESCRIPT ""
    sleep 1
    
    sleep 40
    
    echo "Setting up DTrace"
    util_start_rusage $RUFILE `pidof $EXECNAME` >> $LOG 2>> $LOG &
    RUPID="$!"
    
    wait $FUNC_PID
    if [ $? -eq 124 ];then
    	echo "[Aurora `date +'%T'`] Issue with db_bench, restart required"
    	exit 1
    fi
    sleep 2
    
    util_stop_rusage $RUPID >> $LOG 2>> $LOG
    util_stop_dtrace
    
    mv "$AURMNT/$TMP" $OUTFILE
    fsync $OUTFILE
    sysctl aurora > $SYSCTLFILE
    sysctl aurora_slos >> $SYSCTLFILE
    touch $IDFILE
    
}

rocksutil_testrun()
{
    CONFIG="$1"
    CMDLINE="$2"
    DTRACESCRIPT="$3"
    DIR="$OUT/rocksdb/$CONFIG"
    EXECNAME="db_bench"
    ITER=0

    echo "$EXECNAME $CMDLINE"

    chroot $AURMNT /bin/sh -c "$EXECNAME $CMDLINE | tee > $TMP 2> $TMP " &
    FUNC_PID="$!"
    
    wait $FUNC_PID
    if [ $? -eq 124 ];then
    	echo "[Aurora `date +'%T'`] Issue with db_bench, restart required"
    	exit 1
    fi
}


rocksutil_filecopy()
{
	BUILDDIR=$1
	AURMNT=$2

	cp -r rocksdb/$BUILDDIR/librocksdb.so* $AURMNT/lib
	cp rocksdb/$BUILDDIR/db_bench $AURMNT/sbin/db_bench
}

rocksutil_objsetup()
{
	OBJMNT=$1
	OBJDISK=$2

	# XXX Merge with the SQLite equivalent?
	mdconfig -u $OBJSNAP_MD_NUM -a -s $OBJSNAP_MD_SIZE -t "swap"
	util_setup_ffs $OBJMNT $OBJSNAP_MD_PATH
	util_setup_objsnap $OBJMNT $OBJDISK

	util_setup_root $OBJMNT
	rocksutil_filecopy "objsnap" $OBJMNT

	echo "Setup done"
}

rocksutil_objteardown()
{
	AURMNT=$1

	util_teardown_objsnap $AURMNT
	util_teardown_ffs $AURMNT

	mdconfig -u $OBJSNAP_MD_NUM -d >/dev/null 2>/dev/null
}

rocksutil_aursetup()
{
	AURMNT=$1

	util_setup_aurora $AURMNT
	sysctl aurora.objprotect=1;

	util_setup_root $AURMNT
	rocksutil_filecopy "slsdb" $AURMNT

	echo "Setup done"
}

rocksutil_aurteardown()
{
	AURMNT=$1

	util_teardown_aurora $AURMNT
}

rocksutil_regionsetup()
{
	AURMNT=$1

	util_setup_aurora $AURMNT
	sysctl aurora.objprotect=1

	util_setup_root $AURMNT
	rocksutil_filecopy "sls" $AURMNT

	echo "Setup done"
}

rocksutil_regionteardown()
{
	AURMNT=$1

	util_teardown_aurora $AURMNT
}


rocksutil_preamble()
{

	clear_log
	echo "[Aurora `date +'%T'`] Running with $MAX_ITER iterations"

	# Kill any perf lingering 
	pkill pmcstat
	pkill dtrace
	sleep 1

	# Remove previous tests
	rm -r $OUT/rocksdb
	mkdir -p $OUT/rocksdb

	# Clean up previous setups
	rocksutil_aurteardown $MNT 
	rocksdb_teardown_zfs > /dev/null 2> /dev/null
	gstripe load

	util_setup_pmcstat

}

rocksutil_epilogue()
{
	# Move the benchmarks from their temporary 
	# to their permanent location
	mv "$OUT/rocksdb" "$OUT/rocksdb-$NAME"

	echo "[Aurora `date +'%T'`] Tests done"
}
