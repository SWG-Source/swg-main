
# ======================================================================
# This is a set of macros for oft-used things in swg.

# ======================================================================
# common settings

set print static-members off
handle SIGUSR2 nostop noprint pass
handle SIG32 nostop noprint pass

# ======================================================================
# Traversal macros for various container types.  These are set up to take a macro to be called on each element of the container.
# For some container types the key and/or value types are specified as parameters because we cannot infer them from the
# container itself.

define stl_vector_traverse
	set $svt_i = 0
	while $arg0._M_start+$svt_i != $arg0._M_finish
		$arg1 $arg0._M_start[$svt_i++]
	end
end

document stl_vector_traverse
	Usage: stl_vector_traverse VectorVar ProcessMacro
	Traverse an std::vector<...>, invoking ProcessMacro for each element of the container.
	The element is passed to ProcessMacro as $arg0.
end

# ----------------------------------------------------------------------

define stl_list_traverse
	set $slt_end = (void*)($arg0._M_node->_M_data)
	set $slt_i=*(void**)$slt_end
	while $slt_i != $slt_end
		$arg2 *($arg1*)($slt_i+8)
		set $slt_i=*(void**)$slt_i
	end
end

document stl_list_traverse
	Usage: stl_list_traverse ListVar ValueType ProcessMacro
	Traverse an std::list<ValueType>, invoking ProcessMacro for each element of the container.
	The element is passed to ProcessMacro as $arg0.
end

# ----------------------------------------------------------------------

define stl_map_traverse
	# set $smt_end = $arg0._M_t._M_header._M_data
	set $smt_end = ((void**)&$arg0)[1]
	_map_left $smt_end
	set $smt_i = $ret
	while $smt_i != $smt_end
		set $key = *($arg1*)($smt_i+16)
		set $value = *($arg2*)($smt_i+16+sizeof($arg1))
		$arg3 $key $value
		_map_right $smt_i
		set $smt_k = $ret
		if $smt_k != 0
			_map_right $smt_i
			set $smt_i = $ret
			_map_left $smt_i
			while $ret != 0
				set $smt_i = $ret
				_map_left $smt_i
			end
		end
		if $smt_k == 0
			_map_parent $smt_i
			set $smt_j = $ret
			_map_right $smt_j
			while $smt_i == $ret
				set $smt_i = $smt_j
				_map_parent $smt_j
				set $smt_j = $ret
				_map_right $smt_j
			end
			_map_right $smt_i
			if $ret != $smt_j
				set $smt_i = $smt_j
			end
		end
	end
end

document stl_map_traverse
	Usage: stl_map_traverse MapVar KeyType ValueType ProcessMacro
	Traverse a std::map<KeyType, ValueType>, invoking ProcessMacro for each element of the container.
	The key and value are passed to ProcessMacro as $arg0 and $arg1 respectively.
end

define _map_left
	set $ret = ((void**)$arg0)[2]
end

define _map_right
	set $ret = ((void**)$arg0)[3]
end

define _map_parent
	set $ret = ((void**)$arg0)[1]
end

# ----------------------------------------------------------------------

define stl_hashmap_traverse
	set $ht = $arg0->_M_ht
	set $btiter = $ht->_M_buckets->_M_start
	while $btiter != $ht->_M_buckets->_M_finish
		set $bucket = *$btiter++
		while $bucket != 0
			set $key = *($arg1*)($bucket+4)
			set $value = *($arg2*)($bucket+4+sizeof($arg1))
			$arg3 $key $value
			set $bucket = *(void**)$bucket
		end
	end
end

document stl_hashmap_traverse
	Usage: stl_hashmap_traverse HashMapVar KeyType ValueType ProcessMacro
	Traverse a std::hash_map<KeyType, ValueType>, invoking ProcessMacro for each element of the container.
	The key and value are passed to ProcessMacro as $arg0 and $arg1 respectively.
end

# ----------------------------------------------------------------------

define stl_deque_traverse
	set $sdt_iter_node = $arg0._M_start._M_node
	set $sdt_iter_cur = $arg0._M_start._M_cur
	set $sdt_end_node = $arg0._M_finish._M_node
	set $sdt_end_cur = $arg0._M_finish._M_cur
	set $sdt_blocksize = $arg0._M_start._M_last-$arg0._M_start._M_first
	while $sdt_iter_node != $sdt_end_node || $sdt_iter_cur != $sdt_end_cur
		$arg1 *$sdt_iter_cur
		set $sdt_iter_cur = $sdt_iter_cur+1
		if $sdt_iter_cur == *$sdt_iter_node+$sdt_blocksize
			set $sdt_iter_node = $sdt_iter_node+1
			set $sdt_iter_cur = *$sdt_iter_node
		end
	end
