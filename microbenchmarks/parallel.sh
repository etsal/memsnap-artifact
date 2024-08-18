#!/bin/sh

. helper.sh

printf "IO Size\tMemsnap\tMemsnap w/ Objsnap\n"
for i in 1 2 4 8 16 32 64 128 256 512 1024; do
	printf "%d KB\t" $(( $i * 4 ))

	printf " & "

	clean
	sysctl aurora.objprotect=1 >/dev/null 2>/dev/null
	sysctl aurora.tracebuf=1 >/dev/null 2>/dev/null

	sinit
	sleep 1
	./parallel-sastrack $(( $i * 4096 )) 
	sleep 1
	sfini

	printf " & "

	sinit_objsnap
	sleep 1
	./parallel-combo $(( $i * 4096 )) 
	sleep 1
	sfini_objsnap

	printf " & "

	printf "\\\\"

	printf "\n"
done
