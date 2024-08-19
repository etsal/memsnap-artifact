#!/bin/sh

. helper.sh

printf "Threads\tMemsnap\tMemsnap w/ Objsnap\tObjsnap\n"
for i in `seq 1 1 12`; do
	printf "%d\t" $i

	printf " & "

	clean
	sysctl aurora.objprotect=1 >/dev/null 2>/dev/null
	sysctl aurora.tracebuf=1 >/dev/null 2>/dev/null

	sinit
	sleep 1
	./parallel-sastrack $i
	sleep 1
	sfini

	printf " & "

	sinit_objsnap
	sleep 1
	./parallel-combo $i
	sleep 1
	sfini_objsnap

	printf " & "

	sinit_objsnap
	sleep 1
	./objsnap $i
	sleep 1
	sfini_objsnap

	printf " & "
	printf "\\\\"

	printf "\n"
done
