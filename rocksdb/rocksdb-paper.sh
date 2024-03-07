#!/bin/sh

set -uo pipefail

set -a
. rocksdb.config
. $SRCROOT/tests/aurora

. ../util.sh
. rocksutil-common.sh
OID=1500
set +a

rocksdb_no_op()
{
        echo "No-op, continuing"
}

rocksdb_slsdb_teardown()
{
        slsctl partdel -o $OID
}

rocksdb_slsdb()
{
    PAGE_LIMIT=$1
    FULLCHECKPOINT=$2
    CFGNAME=$3

    DIR="$OUT/rocksdb/slsdb-$CFGNAME-$PAGE_LIMIT"
    CONFIG="slsdb-$CFGNAME-$PAGE_LIMIT"
    DTRACESCRIPT="$PWD/rocksdb-sls.d"
    SETUP_FUNC=rocksdb_no_op
    TEARDOWN_FUNC=rocksdb_slsdb_teardown
    WALPATH="/tmp/log"
    CMDLINE="$BASEDB_BENCH_ARGS \
    	--disable_auto_compactions \
    	--sync=true \
	--disable_wal=false \
	--enable_pipelined_write=false \
    	--allow_concurrent_memtable_write=false \
	--wal_dir=/wal \
	--wal_path=$WALPATH \
	--checkpoint_threshold=$(( 2 << $PAGE_LIMIT )) \
	--sls_oid=$OID \
	--full_checkpoint=$FULLCHECKPOINT \
	--ignore_wal=false"

    	#--allow_concurrent_memtable_write=false \
    rocksutil_runbenchmark "slsdb" "$CONFIG" "$SETUP_FUNC" "$TEARDOWN_FUNC" "$CMDLINE" "$DTRACESCRIPT"
}

rocksdb_setup_aurora()
{
	CONFIG="$1"
	PROTECT="$2"
	
	if [ -n "$CKPTSTRIPE" ]; then
		set -- $CKPTDISKS
		gstripe create -s 65536 $CKPTSTRIPE $@
	fi

	if [ -n "$WALSTRIPE" ]; then
		set -- $WALDISKS
		gstripe create -s 65536 $WALSTRIPE $@
	fi

	rocksutil_aursetup $MNT $CONFIG "$PROTECT"
}

rocksdb_teardown_aurora()
{
	rocksutil_aurteardown $MNT
	if [ -n "$CKPTSTRIPE" ]; then gstripe stop $CKPTSTRIPE; fi
	if [ -n "$WALSTRIPE" ]; then gstripe stop $WALSTRIPE; fi
}

rocksdb_baseline()
{
    PAGE_LIMIT=$1
    CFGNAME=$2
    CMDLINE=$3

    DIR="$OUT/rocksdb/slsdb-$CFGNAME-$PAGE_LIMIT"
    CONFIG="slsdb-$CFGNAME-$PAGE_LIMIT"
    DTRACESCRIPT="$PWD/rocksdb-baseline.d"
    SETUP_FUNC=rocksdb_no_op
    TEARDOWN_FUNC=rocksdb_no_op

    rocksutil_runbenchmark "slsdb" "$CONFIG" "$SETUP_FUNC" "$TEARDOWN_FUNC" "$CMDLINE" "$DTRACESCRIPT"
}

rocksdb_compact()
{
    PAGE_LIMIT=$1
    CFGNAME=$2
    CMDLINE="$BASEDB_BENCH_ARGS \
	--enable_pipelined_write=false \
    	--allow_concurrent_memtable_write=false \
	--level0_file_num_compaction_trigger=4 \
    	--sync=true \
	--disable_wal=false \
	--write_buffer_size=$(( 2 << $PAGE_LIMIT ))"

    rocksdb_baseline "$PAGE_LIMIT" "$CFGNAME" "$CMDLINE"
}

rocksdb_setup_zfs()
{
	util_setup_zfs $MNT $ALLDISKS
	util_setup_root $MNT
	rocksutil_filecopy baseline $MNT
}

rocksdb_teardown_zfs()
{
	util_teardown_zfs $MNT
}


#==============MAIN==============

NAME=artifact
rocksutil_preamble

gstripe create $CKPTSTRIPE $CKPTDISKS
for LIMIT in `seq 24 1 24`; do
	rocksdb_setup_aurora "slsdb" "true"
	rocksdb_slsdb $LIMIT false "slsdb" 
	rocksdb_teardown_aurora
done

for LIMIT in `seq 24 1 24`; do
	rocksdb_setup_aurora "slsdb" "false"
	rocksdb_slsdb $LIMIT "false" "aurora"
	rocksdb_teardown_aurora
done
gstripe destroy $CKPTSTRIPE

#for LIMIT in `seq 24 1 24`; do
#	rocksdb_setup_zfs
#	rocksdb_compact $LIMIT "compact"
#	rocksdb_teardown_zfs
#done

rocksutil_epilogue
