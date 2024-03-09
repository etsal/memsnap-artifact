#!/bin/sh

. helper.sh

printf "IO Size\tAurora Full\tAurora Region\tMemSnap\n"
for i in 1 16 1024; do
	printf "%d KB\t" $(( $i * 4 ))
	clean

	printf " & "

#	sinit_old
#	./old $(( $i * 4096 ))
#	sfini_old
#
#	printf " & "

	sinit
	sleep 1
	sysctl aurora.objprotect=0 >/dev/null 2>/dev/null
	sysctl aurora.tracebuf=0 >/dev/null 2>/dev/null
	./memsnap.d &
	./memsnap $(( $i * 4096 )) "YES"
	kill %1
	wait %1
	sleep 1
	sfini

	printf " & "

#	sinit
#	sleep 1
#	sysctl aurora.objprotect=1 >/dev/null 2>/dev/null
#	sysctl aurora.tracebuf=1 >/dev/null 2>/dev/null
#	./sastrack $(( $i * 4096 )) 
#	sleep 1
#	sfini

	printf " & "

	printf "\\\\"

	printf "\n"
done
