#!/usr/local/bin/bash

. rocksdb.config
. ../util.sh

check_dependencies()
{
    util_check_binary "pidof"
    util_check_binary "libtoolize"
    util_check_binary "aclocal"
    util_check_binary "autoheader"
    util_check_binary "automake"
    util_check_binary "autoconf"
    util_check_binary "cmake"
    util_check_binary "scons"
    util_check_library "snappy"
    util_check_library "gflags"
}

rocksdb_compile()
{
    BASEDIR="$1"
    BRANCH="$2"
    BUILDDIR="$1/rocksdb/$3"
    SLSROOT=$4

    THRS=`sysctl hw.ncpu | awk -F ' ' '{print $2}'`

    cd $BASEDIR/rocksdb

    git fetch origin $BRANCH
    git checkout $BRANCH

    mkdir -p $BUILDDIR
    cd $BUILDDIR
    cmake .. -DCMAKE_BUILD_TYPE=Release -DFAIL_ON_WARNINGS=OFF -DWITH_SNAPPY=ON -DSLS_PATH=$SLSROOT
    make -j $THRS db_bench
    cd $BASEDIR
}

rocksdb_setup()
{
    # Needed for SRCROOT
    . rocksdb.config 

    git clone "https://github.com/rcslab/aurora-rocksdb.git" "rocksdb"

    rocksdb_compile "$PWD" "slsdb-beta2" "slsdb" $SRCROOT
    rocksdb_compile "$PWD" "slsdb-region2" "sls" $SRCROOT
    rocksdb_compile "$PWD" "sls-baseline2" "baseline" $SRCROOT
    rocksdb_compile "$PWD" "slsdb-objsnap" "objsnap" $SRCROOT
}

check_dependencies

mkdir -p $MNT

mkdir $OUT 2> /dev/null
chmod a+rw $OUT 2> /dev/null

echo "[Aurora] Setting up rocksdb"
rocksdb_setup > /dev/null

wait
echo "[Aurora] Setup Done"