end

document stl_deque_traverse
	Usage: stl_deque_traverse DequeVar ProcessMacro
	Traverse an std::deque<...>, invoking ProcessMacro for each element of the container.
	The element is passed to ProcessMacro as $arg0.
end

# ======================================================================
# Various user callable macros

define find_object_by_id
	set $b=NetworkIdManager::ms_instance.m_objectHashMap->_M_ht._M_buckets
	set $ha=(unsigned long)(((long long)$arg0) >> 32)
	set $hb=(unsigned long)(((long long)$arg0) & 0xffffffff)
	set $hc=(unsigned long)(($hb * 65537) ^ $ha)
	set $hd=(unsigned long)($hb & 15)

	set $he=(unsigned long)0
	if $hd == 0
	set $he=(unsigned long)2420513004
	end
	if $hd == 1
	set $he=(unsigned long)2512581220
	end
	if $hd == 2
	set $he=(unsigned long)3848024318
	end
	if $hd == 3
	set $he=(unsigned long)747819729
	end
	if $hd == 4
	set $he=(unsigned long)2205586187
	end
	if $hd == 5
	set $he=(unsigned long)392572272
	end
	if $hd == 6
	set $he=(unsigned long)712530737
	end
	if $hd == 7
	set $he=(unsigned long)511472257
	end
	if $hd == 8
	set $he=(unsigned long)1622951493
	end
	if $hd == 9
	set $he=(unsigned long)2584534927
	end
	if $hd == 10
	set $he=(unsigned long)2847675197
	end
	if $hd == 11
	set $he=(unsigned long)244979692
	end
	if $hd == 12
	set $he=(unsigned long)3447097869
	end
	if $hd == 13
	set $he=(unsigned long)3762163791
	end
	if $hd == 14
	set $he=(unsigned long)3975852477
	end
	if $hd == 15
	set $he=(unsigned long)1984576111
	end

	set $h=(size_t)($hc ^ $he)
	set $s=$b._M_finish-$b._M_start
	set $i=$b._M_start[$h%$s]
	while $i && *(long long*)($i+4) != $arg0
		set $i = *(void**)$i
	end
	if $i == 0
		printf "Object %lld not found.\n", (long long)$arg0
	else
		print (*(ServerObject **)($i+12))
	end
end

document find_object_by_id
	Usage: find_object_by_id NetworkId
	This finds and prints the address of a ServerObject given its NetworkId
	by looking it up in the NetworkIdManager.
end

# ----------------------------------------------------------------------

define print_stl_vector
	set $count=0
	stl_vector_traverse $arg0 _stl_vector_process
	printf "%d elements.\n", $count
end

document print_stl_vector
	Usage: print_stl_vector VectorVar
	This prints the elements of a std::vector<...>.
end

define _stl_vector_process
	printf "[%d]: ", $count
	set $count = $count+1
	print $arg0
end

# ----------------------------------------------------------------------

define print_stl_list
	set $count=0
	stl_list_traverse $arg0 $arg1 _stl_list_process
	printf "%d elements.\n", $count
end

document print_stl_list
	Usage: print_stl_list ListVar ValueType
	This prints the elements of a std::list<ValueType>.
end

define _stl_list_process
	printf "[%d]: ", $count
	print $arg0
	set $count = $count+1
end

# ----------------------------------------------------------------------

define print_stl_set
	set $count = 0
	stl_map_traverse $arg0 $arg1 $arg1 _stl_set_process
	printf "%d elements.\n", $count
end

document print_stl_set
	Usage: print_stl_set SetVar ValueType
	This prints the elements of a std::set<ValueType>.
end

define _stl_set_process
	print $arg0
	set $count = $count+1
end

# ----------------------------------------------------------------------

# print_stl_map MapVar KeyType ValueType
define print_stl_map
	set $count = 0
	stl_map_traverse $arg0 $arg1 $arg2 _stl_map_process
	printf "%d elements.\n", $count
end

document print_stl_map
	Usage: print_stl_map MapVar KeyType ValueType
	This prints the elements of a std::map<KeyType, ValueType>.
end

define _stl_map_process
	printf "key: "
	print $arg0
	printf "value: "
	print $arg1
	set $count = $count+1
