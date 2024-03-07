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
    
    slsctl partdel -o $OID
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
    SLS_ENABLED=$3

    OID=1600
    DB_SIZE=256
    VALUE_SIZE=128
    WRITE_PERCENT=50
    OPERATIONS=$(( 2 * 1024 * 1024 ))
    KEYS=$(( 1024 * 1024 ))

    if [ ! -z $SLS_ENABLED ]; then
    	CONFIG="sls-batch-$BATCH_SIZE-$BENCHMARK"
	SETUP_FUNC=sqliteutil_no_op
	TEARDOWN_FUNC=sqlite_slsdb_teardown
    	WAL_ENABLED=0
	DTRACESCRIPT="$PWD/sqlite-sls.d"
    else
    	CONFIG="baseline-batch-$BATCH_SIZE-$BENCHMARK"
	SETUP_FUNC=sqliteutil_no_op
	TEARDOWN_FUNC=sqlite_batch_teardown
    	WAL_ENABLED=1
	DTRACESCRIPT="$PWD/sqlite-baseline.d"
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

    if [ ! -z $SLS_ENABLED ]; then
	    CMDOPTIONS="$CMDOPTIONS --extension=auroravfs --oid=$OID"
    fi
    
    sqliteutil_run_dbbench "$CONFIG" "$SETUP_FUNC" "$TEARDOWN_FUNC" "$CMDOPTIONS" "$DTRACESCRIPT"
}

#==============MAIN==============

NAME="artifact"
sqliteutil_preamble

gstripe create $CKPTSTRIPE $CKPTDISKS
for BATCH_SIZE in 1 2 4 8 16 32 64 128 256; do
    for BENCHMARK in "fillrandbatch" "fillseqbatch"; do
	    sqliteutil_aursetup "sls"
	    sqlite_walsize "$BATCH_SIZE" "$BENCHMARK" "YES" 
	    sqliteutil_aurteardown
    done
done
gstripe destroy $CKPTSTRIPE

for BATCH_SIZE in 1 2 4 8 16 32 64 128 256; do
    for BENCHMARK in "fillrandbatch" "fillseqbatch"; do
	    sqliteutil_setup_zfs
	    sqlite_walsize "$BATCH_SIZE" "$BENCHMARK" ""
	    sqliteutil_teardown_zfs
    done
done

sqliteutil_epilogue "batch-$NAME"
