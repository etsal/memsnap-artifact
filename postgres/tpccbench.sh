#!/usr/bin/env bash
TABLES=10
SCALE=15
TIME=120
THREADS=24
HOST="129.97.75.131"

preparetpcc() {
  cd sysbench-tpcc
   cpuset -c -l 24-47 ./tpcc.lua --tables=$TABLES --db-driver=pgsql --pgsql-user=sbtest \
    --pgsql-db=test --threads=$THREADS --scale=$SCALE --report-interval=1 \
    --time=$TIME prepare
  cd -
}

runtpcc () {
	cd sysbench-tpcc
  TXNIDB=$(psql -U sbtest -d test -c "SELECT pg_current_xact_id();")
	cpuset -c -l 24-47 ./tpcc.lua --tables=$TABLES --db-driver=pgsql \
	--pgsql-user=sbtest --pgsql-db=test \
	--threads=$THREADS --time=$TIME --trx_level=RC --scale=$SCALE run &
	PID=$!

  # Let it ramp up
  sleep 20

	RUSAGEF="rusage${THREADS}t-before.log"
	procstat rusage `pidof postgres` > $RUSAGEF 
	echo "=== PS ===" >> $RUSAGEF
	ps -ax | grep postgres >> $RUSAGEF
	mv $RUSAGEF ../

  gstat -I 1s -C -f st0 > gstat.out &
  # 30 Second snapshot
  sleep 30

  kill -9 `pidof gstat`
  mv gstat.out ../

	RUSAGEF="rusage${THREADS}t-after.log"
	procstat rusage `pidof postgres` > $RUSAGEF 
	echo "=== PS ===" >> $RUSAGEF
	ps -ax | grep postgres >> $RUSAGEF
	mv $RUSAGEF ../



  #PGPID=$(psql -U sbtest -d test -c "SELECT pid FROM pg_stat_activity WHERE state = 'active'" \
  #  | head -5 | tail -1)

  #dtrace -qs ../transaction.d -o ../trx.out $PGPID &
	sleep $(expr $TIME - 55)


	RUSAGEF="rusage${THREADS}t.log"
	procstat rusage `pidof postgres` > $RUSAGEF 
	echo "=== PS ===" >> $RUSAGEF
	ps -ax | grep postgres >> $RUSAGEF

	wait $PID

  psql -U sbtest -d test -c "CHECKPOINT;"

  sleep 40

	echo "=== CHECKPOINT ===" >> $RUSAGEF
	procstat rusage `pidof postgres` >> $RUSAGEF 
	mv $RUSAGEF ../


  TXNIDA=$(psql -U sbtest -d test -c "SELECT pg_current_xact_id();")
  echo "before $TXNIDB, after $TXNIDA"

	cd -
}

cleantpcc() {
  cd sysbench-tpcc
  ./tpcc.lua --tables=$TABLES --db-driver=pgsql \
  	--pgsql-user=sbtest --pgsql-db=test --threads=$THREADS --scale=$SCALE --report-interval=1 --time=$TIME cleanup
  cd -
}
