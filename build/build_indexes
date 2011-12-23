#!/bin/bash

BASE=$(dirname $0)
PATH=$PATH:$BASE/bin
SQL="$BASE/sql"

# Just run the SQL that constructs the indexes.
sqlite3 $1 < ${SQL}/index.sql