end

# ----------------------------------------------------------------------

#print_stl_hashmap mapvar keytype valuetype
define print_stl_hashmap
	set $count = 0
	stl_hashmap_traverse $arg0 $arg1 $arg2 _stl_hashmap_process
	printf "%d elements.\n", $count
end

document print_stl_hashmap
	Usage: print_stl_hashmap HashMapVar KeyType ValueType
	This prints the elements of a std::hash_map<KeyType, ValueType>.
end

define _stl_hashmap_process
	printf "key: "
	print $arg0
	printf "value: "
	print $arg1
	set $count = $count+1
end

# ----------------------------------------------------------------------

# print_stl_queue DequeVar
define print_stl_deque
	set $count = 0
	stl_deque_traverse $arg0 _stl_deque_process
	printf "%d elements.\n", $count
end

document print_stl_deque
	Usage: print_stl_deque DequeVar
	This prints the elements of a std::deque
end

define _stl_deque_process
	print $arg0
	set $count = $count+1
end

# ----------------------------------------------------------------------

# print_stl_queue QueueVar
define print_stl_queue
	print_stl_deque $arg0.c
end

document print_stl_queue
	Usage: print_stl_queue QueueVar ValueType
	This prints the elements of a std::queue<ValueType>.
end

# ----------------------------------------------------------------------

define print_u
	set $m=0
	while ((char*)$arg0)[$m] != 0
		printf "%c", ((char*)$arg0)[$m]
		set $m = $m+2
	end
	printf "\n"
end

document print_u
	Usage: print_u unicode_char_t*
	This prints a unicode string as ascii.
end

# ----------------------------------------------------------------------

# print_dynvarlist dynvarlist*
define print_dynvarlist
	print_stl_map $arg0->m_map.container char* char*
end

document print_dynvarlist
	Usage: print_dynvarlist DynVarList
	This prints the elements of a dynamic variable list.
end

# ----------------------------------------------------------------------

define profilerstack
	set $i = ((int**)&'_17ProfilerNamespace.ms_profilerEntryStack')[0]
	set $end = ((int**)&'_17ProfilerNamespace.ms_profilerEntryStack')[1]
	set $entries = *((char***)'_17ProfilerNamespace.ms_profilerEntriesCurrent')
	while $i != $end
		printf "%s %d\n", $entries[(*$i)*9], (int)$entries[(*$i++)*9+6]
	end
end

document profilerstack
	Usage: profilerstack
	This prints out the stack from the engine profiler, which can be useful for
	getting caller information when stack traces are incomplete.
end

# ----------------------------------------------------------------------

define meminfo
    printf "ms_allocateCalls=%d\n", '_22MemoryManagerNamespace.ms_allocateCalls'
    printf "ms_freeCalls=%d\n", '_22MemoryManagerNamespace.ms_freeCalls'
    printf "ms_allocations=%d\n", '_22MemoryManagerNamespace.ms_allocations'
    printf "ms_maxAllocations=%d\n", '_22MemoryManagerNamespace.ms_maxAllocations'
    printf "ms_freeBlocks=%d\n", '_22MemoryManagerNamespace.ms_freeBlocks'
    printf "ms_maxFreeBlocks=%d\n",  '_22MemoryManagerNamespace.ms_maxFreeBlocks'
    printf "ms_currentBytesAllocated=%d\n", '_22MemoryManagerNamespace.ms_currentBytesAllocated'
    printf "ms_maxBytesAllocated=%d\n", '_22MemoryManagerNamespace.ms_maxBytesAllocated'
    printf "ms_systemMemoryAllocatedMegabytes=%d\n", '_22MemoryManagerNamespace.ms_systemMemoryAllocatedMegabytes'
    printf "ms_numberOfSystemAllocations=%d\n", '_22MemoryManagerNamespace.ms_numberOfSystemAllocations'
    set $cms_blockSize = (sizeof(Block) + 15) & (~15)
    set $index = 1
    set $start = '_22MemoryManagerNamespace.ms_firstSystemAllocation'
    while $start != 0
        printf "allocation %d, size %d\n", $index, $start->m_size

