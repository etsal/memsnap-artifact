#!/bin/sh
/usr/local/pgsql/bin/psql --host=127.0.0.1 --port=5432 --dbname=test --username=sbtest <<EOF
select * FROM blocking_tree 
\watch 1
EOF

