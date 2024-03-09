#!/usr/bin/env bash

. pg.config
. tpccbench.sh

ASPG="sudo -u postgres"

pg_conf_and_make() {
  CWD=$PWD
  cd postgres
  echo "Cleaning repo..."
  gmake clean distclean > /dev/null 2> /dev/null
  sudo rm -rf /usr/local/pgsql
  echo "Configuring postgres..."
  ./configure \
     --with-perl \
     --with-python \
     --with-openssl \
     --with-libraries=/usr/local/lib:/usr/lib/libsls \
     --without-readline \
     --with-includes=/usr/local/include:$SRCROOT/include/ ${@} > /dev/null 2> /dev/null
  echo "Building with args (${@})"
  gmake -j $(sysctl -n hw.ncpu) > /dev/null 2> /dev/null
  sudo gmake install > /dev/null 2> /dev/null
  cd $CWD
}

create_dirs() {
  echo "Creating directories..."
  sudo mkdir -p "$DATADIR" >/dev/null 2>/dev/null
  sudo chmod a+rwx "$DATADIR"
  sudo chown postgres $DATADIR
}


clean_database() {
  echo "Stopping and cleaning DB..."
  $ASPG pg_ctl stop -D "$1"
  cp -r "$1/log" "$OUT/$DATAOUT/"
  sudo rm -rf "$1"
}

just_clean_database() {
  echo "Stopping and cleaning DB..."
  $ASPG pg_ctl stop -D "$1"
  sudo rm -rf "$1"
}


parse_log() {
  TOTALCKPT_SEC=$(grep -o 'total=[0-9]*\.[0-9]*' "$1" -r '$1' | awk '{n+=$1} END {print n}')
  TOTALSYNC_SEC=$(grep -o 'sync=[0-9]*\.[0-9]*' "$1" -r '$1' | awk '{n+=$1} END {print n}')
  TOTALWRITE_SEC=$(grep -o 'write=[0-9]*\.[0-9]*' "$1" -r '$1' | awk '{n+=$1} END {print n}')
  echo "$TOTALCKPT_SEC, $TOTALSYNC_SEC, $TOTALWRITE_SEC"
}

parse_bench() {
  if [ "$1" = "pgbench" ]; then
    TPS=$(grep "tps = .* (including connections" $2 | awk -F ' ' '{print $3}')
    ICT=$(grep "initial connection time =" $2 | awk -F ' ' '{print $5}')
    LAT=$(grep "latency average =" $2 | awk -F ' ' '{print $4}')
    PERCLIENT=$(grep "number of transactions per client:" $2 | awk -F ' ' '{print $6}')
    NUMTRAN=$(grep "number of transactions actually processed:" $2 | awk -F ' ' '{print $6}')
    FAILED=$(grep "number of failed transactions:" $2 | awk -F ' ' '{print $5}')
    LOGPARSE=$(parse_log "data/serverlog.last")
    echo "$TPS, $ICT, $LAT, $PERCLIENT, $NUMTRAN, $FAILED, $LOGPARSE, $1"
  elif [ "$1" = "tpcc" ]; then
    TPS=$(grep "transactions: " $2 | awk -F'[()]' '{print $2}' | awk -F' ' '{print $1}')
    QPS=$(grep "queries: " $2 | awk -F'[()]' '{print $2}' | awk -F' ' '{print $1}')
    LAT=$(grep "avg: " $2 | awk -F' ' '{print $2}')
    LATMAX=$(grep "max: " $2 | awk -F' ' '{print $2}')
    LATMIN=$(grep "min: " $2 | awk -F' ' '{print $2}')
    LATNINEFIVE=$(grep "95th percentile: " $2 | awk -F' ' '{print $3}')
    LOGPARSE=$(parse_log "data/serverlog.last")
    echo "$TPS, $QPS, $LAT, $LATMAX, $LATMIN, $LATNINEFIVE, $LOGPARSE, $1"
  fi
}

pgattach() {
  POSTGRESPID=$(head -n 1 "/testmnt/data/postmaster.pid")
  # slsctl partadd slos -o "1000" -d -i
  # echo "POSTGRESPID $POSTGRESPID"
  # slsctl attach -p "$POSTGRESPID" -o "1000"
  # slsctl checkpoint -o "1000" -r
}

hwpmcprocess() {
  util_stop_pmcstat
  util_process_pmcstat "$OUT/" "$OUT/pmc.out" "$OUT/processed-pmc.log" "$OUT/pmc-graph.svg"
}

pgsetup() {
  create_dirs
  if [[ "$1" = "true" ]]; then
    $ASPG ./setup-db.sh $DATADIR true
  else
    $ASPG ./setup-db.sh $DATADIR false
  fi
}

