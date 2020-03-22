#!/bin/bash

ant stop

cd exe/linux

export LLVM_PROFILE_FILE="output-%p.profraw"

killall LoginServer &> /dev/null
killall CentralServer &> /dev/null
killall ChatServer &> /dev/null
killall CommoditiesServer &> /dev/null
killall ConnectionServer &> /dev/null
killall CustomerServiceServer &> /dev/null
killall LogServer &> /dev/null
killall MetricsServer &> /dev/null
killall PlanetServer &> /dev/null
killall ServerConsole &> /dev/null
killall SwgDatabaseServer &> /dev/null
killall SwgGameServer &> /dev/null 
killall TransferServer &> /dev/null

./bin/LoginServer -- @servercommon.cfg &

sleep 5

./bin/TaskManager -- @servercommon.cfg
