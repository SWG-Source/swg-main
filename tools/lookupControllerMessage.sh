#!/bin/sh -f

while [ $# -gt 0 ]; do
	cat ../src/engine/shared/library/sharedFoundation/src/shared/GameControllerMessage.def |grep CM_ |grep -v CM_nothing |nl |grep "^[^0-9]*$1[^0-9]"
	shift 1
done

