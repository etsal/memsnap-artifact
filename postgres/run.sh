#!/usr/bin/env bash

. pg.config
. ../util.sh
. postgres-util.sh

export SRCROOT=/root/memsnap-artifact/aurora-memsnap/

. $SRCROOT/tests/aurora



print_usage() {
cat <<EOF
Usage: $0 [options]

-h| --help                  Help options.
-v| --vm                    Enable VM Mode    
-f| --fs                    FS to to setup in comma seperated list, formated like <fs>:<dev>:<mnt>
-o| --out                   Data out    
-s| --PMC Arguments         Enable pmcstat and capture specified counters
-b| --benchmark             pgbench or tpcc
-m| --main                  The main data directory for PostGreSQL
-i| --iter                  Run <i> times
-a| --attach                Attach and register SLS Checkpointer
-n| --nomake                Disable running configure and make 
-p| --pgargs <args>         Compile options for Postgres 
    For example:
      --pgargs "--with-slswal --extra_args"
    Extra Options are:
      --with-slswal
EOF

}

for arg in "$@"; do
  shift
  case "$arg" in
    '--help')       set -- "$@" '-h'   ;;
    '--vm')         set -- "$@" '-v'   ;;
    '--benchmark')  set -- "$@" '-b'   ;;
    '--main')       set -- "$@" '-m'   ;;
    '--fs')         set -- "$@" '-f'   ;;
    '--pgargs')     set -- "$@" '-p'   ;;
    '--pmc')        set -- "$@" '-s'   ;;
    '--out')        set -- "$@" '-o'   ;;
    '--nomake')     set -- "$@" '-n'   ;;
    '--iter')       set -- "$@" '-i'   ;;
    '--attach')     set -- "$@" '-a'   ;;
    *)              set -- "$@" "$arg" ;;
  esac
done

ISVM=false; WITHSLS=false; PGARGS=""; DATAOUT="out.log"
FSES=""; ITER=1; NOMAKE=false; DATADIR=""; BENCHMARK="pgbench"
PMCARGS=""; WITHSLS=false;

OPTIND=1
while getopts "hvf:p:o:i:nm:b:s:a" opt
do
  case "$opt" in
    'h') print_usage; exit 0 ;;
    'v') ISVM=true ;;
    'b') BENCHMARK=$OPTARG ;;
    'a') WITHSLS=true ;;
    'm') DATADIR=$OPTARG ;;
    'f') FSES=$OPTARG ;;
    's') PMCARGS=$OPTARG ;;
    'p') PGARGS=$OPTARG ;;
    'o') DATAOUT=$OPTARG ;;
    'n') NOMAKE=true ;;
    'i') ITER=$OPTARG ;;
    '?') print_usage >&2; exit 1 ;;
  esac
done
shift $(expr $OPTIND - 1) # remove options from positional parameters

if $ISVM; then
  FREQ=$VMFREQ
fi


if ! $NOMAKE; then
  pg_conf_and_make $PGARGS
fi

if [ "$PMCARGS" != "" ]; then
  util_setup_pmcstat
fi

for i in $(seq 1 $ITER); 
do

setup_fses $FSES

pgrun $BENCHMARK $WITHSLS "$PMCARGS"
mkdir -p "$OUT/$DATAOUT"
parse_bench $BENCHMARK $LAST >> "$OUT/$DATAOUT/$DATAOUT.csv"
mv "$OUT/last.log" "$OUT/$DATAOUT/$DATAOUT-last.log"
mv "$OUT/serverlog.last" "$OUT/$DATAOUT/$DATAOUT-serverlog.last"
mv "$OUT/pmc-graph.svg" "$OUT/$DATAOUT/"
mv "$OUT/processed-pmc.log" "$OUT/$DATAOUT/"
mv "$OUT/trx.out" "$OUT/$DATAOUT/"
mv "lock.log" "$OUT/$DATAOUT/"
if [ "$PMCARGS" != "" ]; then
  echo $PWD
  mv "$OUT/$PMCARGS" "$OUT/$DATAOUT/$PMCARGS"
  mv "$PMCARGS" "$OUT/$DATAOUT/$PMCARGS"
fi

rm pmc.out
mv rusage*.log "$OUT/$DATAOUT"
mv gstat.out "$OUT/$DATAOUT"
chmod -R a+rwx "$OUT/$DATAOUT"


teardown_fses $FSES

done
