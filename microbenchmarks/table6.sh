#!/bin/sh

. helper.sh

printf "IO Size\tDirect IO\tSerial FFS\tSerial ZFS\tCheckpoint FFS\tCheckpoint ZFS\tMemsnap sync\tMemsnap async\n"
for i in 1 2 4 8 16 32 64 128 256 512 1024; do
	printf "%d KB\t" $(( $i * 4 ))
	clean
	sysctl aurora.objprotect=1 >/dev/null 2>/dev/null
	sysctl aurora.tracebuf=1 >/dev/null 2>/dev/null

	ginit
	./directio $(( i * 4096 )) $DISK
	gfini

	printf " & "

	finit
	./wal $(( $i * 4096 ))
	ffini

	printf " & "

	zinit
	./wal $(( $i * 4096 ))
	zfini

	printf " & "

	finit
	./checkpoint $(( $i * 4096 ))
	ffini

	printf " & "

	zinit
	./checkpoint $(( $i * 4096 ))
	zfini

	printf " & "

	sinit
	sleep 1
	./sastrack $(( $i * 4096 )) 
	sleep 1
	sfini

	printf " & "

	sinit
	sleep 1
	sysctl aurora_slos.sas_commit_async=1 >/dev/null 2>/dev/null
	./sastrack $(( $i * 4096 )) 
	sleep 1
	sysctl aurora_slos.sas_commit_async=0 >/dev/null 2>/dev/null
	sfini

	printf " & "

	printf "\\\\"

	printf "\n"
done
