#!/bin/bash

basedir=$PWD

find $basedir/dsrc -name '*.tdf' | while read filename; do
	echo $filename
	$basedir/exe/linux/bin/TemplateDefinitionCompiler -compile $filename
done
