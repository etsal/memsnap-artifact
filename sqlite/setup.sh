#!/bin/sh

set -a
. sqlite.config
set +a

compile_libsqlite()
{
	THRS=$1
	BASEDIR=$PWD
	BUILDDIR="$PWD/sqlite/build"

	mkdir $BUILDDIR
	cd $BUILDDIR

	../configure

	# Create the single includable file before building the library itself.
	make -j $THRS sqlite3.c

	cd $BASEDIR
}

compile_db_bench()
{
	THRS=$1
	BASEDIR=$PWD

	cd $BASEDIR/db_bench
	make -j $THRS
	cd $BASEDIR
}

compile_auroravfs()
{
	THRS=$1
	BASEDIR=$PWD

	cd $BASEDIR/auroravfs
	make -j $THRS
	cd $BASEDIR
}

compile_tatp()
{
	THRS=$1
	BASEDIR=$PWD

	cd $BASEDIR/tatp
	mkdir build
	cd build
	cmake .. -DCMAKE_BUILD_TYPE=Release
	cmake --build . --parallel $THRS

	cd $BASEDIR
}

#===========MAIN===========

git clone https://github.com/sqlite/sqlite.git --depth 1 --branch="branch-3.41" sqlite
git clone https://github.com/etsal/AuroraVFS.git auroravfs
git clone https://github.com/etsal/sqlite-tatp.git tatp
THRS=`sysctl hw.ncpu | awk -F ' ' '{print $2}'`

# Compile everything
compile_libsqlite $THRS
compile_auroravfs $THRS
compile_db_bench $THRS
#compile_tatp $THRS
