#!/bin/sh

DATA=$1

echo "Compiling the report..."

./report-vsaurora.py $DATA &
VSAURORA="$!"
./report-dtrace.py $DATA &
DTRACE="$!"
./report-svgtopdf.py $DATA &
SVGTOPDF="$!"
./report-svgparsing.py $DATA &
SVGPARSING="$!"
./report-rusage.py $DATA &
RUSAGE="$!"
# XXX SYSCTL 

echo "Waiting for compilation."
wait $VSAURORA
echo "Compiled dbbench."
wait $DTRACE
echo "Compiled dtrace."
wait $SVGTOPDF
echo "Compiled svgtopdf."
wait $SVGPARSING
echo "Compiled svgparsing."
wait $RUSAGE
echo "Compiled rusage."

echo "Compiling final report..."
pdfunite report-vsaurora.pdf \
	report-dtrace.pdf \
	report-rusage-*.pdf \
	report-flamegraph-slsdb-*.pdf \
	report-pmcstat-slsdb-*.pdf \
	report-flamegraph-aurora-*.pdf \
	report-pmcstat-aurora-*.pdf \
	report.pdf

echo "Done."
rm report-*.pdf
