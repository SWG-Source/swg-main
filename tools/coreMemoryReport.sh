#!/bin/bash -f

if [ $# != 4 ]; then
	echo Usage: coreMemoryReport.sh exename corename dumpname reportname
	exit 1
fi

checkTool()
{
	which $1 >& /dev/null
	if [ $? = 1 ]; then
		echo "Could not find $1 in $PATH."
		exit 1
	fi
}

# check for needed tools
checkTool grep
checkTool sed
checkTool sort
checkTool uniq
checkTool gawk
checkTool objdump
checkTool addr2line
checkTool CoreMemWalker

# check gawk version, need >= 3.1 for coprocesses
awk_major=`gawk --version |grep '^GNU Awk' |sed -e '/^GNU Awk /s///' -e '/\..*$/s///'`
awk_minor=`gawk --version |grep '^GNU Awk' |sed -e '/^GNU Awk [0-9]*\./s///' -e '/\..*$/s///'`

if [ $awk_major -le 3 ]; then
	if [ $awk_major -lt 3 ] || [ $awk_minor -lt 1 ]; then
		echo 'GNU Awk version >= 3.1 is required.'
		exit 1
	fi
fi

EXE=$1
CORE=$2
DUMPNAME=$3
REPORTNAME=$4

# load the memory map for a specified object file and section type
loadMemoryMap()
{
	objdump -h $1 |grep $2 >.tmpmem
	ao_c=0
	while read -a LINE ; do
		let s=0x${LINE[3]}
		let e=$s+0x${LINE[2]}
		let o=0x${LINE[5]}-$s
		ao_s[$ao_c]=$s
		ao_e[$ao_c]=$e
		ao_o[$ao_c]=$o
		let ao_c=$ao_c+1
	done <.tmpmem
}

# determine the offset in the file associated with the current memory map of the memory address passed in
getAddrOffset()
{
	result=0
	let t=$1
	i=0
	while [ $i -lt $ao_c ]; do
		if [ $t -ge ${ao_s[$i]} ] && [ $t -lt ${ao_e[$i]} ] ; then
			let result=${ao_o[$i]}+$t
			break
		fi
		let i=$i+1
	done
	echo $result
}

# determine the object to search for memory manager info
MEMOBJ=`ldd $EXE |grep libsharedMemoryManager.so |sed 's/[()]//g' |gawk '{print $3}'`
if [ "$MEMOBJ" = "" ]; then
	MEMOBJ=$EXE
	MEMOFS=0
else
	LINE=(`ldd $EXE |sed 's/[()]//g' |sort -k 4,4 |nl |gawk '{print $1, $4}' |grep libsharedMemoryManager.so`)
	MEMOFS=0x`objdump -h $CORE |grep -B1 'READONLY, CODE' |grep '00000000  4' |nl |grep "^ *${LINE[0]}	" |gawk '{print $5}'`
fi

# grab the mappings of memory regions in the memory manager object
echo Getting memory manager object memory map...
loadMemoryMap $MEMOBJ rodata

# determine the number of entries in the memory block call stacks
echo Determining memory block owner call stack size...
LINE=(`objdump -t $MEMOBJ |grep ' _[^G]*22MemoryManagerNamespace.*cms_allocatedBlockSize'`)
offset=`getAddrOffset 0x${LINE[0]}`
LINE=(`od -t x4 -j$offset -N4 $MEMOBJ`)
let own_size=(0x${LINE[1]}-12)/4

# grab the mappings of memory regions in the core file
echo Getting core memory map...
loadMemoryMap $CORE load

# get the address of the first memory block
echo Finding first memory block...
LINE=(`objdump -t $MEMOBJ |grep '22MemoryManagerNamespace.*ms_firstSystemAllocation'`)
let adjustedOfs=0x${LINE[0]}+$MEMOFS
offset=`getAddrOffset $adjustedOfs`
LINE=(`od -t x4 -j$offset -N4 $CORE`)
let firstAddr=0x${LINE[1]}

rm -f $DUMPNAME

echo Dumping allocated block info...
CoreMemWalker $CORE .tmpmem $firstAddr $own_size >$DUMPNAME
rm -f .tmpmem

echo Processing memory report...
cat $DUMPNAME |sed 's/^0x[0-9a-f]* //' |sort -n |uniq -c | \
gawk '
{
	printf "%d %d", $1*$2, $1
	for (i = 3; i <= NF; ++i)
		printf " %s", $i
	printf "\n"
}' | sort -n -r >.tmpdmp

rm -f .tmpresolve .tmplib*

# Determine all binaries associated with $EXE, and store their names and
# base addresses in the lib_name and lib_addr arrays respectively.
echo Determining address spaces...
lib_count=1
lib_addr[0]=0
lib_name[0]=$EXE
ldd $EXE |sed 's/[()]//g' |sort -k 4,4 |nl |gawk '{print $1, $4}' >.tmplibs
while read -a LINE ; do
	lib_name[$lib_count]=${LINE[1]}
	let lib_addr[$lib_count]=0x`objdump -h $CORE |grep -B1 'READONLY, CODE' |grep '00000000  4' |nl |grep "^ *${LINE[0]}	" |gawk '{print $5}'`
	let lib_count=$lib_count+1
done <.tmplibs

# Determine which library in the lib_name/lib_addr arrays the passed in
# address belongs to.  Return the index in the array.
getLibNumber()
{
	result=0
	let t=$1
	j=1
	while [ $j -lt $lib_count ]; do
		if [ ${lib_addr[$j]} -gt $t ] ; then
			break
		fi
		let j=$j+1
	done
	let result=$j-1
	echo $result
}

# Run through all referenced addresses, sorting them by the binary they
# belong to, and saving a file of addresses and a separate file of
# addresses relative to the binary's start address.  Also fill in '??:0'
# in the resolved address cache for each address, so that every referenced
# address has an entry, and use that to prevent trying to resolve an
# address multiple times (by outputting duplicates to the per-binary
# address list files).
echo Sorting addresses by lib...
while read -a LINE ; do
	# run through $LINE[2..] accumulating addresses per lib
	i=2
	while [ $i -lt ${#LINE[*]} ]; do
		addr=${LINE[$i]}
		if [ "${addr_cache[$addr]}" != "??:0" ] ; then
			lib_number=`getLibNumber $addr`
			let offset=addr-${lib_addr[$lib_number]}
			echo $addr >> .tmplib_addr_$lib_number
			echo -n "0x" >> .tmplib_ofs_$lib_number
			echo "obase=16; $offset" |bc >> .tmplib_ofs_$lib_number
			addr_cache[$addr]="??:0"
		fi
		let i=$i+1
	done
done <.tmpdmp

# Resolve all addresses referenced in the report, batched by which binary
# the address belongs to.
echo Resolving Addresses...
i=0
while [ $i -lt $lib_count ]; do
	if [ -e .tmplib_ofs_$i ]; then
		addr2line -s -e ${lib_name[$i]} `cat .tmplib_ofs_$i` >.tmpresolve
		j=0
		while read -a LINE ; do
			resolved[$j]=${LINE[*]}
			let j=$j+1
		done <.tmpresolve
		j=0
		while read -a LINE ; do
			addr_cache[${LINE[*]}]=${resolved[$j]}
			let j=$j+1
		done <.tmplib_addr_$i
	fi
	let i=$i+1
done

# Generate the final report file, by looking up all but the first 2 fields of
# everything in .tmpdmp in the resolved address cache.
echo Generating Report...
rm -f $REPORTNAME
while read -a LINE ; do
	echo -n "${LINE[0]} ${LINE[1]}" >> $REPORTNAME
	i=2
	while [ $i -lt ${#LINE[*]} ]; do
		addr=${LINE[$i]}
		echo -n " ${addr_cache[$addr]}($addr)" >> $REPORTNAME
		let i=$i+1
	done
	echo >> $REPORTNAME
done <.tmpdmp

rm -f .tmpdmp .tmpresolve .tmplib*

echo Done!

