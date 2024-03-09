#!/bin/sh

# Note: FreeBSD 12.3 has an issue with building that causes a spurious error caused by a missing "opt_global.h".
# Rerun the above command and eventually it goes away.

cd /usr/src && make -j9 NO_CLEAN=yes KERNCONF=PERF buildkernel
make NO_CLEAN=yes KERNCONF=PERF installkernel
