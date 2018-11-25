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

echo -e "\033[1;36m";
#Commenting this for now... This script doesn't pull anyways.
#read -p "What is your GIT username (so we can get the code correctly): " response
#GIT_USER=${response,,}
#GIT_URL=https://${GIT_USER}@github.com/SWG-Source/
#GIT_REPO_DEPEND=${GIT_URL}dependencies.git
#GIT_REPO_SRC=${GIT_URL}src.git
#GIT_REPO_DSRC=${GIT_URL}dsrc.git
#GIT_REPO_CONFIG=${GIT_URL}configs.git
#GIT_REPO_CLIENTDATA=${GIT_URL}clientdata.git

# specify git branches for each repo
#GIT_REPO_DEPEND_BRANCH=master
#GIT_REPO_SRC_BRANCH=master
#GIT_REPO_DSRC_BRANCH=master
#GIT_REPO_CONFIG_BRANCH=master
#GIT_REPO_CLIENTDATA_BRANCH=master


echo -e "\033[2;31m******************************************************************
Begin individual building of scripts for /dsrc to /data
******************************************************************";
echo -e "\033[2;36m";
read -p "Do you want to recompile the scripts (.java)? (y/n) " response
response=${response,,} # tolower
if [[ $response =~ ^(yes|y| ) ]]; then
	#prepare environment to run data file builders
	oldPATH=$PATH
	PATH=$basedir/build/bin:$PATH

	read -p "Do you wanna use multi-core building (default) or stick with the safe option? You may need to rerun the single version if there are stragglers. (multi/safe) " response
    response=${response,,}
	if [[ $response =~ ^(multi|m| ) ]]; then
	  $basedir/utils/build_java_multi.sh
	else
	  $basedir/utils/build_java.sh
	fi

	PATH=$oldPATH
fi

buildTemplates=false

read -p "Do you want to build the mIFF files (.mif)? (y/n) " response
response=${response,,}
if [[ $response =~ ^(yes|y| ) ]]; then
	#prepare environment to run data file builders
	oldPATH=$PATH
	PATH=$basedir/build/bin:$PATH

	$basedir/utils/build_miff.sh

	buildTemplates=true

	PATH=$oldPATH
fi

read -p "Do you want to build the datatables (.tab)? (y/n) " response
response=${response,,}
if [[ $response =~ ^(yes|y| ) ]]; then
	#prepare environment to run data file builders
	oldPATH=$PATH
	PATH=$basedir/build/bin:$PATH

	read -p "Do you wanna use multi-core building (default) or stick with the safe option? You may need to rerun the single version if there are stragglers. (multi/safe) " response
   response=${response,,}
	if [[ $response =~ ^(multi|m| ) ]]; then
	  $basedir/utils/build_tab_multi.sh
	else
	  $basedir/utils/build_tab.sh
	fi

	buildTemplates=true

	PATH=$oldPATH
fi

read -p "Do you want to build the template files (.tpf)? (y/n) " response
response=${response,,}
if [[ $response =~ ^(yes|y| ) ]]; then
	#prepare environment to run data file builders
	oldPATH=$PATH
	PATH=$basedir/build/bin:$PATH

	read -p "Do you wanna use multi-core building (default) or stick with the safe option? You may need to rerun the single version if there are stragglers. (multi/safe) " response
    response=${response,,}
	if [[ $response =~ ^(multi|m| ) ]]; then
	  $basedir/utils/build_tpf_multi.sh
	else
	  $basedir/utils/build_tpf.sh
	fi

	buildTemplates=true

	PATH=$oldPATH
fi

if [[ $buildTemplates = false ]]; then
	read -p "Do you want to build the Object Template or Quest CRC files? (y/n) " response
	response=${response,,}
	if [[ $response =~ ^(yes|y| ) ]]; then
		$buildTemplates=true
	fi
fi

templatesLoaded=false

if [[ $buildTemplates = true ]]; then
	echo "Object Template and Quest CRC files will now be built and re-imported into the database."

	if [[ -z "$DBSERVICE" ]]; then
		echo "Enter the DSN for the database connection e.g. //127.0.0.1/swg"
		read DBSERVICE
	fi

	if [[ -z "$DBUSERNAME" ]]; then
		echo "Enter the database username "
		read DBUSERNAME
	fi

	if [[ -z "$DBPASSWORD" ]]; then
		echo "Enter the database password "
		read DBPASSWORD
	fi

	#prepare environment to run data file builders
	oldPATH=$PATH
	PATH=$basedir/build/bin:$PATH

	$basedir/utils/build_object_template_crc_string_tables.py
	$basedir/utils/build_quest_crc_string_tables.py

	cd $basedir/src/game/server/database

	echo "Loading template list"

	perl ./templates/processTemplateList.pl < $basedir/dsrc/sku.0/sys.server/built/game/misc/object_template_crc_string_table.tab > $basedir/build/templates.sql
	sqlplus ${DBUSERNAME}/${DBPASSWORD}@${DBSERVICE} @$basedir/build/templates.sql > $basedir/build/templates.out

	templatesLoaded=true

	cd $basedir
	PATH=$oldPATH
fi
echo -e "\033[2;36m";
echo -e "\033[1;31m******************************************************************
END of individual building of scripts for /dsrc to /data
******************************************************************"
