sqliteutil_runbenchmark()
{
    CONFIG="$1"
    SETUP_FUNC="$2"
    TEARDOWN_FUNC="$3"
    CMD="$4"
    TMP="$5"
    DTRACESCRIPT="$6"
    EXECNAME="$7"
    DIR="$OUT/sqlite/$CONFIG"
    FSMNT=$MNT

    mkdir -p $DIR

    for ITER in `seq 0 $MAX_ITER`
    do
    	OUTFILE="$DIR/$ITER.out"
	LOG="/tmp/log"

	if check_completed $OUTFILE; then
	    continue
	fi

	echo "[Aurora `date +'%T'`] Running sqlite: $CONFIG, Iteration $ITER"

	PMCID="$NAME.$ITER"
	DTRACEOUT="$DIR/dtrace.$ITER"
	PMCFILE="$DIR/sample.$PMCID.out"
	IDFILE="$DIR/$NAME.$ITER.done"
	SYSCTLFILE="$DIR/sysctl.$ITER"
	RUFILE="$DIR/rusage.$ITER"

	PMCSTACK="$DIR/stackpmc.$ITER"
	PMCGRAPH="$DIR/flamegraph.$ITER.svg"
	PMCTXT="$DIR/pmc.$ITER"
	GMONDIR="$DIR/sample.gmon"

	chroot $MNT /bin/sh -c "$CMD" &
	FUNC_PID="$!"
	sleep 1

	$SETUP_FUNC $FUNC_PID

	util_start_dtrace $DTRACEOUT $DTRACESCRIPT `pidof $EXECNAME` >> $LOG 2>> $LOG
	util_start_pmcstat $PMCFILE >> $LOG 2>> $LOG
	util_start_rusage $RUFILE `pidof $EXECNAME` >> $LOG 2>> $LOG &
	RUPID="$!"
	util_start_sysctl $SYSCTLFILE >> $LOG 2>> $LOG &
	SYSCTLPID="$!"

	wait $FUNC_PID
	if [ $? -eq 124 ];then
		echo "[Aurora `date +'%T'`] Issue with db_bench, restart required"
		exit 1
	fi

	util_stop_sysctl $SYSCTLPID >> $LOG 2>> $LOG
	util_stop_rusage $RUPID >> $LOG 2>> $LOG
	util_stop_dtrace >> $LOG 2>> $LOG
	util_stop_pmcstat >> $LOG 2>> $LOG

	BATCH_SIZE=`echo $CONFIG | cut -d "-" -f 3`
	if [ -z $BATCH_SIZE ]; then
		BATCH_SIZE=0
	fi
	if [ $BATCH_SIZE == 8 ]; then
		util_process_pmcstat $GMONDIR $PMCFILE $PMCTXT $PMCGRAPH $PMCSTACK> $LOG 2> $LOG
	fi

	mv "$FSMNT/$TMP" $OUTFILE > $LOG 2> $LOG
	fsync $OUTFILE
	touch $IDFILE
	echo "$CMD" >> $IDFILE

	$TEARDOWN_FUNC $DIR $ITER

	mv $LOG "$DIR/$ITER.out.log"
    done
}

sqliteutil_testrun()
{
    CONFIG="$1"
    SETUP_FUNC="$2"
    TEARDOWN_FUNC="$3"
    CMD="$4"
    TMP="$5"
    DTRACESCRIPT="$6"
    EXECNAME="$7"
    DIR="$OUT/sqlite/$CONFIG"
    FSMNT=$MNT
    ITER="$1"


    echo "[Aurora `date +'%T'`] Running sqlite: $CONFIG, Iteration $ITER"
    
    echo "$CMD" 
    
    chroot $MNT /bin/sh -c "$CMD" &
    FUNC_PID="$!"
    sleep 1
    
    $SETUP_FUNC $FUNC_PID
    
    wait $FUNC_PID
    if [ $? -eq 124 ];then
    	echo "[Aurora `date +'%T'`] Issue with benchmark, restart required"
    	exit 1
    fi

    $TEARDOWN_FUNC $DIR "ITER"
}

