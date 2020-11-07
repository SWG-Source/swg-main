#!/bin/bash

cd exe/linux

./bin/LoginServer -- @servercommon.cfg &

sleep 4

./bin/TaskManager -- @servercommon.cfg
