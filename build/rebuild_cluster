#!/bin/bash

BASE=$(dirname $0)
PATH=$PATH:$BASE/bin
SQL="$BASE/sql"

OLD_DB=$1
DATABASE=${OLD_DB}.$$

[ -r $DATABASE ] && echo "$DATABASE already exists." && exit -1
[ ! -r $OLD_DB ] && echo "Can't read $OLD_DB." && exit -1

# Create a shiny new database, attach the old one,
#   extract the data from it, and then index that.
#   Finally, overwrite the old database with the new one.
( cat ${SQL}/create.sql && \
  echo "ATTACH DATABASE '${OLD_DB}' AS old;" && \
  cat ${SQL}/cluster.sql && \
  echo "DETACH DATABASE old;" && \
  cat ${SQL}/index.sql && \
  echo "ANALYZE;" ) | sqlite3 $DATABASE \
  && mv $DATABASE $OLD_DB
