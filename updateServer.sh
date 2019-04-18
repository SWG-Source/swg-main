#!/bin/bash

basedir=$PWD
PATH=$PATH:$basedir/build/bin
DBSERVICE=
DBUSERNAME=
DBPASSWORD=
HOSTIP=
CLUSTERNAME=
NODEID=
DSRC_DIR=
DATA_DIR=

# Public facing - builds profdata
#MODE=RELWITHDEBINFO

# Public facing, builds heavily optimized bins
#MODE=MINSIZEREL

if [ ! -d $basedir/build ]
then
	mkdir $basedir/build
fi

echo -e "\n";
echo -e "\033[1;33m ___ __      __ ___   ___                                 _     ___  ";
echo -e "\033[1;33m/ __|\ \    / // __| / __| ___  _  _  _ _  __  ___  __ __/ |   |_  )";
echo -e "\033[1;33m\__ \ \ \/\/ /| (_ | \__ \/ _ \| || || '_|/ _|/ -_) \ V /| | _  / /";
echo -e "\033[1;33m|___/  \_/\_/  \___| |___/\___/ \_,_||_|  \__|\___|  \_/ |_|(_)/___|";
echo -e "\033[1;31m";


#GIT_USER=${response,,}
GIT_URL=https://github.com/SWG-Source/
GIT_REPO_DEPEND=${GIT_URL}dependencies.git
GIT_REPO_SRC=${GIT_URL}src.git
GIT_REPO_DSRC=${GIT_URL}dsrc.git
GIT_REPO_CONFIG=${GIT_URL}configs.git
GIT_REPO_CLIENTDATA=${GIT_URL}clientdata.git
GIT_REPO_DEPEND_BRANCH=master
GIT_REPO_SRC_BRANCH=master
GIT_REPO_DSRC_BRANCH=archive-1.2.1
GIT_REPO_CONFIG_BRANCH=master
GIT_REPO_CLIENTDATA_BRANCH=master



git pull
cd $basedir/src
git pull
cd $basedir
cd $basedir/dsrc
git pull
cd $basedir
cd $basedir/configs
git pull
cd $basedir
cd $basedir/clientdata
git pull
cd $basedir
MODE=Release


unset ORACLE_HOME;
unset ORACLE_SID;
unset JAVA_HOME;
export ORACLE_HOME=/usr/lib/oracle/12.2/client;
export JAVA_HOME=/usr/java;
export ORACLE_SID=swg;
rm -rf /home/swg/swg-main/build
mkdir /home/swg/swg-main/build
mkdir /home/swg/swg-main/build/bin
cd $basedir/build
export LDFLAGS=-L/usr/lib32
export CMAKE_PREFIX_PATH="/usr/lib32:/lib32:/usr/lib/i386-linux-gnu:/usr/include/i386-linux-gnu"
cmake -DCMAKE_C_FLAGS=-m32 \
-DCMAKE_CXX_FLAGS=-m32 \
-DCMAKE_EXE_LINKER_FLAGS=-m32 \
-DCMAKE_MODULE_LINKER_FLAGS=-m32 \
-DCMAKE_SHARED_LINKER_FLAGS=-m32 \
-DCMAKE_BUILD_TYPE=$MODE \
$basedir/src
make -j$(nproc)
strip -s bin/*
cd $basedir
oldPATH=$PATH
PATH=$basedir/build/bin:$PATH
$basedir/utils/build_java_multi.sh
$basedir/utils/build_miff.sh
$basedir/utils/build_tab_multi.sh
$basedir/utils/build_tpf_multi.sh
$basedir/utils/build_object_template_crc_string_tables.py
$basedir/utils/build_quest_crc_string_tables.py
PATH=$oldPATH


cd $basedir/stationapi
./build.sh
mv -T /home/swg/swg-main/stationapi/build/bin /home/swg/swg-main/chat
cd $basedir


echo -e "\033[1;33m";
echo "Congratulations the latest server updates have been downloaded and compiled!"