pgrun() {
  pgsetup $2
  if [ "$1" = "pgbench" ]; then

    echo "Initializing database - $DBNAME"
    $ASPG pgbench -i -s $DBSIZE_1GB $DBNAME > /dev/null 2> /dev/null

    if [[ "$2" = "true" ]]; then
      pgattach
    fi

    echo "Running pgbench - sending results to $OUT/last.log"
    mkdir -p $OUT > /dev/null 2> /dev/null
    chmod a+rwx $OUT

    if [ "$3" != "" ]; then
      util_start_pmcstat_args "data/pmc.out" "$3"
    fi

    $ASPG pgbench -c 10 -j 2 -t 5000 $DBNAME > $OUT/last.log

    if [ "$3" != "" ]; then
      echo $PWD
      hwpmcprocess "$3"
    fi


  elif [ "$1" = "tpcc" ]; then
    for x in `pidof postgres`;
    do
        cpuset -l 0-24 -c -p $x
    done

    preparetpcc

    if [[ "$2" = "true" ]]; then
      pgattach
    fi

    if [ "$3" != "" ]; then
      util_start_pmcstat_args "$OUT/pmc.out" "$3"
    fi

    runtpcc > $OUT/last.log

    echo "=== SYSCTL ===" >> $OUT/last.log
    sysctl aurora >> $OUT/last.log

    if [ "$3" != "" ]; then
      hwpmcprocess "$3"
    fi

  fi

  chmod -R a+rw "data"
  cat /testmnt/data/log/* > "data/serverlog.last"

  clean_database $DATADIR
}

if_stripe_setup() {
  IFS=";" read -ra fses <<< "$1"
  if [ "${#fses[@]}" -gt 1 ]; then
   gstripe destroy st0
   gstripe create -s $2 -v st0 "${fses[@]}"
   return 0
  fi
  return 1
}

if_stripe_destroy() {
  IFS=";" read -ra fses <<< "$1"
  if [ "${#fses[@]}" -gt 1 ]; then
   gstripe destroy st0
   return 0
  fi
  return 1
}

setup_fs() {
  FS_VAR=$1
  DEV_VAR=$2
  MNT_VAR=$3
  PERM_VAR=$4
  

  case "$FS_VAR" in
    "sls")
      if if_stripe_setup "$DEV_VAR" "65536"; then
        DISKPATH="/dev/stripe/st0"
      else
        DISKPATH="/dev/$DEV_VAR"
      fi
      util_teardown_aurora $MNT_VAR > /dev/null 2> /dev/null
      util_setup_aurora $MNT_VAR $FREQ
      ;;
    "ffs")
      if if_stripe_setup "$DEV_VAR" "65536"; then
        DISKPATH="/dev/stripe/st0"
      else
        DISKPATH="/dev/$DEV_VAR"
      fi
      util_setup_ffs $MNT_VAR $DISKPATH
      ;;
    "zfs")
      util_setup_zfs $MNT_VAR $DEV_VAR
      ;;
    *)
      print_usage
      exit 1
      ;;
  esac

  chmod $4 "$MNT_VAR"
}

teardown_fs() {
  FS_VAR=$1
  DEV_VAR=$2
  MNT_VAR=$3
  PERM_VAR=$4

  
  case "$FS_VAR" in
    "sls")
      if if_stripe_destroy "$DEV_VAR"; then
        DISKPATH="/dev/stripe/st0"
      else
        DISKPATH="/dev/$DEV_VAR"
      fi
      util_teardown_aurora $MNT_VAR > /dev/null 2> /dev/null
      ;;
    "ffs")
      if if_stripe_destroy "$DEV_VAR"; then
        DISKPATH="/dev/stripe/st0"
      else
        DISKPATH="/dev/$DEV_VAR"
      fi
      util_teardown_ffs $MNT_VAR
      ;;
    "zfs")
      util_teardown_zfs $MNT_VAR
      ;;
    *)
      echo "Should never reach this"
      print_usage
      exit 1
      ;;
  esac

  rm -rf "$MNT_VAR/*"
}

setup_fses()
{
  IFS="," read -ra fses <<< "$1"
  for fs in "${fses[@]}";
  do
    IFS=":" read -ra fsvals <<< "$fs"
    FS_VAR="${fsvals[0]}"
    DEV_VAR="${fsvals[1]}"
    MNT_VAR="${fsvals[2]}"
    PERM_VAR="${fsvals[3]}"

    setup_fs "$FS_VAR" "$DEV_VAR" "$MNT_VAR" "$PERM_VAR"
  done
}

pmc_processdir()
{
  cd $1
  PMCTXT=processed-pmc.log
  touch $PMCTXT
	echo "======================SLS=======================" >> $PMCTXT
	gprof /boot/modules/sls.ko inst_retired.any/sls.ko.gmon >> $PMCTXT
	echo "======================SLOS======================" >> $PMCTXT
	gprof /boot/modules/slos.ko inst_retired.any/slos.ko.gmon >> $PMCTXT
	echo "=====================KERNEL=====================" >> $PMCTXT
	gprof /boot/kernel/kernel inst_retired.any/kernel.gmon >> $PMCTXT
  echo "=====================POSTGRES=====================" >> $PMCTXT
	gprof /usr/local/pgsql/bin/postgres inst_retired.any/postgres.gmon >> $PMCTXT
  cd -
}

teardown_fses()
{
  IFS="," read -ra fses <<< "$1"
  for fs in "${fses[@]}";
  do
    IFS=":" read -ra fsvals <<< "$fs"
    FS_VAR="${fsvals[0]}"
    DEV_VAR="${fsvals[1]}"
    MNT_VAR="${fsvals[2]}"
    PERM_VAR="${fsvals[3]}"

    teardown_fs "$FS_VAR" "$DEV_VAR" "$MNT_VAR" "$PERM_VAR"
  done

}


