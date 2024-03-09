#!/usr/bin/env bash
. pg.config
. ../util.sh
. postgres-util.sh

export SRCROOT=/root/memsnap-artifact/aurora-memsnap
. $SRCROOT/tests/aurora

ASPG="sudo -u postgres"
DISK1=nvd0
DISK2=nvd1
BENCHMARK="tpcc"
#DE="--enable-debug"
#DE="--enable-dtrace"
DE=""

ITER=5

sysctl -f sysctl-opt.sh


echo "Running FFS"
./run.sh --iter "$ITER" --vm \
	--main "/testmnt/data" \
	--fs "ffs:$DISK1;$DISK2:/testmnt:a+rwx" \
	--benchmark "$BENCHMARK" \
	--pgargs "$DE" \
	--out "ffs"

echo "Running FFS + MMAP"
./run.sh --iter "$ITER" --vm \
	--main "/testmnt/data" \
	--fs "ffs:$DISK1;$DISK2:/testmnt:a+rwx" \
	--pgargs "--with-mmap $DE" \
	--benchmark "$BENCHMARK" \
	--out "ffs-mmap"

echo "Running FFS + MMAP + BUFDIRECT"
./run.sh --iter "$ITER" --vm \
	--main "/testmnt/data" \
	--fs "ffs:$DISK1;$DISK2:/testmnt:a+rwx" \
	--pgargs "--with-mmap --with-bufdirect $DE" \
	--benchmark "$BENCHMARK" \
	--out "ffs-mmap-bufdirect"

echo "Running Memsnap"
./run.sh --iter "$ITER" --vm \
  --main "/testmnt/data" \
  --fs "sls:$DISK1;$DISK2:/testmnt:a+rwx" \
  --pgargs "--with-mmap --with-bufdirect --with-sls --with-sas --with-slswal $DE" \
  --benchmark "$BENCHMARK" \
  --attach \
  --out "slsfs-latest"
