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

read -p "What is your GIT username (so we can get the code correctly): " response
GIT_USER=${response,,}
GIT_URL=https://${GIT_USER}@bitbucket.org/theswgsource/
GIT_REPO_DEPEND=${GIT_URL}dependencies-1.2.git
GIT_REPO_SRC=${GIT_URL}src-1.2.git
GIT_REPO_DSRC=${GIT_URL}dsrc-1.2.git
GIT_REPO_CONFIG=${GIT_URL}configs-1.2.git

if [ ! -f $basedir/.setup ]; then
	if [[ $(lsb_release -a) =~ .*Ubuntu.* ]] || [ -f "/etc/debian_version" ]
	then
		read -p "!!!ONLY RUN ONCE!!! Do you want to install dependencies (y/n)?" response
		response=${response,,} # tolower
		if [[ $response =~ ^(yes|y| ) ]]; then
			if [ ! -d $basedir/dependencies ]; then
				git clone $GIT_REPO_DEPEND src
			else
				cd $basedir/dependencies
				git pull
				cd $basedir
			fi
			$basedir/utils/init/debian.sh
			source /etc/profile.d/java.sh
			source /etc/profile.d/oracle.sh
			touch $basedir/.setup
			
			echo "Please login and out or reboot as changes have been made to your PATH "
		fi
	fi
fi

read -p "Do you want to pull/update git? (y/n) " response
response=${response,,} # tolower
if [[ $response =~ ^(yes|y| ) ]]; then
	# update main repo
	git pull

	# update or clone each sub-repo
	if [ ! -d $basedir/src ]; then
		git clone $GIT_REPO_SRC src
	else
		cd $basedir/src
		git pull
		cd $basedir
	fi

	if [ ! -d $basedir/dsrc ]; then
		git clone $GIT_REPO_DSRC dsrc
	else
		cd $basedir/dsrc
		git pull
		cd $basedir
	fi

	if [ ! -d $basedir/configs ]; then
		git clone $GIT_REPO_CONFIG configs
	else
		cd $basedir/configs
		git pull
		cd $basedir
	fi
fi

read -p "Is this for DEBUG mode or RELEASE mode? (d/r): " response
response=${response,,}
if [[ $response =~ ^(debug|d| ) ]]; then
	MODE=Debug
else
	MODE=Release
fi

read -p "Do you want to recompile the server code (C++) now? (y/n) " response
response=${response,,} # tolower
if [[ $response =~ ^(yes|y| ) ]]; then
	cd $basedir/build

	# prefer clang
	# if type clang &> /dev/null; then
	#	export CC=clang
	#	export CXX=clang++
	# fi	

	if [ $(arch) == "x86_64" ]; then
        	export LDFLAGS=-L/usr/lib32
		export CMAKE_PREFIX_PATH="/usr/lib32:/lib32:/usr/lib/i386-linux-gnu:/usr/include/i386-linux-gnu"

		cmake -DCMAKE_C_FLAGS=-m32 \
		-DCMAKE_CXX_FLAGS=-m32 \
		-DCMAKE_EXE_LINKER_FLAGS=-m32 \
		-DCMAKE_MODULE_LINKER_FLAGS=-m32 \
		-DCMAKE_SHARED_LINKER_FLAGS=-m32 \
		-DCMAKE_BUILD_TYPE=$MODE \
		$basedir/src
	else
		cmake $basedir/src -DCMAKE_BUILD_TYPE=$MODE
	fi

	make -j$(nproc)

	if [[ $MODE =~ ^(Release) ]]; then
		strip -s bin/*
	fi

	cd $basedir
fi

read -p "Do you want to build the config environment now? (y/n) " response
response=${response,,} # tolower
if [[ $response =~ ^(yes|y| ) ]]; then

	# Prompt for configuration environment.
	read -p "Configure environment (local, live, tc, design)? You probably want local. " config_env

	# Make sure the configuration environment exists.
	if [ ! -d $basedir/configs/$config_env ]; then
		echo "Invalid configuration environment."
		exit
	fi

        
	echo "Enter your IP address (LAN for port forwarding or internal, outside IP for DMZ)"
	read HOSTIP

	echo "Enter the DSN for the database connection "
	read DBSERVICE

	echo "Enter the database username "
	read DBUSERNAME

	echo "Enter the database password "
	read DBPASSWORD

	echo "Enter a name for the galaxy cluster "
	read CLUSTERNAME

	if [ -d $basedir/exe ]; then
		rm -rf $basedir/exe
	fi

	mkdir -p $basedir/exe/linux/logs
	mkdir -p $basedir/exe/shared

	ln -s $basedir/build/bin $basedir/exe/linux/bin

	cp -u $basedir/configs/$config_env/linux/* $basedir/exe/linux
	cp -u $basedir/configs/$config_env/shared/* $basedir/exe/shared

	for filename in $(find $basedir/exe -name '*.cfg'); do
		sed -i -e "s@DBSERVICE@$DBSERVICE@g" -e "s@DBUSERNAME@$DBUSERNAME@g" -e "s@DBPASSWORD@$DBPASSWORD@g" -e "s@CLUSTERNAME@$CLUSTERNAME@g" -e "s@HOSTIP@$HOSTIP@g" $filename
	done

	#
	# Generate other config files if their template exists.
	#

		# Generate at least 1 node that is the /etc/hosts IP.
		$basedir/utils/build_node_list.sh
fi

if [ ! -d $basedir/data ]; then
	read -p "Symlink to data directory (y/n)? " remote_dsrc_response
	remote_dsrc_response=${remote_dsrc_response,,}
	if [[ $remote_dsrc_response =~ ^(yes|y| ) ]]; then
		read -p "Enter target data directory " DATA_DIR
		ln -s $DATA_DIR ./data
	fi
fi

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
		buildTemplates=true
	fi
fi

templatesLoaded=false

if [[ $buildTemplates = true ]]; then
	echo "Object Template and Quest CRC files will now be built and re-imported into the database."

	if [[ -z "$DBSERVICE" ]]; then
		echo "Enter the DSN for the database connection "
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

read -p "Import database? (y/n) " response
response=${response,,}
if [[ $response =~ ^(yes|y| ) ]]; then
	cd $basedir/src/game/server/database/build/linux

	if [[ -z "$DBSERVICE" ]]; then
		echo "Enter the DSN for the database connection "
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

	perl ./database_update.pl --username=$DBUSERNAME --password=$DBPASSWORD --service=$DBSERVICE --goldusername=$DBUSERNAME --loginusername=$DBUSERNAME --createnewcluster --packages

	if [[ $templatesLoaded = false ]]; then
		echo "Loading template list"
		perl ../../templates/processTemplateList.pl < ../../../../../../dsrc/sku.0/sys.server/built/game/misc/object_template_crc_string_table.tab > $basedir/build/templates.sql
		sqlplus ${DBUSERNAME}/${DBPASSWORD}@${DBSERVICE} @$basedir/build/templates.sql > $basedir/build/templates.out
	fi
fi

echo "Build complete!"