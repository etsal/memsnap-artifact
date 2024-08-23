#!/bin/sh

set -uo pipefail

set -a
. rocksdb.config
. $SRCROOT/tests/aurora

. ../util.sh
. rocksutil-common.sh
OID=1500
set +a

rocksdb_slsdb()
{
    CFGNAME=$1

    PAGE_LIMIT=24
    FULLCHECKPOINT="false"

    DIR="$OUT/rocksdb/slsdb-$CFGNAME-$PAGE_LIMIT"
    CONFIG="slsdb-$CFGNAME-$PAGE_LIMIT"
    DTRACESCRIPT="$PWD/rocksdb-sls.d"
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

    if [ $CFGNAME = "objsnap" ]; then
	    DTRACESCRIPT="$PWD/rocksdb-obj.d"
    fi

    rocksutil_runbenchmark "$CONFIG" "$CMDLINE" "$DTRACESCRIPT"
}

rocksdb_compact()
{
    CFGNAME=$1
    PAGE_LIMIT=24
    CMDLINE="$BASEDB_BENCH_ARGS \
	--enable_pipelined_write=false \
    	--allow_concurrent_memtable_write=false \
	--level0_file_num_compaction_trigger=4 \
    	--sync=true \
	--disable_wal=false \
	--write_buffer_size=$(( 2 << $PAGE_LIMIT ))"

    DIR="$OUT/rocksdb/slsdb-$CFGNAME-$PAGE_LIMIT"
    CONFIG="slsdb-$CFGNAME-$PAGE_LIMIT"
    DTRACESCRIPT="$PWD/rocksdb-baseline.d"

    rocksutil_runbenchmark "$CONFIG" "$CMDLINE" "$DTRACESCRIPT"
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
rocksutil_objsetup $MNT "/dev/stripe/$CKPTSTRIPE"
rocksdb_slsdb "objsnap" 
rocksutil_objteardown $MNT

rocksutil_aursetup $MNT 
rocksdb_slsdb "slsdb" 
rocksutil_aurteardown $MNT

rocksutil_regionsetup $MNT
rocksdb_slsdb "aurora"
rocksutil_regionteardown $MNT

gstripe destroy $CKPTSTRIPE

rocksdb_setup_zfs
rocksdb_compact "compact"
rocksdb_teardown_zfs

rocksutil_epilogue
