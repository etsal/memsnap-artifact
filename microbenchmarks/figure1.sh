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

runmemsnap()
{
	SIZE=$1
	USE_OBJSNAP=$2
	TMP=tmp

	sinit_objsnap
	./sastrack.d >$TMP 2>$TMP &

	sleep 1

	if [ $USE_OBJSNAP = "yes" ]; then
		./memsnap-objsnap-combo $SIZE > /dev/null
	else
		./sastrack $SIZE  > /dev/null
	fi

	RESULT=`cat $TMP | grep "Resetting tracking" | tr -s ' ' #| cut -d ' ' -f 3`
	#RESULT=$(( $RESULT / 1000 ))
	printf "%d us\t" $RESULT

	kill %1
	wait %1

	sfini_objsnap
}

printf "IO Size\tAurora Region\tMemSnap w/o Trace\tMemSnap (Aurora)\tMemSnap (SAS)\tMemSnap (ObjSnap)\n"
for i in 1 1024; do
	printf "%d KB\t" $(( $i * 4 ))
	clean

	SIZE=$(( $i * 4096 ))

	printf " & "

	runexperiment 0 0 $SIZE "shadow"

	printf " & "

	runexperiment 1 0 $SIZE "protect"

	printf " & "

	runexperiment 1 1 $SIZE "protect"

	printf " & "

	runmemsnap $SIZE "no"

	printf " & "

	runmemsnap $SIZE "yes"

	printf "\\\\"

	printf "\n"
done
