#!/bin/sh

. helper.sh

printf "IO Size\tAurora Region\tMemSnap w/o Trace\tMemSnap\n"
for i in 1 1024; do
	printf "%d KB\t" $(( $i * 4 ))
	clean

	printf " & "

	sinit
	sleep 1
	sysctl aurora.objprotect=0 >/dev/null 2>/dev/null
	sysctl aurora.tracebuf=0 >/dev/null 2>/dev/null
	./memsnap $(( $i * 4096 )) 
	sleep 1
	sfini

	printf " & "

	sinit
	sleep 1
	sysctl aurora.objprotect=0 >/dev/null 2>/dev/null
	sysctl aurora.tracebuf=0 >/dev/null 2>/dev/null
	./sastrack $(( $i * 4096 )) 
	sleep 1
	sfini

	printf " & "

	sinit
	sleep 1
	sysctl aurora.objprotect=1 >/dev/null 2>/dev/null
	sysctl aurora.tracebuf=1 >/dev/null 2>/dev/null

	# XXX Start the DTrace script for SAS
	sleep 1
	./sastrack $(( $i * 4096 )) 
	# XXX Kill the Dtrace script and get its output
	# Parse its output to grab just the number we need
	sleep 1
	sfini

	printf " & "
	printf "\\\\"

	printf "\n"
done
