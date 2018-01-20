#/bin/bash

destination="data/sku.0/sys.server/compiled/game"
sourcepath="dsrc/sku.0/sys.server/compiled/game"

mkdir -p $destination/script

javac -Xlint:-options -encoding utf8 -classpath "$destination" -d "$destination" -sourcepath "$sourcepath" -g -deprecation "$1"
