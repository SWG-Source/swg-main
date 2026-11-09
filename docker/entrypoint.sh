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
rm -f .shutdown
./bin/LoginServer -- @servercommon.cfg &
login=$!
sleep 4
./bin/TaskManager -- @servercommon.cfg &
taskmanager=$!

# "docker compose stop" sends SIGTERM. Shut the cluster down the normal way so
# it saves: CentralServer checks for a .shutdown file (every 30 seconds), warns
# players, runs a final database save, then has TaskManager stop every server.
# If that takes longer than SWG_STOP_TIMEOUT seconds, the remaining servers are
# killed. Keep stop_grace_period in docker-compose.yml longer than this.
stop_timeout=${SWG_STOP_TIMEOUT:-240}
stop_requested=
on_stop() {
    [ -n "$stop_requested" ] && return
    stop_requested=$SECONDS
    echo "Stop requested: saving and shutting down the cluster (up to ${stop_timeout}s)..."
    echo 1 > .shutdown
}
trap on_stop TERM INT

# Until a stop is requested, sleep in wait (a trapped signal interrupts it).
# After that, poll each second so the timeout can fire.
while kill -0 "$taskmanager" 2>/dev/null; do
    if [ -z "$stop_requested" ]; then
        wait "$taskmanager" 2>/dev/null || true
        continue
    fi
    # CentralServer finishes the save and stops the servers, but TaskManager
    # itself stays up. Once every server process is gone, the shutdown is done.
    if ! pgrep -f 'bin/(CentralServer|SwgDatabaseServer|SwgGameServer|PlanetServer|ConnectionServer)' >/dev/null; then
        echo "Cluster saved and stopped after $((SECONDS - stop_requested))s."
        kill "$taskmanager" 2>/dev/null || true
        break
    fi
    if [ $((SECONDS - stop_requested)) -ge "$stop_timeout" ]; then
        echo "Shutdown did not finish within ${stop_timeout}s; stopping the remaining servers."
        pkill -9 -f 'bin/(TaskManager|CentralServer|SwgGameServer|SwgDatabaseServer|PlanetServer|ConnectionServer|ChatServer|CommoditiesServer|LogServer|TransferServer|MetricsServer|CustomerServiceServer)' || true
        break
    fi
    sleep 1
done

kill "$login" 2>/dev/null || true
pkill stationchat 2>/dev/null || true
wait 2>/dev/null || true
