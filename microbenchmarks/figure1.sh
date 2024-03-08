#!/bin/sh

. helper.sh

runexperiment()
{
	OBJPROT=$1
	TRACE=$2
	SIZE=$3
	METRIC=$4
	TMP=tmp

	sinit
	sysctl aurora.objprotect=$OBJPROT >/dev/null 2>/dev/null
	sysctl aurora.tracebuf=$TRACE >/dev/null 2>/dev/null
	./figure1.d >$TMP 2>$TMP &

	sleep 1

	./memsnap $SIZE  > /dev/null

	kill %1
	wait %1

	RESULT=`cat $TMP | grep $METRIC | tr -s ' ' | cut -d ' ' -f 3`
	RESULT=$(( $RESULT / 1000 ))
	printf "%d us\t" $RESULT

	sfini
}


printf "IO Size\tAurora Region\tMemSnap w/o Trace\tMemSnap\n"
for i in 1 1024; do
	printf "%d KB\t" $(( $i * 4 ))
	clean

	printf " & "

	runexperiment 0 0 $(( $i * 4096 )) "shadow"

	printf " & "

	runexperiment 1 0 $(( $i * 4096 )) "protect"

	printf " & "

	runexperiment 1 1 $(( $i * 4096 )) "protect"

	printf " & "
	printf "\\\\"

	printf "\n"
done