sqliteutil_run_dbbench()
{
    CONFIG="$1"
    SETUP_FUNC="$2"
    TEARDOWN_FUNC="$3"
    CMDLINE="$4"
    DTRACESCRIPT="$5"
    TMP="/tmp/out"
    EXECNAME="db_bench_sqlite3"

    CMD="$EXECNAME $CMDLINE 2> $TMP | tee $TMP"

    sqliteutil_runbenchmark "$CONFIG" "$SETUP_FUNC" "$TEARDOWN_FUNC" "$CMD" "$TMP" "$DTRACESCRIPT" "$EXECNAME"
}

sqliteutil_run_tatp()
{
    CONFIG="$1"
    SETUP_FUNC="$2"
    TEARDOWN_FUNC="$3"
    CMDLINE="$4"
    DTRACESCRIPT="$5"
    EXECNAME="$6"
    TMP="/tmp/out"

    CMD="$EXECNAME $CMDLINE 2> $TMP | tee $TMP"

    sqliteutil_runbenchmark "$CONFIG" "$SETUP_FUNC" "$TEARDOWN_FUNC" "$CMD" "$TMP" "$DTRACESCRIPT" "$EXECNAME"
}

sqliteutil_filecopy()
{
	FSMNT=$1

	mkdir -p $FSMNT/usr/local/lib
	mkdir -p $FSMNT/memsnap

	cp auroravfs/auroravfs.so $FSMNT/lib/auroravfs.so
	cp auroravfs/auroravfs-objsnap.so $FSMNT/lib/auroravfs-objsnap.so
	cp db_bench/db_bench $FSMNT/sbin/db_bench_sqlite3
	cp db_bench/db_bench_objsnap $FSMNT/sbin/db_bench_objsnap_sqlite3
	cp tatp/build/tatp/tatp_sqlite3 $FSMNT/sbin/tatp_sqlite3
	cp tatp/build/tatp/tatp_sqlite3_objsnap $FSMNT/sbin/objsnap_tatp
}

sqliteutil_aursetup()
{
	CONFIG=$1

	util_setup_aurora $AURMNT 
	util_setup_root $AURMNT
	sqliteutil_filecopy $AURMNT

	echo "Setup done"
}

sqliteutil_aurteardown()
{
	util_teardown_aurora $AURMNT
}

sqliteutil_setup_zfs()
{
	util_setup_zfs $MNT $ALLDISKS
	util_setup_root $MNT
	sqliteutil_filecopy $MNT
}

sqliteutil_teardown_zfs()
{
	util_teardown_zfs $MNT
}

sqliteutil_setup_ffs()
{
	util_setup_ffs $MNT $DISKPATH
	util_setup_root $MNT
	sqliteutil_filecopy $MNT
}

sqliteutil_teardown_ffs()
{
	util_teardown_ffs $MNT
}

sqliteutil_setup_objsnap()
{
	mdconfig -u $OBJSNAP_MD_NUM -a -s $OBJSNAP_MD_SIZE -t "swap"
	util_setup_ffs $MNT $OBJSNAP_MD_PATH
	util_setup_root $MNT
	sqliteutil_filecopy $MNT
	util_setup_objsnap $MNT $DISKPATH
}

sqliteutil_teardown_objsnap()
{
	util_teardown_objsnap $MNT
	util_teardown_ffs $MNT
	mdconfig -u $OBJSNAP_MD_NUM -d >/dev/null 2>/dev/null
}

sqliteutil_preamble()
{
	clear_log
	echo "[Aurora `date +'%T'`] Running with $MAX_ITER iterations"

	# Kill any perf lingering 
	pkill pmcstat
	pkill dtrace
	sleep 1

	# Remove previous tests
	rm -r $OUT/sqlite
	mkdir -p $OUT/sqlite

	# Destroy any memory disks we may have created
	mdconfig -d -u $OBJSNAP_MD_NUM >/dev/null 2>/dev/null

	# Clean up previous setups
	sqliteutil_teardown_objsnap > /dev/null 2> /dev/null
	sqliteutil_aurteardown > /dev/null 2> /dev/null
	sqliteutil_teardown_zfs > /dev/null 2> /dev/null
	sqliteutil_teardown_ffs > /dev/null 2> /dev/null
	gstripe load

	util_setup_pmcstat

}

sqliteutil_epilogue()
{
	NAME=$1

	# Move the benchmarks from their temporary 
	# to their permanent location
	mv "$OUT/sqlite" "$OUT/sqlite-$NAME"

	echo "[Aurora `date +'%T'`] Tests done"
}


sqliteutil_no_op()
{
        echo "No-op, continuing"
}

