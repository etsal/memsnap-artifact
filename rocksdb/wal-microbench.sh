#!/bin/sh

set -uo pipefail

set -a
# Needed for the installroot command
SRCROOT=/root/aurora
. $SRCROOT/tests/aurora

. ../util.sh
. ./rocksutil-common.sh
set +a

ROCKSDB_NUM=50000000
ROCKSDB_DUR=30

DB_BENCH_ARGS=" \
	--benchmarks=fillbatch,mixgraph \
	--use_direct_io_for_flush_and_compaction=true \
	--use_direct_reads=true \
	--cache_size=$((256 << 20)) \
	--key_dist_a=0.002312 \
	--key_dist_b=0.3467 \
	--keyrange_dist_a=14.18 \
	--keyrange_dist_b=0.3467 \
	--keyrange_dist_c=0.0164 \
	--keyrange_dist_d=-0.08082 \
	--keyrange_num=30 \
	--value_k=0.2615 \
	--value_sigma=25.45 \
	--iter_k=2.517 \
	--iter_sigma=14.236 \
	--mix_get_ratio=0.83 \
	--mix_put_ratio=0.14 \
	--mix_seek_ratio=0.03 \
	--sine_mix_rate_interval_milliseconds=5000 \
	--sine_a=1000 \
	--sine_b=0.000073 \
	--sine_d=4500 \
	--perf_level=2 \
	--num=$ROCKSDB_NUM \
	--key_size=48 \
	--db=/tmp-db \
	--wal_dir=/wal \
	--duration=$ROCKSDB_DUR \
	--histogram=1 \
	--write_buffer_size=$((16 << 30)) \
	--disable_auto_compactions \
	--threads=24 \
"

MAX_ITER=1
ROCKSDIR="$PWD/rocksdb"
ALLDISKS="nvd0 nvd1 nvd2 nvd3"
MNT="/testmnt"

rocksdb_copy_files()
{
	BUILDDIR=$1

	cp -r $ROCKSDIR/$BUILDDIR/librocksdb.so* $MNT/lib
	cp $ROCKSDIR/$BUILDDIR/db_bench $MNT/sbin/db_bench
}

rocksdb_base()
{
    CMDLINE=$1

    for ITER in `seq 0 $MAX_ITER`
    do
	chroot $MNT /bin/sh -c "db_bench $CMDLINE"
    done
}

rocksdb_base_wal()
{
    CMDLINE="$DB_BENCH_ARGS --sync=true --disable_wal=false"

    echo "=====ROCKSDB WITH WAL====="
    rocksdb_base "$CMDLINE"
}

rocksdb_base_nowal()
{
    CMDLINE="$DB_BENCH_ARGS --sync=false --disable_wal=true"

    echo "=====ROCKSDB WITHOUT WAL====="
    rocksdb_base "$CMDLINE"
}

rocksdb_setup_zfs()
{
	util_setup_zfs $MNT $ALLDISKS
	util_setup_root $MNT
	rocksdb_copy_files baseline
}

rocksdb_teardown_zfs()
{
	util_teardown_zfs $MNT
}

#==============MAIN==============

echo "[Aurora `date +'%T'`] Running with $MAX_ITER iterations"

# Clean up previous setups
rocksdb_teardown_zfs > /dev/null 2> /dev/null

# Benchmarks
rocksdb_setup_zfs baseline
rocksdb_base_wal
rocksdb_teardown_zfs

rocksdb_setup_zfs baseline
rocksdb_base_nowal
rocksdb_teardown_zfs

echo "[Aurora `date +'%T'`] Tests done"
