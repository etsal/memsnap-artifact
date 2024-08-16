#!/bin/sh

. helper.sh

SIZE=65536

echo "=====MEMSNAP W/ SLSFS====="

sinit
sleep 1
sysctl aurora.objprotect=1 >/dev/null 2>/dev/null
sysctl aurora.tracebuf=1 >/dev/null 2>/dev/null

./sastrack.d &
sleep 1
./sastrack $SIZE >/dev/null 2>/dev/null
pkill dtrace
sleep 1
sfini

echo "=====MEMSNAP W/ OBJSNAP====="

sinit_objsnap
sleep 1

./sastrack.d &
sleep 1
./memsnap-objsnap-combo $SIZE >/dev/null 2>/dev/null
pkill dtrace
sleep 1
sfini_objsnap
