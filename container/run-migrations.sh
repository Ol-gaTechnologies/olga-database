#!/bin/sh
set -eu

: "${OLGA_POSTGRES_CONNECTION_STRING:?OLGA_POSTGRES_CONNECTION_STRING is required}"

remaining=$OLGA_POSTGRES_CONNECTION_STRING
pg_host=''
pg_port='5432'
pg_database=''
pg_user=''
pg_password=''

while [ -n "$remaining" ]; do
  case "$remaining" in
    *';'*)
      component=${remaining%%;*}
      remaining=${remaining#*;}
      ;;
    *)
      component=$remaining
      remaining=''
      ;;
  esac
  key=${component%%=*}
  value=${component#*=}
  case "$key" in
    Host) pg_host=$value ;;
    Port) pg_port=$value ;;
    Database) pg_database=$value ;;
    Username) pg_user=$value ;;
    Password) pg_password=$value ;;
  esac
done

: "${pg_host:?PostgreSQL Host is missing from the connection string}"
: "${pg_database:?PostgreSQL Database is missing from the connection string}"
: "${pg_user:?PostgreSQL Username is missing from the connection string}"
: "${pg_password:?PostgreSQL Password is missing from the connection string}"

export PGHOST=$pg_host PGPORT=$pg_port PGDATABASE=$pg_database PGUSER=$pg_user PGPASSWORD=$pg_password
export PGSSLMODE=verify-full PGCONNECT_TIMEOUT=15
unset OLGA_POSTGRES_CONNECTION_STRING pg_password

echo "Starting OLGA database deployment against ${PGHOST}/${PGDATABASE}."
exec psql --no-psqlrc --echo-errors --set=ON_ERROR_STOP=on \
  --set="seed_mvp_policies=${SEED_MVP_POLICIES:-0}" --file=/migrations/deploy.sql
