#/usr/bin/env bash

. pg.config

postgres_setup()
{
  echo "Fetching PostgreSQL Repo"
  git clone --depth=1 https://github.com/krhancoc/postgres.git postgres

  echo "Adding correct users"
  sudo adduser -f users > /dev/null 2> /dev/null
  # CREATE THE POSTGRES USER - No password auth
  sudo pw user add -n postgres -s /bin/sh -m -w none

  #echo "Install dependencies"
  #sudo pkg install readline flex bison python gmake autoconf sysbench sudo
}

postgres_setup
