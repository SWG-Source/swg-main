#!/bin/sh

ORIGINAL_DIR=`pwd`
#LINT_OPTIONS="-u -p +vmf" 
LINT_OPTIONS="-u" 

for SOURCE_FILE in $* ; do
{
    SOURCE_FILE_DIR=`dirname $SOURCE_FILE`
    cd "$SOURCE_FILE_DIR"
    PROJECT_DIR=
    while [ ! -f ${PROJECT_DIR}/project.lnt ] ; do
	{
	    TEMP=../${PROJECT_DIR}
	    PROJECT_DIR=$TEMP
	    
	    cd $PROJECT_DIR;

	    if [ "`pwd`" = "/" ] ; then
		{
		    echo "$SOURCE_FILE : Cannot find project.lnt!"
		    exit -1
		};
	    fi
	    
	    cd $SOURCE_FILE_DIR   
	};
    done
    
    cd $PROJECT_DIR
    
    TOOLS_DIR=tools
    while [ ! -d $TOOLS_DIR ] ; do
	{
	    TEMP=../${TOOLS_DIR}
	    TOOLS_DIR=$TEMP;
	};
    done
    
    ${TOOLS_DIR}/flint ${LINT_OPTIONS} -i${HOME}/lint -i${TOOLS_DIR}/lint project.lnt ${SOURCE_FILE_DIR}/`basename $SOURCE_FILE`
}; done