#        set $startBlock = (Block *)(((int)$start) + $cms_blockSize)
#        set $startBlock = $startBlock->m_next
#        set $endBlock = (Block *)(((int)$start) + $start->m_size - $cms_blockSize)
#        set $blockIndex = 1
#        while $startBlock != $endBlock
#            set $blockSize = (int)$startBlock->m_next - (int)$startBlock
#            set $blockFree = 0
#            if $startBlock->m_free
#                set $blockFree = 1
#            end
#            if $blockFree == 1
#                printf "block %d, size %d, free %d\n", $blockIndex, $blockSize, $blockFree
#            end
#            set $blockIndex = $blockIndex + 1
#            set $startBlock = $startBlock->m_next
#        end

        set $index = $index + 1
        set $start = $start->m_next
    end
end

document meminfo
	Usage: meminfo
	This prints memory allocation information for our memory
	manager.
end

# ----------------------------------------------------------------------

define print_gsconnids
	stl_hashmap_traverse GameServer::ms_instance->m_gameServers uint32 GameServerConnection* _gsc_process
end

define _gsc_process
	printf "GameServerConnection processId=%d ptr=%p\n", $arg0, $arg1
end

# ----------------------------------------------------------------------

define print_authtransfermap
	set $count = 0
	stl_map_traverse s_authTransferMap NetworkId AuthTransferInfo* _atm_process
	printf "%d elements.\n", $count
end

define _atm_process
	printf "id: %lld newAuth %u unconf", $arg0.m_value, $arg1->newAuthProcessId
	set $j = $arg1->unconfirmedProcessIds._M_start
	while $j != $arg1->unconfirmedProcessIds._M_finish
		printf " %u", *$j++
	end
	printf "\n"
	set $count = $count+1
end

# ----------------------------------------------------------------------

define print_observing
	set $count = 0
	stl_map_traverse $arg0->m_observing void* void* _void_obj_id_process
	printf "%d elements.\n", $count
end

define _void_obj_id_process
	print *(u_int64_t*)($arg0+24)
	set $count = $count+1
end

# ----------------------------------------------------------------------

define print_observers
	set $count = 0
	stl_map_traverse $arg0->m_observers void* void* _void_client_id_process
	printf "%d elements.\n", $count
end

define _void_client_id_process
	print *(u_int64_t*)($arg0+44)
	set $count = $count+1
end

# ----------------------------------------------------------------------

define print_containment_chain
	# set $i = $arg0
	set $i = (void**)$arg0
	while $i != 0
		#	printf "%lld\n", $i->m_networkId->m_value
		printf "%lld\n", *(long long *)($i+5)
		#	set $i = (ServerObject*)$i->m_containedBy->m_containedBy.m_object.m_data
		set $i = ((void***)*($i+37))[5]
	end
end

# ----------------------------------------------------------------------

define print_cs_game_conn
        set $count = 0
        stl_map_traverse CentralServer::instance.m_gameServerConnections uint32 GameServerConnection* print_cs_game_conn_process
        printf "%d elements.\n", $count
end

define print_cs_game_conn_process
        printf "server=%lu, size=%u, allocatedSize=%u (%u), data->size=%lu\n", $arg0, $arg1->m_tcpClient->m_pendingSend->size, $arg1->m_tcpClient->m_pendingSend->allocatedSize, $arg1->m_tcpClient->m_pendingSend->allocatedSizeLimit, ($arg1->m_tcpClient->m_pendingSend->data ? $arg1->m_tcpClient->m_pendingSend->data->size : 0)
        set $count = $count+1
end

# ----------------------------------------------------------------------

define get_java_obj_id
	print (*(NetworkId**)$arg0)[9]
end

# ----------------------------------------------------------------------

define print_slot_contents
	set $slotids_start = (char***)('_22SlotIdManagerNamespace.s_slots'._M_start)
	# set $plist_start = $arg0->m_propertyList->_M_start
	set $plist_start = (*(void****)$arg0)[0]
	# set $plist_end = $arg0->m_propertyList->_M_finish
	set $plist_end = (*(void****)$arg0)[1]
	set $plist_iter = $plist_start
	while $plist_iter != $plist_end
		# if (*$plist_iter)->m_propertyId == 2128027438
		if (*((int**)$plist_iter))[1] == 2128027438
			set $slot_contents_start = (long long*)((*(void***)$plist_iter)[4])
			stl_map_traverse *((*(void***)$plist_iter)[9]) int int _slotmap_process
		end
		set $plist_iter = $plist_iter+1
	end
end

# ----------------------------------------------------------------------

define _slotmap_process
	if $arg1 != -1
		printf "[%s]: %lld\n", $slotids_start[$arg0][3], $slot_contents_start[$arg1*2]
	end
end

# ======================================================================

