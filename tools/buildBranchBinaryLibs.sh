#!/bin/sh
# Copyright 2003, Sony Online Entertainment.
# All rights reserved.
#
# Based off a script originally written by Rick Delashmit.

# PURPOSE: Build the infrequently-changing Linux libraries that
# typically live in perforce as binaries.  The gcc 2.95.3 C++ libraries are
# incompatible with the gcc 3.x C++ libraries.  This script builds
# all the libraries that normally exist in perforce as binaries.

# NOTE: This script will fail if the user has not taken care to remove
# *.a and *.so from their client spec.  Those files will be read-only and
# the new compiled versions will fail to replace them.  As of this writing,
# the only .a file that should exist in perforce is the one for pcre in
# swg/$BRANCH/src/external/3rd/library/pcre/*.

# USAGE: run this script in the from the base directory of a branch.
#
# Here's some examples of branch directories:
#   ~/swg/current
#   ~/swg/test
#   /swo/swg/current

# BUGS:
#
# * This script does no error checking on the result of the builds.  If
# the caller does not watch the output, it is possible this script will fail.
#
# * This script has failed to build in the live branch on Matt Bogue's machine.
# Rick and I could not resolve the apparent bash substitution issue that was
# occurring.  Our workaround was to link the live branch's 
# external/3rd/library/platform/libs directory to the corresponding directory
# in the current branch.

export BASEDIR=`pwd`
export TEAMBUILDER=0
export PLATFORM=linux

# chatapi
cd $BASEDIR/src/external/3rd/library/soePlatform/ChatAPI2/ChatAPI/projects/Chat/ChatMono
make debug release
mkdir -p ../../../../../libs/Linux-Debug
mkdir -p ../../../../../libs/Linux-Release
cp ../../../lib/debug/libChatAPI.a ../../../../../libs/Linux-Debug/
cp ../../../lib/release/libChatAPI.a ../../../../../libs/Linux-Release/

# stlport
cd $BASEDIR/src/external/3rd/library/stlport453/src
make -f gcc-linux.mak

# zlib
# Note: just link zlib to the zlib already installed under Linux.
mkdir -p $BASEDIR/src/external/3rd/library/zlib/lib/linux
ln -s -f /usr/lib/libz.a $BASEDIR/src/external/3rd/library/zlib/lib/linux/libz.a

# loginapi
cd $BASEDIR/src/external/3rd/library/platform/projects/Session/LoginAPI
make debug release

# commonapi
cd $BASEDIR/src/external/3rd/library/platform/projects/Session/CommonAPI
make debug release

# base
cd $BASEDIR/src/external/3rd/library/platform/utils/Base/linux
make debug_st release_st

# commodityapi
cd $BASEDIR/src/external/3rd/library/soePlatform/CommodityAPI/linux
make debug release
cp $BASEDIR/src/external/3rd/library/soePlatform/libs/Linux-Debug/libcommodityapi.so $BASEDIR/exe/linux/
cp $BASEDIR/src/external/3rd/library/soePlatform/libs/Linux-Debug/libcommodityapi.so $BASEDIR/dev/linux/

# csassistgameapi
cd $BASEDIR/src/external/3rd/library/soePlatform/CSAssist/projects/CSAssist/CSAssistgameapi
make debug release

echo Copying csassistgameapi
mkdir -p ../../../../libs/Linux-Debug
mkdir -p ../../../../libs/Linux-Release

cp debug/libCSAssistgameapi.a ../../../../libs/Linux-Debug/
cp release/libCSAssistgameapi.a ../../../../libs/Linux-Release/
# note: this includes various other libs that CustomerServiceServer expects to link with, so is not compatible

echo Building monapi
# monapi
cd $BASEDIR/src/external/3rd/library/platform/MonAPI2
make clean
make all

# libOracleDB (CommodityServer)
cd $BASEDIR/src/external/3rd/library/soePlatform/CommodityServer/platform/utils/OracleDB
rm -f *.o
ls *.cpp |sed -e '/\.cpp/s///' -e '/^.*$/s//g++ -g -c -I..\/..\/..\/..\/..\/oracle\/include -I.. &.cpp -o &.o/' >comp.sh
source ./comp.sh
rm -f comp.sh
ar rcs libOracleDB.a *.o
mkdir -p ../../../../libs/Linux-Debug
mv -f libOracleDB.a ../../../../libs/Linux-Debug/libOracleDB.a

# libBase (CommodityServer)
cd $BASEDIR/src/external/3rd/library/soePlatform/CommodityServer/platform/utils/Base
rm -f *.o */*.o
ls *.cpp linux/*.cpp |sed -e '/\.cpp/s///' -e '/^.*$/s//g++ -g -c -Dlinux=1 -D_REENTRANT &.cpp -o &.o/' >comp.sh
source ./comp.sh
rm -f comp.sh
ar rcs libBase.a *.o linux/*.o
mkdir -p ../../../../libs/Linux-Debug
mv -f libBase.a ../../../../libs/Linux-Debug/libBase.a

# Create an empty library.a to solve makefile dependencies on libCSAssistBase.a and libCSAssistUnicode.a
echo > /tmp/empty.cpp
g++ -c -o /tmp/empty.o /tmp/empty.cpp
ar crs /tmp/empty.a /tmp/empty.o

mkdir -p $BASEDIR/src/external/3rd/library/soePlatform/libs/Linux-Debug
cp /tmp/empty.a $BASEDIR/src/external/3rd/library/soePlatform/libs/Linux-Debug/libCSAssistBase.a
cp /tmp/empty.a $BASEDIR/src/external/3rd/library/soePlatform/libs/Linux-Debug/libCSAssistUnicode.a

mkdir -p $BASEDIR/src/external/3rd/library/soePlatform/libs/Linux-Release
cp /tmp/empty.a $BASEDIR/src/external/3rd/library/soePlatform/libs/Linux-Release/libCSAssistBase.a
cp /tmp/empty.a $BASEDIR/src/external/3rd/library/soePlatform/libs/Linux-Release/libCSAssistUnicode.a

# Build CommoditiesServer_d and CommoditiesServer_r
# .. start with local OracleDB library
cd $BASEDIR/src/external/3rd/library/soePlatform/CommodityServer/platform/utils/OracleDB
make all

# .. now do the server
cd ../../..
make all

# Copy CommoditiesServer_* to exe/linux.  The normal
# make process copies those from exe/linux to dev/linux.
cp commoditysvr $BASEDIR/exe/linux/CommoditiesServer_d
cp commoditysvr $BASEDIR/exe/linux/CommoditiesServer_r

# Remove the debugging symbols from the release version.
# This save 80+ MB.
strip -g $BASEDIR/exe/linux/CommoditiesServer_r

# Copy Commodities server from exe/linux to dev/linux for the first time.  Failure to do this
# will cause the build to break.
cp $BASEDIR/exe/linux/CommoditiesServer_* $BASEDIR/dev/linux

# Build the MonAPI2 library.
cd $BASEDIR/src/external/3rd/library/platform/MonAPI2
./bootstrap
./configure --with-udplibrary=../../udplibrary --prefix=`pwd`
make
make install
