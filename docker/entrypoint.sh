#!/bin/bash
# Starts the 64-bit SWG cluster. The first start against an empty database creates it.
set -euo pipefail
cd /swg-main

: "${SWG_PUBLIC_IP:?Set SWG_PUBLIC_IP to the address game clients connect to}"
DB="swg/swg@oracle/FREEPDB1"
SELF_IP=$(hostname -i | awk '{print $1}')

sql() { printf 'set heading off feedback off pagesize 0\n%s\nexit\n' "$1" | sqlplus -s "$DB"; }

echo "Waiting for the database..."
until sql "select 1 from dual;" | grep -q 1; do sleep 5; done

# Internal addresses (TaskManager, Central, Login) use this container's IP.
ant -q -Dfirstrun=true -DADDR4="$SELF_IP" update_configs

# Clients are told to connect to SWG_PUBLIC_IP.
cfg=exe/linux/localOptions.cfg
grep -q '^altPublicBindAddress=' "$cfg" \
    && sed -i "s/^altPublicBindAddress=.*/altPublicBindAddress=$SWG_PUBLIC_IP/" "$cfg" \
    || sed -i "s/^\[ConnectionServer\]\r\?$/&\naltPublicBindAddress=$SWG_PUBLIC_IP/" "$cfg"

if [ "$(sql "select count(*) from user_tables where table_name='CLUSTER_LIST';" | tr -d '[:space:]')" = "0" ]; then
    echo "Empty database: creating schema, cluster and templates."
    ant -Dfirstrun=true -DADDR4="$SELF_IP" create_database
    (cd build && sqlplus -s "$DB" @templates.sql < /dev/null)
fi

# Bring the database up to this build's version. Safe to repeat: updates
# that are already applied are skipped.
ant update_database

sql "update cluster_list set address='$SELF_IP' where name='swg'; commit;" > /dev/null

# Chat server (stationapi).
if [ ! -s chat/var/stationapi/stationchat.db ]; then
    mkdir -p chat/var/stationapi
    sqlite3 chat/var/stationapi/stationchat.db < chat/init_database.sql
fi
(cd chat && ./stationchat > /var/log/stationchat.log 2>&1 &)

ant create_symlinks
cd exe/linux
./bin/LoginServer -- @servercommon.cfg &
sleep 4
exec ./bin/TaskManager -- @servercommon.cfg
