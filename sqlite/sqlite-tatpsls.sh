#!/bin/sh

set -uo pipefail

set -a
. sqlite.config
. $SRCROOT/tests/aurora

. ../util.sh
. sqliteutil-common.sh
set +a

sqlite_tatp()
{
    NUM_RECORDS=$1
    STORAGE=$2

    if [ $STORAGE = "SLSFS" ]; then 
    	CONFIG="sls-$NUM_RECORDS"
	DTRACESCRIPT="$PWD/sqlite-sls.d"
    elif [ $STORAGE = "ZFS" ]; then
    	CONFIG="baseline-$NUM_RECORDS"
	DTRACESCRIPT="$PWD/sqlite-baseline.d"
    elif [ $STORAGE = "OBJSNAP" ]; then
    	CONFIG="objsnap-$NUM_RECORDS"
	DTRACESCRIPT="$PWD/sqlite-sls.d"
    else
	echo "ERROR: Invalid storage option $STORAGE"
	exit 1
    fi

    WAL_SIZE_PAGES=1024
    SETUP_FUNC=sqliteutil_no_op
    TEARDOWN_FUNC=sqliteutil_no_op
    JOURNAL_MODE="WAL"
    CACHE_SIZE=1024
    OID=1500

    CMDOPTIONS="--records=$NUM_RECORDS \
		--cache_size=$CACHE_SIZE \
		--wal_size=$WAL_SIZE_PAGES"
    
    BINARY="tatp_sqlite3"
    if [ $STORAGE = "SLSFS" ]; then 
	    CMDOPTIONS="$CMDOPTIONS --extension=auroravfs --oid=$OID"
    elif [ $STORAGE = "OBJSNAP" ]; then 
	    BINARY="objsnap_tatp"
	    CMDOPTIONS="$CMDOPTIONS --extension=auroravfs --oid=$OID"
    fi

    sqliteutil_run_tatp "$CONFIG" "$SETUP_FUNC" "$TEARDOWN_FUNC" "$CMDOPTIONS" "$DTRACESCRIPT" "$BINARY"
}

#==============MAIN==============

NAME="$1"
sqliteutil_preamble 

gstripe create $CKPTSTRIPE $CKPTDISKS
for NUM_RECORDS in 1000 10000 100000 1000000; do
	sqliteutil_setup_objsnap
	sqlite_tatp $NUM_RECORDS "OBJSNAP"
	sqliteutil_teardown_objsnap
done

for NUM_RECORDS in 1000 10000 100000 1000000; do
	sqliteutil_aursetup "sls"
	sqlite_tatp $NUM_RECORDS "SLSFS" 
	sqliteutil_aurteardown
done

gstripe destroy $CKPTSTRIPE

for NUM_RECORDS in 1000 10000 100000 1000000; do
	sqliteutil_setup_zfs
	sqlite_tatp "$NUM_RECORDS" "ZFS"
	sqliteutil_teardown_zfs
done

sqliteutil_epilogue "tatpsls-$NAME"

