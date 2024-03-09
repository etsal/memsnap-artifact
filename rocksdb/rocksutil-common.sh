rocksutil_runbenchmark()
{
    TARGETDIR="$1"
    CONFIG="$2"
    SETUP_FUNC="$3"
    TEARDOWN_FUNC="$4"
    CMDLINE="$5"
    DTRACESCRIPT="$6"
    DIR="$OUT/rocksdb/$CONFIG"
    EXECNAME="db_bench"

    mkdir -p $DIR

    for ITER in `seq 0 $MAX_ITER`
    do
    	TMP="/tmp/out"
    	OUTFILE="$DIR/$ITER.out"

	if check_completed $OUTFILE; then
	    continue
	fi

	echo "[Aurora `date +'%T'`] Running Rocksdb: $CONFIG, Iteration $ITER"

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
	# XXX Add PMCSTACK

	chroot $AURMNT /bin/sh -c "$EXECNAME $CMDLINE | tee > $TMP 2> $TMP " &
	FUNC_PID="$!"
	util_start_dtrace $DTRACEOUT $DTRACESCRIPT ""
	sleep 1

	echo "Setting up"
	$SETUP_FUNC $ITER $TARGETDIR
	echo "Done setting up"

	sleep 40

	echo "Setting up DTrace"
	util_start_pmcstat $PMCFILE
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
	util_stop_pmcstat
	util_process_pmcstat $GMONDIR $PMCFILE $PMCTXT $PMCGRAPH $PMCSTACK

	mv "$AURMNT/$TMP" $OUTFILE
	fsync $OUTFILE
	sysctl aurora > $SYSCTLFILE
	sysctl aurora_slos >> $SYSCTLFILE
	touch $IDFILE

	$TEARDOWN_FUNC
    done
}

rocksutil_filecopy()
{
	BUILDDIR=$1
	AURMNT=$2

	cp -r rocksdb/$BUILDDIR/librocksdb.so* $AURMNT/lib
	cp rocksdb/$BUILDDIR/db_bench $AURMNT/sbin/db_bench
}

rocksutil_aursetup()
{
	AURMNT=$1
	CONFIG=$2
	PROTECT=$3

	util_setup_aurora $AURMNT 
	if [ "$PROTECT" = "true" ]; then
		sysctl aurora.objprotect=1;
		sysctl aurora.tracebuf=1;
	else
		sysctl aurora.objprotect=0;
		sysctl aurora.tracebuf=0;
	fi

	util_setup_root $AURMNT
	# Both Aurora and memsnap use the same RocksDB codebase
	rocksutil_filecopy "$CONFIG" $AURMNT

	echo "Setup done"
}

rocksutil_aurteardown()
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
	rocksdb_teardown_aurora $MNT > /dev/null 2> /dev/null
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
