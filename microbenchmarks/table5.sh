#!/bin/sh

. helper.sh

SIZE=65536

sinit
sleep 1
sysctl aurora.objprotect=1 >/dev/null 2>/dev/null
sysctl aurora.tracebuf=1 >/dev/null 2>/dev/null

./sas.d &
sleep 1
./sastrack $SIZE >/dev/null 2>/dev/null
pkill dtrace
sleep 1
sfini
