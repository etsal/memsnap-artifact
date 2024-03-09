. pg.config
. tpccbench.sh

DIRECT=$PWD
cd $1
echo $PWD
rm -rf "$1/*"
initdb -D "$1" #> /dev/null 
rm /tmp/.s.PGSQL.* #> /dev/null 2>/dev/null
if $2; then
  echo "USING SLS CONF"
  cp $DIRECT/slspostgresql.conf $1/postgresql.conf
else
  echo "USING REGULAR CONF"
  cp $DIRECT/postgresql.conf $1
fi

# Config for allowed connections
cp $DIRECT/pg_hba.conf $1

truncate -s 0 "$SERVERLOG"
pg_ctl -D "$1" -l "$SERVERLOG" start #> /dev/null
sleep 1
createdb $DBNAME #> /dev/null
createuser -d -s sbtest #> /dev/null

