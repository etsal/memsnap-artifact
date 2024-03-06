#!/bin/sh

. helper.sh

# XXX Use the RocksDB benchmark to measure this, not the microbenchmark
SIZE=65536

sinit
sleep 1
sysctl aurora.objprotect=1 >/dev/null 2>/dev/null
sysctl aurora.tracebuf=1 >/dev/null 2>/dev/null

./memsnap.d &
sleep 1
./memsnap $SIZE >/dev/null 2>/dev/null
pkill dtrace
sleep 1
sfini
