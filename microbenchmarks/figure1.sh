#!/bin/sh

. helper.sh

runexperiment()
{
	NAME=$1
	OBJPROT=$2
	TRACE=$3
	SIZE=$4
	TMP=tmp

	sinit
	sysctl aurora.objprotect=$OBJPROT >/dev/null 2>/dev/null
	sysctl aurora.tracebuf=$TRACE >/dev/null 2>/dev/null
	./$NAME.d > $TMP  2> $TMP &
	sleep 1

	./memsnap $SIZE  > /dev/null

	pkill dtrace
	sleep 1

	cat $TMP
	RESULT1=`cat $TMP | grep "shadow creation" | tr -s ' ' | cut -d " " -f 4`
	RESULT2=`cat $TMP | grep "Resetting tracking" | tr -s ' ' | cut -d " " -f 4`
	RESULT="$RESULT1$RESULT2"
	printf "%.1f us\t" `echo "scale=scale(1.1);$RESULT/1000" | bc`

	rm $TMP
	sfini
}


printf "IO Size\tAurora Region\tMemSnap w/o Trace\tMemSnap\n"
for i in 1 1024; do
	printf "%d KB\t" $(( $i * 4 ))
	clean

	printf " & "

	runexperiment memsnap 0 0 $(( $i * 4096 ))

	printf " & "

	runexperiment memsnap 1 0 $(( $i * 4096 ))

	printf " & "

	runexperiment memsnap 1 1 $(( $i * 4096 ))

	printf " & "
	printf "\\\\"

	printf "\n"
done
