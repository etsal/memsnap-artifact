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
	PMCFILE="$DIR/sample.$PMCID.out"
	GMONDIR="$DIR/sample.gmon"
	DTRACEOUT="$DIR/dtrace.$ITER"
	PMCTXT="$DIR/pmc.$ITER"
	PMCSTACK="$DIR/stackpmc.$ITER"
	PMCGRAPH="$DIR/flamegraph.$ITER.svg"
	IDFILE="$DIR/$NAME.$ITER.done"
	SYSCTLFILE="$DIR/sysctl.$ITER"
	RUFILE="$DIR/rusage.$ITER"

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
	util_process_pmcstat $GMONDIR $PMCFILE $PMCTXT $PMCGRAPH $PMCSTACK> $LOG 2> $LOG

	mv "$FSMNT/$TMP" $OUTFILE > $LOG 2> $LOG
	fsync $OUTFILE
	touch $IDFILE
	echo "$CMD" >> $IDFILE

	$TEARDOWN_FUNC $DIR $ITER

	mv $LOG "$DIR/$ITER.out.log"
    done
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
    TMP="/tmp/out"
    EXECNAME="tatp_sqlite3 "

    CMD="$EXECNAME $CMDLINE 2> $TMP | tee $TMP"

    sqliteutil_runbenchmark "$CONFIG" "$SETUP_FUNC" "$TEARDOWN_FUNC" "$CMD" "$TMP" "$DTRACESCRIPT" "$EXECNAME"
}

sqliteutil_filecopy()
{
	FSMNT=$1

	mkdir -p $FSMNT/usr/local/lib

	cp auroravfs/auroravfs.so $FSMNT/lib/auroravfs.so
	cp db_bench/db_bench $FSMNT/sbin/db_bench_sqlite3
	cp tatp/build/tatp/tatp_sqlite3 $FSMNT/sbin/tatp_sqlite3
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

	# Clean up previous setups
	sqliteutil_teardown_aurora > /dev/null 2> /dev/null
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
	mv "$OUT/sqlite" "$OUT/sqlite-$NAME-`date "+%m-%d,%H:%M:%S"`"

	echo "[Aurora `date +'%T'`] Tests done"
}


sqliteutil_no_op()
{
        echo "No-op, continuing"
}

