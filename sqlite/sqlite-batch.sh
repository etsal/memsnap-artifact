#!/bin/sh

set -uo pipefail

set -a
set +x
. sqlite.config
. $SRCROOT/tests/aurora

. ../util.sh
. sqliteutil-common.sh
set +a

sqlite_slsdb_teardown()
{
    DIR=$1
    ITER=$2
    
    mv $MNT/tmp/raw $DIR/raw.$ITER 
}

sqlite_batch_teardown()
{
    DIR=$1
    ITER=$2
    
    mv $MNT/tmp/raw $DIR/raw.$ITER 
    rm $MNT/tmp/*.db
}

sqlite_walsize()
{
    BATCH_SIZE=$1
    BENCHMARK=$2
    STORAGE=$3

    OID=1600
    DB_SIZE=256
    VALUE_SIZE=128
    WRITE_PERCENT=50
    OPERATIONS=$(( 2 * 1024 * 1024 ))
    KEYS=$(( 1024 * 1024 ))

    if [ $STORAGE = "SLSFS" ]; then 
    	CONFIG="sls-batch-$BATCH_SIZE-$BENCHMARK"
	SETUP_FUNC=sqliteutil_no_op
	TEARDOWN_FUNC=sqlite_slsdb_teardown
    	WAL_ENABLED=0
	DTRACESCRIPT="$PWD/sqlite-sls.d"
    elif [ $STORAGE = "ZFS" ]; then 
    	CONFIG="baseline-batch-$BATCH_SIZE-$BENCHMARK"
	SETUP_FUNC=sqliteutil_no_op
	TEARDOWN_FUNC=sqlite_batch_teardown
    	WAL_ENABLED=1
	DTRACESCRIPT="$PWD/sqlite-baseline.d"
    elif [ $STORAGE = "OBJSNAP" ]; then
    	CONFIG="objsnap-batch-$BATCH_SIZE-$BENCHMARK"
	SETUP_FUNC=sqliteutil_no_op
	TEARDOWN_FUNC=sqlite_slsdb_teardown
    	WAL_ENABLED=0
	DTRACESCRIPT="$PWD/sqlite-obj.d"
    else
	echo "ERROR: Invalid storage option $STORAGE"
	exit 1
    fi

    CMDOPTIONS="--benchmarks=$BENCHMARK \
	     --histogram=1 \
   	     --WAL_enabled=$WAL_ENABLED \
	     --mmap_size_mb=$DB_SIZE \
	     --num_pages=$(($DB_SIZE * (1024 * 1024 / 4096)))\
	     --write_percent=$WRITE_PERCENT \
	     --checkpoint_granularity=$(( 4 * 1024 )) \
	     --num_ops=$OPERATIONS \
	     --num_keys=$KEYS \
	     --batch_size=$(( $BATCH_SIZE * (4096 / $VALUE_SIZE) )) \
	     --raw=1 \
	     --value_size=$VALUE_SIZE"

    BINARY="db_bench_sqlite3"
    if [ $STORAGE = "SLSFS" ]; then
	    CMDOPTIONS="$CMDOPTIONS --extension=auroravfs --oid=$OID"
    elif [ $STORAGE = "OBJSNAP" ]; then
            BINARY="objsnap_sqlite3"
	    CMDOPTIONS="$CMDOPTIONS --extension=auroravfs --oid=$OID"
    fi
    
    sqliteutil_run_dbbench "$CONFIG" "$SETUP_FUNC" "$TEARDOWN_FUNC" "$CMDOPTIONS" "$DTRACESCRIPT" "$BINARY"
}

#==============MAIN==============

NAME="artifact"
sqliteutil_preamble

gstripe create $CKPTSTRIPE $CKPTDISKS
for BATCH_SIZE in 1 2 4 8 16 32 64 128 256; do
    for BENCHMARK in "fillrandbatch" "fillseqbatch"; do
           sqliteutil_setup_objsnap
           sqlite_walsize "$BATCH_SIZE" "$BENCHMARK" "OBJSNAP"
           sqliteutil_teardown_objsnap
    done
done

for BATCH_SIZE in 1 2 4 8 16 32 64 128 256; do
    for BENCHMARK in "fillrandbatch" "fillseqbatch"; do
	    sqliteutil_aursetup "sls"
	    sqlite_walsize "$BATCH_SIZE" "$BENCHMARK" "SLSFS" 
	    sqliteutil_aurteardown
    done
done
gstripe destroy $CKPTSTRIPE

for BATCH_SIZE in 1 2 4 8 16 32 64 128 256; do
    for BENCHMARK in "fillrandbatch" "fillseqbatch"; do
	    sqliteutil_setup_zfs
	    sqlite_walsize "$BATCH_SIZE" "$BENCHMARK" "ZFS"
	    sqliteutil_teardown_zfs
    done
done

sqliteutil_epilogue "batch-$NAME"
