#include <assert.h>
#include <time.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "UdpLibrary.hpp"

#if defined(WIN32)
	#pragma warning(disable : 4710)
	#if defined(UDPLIBRARY_WINSOCK2)
		#include <winsock2.h>
		#include <ws2tcpip.h>
	#else
		#include <winsock.h>
	#endif

	typedef int socklen_t;
#elif defined(sparc)
    #include <arpa/inet.h>
    #include <netdb.h>
    #include <sys/filio.h>
    #include <sys/ioctl.h>
    #include <sys/socket.h>
    #include <sys/time.h>
    #include <sys/types.h>
    #include <unistd.h>
    #include <errno.h>

    const int INADDR_NONE    = -1;
    const int INVALID_SOCKET = 0xFFFFFFFF;
    const int SOCKET_ERROR   = 0xFFFFFFFF;
#else		// for non-windows platforms (linux)
	#include <arpa/inet.h>
	#include <netdb.h>
	#include <sys/ioctl.h>
	#include <sys/socket.h>
	#include <sys/time.h>
	#include <sys/types.h>
	#include <unistd.h>
	#include <netinet/ip_icmp.h>		// needed by gcc 3.1 for linux
	const int INVALID_SOCKET = 0xFFFFFFFF;
	const int SOCKET_ERROR   = 0xFFFFFFFF;
#endif

template <typename ValueType>
const ValueType & udpMax(const ValueType & a, const ValueType & b)
{
	if(a < b)
		return b;
	return a;
}

template<typename ValueType>
const ValueType & udpMin(const ValueType & a, const ValueType & b)
{
	if(b < a)
		return b;
	return a;
}

	/////////////////////////////////////////////////////////////////////////////////////////////
	// operating system dependent initialization routines (internally called when needed)
	/////////////////////////////////////////////////////////////////////////////////////////////
void InitializeOperatingSystem()
{
#if defined(WIN32)
	WSADATA wsaData;
	#if defined(UDPLIBRARY_WINSOCK2)
		WSAStartup(MAKEWORD(2,2), &wsaData);
	#else
		WSAStartup(MAKEWORD(1,1), &wsaData);
	#endif
#endif
}

void TerminateOperatingSystem()
{
#if defined(WIN32)
	WSACleanup();
#endif
}


	/////////////////////////////////////////////////////////////////////////////////////////////////////
	// UdpConnectionHandler default implementation
	/////////////////////////////////////////////////////////////////////////////////////////////////////
void UdpConnectionHandler::OnConnectComplete(UdpConnection * /*con*/)
{
}

void UdpConnectionHandler::OnTerminated(UdpConnection * /*con*/)
{
}

void UdpConnectionHandler::OnCrcReject(UdpConnection * /*con*/, const uchar * /*data*/, int /*dataLen*/)
{
}

void UdpConnectionHandler::OnPacketCorrupt(UdpConnection * /*con*/, const uchar * /*data*/, int /*dataLen*/, UdpCorruptionReason /*reason*/)
{
}


	/////////////////////////////////////////////////////////////////////////////////////////////////////
	// UdpManagerHandler default implementation
	/////////////////////////////////////////////////////////////////////////////////////////////////////
void UdpManagerHandler::OnConnectRequest(UdpConnection * /*con*/)
{
}

int UdpManagerHandler::OnUserSuppliedEncrypt(UdpConnection * /*con*/, uchar *destData, const uchar *sourceData, int sourceLen)
{
	memcpy(destData, sourceData, sourceLen);
	return(sourceLen);
}

int UdpManagerHandler::OnUserSuppliedEncrypt2(UdpConnection * /*con*/, uchar *destData, const uchar *sourceData, int sourceLen)
{
	memcpy(destData, sourceData, sourceLen);
	return(sourceLen);
}

int UdpManagerHandler::OnUserSuppliedDecrypt(UdpConnection * /*con*/, uchar *destData, const uchar *sourceData, int sourceLen)
{
	memcpy(destData, sourceData, sourceLen);
	return(sourceLen);
}

int UdpManagerHandler::OnUserSuppliedDecrypt2(UdpConnection * /*con*/, uchar *destData, const uchar *sourceData, int sourceLen)
{
	memcpy(destData, sourceData, sourceLen);
	return(sourceLen);
}


	/////////////////////////////////////////////////////////////////////////////////////////////////////
	// UdpIpAddress implementation
	/////////////////////////////////////////////////////////////////////////////////////////////////////
UdpIpAddress::UdpIpAddress(unsigned int ip)
{
	mIp = ip;
}

char *UdpIpAddress::GetAddress(char *buffer) const
{
	assert(buffer != NULL);

	struct sockaddr_in addr_serverUDP;
	addr_serverUDP.sin_addr.s_addr = mIp;
	strcpy(buffer, inet_ntoa(addr_serverUDP.sin_addr));
	return(buffer);
}

	/////////////////////////////////////////////////////////////////////////////////////////////////////
	// UdpManager::Params initializations constructor (ie. default values)
	/////////////////////////////////////////////////////////////////////////////////////////////////////
UdpManager::Params::Params()
{
	handler = NULL;
	outgoingBufferSize = 64 * 1024;
	incomingBufferSize = 64 * 1024;
	packetHistoryMax = 100;
	maxDataHoldTime = 50;
	maxDataHoldSize = -1;
	maxRawPacketSize = 512;
	hashTableSize = 100;
	avoidPriorityQueue = false;
	clockSyncDelay = 0;
	crcBytes = 0;
	encryptMethod[0] = UdpManager::cEncryptMethodNone;
	encryptMethod[1] = UdpManager::cEncryptMethodNone;
	keepAliveDelay = 0;
	portAliveDelay = 0;
	noDataTimeout = 0;
	maxConnections = 10;
	port = 0;
	portRange = 0;
	pooledPacketMax = 1000;
	pooledPacketSize = -1;
	pooledPacketInitial = 0;
	replyUnreachableConnection = true;
	allowPortRemapping = true;
	allowAddressRemapping = false;
	icmpErrorRetryPeriod = 5000;
	oldestUnacknowledgedTimeout = 90000;
	processIcmpErrors = true;
	processIcmpErrorsDuringNegotiating = false;
	connectAttemptDelay = 1000;
	reliableOverflowBytes = 0;
	memset(bindIpAddress, 0, sizeof(bindIpAddress));

	userSuppliedEncryptExpansionBytes = 0;
	userSuppliedEncryptExpansionBytes2 = 0;
	simulateIncomingByteRate = 0;
	simulateIncomingLossPercent = 0;
	simulateOutgoingByteRate = 0;
	simulateOutgoingLossPercent = 0;
	simulateDestinationOverloadLevel = 0;
	simulateOutgoingOverloadLevel = 0;

	reliable[0].maxInstandingPackets = 400;
	reliable[0].maxOutstandingBytes = 200 * 1024;
	reliable[0].maxOutstandingPackets = 400;
	reliable[0].outOfOrder = false;
	reliable[0].processOnSend = false;
	reliable[0].coalesce = true;
	reliable[0].ackDeduping = true;
	reliable[0].fragmentSize = 0;
	reliable[0].resendDelayAdjust = 300;
	reliable[0].resendDelayPercent = 125;
	reliable[0].resendDelayCap = 5000;
	reliable[0].congestionWindowMinimum = 0;
	reliable[0].trickleRate = 0;
	reliable[0].trickleSize = 0;
	for (int j = 1; j < cReliableChannelCount; j++)
		reliable[j] = reliable[0];
}


	/////////////////////////////////////////////////////////////////////////////////////////////////////
	// UdpManager implementation
	/////////////////////////////////////////////////////////////////////////////////////////////////////
UdpManager::UdpManager(const UdpManager::Params *params)
{
	assert(params->clockSyncDelay >= 0);							// negative clockSyncDelay is not allowed (makes no sense)
	assert(params->crcBytes >= 0 && params->crcBytes <= 4);			// crc bytes must be between 0 and 4
	assert(params->encryptMethod[0] >= 0 && params->encryptMethod[0] < cEncryptMethodCount);		// illegal encryption method specified
	assert(params->encryptMethod[1] >= 0 && params->encryptMethod[1] < cEncryptMethodCount);		// illegal encryption method specified
	assert(params->hashTableSize > 0);								// a hash table size greater than zero is required
	assert(params->maxRawPacketSize >= 64);							// raw packet size must be at least 64 bytes
	assert(params->incomingBufferSize >= params->maxRawPacketSize);	// incoming socket buffer size must be at least as big as one raw packet
	assert(params->keepAliveDelay >= 0);							// keep alive delay can't be negative
	assert(params->portAliveDelay >= 0);							// port alive delay can't be negative
	assert(params->maxConnections > 0);								// must have at least 1 connection allowed
	assert(params->outgoingBufferSize >= params->maxRawPacketSize);	// outgoing socket buffer must larger than a raw packet size
	assert(params->packetHistoryMax > 0);							// packet history must be at least 1
	assert(params->port >= 0);										// port cannot be negative
	assert(params->userSuppliedEncryptExpansionBytes + params->userSuppliedEncryptExpansionBytes2 < params->maxRawPacketSize);	// if encryption expansion is larger than raw packet size, we are screwed
	assert(params->reliable[0].maxOutstandingBytes >= params->maxRawPacketSize);
	assert(params->reliable[1].maxOutstandingBytes >= params->maxRawPacketSize);
	assert(params->reliable[2].maxOutstandingBytes >= params->maxRawPacketSize);
	assert(params->reliable[3].maxOutstandingBytes >= params->maxRawPacketSize);
	assert(params->port != 0 || params->portRange == 0);

	mRefCount = 1;
	mParams = *params;
	mParams.maxRawPacketSize = udpMin(mParams.maxRawPacketSize, (int)cHardMaxRawPacketSize);
	if (mParams.maxDataHoldSize == -1)
	{
		mParams.maxDataHoldSize = mParams.maxRawPacketSize;
	}
	if (mParams.pooledPacketSize == -1)
	{
		mParams.pooledPacketSize = mParams.maxRawPacketSize;
	}

	mParams.maxDataHoldSize = udpMin(mParams.maxDataHoldSize, mParams.maxRawPacketSize);
	mParams.packetHistoryMax = udpMax(1, mParams.packetHistoryMax);
	mPacketHistoryPosition = 0;
	mPassThroughData = NULL;

	typedef PacketHistoryEntry *PacketHistoryEntryPtr;
	mPacketHistory = new PacketHistoryEntryPtr[mParams.packetHistoryMax];

	int i;
	for (i = 0; i < mParams.packetHistoryMax; i++)
	{
		mPacketHistory[i] = new PacketHistoryEntry(mParams.maxRawPacketSize);
	}

	ResetStats();
	mLastReceiveTime = 0;
	mLastSendTime = 0;
    mLastEmptySocketBufferStamp = 0;
    mProcessingInducedLag = 0;
	mStartTtl = 32;
	mMinimumScheduledStamp = 0;
	mUdpSocket = INVALID_SOCKET;

	mConnectionListCount = 0;
	mConnectionList = NULL;

	mPoolCreated = 0;
	mPoolAvailable = 0;
	mPoolAvailableRoot = NULL;
	mPoolCreatedRoot = NULL;

	mWrappedCreated = 0;
	mWrappedAvailable = 0;
	mWrappedAvailableRoot = NULL;
	mWrappedCreatedRoot = NULL;

	for (i = 0; i < mParams.pooledPacketInitial && i < mParams.pooledPacketMax; i++)
	{
		mPoolCreated++;
		PooledLogicalPacket *lp = new PooledLogicalPacket(this, mParams.pooledPacketSize);
		PoolReturn(lp);
		lp->Release();
	}

	mSimulateQueueStart = NULL;
	mSimulateQueueEnd = NULL;
	mSimulateNextOutgoingTime = 0;
	mSimulateNextIncomingTime = 0;
	mSimulateQueueBytes = 0;

	mDisconnectPendingList = NULL;

	if (mParams.avoidPriorityQueue)
		mPriorityQueue = NULL;
	else
		mPriorityQueue = new PriorityQueue<UdpConnection, UdpMisc::ClockStamp>(mParams.maxConnections);

	mAddressHashTable = new ObjectHashTable<AddressHashTableMember *>(mParams.hashTableSize);
	mConnectCodeHashTable = new ObjectHashTable<ConnectCodeHashTableMember *>(udpMax(mParams.hashTableSize / 5, 10));		// rarely used, so make it a fraction of the main tables size

	InitializeOperatingSystem();

	if (mParams.portRange == 0)
	{
		CreateAndBindSocket(mParams.port);
	}
	else
	{
		int r = rand() % mParams.portRange;
		for (int i = 0; i < mParams.portRange; i++)
		{
			CreateAndBindSocket(mParams.port + ((r + i) % mParams.portRange));
			if (mErrorCondition != cErrorConditionCouldNotBindSocket)
				break;
		}
	}
}

UdpManager::~UdpManager()
{
	{
			// first we need to tell all the pooled packets we have created that they can no longer check themselves back into use
			// when they are released
		PooledLogicalPacket *walk = mPoolCreatedRoot;
		while (walk != NULL)
		{
			walk->mUdpManager = NULL;
			walk = walk->mCreatedNext;
		}
			// next release the ones we have in our available pool
		walk = mPoolAvailableRoot;
		while (walk != NULL)
		{
			PooledLogicalPacket *hold = walk;
			walk = walk->mAvailableNext;
			hold->Release();
		}
	}


	{
			// next we need to tell all the warpped packets we have created that they can no longer check themselves back into use
			// when they are released
		WrappedLogicalPacket *walk = mWrappedCreatedRoot;
		while (walk != NULL)
		{
			walk->mUdpManager = NULL;
			walk = walk->mCreatedNext;
		}
			// next release the ones we have in our available pool
		walk = mWrappedAvailableRoot;
		while (walk != NULL)
		{
			WrappedLogicalPacket *hold = walk;
			walk = walk->mAvailableNext;
			hold->Release();
		}
	}

		// next thing we must do is tell all the connections to disconnect (which severs their link to this dying manager)
		// this has to be done first since they will call back into us and have themselves removed from our connection-list/priority-queue/etc
	while (mConnectionList != NULL)
	{
		mConnectionList->InternalDisconnect(0, UdpConnection::cDisconnectReasonManagerDeleted);
			// the above call ended up calling us back and removing them from our connection list, so now mConnectionList is pointing to the next entry
			// hopefully the compiler will be smart enough not to over optimize this.
	}

		// release any objects that were pending disconnection
	while (mDisconnectPendingList != NULL)
	{
		UdpConnection *next = mDisconnectPendingList->mDisconnectPendingNextConnection;
		mDisconnectPendingList->Release();
		mDisconnectPendingList = next;
	}

	CloseSocket();

	TerminateOperatingSystem();

	delete mAddressHashTable;
	delete mConnectCodeHashTable;
	delete mPriorityQueue;
	for (int i = 0; i < mParams.packetHistoryMax; i++)
	{
		delete mPacketHistory[i];
	}
	delete[] mPacketHistory;

	while (mSimulateQueueStart != NULL)
	{
		SimulateQueueEntry *entry = mSimulateQueueStart;
		mSimulateQueueStart = entry->mNext;
		delete entry;
	}
}

void UdpManager::CreateAndBindSocket(int usePort)
{
	CloseSocket();
	mErrorCondition = cErrorConditionNone;
	mUdpSocket = socket(PF_INET, SOCK_DGRAM, 0);
	if (mUdpSocket != INVALID_SOCKET)
	{
#if defined(WIN32)
		ulong lb = 1;
		int err = ioctlsocket(mUdpSocket, FIONBIO, &lb);
		int nb = mParams.outgoingBufferSize;
		err = setsockopt(mUdpSocket, SOL_SOCKET, SO_SNDBUF, (char *)&nb, sizeof(nb));
		nb = mParams.incomingBufferSize;
		err = setsockopt(mUdpSocket, SOL_SOCKET, SO_RCVBUF, (char *)&nb, sizeof(nb));
		int optLen = sizeof(mStartTtl);
		getsockopt(mUdpSocket, IPPROTO_IP, IP_TTL, (char *)&mStartTtl, &optLen);
#elif defined(sparc)
		ulong nb = 1;
		int err = ioctl(mUdpSocket, FIONBIO, &nb);
		assert(err != -1);
		nb = udpMin(256 * 1024, mParams.outgoingBufferSize);
		err = setsockopt(mUdpSocket, SOL_SOCKET, SO_SNDBUF, &nb, sizeof(nb));
		assert(err == 0);
		nb = udpMin(256 * 1024, mParams.incomingBufferSize);
		err = setsockopt(mUdpSocket, SOL_SOCKET, SO_RCVBUF, &nb, sizeof(nb));
		assert(err == 0);

		int optLen = sizeof(mStartTtl);
		getsockopt(mUdpSocket, IPPROTO_IP, IP_TTL, &mStartTtl, (socklen_t *)&optLen);

		nb = 1;
		err = setsockopt(mUdpSocket, SOL_SOCKET, SO_DGRAM_ERRIND, &nb, sizeof(nb));
		assert(err == 0);
#else	// linux is to remain the default compile mode
		unsigned long nb = 1;
		int err = ioctl(mUdpSocket, FIONBIO, &nb);
		assert(err != -1);
		nb = mParams.outgoingBufferSize;
		err = setsockopt(mUdpSocket, SOL_SOCKET, SO_SNDBUF, &nb, sizeof(nb));
		assert(err == 0);
		nb = mParams.incomingBufferSize;
		err = setsockopt(mUdpSocket, SOL_SOCKET, SO_RCVBUF, &nb, sizeof(nb));
		assert(err == 0);
		nb = 0;
		err = setsockopt(mUdpSocket, SOL_SOCKET, SO_BSDCOMPAT, &nb, sizeof(nb));
		assert(err == 0);
		nb = 1;
		err = setsockopt(mUdpSocket, SOL_IP, IP_RECVERR, &nb, sizeof(nb));
		assert(err == 0);

		int optLen = sizeof(mStartTtl);
		getsockopt(mUdpSocket, IPPROTO_IP, IP_TTL, &mStartTtl, (socklen_t *)&optLen);
#endif
	
			// bind it to any address
		struct sockaddr_in addr_loc;
		addr_loc.sin_family = PF_INET;
		addr_loc.sin_port = htons((ushort)usePort);

		addr_loc.sin_addr.s_addr = htonl(INADDR_ANY);
		if (mParams.bindIpAddress[0] != 0)
		{
			unsigned long address = inet_addr(mParams.bindIpAddress);
			assert(address != INADDR_NONE);		// if this asserts, it means you are trying to explicitly bind to an illegally-formatted IP address.

			if (address != INADDR_NONE)
				addr_loc.sin_addr.s_addr = address;		// this is already in network order from the call above
		}

		if (bind(mUdpSocket, (struct sockaddr *)&addr_loc, sizeof(addr_loc)) != 0)
		{
			mErrorCondition = cErrorConditionCouldNotBindSocket;
			CloseSocket();
		}
	}
	else
	{
		mErrorCondition = cErrorConditionCouldNotAllocateSocket;
	}
}

void UdpManager::CloseSocket()
{
	if (mUdpSocket != INVALID_SOCKET)
	{
#if defined(WIN32)
		closesocket(mUdpSocket);
#else
		close(mUdpSocket);
#endif
		mUdpSocket = INVALID_SOCKET;
	}
}


UdpManager::ErrorCondition UdpManager::GetErrorCondition() const
{
	return(mErrorCondition);
}


void UdpManager::ProcessDisconnectPending()
{
	UdpConnection *entry = mDisconnectPendingList;
	UdpConnection **prev = &mDisconnectPendingList;
	while (entry != NULL)
	{
		if (entry->GetStatus() == UdpConnection::cStatusDisconnected)
		{
			*prev = entry->mDisconnectPendingNextConnection;
			entry->mDisconnectPendingNextConnection = NULL;
			entry->Release();
			entry = *prev;
		}
		else
		{
			prev = &entry->mDisconnectPendingNextConnection;
			entry = entry->mDisconnectPendingNextConnection;
		}
	}
}

void UdpManager::RemoveConnection(UdpConnection *con)
{
	assert(con != NULL);		// attemped to remove a NULL connection object

		// note: it's a bug to Remove a connection object that is already removed...should never be able to happen.
	mConnectionListCount--;
	if (con->mPrevConnection != NULL)
		con->mPrevConnection->mNextConnection = con->mNextConnection;
	if (con->mNextConnection != NULL)
		con->mNextConnection->mPrevConnection = con->mPrevConnection;
	if (mConnectionList == con)
		mConnectionList = con->mNextConnection;
	con->mNextConnection = NULL;
	con->mPrevConnection = NULL;
	if (mPriorityQueue != NULL)
		mPriorityQueue->Remove(con);

	mAddressHashTable->Remove(con, AddressHashValue(con->mIp, con->mPort));
	mConnectCodeHashTable->Remove(con, con->mConnectCode);
}

void UdpManager::AddConnection(UdpConnection *con)
{
	assert(con != NULL);		// attemped to add a NULL connection object

	con->mNextConnection = mConnectionList;
	con->mPrevConnection = NULL;
	if (mConnectionList != NULL)
		mConnectionList->mPrevConnection = con;
	mConnectionList = con;
	mConnectionListCount++;

	mAddressHashTable->Insert(con, AddressHashValue(con->mIp, con->mPort));
	mConnectCodeHashTable->Insert(con, con->mConnectCode);
}

void UdpManager::FlushAllMultiBuffer()
{
	AddRef();
	UdpConnection *cur = mConnectionList;
	while (cur != NULL)
	{
		cur->FlushMultiBuffer();
		cur = cur->mNextConnection;
	}
	Release();
}

bool UdpManager::GiveTime(int maxPollingTime, bool giveConnectionsTime)
{
		// process incoming raw packets from the port
	AddRef();	// keep a reference to ourself in case we callback to the application and the application releases us.

	mManagerStats.iterations++;

	bool found = false;
	if (maxPollingTime != 0)
	{
		UdpMisc::ClockStamp start = UdpMisc::Clock();
		do
		{
			PacketHistoryEntry *e = ActualReceive();

			if (e == NULL)
			{
				mLastEmptySocketBufferStamp = UdpMisc::Clock();
				break;
			}

				// if the application takes too long to process packets, or doesn't give the UdpManager frequent enough time via GiveTime
				// then it's possible that we will have a clock-sync packet that is sitting in the socket buffer waiting to be processed
				// we don't want the applications inability to give us frequent processing time to totally whack up the clock sync stuff
				// so we have the clock-sync code ignore clock-sync packets that get stalled in the socket buffer for too long because our
				// application is busy processing other packets that were queued before it, or because the application paused for a long
				// time before calling GiveTime.
				// note: this is intended to prevent cpu induced stalls from causing a sync packet to appear to take longer.  For example
				// if the player is on a modem, it's possible for the socket-buffer to fill up while the application is stalled and cause the
				// the sync-packet to actually get stalled at the terminal buffer on the other end up of the modem.  When the application starts
				// processing again, it will empty the socket-buffer, but then the get an empty-socket-buffer briefly until the terminal server
				// can send the rest of the buffered packets on over.  A large client side receive socket buffer may help in this regard.
			mProcessingInducedLag = UdpMisc::ClockElapsed(mLastEmptySocketBufferStamp);
			found = true;
			if (e->mLen > 0)
				ProcessRawPacket(e);
		} while (UdpMisc::ClockElapsed(start) < maxPollingTime);

		ProcessIcmpErrors();
	}

	if (giveConnectionsTime)
	{
		if (mPriorityQueue != NULL)
		{
				// give time to everybody in the priority-queue that needs it
			UdpMisc::ClockStamp curPriority = UdpMisc::Clock();

				// at the time we start processing the priority queue, we should effectively be taking a snap-shot
				// of everybody who needs time, before we give anybody time.  Otherwise, it is possible that in the
				// process of giving one connection time, another connection could get bumped up the queue to the point
				// where it needs time now as well (for example, one connection sending another connection data during the
				// give time phase).  Although very rare, in theory this could result in an infinite loop situation.
				// To solve this, we simply set the earliest time period that somebody can schedule for to 1 ms after
				// the current time stamp that we are processing, effectively making it impossible for any connection
				// to be given time twice in the same interation of the loop below
			mMinimumScheduledStamp = curPriority + 1;		

			for (;;)
			{
				UdpConnection *top = mPriorityQueue->TopRemove(curPriority);
				if (top == NULL)
					break;
				top->AddRef();
				top->GiveTime();
				top->Release();
				mManagerStats.priorityQueueProcessed++;
			}
			mManagerStats.priorityQueuePossible += mConnectionListCount;
		}
		else
		{
				// give time to everybody
			UdpConnection *cur = mConnectionList;
			while (cur != NULL)
			{
				cur->GiveTime();
				cur = cur->mNextConnection;
			}
		}

		ProcessDisconnectPending();
	}

	if (mSimulateQueueStart != NULL && UdpMisc::Clock() >= mSimulateNextOutgoingTime)
	{
		SimulateQueueEntry *entry = mSimulateQueueStart;
		mSimulateQueueStart = mSimulateQueueStart->mNext;
		mSimulateNextOutgoingTime = UdpMisc::Clock() + (entry->mDataLen * 1000 / mParams.simulateOutgoingByteRate);
		ActualSendHelper(entry->mData, entry->mDataLen, entry->mIp, entry->mPort);

		UdpConnection *con = AddressGetConnection(entry->mIp, entry->mPort);
		if (con != NULL)
			con->mSimulateQueueBytes -= entry->mDataLen;
		mSimulateQueueBytes -= entry->mDataLen;
		delete entry;
	}

	Release();
	return(found);
}

UdpConnection *UdpManager::EstablishConnection(const char *serverAddress, int serverPort, int timeout)
{
	assert(serverPort != 0);		// can't connect to no port
	assert(serverAddress != NULL);
	assert(serverAddress[0] != 0);

	if (mConnectionListCount >= mParams.maxConnections)
		return(NULL);

		// get server address
	unsigned long address = inet_addr(serverAddress);
	if (address == INADDR_NONE)
	{
		struct hostent * lphp;
		lphp = gethostbyname(serverAddress);
		if (lphp == NULL)
			return(NULL);
		address = ((struct in_addr *)(lphp->h_addr))->s_addr;
	}
	UdpIpAddress destIp(address);

		// first, see if we already have a connection object managing this ip/port, if we do, then fail
	UdpConnection *con = AddressGetConnection(destIp, serverPort);
	if (con != NULL)
		return(NULL);
	return(new UdpConnection(this, destIp, serverPort, timeout));
}

void UdpManager::KeepUntilDisconnected(UdpConnection *con)
{
	con->AddRef();
	con->mDisconnectPendingNextConnection = mDisconnectPendingList;
	mDisconnectPendingList = con;
}

void UdpManager::GetStats(UdpManagerStatistics *stats) const
{
	assert(stats != NULL);
	*stats = mManagerStats;
	stats->poolAvailable = mPoolAvailable;
	stats->poolCreated = mPoolCreated;
	stats->elapsedTime = UdpMisc::ClockElapsed(mManagerStatsResetTime);
}

void UdpManager::ResetStats()
{
	mManagerStatsResetTime = UdpMisc::Clock();
	memset(&mManagerStats, 0, sizeof(mManagerStats));
}

void UdpManager::DumpPacketHistory(const char *filename) const
{
	assert(filename != NULL);
	assert(filename[0] != 0);
	FILE *file = fopen(filename, "wt");
	if (file != NULL)
	{
			// dump history of packets...
		for (int i = 0; i < mParams.packetHistoryMax; i++)
		{
			int pos = (mPacketHistoryPosition + i) % mParams.packetHistoryMax;

			if (mPacketHistory[pos]->mLen > 0)
			{
				char hold[64];
				uchar *ptr = mPacketHistory[pos]->mBuffer;
				fprintf(file, "%16s,%5d %3d: ", mPacketHistory[pos]->mIp.GetAddress(hold), mPacketHistory[pos]->mPort, mPacketHistory[pos]->mLen);
				int len = mPacketHistory[pos]->mLen;
				while (len-- > 0)
				{
					fprintf(file, "%02x ", *ptr);
					ptr++;
				}
				fprintf(file, "\n");
			}
		}
		fclose(file);
	}
}

UdpIpAddress UdpManager::GetLocalIp() const
{
	struct sockaddr_in addr_self;
	memset(&addr_self, 0, sizeof(addr_self));
	socklen_t len = sizeof(addr_self);
	getsockname(mUdpSocket, (struct sockaddr *)&addr_self, &len);
	return(UdpIpAddress(addr_self.sin_addr.s_addr));
}

int UdpManager::GetLocalPort() const
{
	struct sockaddr_in addr_self;
	memset(&addr_self, 0, sizeof(addr_self));
	socklen_t len = sizeof(addr_self);
	getsockname(mUdpSocket, (struct sockaddr *)&addr_self, &len);
	return(ntohs(addr_self.sin_port));
}

UdpManager::PacketHistoryEntry *UdpManager::ActualReceive()
{
	if (mParams.simulateIncomingByteRate > 0 && UdpMisc::Clock() < mSimulateNextIncomingTime)
		return(NULL);

	struct sockaddr_in addr_from;
	socklen_t sf = sizeof(addr_from);
	int pos = mPacketHistoryPosition;
	int res = recvfrom(mUdpSocket, (char *)mPacketHistory[pos]->mBuffer, mParams.maxRawPacketSize, 0, (struct sockaddr *)&addr_from, &sf);

	if (res != SOCKET_ERROR)
	{
		if (mParams.simulateIncomingLossPercent > 0 && ((rand() % 100) < mParams.simulateIncomingLossPercent))
			return(NULL);	// packet, what packet?

		if (mParams.simulateIncomingByteRate > 0)
			mSimulateNextIncomingTime = UdpMisc::Clock() + (res * 1000 / mParams.simulateIncomingByteRate);

		mLastReceiveTime = UdpMisc::Clock();
		mPacketHistory[pos]->mLen = res;
		mPacketHistory[pos]->mIp = UdpIpAddress(addr_from.sin_addr.s_addr);
		mPacketHistory[pos]->mPort = (int)ntohs(addr_from.sin_port);

		mPacketHistoryPosition = (mPacketHistoryPosition + 1) % mParams.packetHistoryMax;
		mManagerStats.bytesReceived += res;
		mManagerStats.packetsReceived++;
		return(mPacketHistory[pos]);
	}
	else
	{
#if defined(WIN32)
			// windows is kind enough to put ICMP error packets inline within the stream as errors, so we
			// can easily see the errors indicating that the destination address is unreachable for some reason
		if (WSAGetLastError() == WSAECONNRESET)
		{
			UdpIpAddress ip = UdpIpAddress(addr_from.sin_addr.s_addr);
			int port = (int)ntohs(addr_from.sin_port);
			UdpConnection *con = AddressGetConnection(ip, port);
			if (con != NULL)
			{
				con->AddRef();
				con->PortUnreachable();
				con->Release();
			}

				// in order to get our parent to give us time again to poll another packet, we must return it a packet
				// to process.  We will do this by sending it an empty packet, which it will simply ignore and call us
				// asking for yet another packet.  We will enter an empty packet into the packet-history so we can effectively
				// see these ICMP packets in the history.
			mLastReceiveTime = UdpMisc::Clock();
			mPacketHistory[pos]->mLen = 0;
			mPacketHistory[pos]->mIp = UdpIpAddress(addr_from.sin_addr.s_addr);
			mPacketHistory[pos]->mPort = (int)ntohs(addr_from.sin_port);
			mPacketHistoryPosition = (mPacketHistoryPosition + 1) % mParams.packetHistoryMax;
			return(mPacketHistory[pos]);
		}
#endif
	}
	return(NULL);
}

void UdpManager::ProcessIcmpErrors()
{
#if defined(WIN32)
		// nothing needed for WIN32, it handles these errors inline with standard packets
#elif defined(sparc)
		// Just to be bassackwards, solaris handles these errors on a subsequent sendto call
#else
		// we can use some ICMP errors to our advantage to more quickly realize that the connection on the other end has disappeared
	unsigned char msg_control[1024];
	struct msghdr msgh = {0};
	struct sockaddr_in msg_name;
	socklen_t sf = sizeof(msg_name);
	msgh.msg_name = &msg_name;
	msgh.msg_namelen = sf;
	msgh.msg_iov = 0;
	msgh.msg_iovlen = 0;
	msgh.msg_control = msg_control;
	msgh.msg_controllen = sizeof(msg_control);
	
	int err = recvmsg(mUdpSocket, &msgh, MSG_ERRQUEUE);
	if(err != -1)
	{
		struct cmsghdr * cmsg;
		if(CMSG_FIRSTHDR(&msgh))
		{
			for(cmsg = CMSG_FIRSTHDR(&msgh); cmsg != NULL; cmsg = CMSG_NXTHDR(&msgh, cmsg))
			{
				if(cmsg->cmsg_level == SOL_IP && cmsg->cmsg_type == IP_RECVERR)
				{
					// HACK! HACK! Can't find any portable definition of sock_extended_err!
					unsigned char * errData = (unsigned char *)CMSG_DATA(cmsg);
					if(errData[4] == 2) // ICMP origin
					{
						uchar code = errData[6];
						if(code == ICMP_PORT_UNREACH)
						{
							UdpIpAddress ip = UdpIpAddress(msg_name.sin_addr.s_addr);
							int port = (int)htons(msg_name.sin_port);
							UdpConnection *con = AddressGetConnection(ip, port);
							if (con != NULL)
							{
								con->AddRef();
								con->PortUnreachable();
								con->Release();
							}
						}
					}
				}
			}
		}
		else
		{
			// ancillary data missing
		}
	}
#endif
}

void UdpManager::ActualSend(const uchar *data, int dataLen, UdpIpAddress ip, int port)
{
	mLastSendTime = UdpMisc::Clock();
	mManagerStats.bytesSent += dataLen;
	mManagerStats.packetsSent++;

	if (mParams.simulateOutgoingByteRate != 0)
	{
			// simulating outgoing byte-rate, so queue it up for sending later
		UdpConnection *con = AddressGetConnection(ip, port);
		if (con != NULL)
		{
			if (mParams.simulateDestinationOverloadLevel > 0 && con->mSimulateQueueBytes + dataLen > mParams.simulateDestinationOverloadLevel)
				return;		// no room, packet gets lost
		}
		if (mParams.simulateOutgoingOverloadLevel > 0 && mSimulateQueueBytes + dataLen > mParams.simulateOutgoingOverloadLevel)
			return;		// no room, packet gets lost

		if (con != NULL)
			con->mSimulateQueueBytes += dataLen;
		mSimulateQueueBytes += dataLen;
		SimulateQueueEntry *entry = new SimulateQueueEntry(data, dataLen, ip, port);

		if (mSimulateQueueStart != NULL)
			mSimulateQueueEnd->mNext = entry;
		else
			mSimulateQueueStart = entry;
		mSimulateQueueEnd = entry;
		mSimulateQueueEnd->mNext = NULL;
		return;
	}
	ActualSendHelper(data, dataLen, ip, port);
}

void UdpManager::ActualSendHelper(const uchar *data, int dataLen, UdpIpAddress ip, int port)
{
	if (mParams.simulateOutgoingLossPercent > 0 && ((rand() % 100) < mParams.simulateOutgoingLossPercent))
		return;
	struct sockaddr_in addr_dest;
	addr_dest.sin_family = PF_INET;
	addr_dest.sin_addr.s_addr = ip.GetAddress();
	addr_dest.sin_port = htons((ushort)port);
	if (SOCKET_ERROR == sendto(mUdpSocket, (const char *)data, dataLen, 0, (struct sockaddr *)&addr_dest, sizeof(addr_dest)))
	{
			// error writing to socket, what is the error?
#if defined(sparc)
		if(errno == ECONNREFUSED || errno == EHOSTUNREACH)
		{
				// flag connection to terminate itself for port-unreachable error on next give time
				// we need to flag it instead of actually terminating it to prevent callbacks from occuring during application sends
			UdpConnection *con = AddressGetConnection(ip, port);
			if (con != NULL)
				con->FlagPortUnreachable();
			return;
		}
#endif

			// error types are OS specific, so unless a particular OS grabs the error and treats it differently just above (as sparc does)
			// then we are going to just treat all errors as socket overflows (which we only track for statistical purposes)
		mManagerStats.socketOverflowErrors++;
	}
}

void UdpManager::SendPortAlive(UdpIpAddress ip, int port)
{
	uchar buf[2];
	buf[0] = 0;
	buf[1] = UdpConnection::cUdpPacketPortAlive;

#if defined(WIN32)
	int val = 5;
	setsockopt(mUdpSocket, IPPROTO_IP, IP_TTL, (char *)&val, sizeof(val));
	ActualSendHelper(buf, 2, ip, port);
	setsockopt(mUdpSocket, IPPROTO_IP, IP_TTL, (char *)&mStartTtl, sizeof(mStartTtl));
#else
	unsigned long val = 5;
	setsockopt(mUdpSocket, IPPROTO_IP, IP_TTL, &val, sizeof(val));
	ActualSendHelper(buf, 2, ip, port);
	setsockopt(mUdpSocket, IPPROTO_IP, IP_TTL, &mStartTtl, sizeof(mStartTtl));
#endif
}

void UdpManager::ProcessRawPacket(const PacketHistoryEntry *e)
{
	if (e->mBuffer[0] == 0 && e->mBuffer[1] == UdpConnection::cUdpPacketPortAlive)
		return;		// port-alive packets are not supposed to reach the destination machine, but on the odd chance they do, pretend like they never existed
	
	UdpConnection *con = AddressGetConnection(e->mIp, e->mPort);

	if (con == NULL)
	{
			// packet coming from an unknown ip/port
			// if it is a connection request packet, then establish a new connection object to reply to it
			// connection establish packet must always be at least 6 bytes long as we must have a version number, no matter how it changes
		if (e->mBuffer[0] == 0 && e->mBuffer[1] == UdpConnection::cUdpPacketConnect && e->mLen == UdpConnection::cUdpPacketConnectSize)
		{
			if (mConnectionListCount >= mParams.maxConnections)
				return;		// can't handle any more connections, so ignore this request entirely

			int protocolVersion = UdpMisc::GetValue32(e->mBuffer + 2);
			if (protocolVersion == cProtocolVersion)
			{
				if (mParams.handler != NULL)
				{
					UdpConnection *newcon = new UdpConnection(this, e);
					mParams.handler->OnConnectRequest(newcon);
					if (newcon->GetRefCount() == 1)
					{
							// we are going to end up destroying this connection when we release it on this next line
							// so disconnect it first giving it a reason
						newcon->InternalDisconnect(0, UdpConnection::cDisconnectReasonConnectionRefused);
					}
					newcon->Release();
				}
			}
		}
		else
		{
			if (mParams.allowPortRemapping)
			{
				if (e->mBuffer[0] == 0 && e->mBuffer[1] == UdpConnection::cUdpPacketRequestRemap)
				{
						// ok, we got a packet from somebody, that we don't know who they are, but, it appears they are asking
						// for their address/port to be remapped.  If we allow port (and/or address) remapping, then go ahead
						// an honor their request if possible
					uchar *ptr = e->mBuffer + 2;
					int connectCode = UdpMisc::GetValue32(ptr);
					ptr += 4;
					int encryptCode = UdpMisc::GetValue32(ptr);

					UdpConnection *con = ConnectCodeGetConnection(connectCode);
					if (con != NULL)
					{
						if (mParams.allowAddressRemapping || con->mIp == e->mIp)
						{
								// one final security check to ensure these are really the same connection, compare encryption codes
							if (con->mConnectionConfig.encryptCode == encryptCode)
							{
									// remapping is allowed, remap ourselves to the address of the incoming request
								mAddressHashTable->Remove(con, AddressHashValue(con->mIp, con->mPort));
								con->mIp = e->mIp;
								con->mPort = e->mPort;
								mAddressHashTable->Insert(con, AddressHashValue(con->mIp, con->mPort));
								return;
							}
						}
					}
				}
			}


				// got a packet from somebody and we don't know who they are and the packet we got was not a connection request
				// just in case they are a previous client who thinks they are still connected, we will send them an internal
				// packet telling them that we don't know who they are
			if (mParams.replyUnreachableConnection)
			{
					// do not reply back with unreachable if the packet coming in is a terminate or unreachable packet itself
				if (e->mBuffer[0] != 0 || (e->mBuffer[0] == 0 && e->mBuffer[1] != UdpConnection::cUdpPacketUnreachableConnection && e->mBuffer[1] != UdpConnection::cUdpPacketTerminate))
				{
						// since we do not have a connection-object associated with this incoming packet, there is no way we could
						// encrypt it or add CRC bytes to it, since we have no idea what the other end of the connection is expecting
						// in this regard.  As such, the UnreachableConnection packet (like the connect and confirm packets) is one
						// of those internal packet types that is designated as not being encrypted or CRC'ed.
					unsigned char buf[8];
					buf[0] = 0;
					buf[1] = UdpConnection::cUdpPacketUnreachableConnection;
					ActualSend(buf, 2, e->mIp, e->mPort);
				}
			}
		}
		return;
	}

	con->AddRef();
	con->ProcessRawPacket(e);
	con->Release();
}

UdpConnection *UdpManager::AddressGetConnection(UdpIpAddress ip, int port) const
{
	UdpConnection *found = static_cast<UdpConnection *>(mAddressHashTable->FindFirst(AddressHashValue(ip, port)));
	while (found != NULL)
	{
		if (found->mIp == ip && found->mPort == port)
			return(found);
		found = static_cast<UdpConnection *>(mAddressHashTable->FindNext(found));
	}
	return(NULL);
}

UdpConnection *UdpManager::ConnectCodeGetConnection(int connectCode) const
{
	UdpConnection *found = static_cast<UdpConnection *>(mConnectCodeHashTable->FindFirst(connectCode));
	while (found != NULL)
	{
		if (found->mConnectCode == connectCode)
			return(found);
		found = static_cast<UdpConnection *>(mConnectCodeHashTable->FindNext(found));
	}
	return(NULL);
}

WrappedLogicalPacket *UdpManager::WrappedBorrow(const LogicalPacket *lp)
{
	if (mWrappedAvailable > 0)
	{
		WrappedLogicalPacket *wp = mWrappedAvailableRoot;
		mWrappedAvailableRoot = mWrappedAvailableRoot->mAvailableNext;
		mWrappedAvailable--;
		wp->SetLogicalPacket(lp);
		return(wp);
	}
	else
	{
		WrappedLogicalPacket *wp = new WrappedLogicalPacket(this);
		wp->SetLogicalPacket(lp);
		return(wp);
	}
}

void UdpManager::WrappedCreated(WrappedLogicalPacket *wp)
{
	wp->mCreatedNext = mWrappedCreatedRoot;
	if (mWrappedCreatedRoot != NULL)
		mWrappedCreatedRoot->mCreatedPrev = wp;
	mWrappedCreatedRoot = wp;
	mWrappedCreated++;
}

void UdpManager::WrappedDestroyed(WrappedLogicalPacket *wp)
{
	if (wp->mCreatedNext != NULL)
	{
		wp->mCreatedNext->mCreatedPrev = wp->mCreatedPrev;
	}
	if (wp->mCreatedPrev != NULL)
	{
		wp->mCreatedPrev->mCreatedNext = wp->mCreatedNext;
	}
	else
	{
			// we are first entry, set root
		mWrappedCreatedRoot = wp->mCreatedNext;
	}

	wp->mCreatedPrev = NULL;
	wp->mCreatedNext = NULL;
	wp->mUdpManager = NULL;
	mWrappedCreated--;
}

LogicalPacket *UdpManager::CreatePacket(const void *data, int dataLen, const void *data2, int dataLen2)
{
	if (mParams.pooledPacketMax > 0)
	{
		int totalLen = dataLen + dataLen2;
		if (totalLen <= mParams.pooledPacketSize)
		{
			if (mPoolAvailable > 0)
			{
				PooledLogicalPacket *lp = mPoolAvailableRoot;
				mPoolAvailableRoot = mPoolAvailableRoot->mAvailableNext;
				mPoolAvailable--;
				lp->SetData(data, dataLen, data2, dataLen2);
				return(lp);
			}
			else
			{
					// create a new pooled packet to fulfil request
				PooledLogicalPacket *lp = new PooledLogicalPacket(this, mParams.pooledPacketSize);
				lp->SetData(data, dataLen, data2, dataLen2);
				return(lp);
			}
		}
	}

	return(UdpMisc::CreateQuickLogicalPacket(data, dataLen, data2, dataLen2));
}

void UdpManager::PoolCreated(PooledLogicalPacket *packet)
{
	packet->mCreatedNext = mPoolCreatedRoot;
	if (mPoolCreatedRoot != NULL)
		mPoolCreatedRoot->mCreatedPrev = packet;
	mPoolCreatedRoot = packet;
	mPoolCreated++;
}

void UdpManager::PoolDestroyed(PooledLogicalPacket *packet)
{
	if (packet->mCreatedNext != NULL)
	{
		packet->mCreatedNext->mCreatedPrev = packet->mCreatedPrev;
	}
	if (packet->mCreatedPrev != NULL)
	{
		packet->mCreatedPrev->mCreatedNext = packet->mCreatedNext;
	}
	else
	{
			// we are first entry, set root
		mPoolCreatedRoot = packet->mCreatedNext;
	}

	packet->mCreatedPrev = NULL;
	packet->mCreatedNext = NULL;
	packet->mUdpManager = NULL;
	mPoolCreated--;
}



	/////////////////////////////////////////////////////////////////////////////////////////////////////
	// PacketHistory implementation
	/////////////////////////////////////////////////////////////////////////////////////////////////////
UdpManager::PacketHistoryEntry::PacketHistoryEntry(int maxRawPacketSize)
{
	mBuffer = new uchar[maxRawPacketSize];
	mPort = 0;
	mLen = 0;
}

UdpManager::PacketHistoryEntry::~PacketHistoryEntry()
{
	delete[] mBuffer;
}


	/////////////////////////////////////////////////////////////////////////////////////////////////////
	// UdpConnection implementation
	/////////////////////////////////////////////////////////////////////////////////////////////////////

UdpConnection::UdpConnection(UdpManager *udpManager, UdpIpAddress destIp, int destPort, int timeout)
{
		// client side initializations
	Init(udpManager, destIp, destPort);

	mConnectAttemptTimeout = timeout;
	mStatus = cStatusNegotiating;
	mConnectCode = (rand() << 16) | rand();
	mUdpManager->AddConnection(this);

	GiveTime();
}

UdpConnection::UdpConnection(UdpManager *udpManager, const UdpManager::PacketHistoryEntry *e)
{
		// server side initialization
	Init(udpManager, e->mIp, e->mPort);

	mStatus = cStatusConnected;
	for (int j = 0; j < UdpManager::cEncryptPasses; j++)
		mConnectionConfig.encryptMethod[j] = mUdpManager->mParams.encryptMethod[j];
	mConnectionConfig.crcBytes = mUdpManager->mParams.crcBytes;
	mConnectionConfig.maxRawPacketSize = mUdpManager->mParams.maxRawPacketSize;
	mConnectionConfig.encryptCode = (rand() << 16) | rand();
	SetupEncryptModel();

		// steal the connect code out of the packet early such that ProcessRawPacket will think it's a valid connect packet instead of ignoring it
		// plus, the AddConnection function needs to know our connect code
	mConnectCode = UdpMisc::GetValue32(e->mBuffer + 6);
	mUdpManager->AddConnection(this);

	ProcessRawPacket(e);
	GiveTime();
}

void UdpConnection::Init(UdpManager *udpManager, UdpIpAddress destIp, int destPort)
{
	mRefCount = 1;
	mUdpManager = udpManager;
	mIp = destIp;
	mPort = destPort;

	mFlaggedPortUnreachable = false;

	mLastPortAliveTime = mLastSendTime = 0;			// makes it send out the first connect packet immediately (if we are in negotiating mode)
	mLastReceiveTime = UdpMisc::Clock();
	mLastClockSyncTime = 0;
	mDataHoldTime = 0;
	mGettingTime = false;
	mHandler = NULL;

	mNoDataTimeout = mUdpManager->mParams.noDataTimeout;
	mKeepAliveDelay = mUdpManager->mParams.keepAliveDelay;

	mMultiBufferData = new uchar[mUdpManager->mParams.maxRawPacketSize];
	mMultiBufferPtr = mMultiBufferData;

	mDisconnectPendingNextConnection = NULL;
	mNextConnection = NULL;
	mPrevConnection = NULL;
	mIcmpErrorRetryStartStamp = 0;		// when the timer started for ICMP error retry delay (gets reset on a successful packet receive)
	mPortRemapRequestStartStamp = 0;

	mEncryptXorBuffer = NULL;
	mEncryptExpansionBytes = 0;
	mOrderedCountOutgoing = 0;
	mOrderedCountOutgoing2 = 0;
	mOrderedStampLast = 0;
	mOrderedStampLast2 = 0;
	mDisconnectReason = cDisconnectReasonNone;
	mOtherSideDisconnectReason = cDisconnectReasonNone;

	mConnectionCreateTime = UdpMisc::Clock();
	mSimulateQueueBytes = 0;
	mPassThroughData = NULL;
	mSilentDisconnect = false;

	mLastSendBin = 0;
	mLastReceiveBin = 0;
	mOutgoingBytesLastSecond = 0;
	mIncomingBytesLastSecond = 0;
	memset(mSendBin, 0, sizeof(mSendBin));
	memset(mReceiveBin, 0, sizeof(mReceiveBin));

    PingStatReset();
	mSyncTimeDelta = 0;
	memset(mChannel, 0, sizeof(mChannel));
	memset(&mConnectionStats, 0, sizeof(mConnectionStats));
}

UdpConnection::~UdpConnection()
{
	if (mUdpManager != NULL)
		InternalDisconnect(0, mDisconnectReason);

	for (int i = 0; i < UdpManager::cReliableChannelCount; i++)
		delete mChannel[i];
	delete[] mMultiBufferData;
	delete[] mEncryptXorBuffer;
}

void UdpConnection::PortUnreachable()
{
	if (!mUdpManager->mParams.processIcmpErrors)
		return;

	if (!mUdpManager->mParams.processIcmpErrorsDuringNegotiating)
	{
		if (mStatus == cStatusNegotiating)		// during negotiating phase, ignore port unreachable errors, since it may be a case of the client starting up first
			return;
	}

	if (mUdpManager->mParams.icmpErrorRetryPeriod != 0)
	{
		if (mIcmpErrorRetryStartStamp == 0)
		{
			mIcmpErrorRetryStartStamp = UdpMisc::Clock();		// start timer on how long we will ignore ICMP errors
			return;
		}

		if (UdpMisc::ClockElapsed(mIcmpErrorRetryStartStamp) < mUdpManager->mParams.icmpErrorRetryPeriod)
		{
			return;		// ignoring ICMP errors for a period of time
		}
	}

	InternalDisconnect(0, cDisconnectReasonIcmpError);
}

void UdpConnection::InternalDisconnect(int flushTimeout, DisconnectReason reason)
{
	mDisconnectReason = reason;
	Status startStatus = mStatus;
	UdpManager *startUdpManager = mUdpManager;

		// if we are in a negotiating state, then you can't have a flushTimeout, any disconnect will occur immediately
	if (mStatus == cStatusNegotiating)
		flushTimeout = 0;

	if (mUdpManager != NULL)
	{
		if (flushTimeout > 0)
		{
			FlushMultiBuffer();
			mDisconnectFlushStamp = UdpMisc::Clock();
			mDisconnectFlushTimeout = flushTimeout;
			ScheduleTimeNow();

			if (mStatus != cStatusDisconnectPending)
			{
				mStatus = cStatusDisconnectPending;
				mUdpManager->KeepUntilDisconnected(this);
			}
			return;
		}

			// send a termination packet to the other side
			// do not send a termination packet if we are still negotiating (we are not allowed to send any packets while negotiating)
			// if you attempt to send a packet while negotiating, then it will potentially attempt to encrypt it before an encryption
			// method is determined, resulting in a function call through an invalid pointer
		if (!mSilentDisconnect)
		{
			if (mStatus == cStatusConnected || mStatus == cStatusDisconnectPending)
			{
				SendTerminatePacket(mConnectCode, mDisconnectReason);
			}
		}

		mUdpManager->RemoveConnection(this);
		mUdpManager = NULL;
	}
	mStatus = cStatusDisconnected;

	if (startStatus != cStatusDisconnected && startUdpManager != NULL)
	{
		if (mHandler != NULL)
			mHandler->OnTerminated(this);
	}
}

void UdpConnection::SendTerminatePacket(int connectCode, DisconnectReason reason)
{
	uchar buf[256];
	buf[0] = 0;
	buf[1] = cUdpPacketTerminate;
	UdpMisc::PutValue32(buf + 2, connectCode);
	UdpMisc::PutValue16(buf + 6, (ushort)reason);
	PhysicalSend(buf, 8, true);
}


void UdpConnection::SetSilentDisconnect(bool silent)
{
		// this function tells the connection to disconnect silently, meaning that it should
		// not send a packet to the other side telling it that the connection is being terminated
	mSilentDisconnect = silent;
}

bool UdpConnection::Send(UdpChannel channel, const void *data, int dataLen)
{
	assert(dataLen >= 0);
	assert(channel >= 0 && channel < cUdpChannelCount);
	assert(mStatus != cStatusNegotiating);	// you are not allowed to start sending data on a connection that is still in the process of negotiating (only applicable client-side obviously since servers never have connections in this state)

	if (mStatus != cStatusConnected)	// if we are no longer connected (not allowed to send more when we are pending disconnect either)
		return(false);
	if (dataLen == 0)		// zero length packets are ignored
		return(false);

	assert(data != NULL);		// can't send a null packet

    mUdpManager->mManagerStats.applicationPacketsSent++;
	mConnectionStats.applicationPacketsSent++;

		// zero-escape application packets that start with 0
	if ((*(const uchar *)data) == 0)
	{
		uchar hold = 0;
		return(InternalSend(channel, &hold, 1, (const uchar *)data, dataLen));
	}

	return(InternalSend(channel, (const uchar *)data, dataLen));
}

bool UdpConnection::Send(UdpChannel channel, const LogicalPacket *packet)
{
	assert(packet != NULL);		// can't send a null packet
	assert(channel >= 0 && channel < cUdpChannelCount);
	assert(mStatus != cStatusNegotiating);	// you are not allowed to start sending data on a connection that is still in the process of negotiating (only applicable client-side obviously since servers never have connections in this state)

	if (mStatus != cStatusConnected)	// if we are no longer connected
		return(false);
	int dataLen = packet->GetDataLen();
	if (dataLen == 0)
		return(false);

    mUdpManager->mManagerStats.applicationPacketsSent++;
	mConnectionStats.applicationPacketsSent++;

		// zero-escape application packets that start with 0
	const uchar *data = (const uchar *)packet->GetDataPtr();
	if (!packet->IsInternalPacket() && data[0] == 0)
	{
		uchar hold = 0;
		return(InternalSend(channel, &hold, 1, data, dataLen));
	}

	return(InternalSend(channel, packet));
}

bool UdpConnection::InternalSend(UdpChannel channel, const uchar *data, int dataLen, const uchar *data2, int dataLen2)
{
		// promote unreliable packets that are larger than maxRawPacketSize to be reliable
	int totalDataLen = dataLen + dataLen2;

	int rawDataBytesMax = (mConnectionConfig.maxRawPacketSize - mConnectionConfig.crcBytes - mEncryptExpansionBytes);
	if ((channel == cUdpChannelUnreliable || channel == cUdpChannelUnreliableUnbuffered) && totalDataLen > rawDataBytesMax)
		channel = cUdpChannelReliable1;
	else if ((channel == cUdpChannelOrdered || channel == cUdpChannelOrderedUnbuffered) && totalDataLen > rawDataBytesMax - cUdpPacketOrderedSize)
		channel = cUdpChannelReliable1;

	uchar tempBuffer[UdpManager::cHardMaxRawPacketSize];
	switch(channel)
	{
		case cUdpChannelUnreliable:
			BufferedSend(data, dataLen, data2, dataLen2, false);
			return(true);
			break;
		case cUdpChannelUnreliableUnbuffered:
		{
			uchar *bufPtr = tempBuffer;
			memcpy(bufPtr, data, dataLen);
			if (data2 != NULL)
				memcpy(bufPtr + dataLen, data2, dataLen2);
			PhysicalSend(bufPtr, totalDataLen, true);
			return(true);
			break;
		}
		case cUdpChannelOrdered:
		{
			uchar *bufPtr = tempBuffer;
			bufPtr[0] = 0;
			bufPtr[1] = cUdpPacketOrdered2;
			UdpMisc::PutValue16(bufPtr + 2, (ushort)(++mOrderedCountOutgoing2 & 0xffff));
			memcpy(bufPtr + 4, data, dataLen);
			if (data2 != NULL)
				memcpy(bufPtr + 4 + dataLen, data2, dataLen2);
			BufferedSend(bufPtr, totalDataLen + 4, NULL, 0, true);
			return(true);
			break;
		}
		case cUdpChannelOrderedUnbuffered:
		{
			uchar *bufPtr = tempBuffer;
			bufPtr[0] = 0;
			bufPtr[1] = cUdpPacketOrdered2;
			UdpMisc::PutValue16(bufPtr + 2, (ushort)(++mOrderedCountOutgoing2 & 0xffff));
			memcpy(bufPtr + 4, data, dataLen);
			if (data2 != NULL)
				memcpy(bufPtr + 4 + dataLen, data2, dataLen2);
			PhysicalSend(bufPtr, totalDataLen + 4, true);
			return(true);
			break;
		}
		case cUdpChannelReliable1:
		case cUdpChannelReliable2:
		case cUdpChannelReliable3:
		case cUdpChannelReliable4:
		{
			int num = channel - cUdpChannelReliable1;
			if (mChannel[num] == NULL)
				mChannel[num] = new UdpReliableChannel(num, this, &mUdpManager->mParams.reliable[num]);
			mChannel[num]->Send(data, dataLen, data2, dataLen2);
			return(true);
			break;
		}
		default:
			break;
	}
	return(false);
}

bool UdpConnection::InternalSend(UdpChannel channel, const LogicalPacket *packet)
{
	switch(channel)
	{
		case cUdpChannelReliable1:
		case cUdpChannelReliable2:
		case cUdpChannelReliable3:
		case cUdpChannelReliable4:
		{
			int num = channel - cUdpChannelReliable1;
			if (mChannel[num] == NULL)
				mChannel[num] = new UdpReliableChannel(num, this, &mUdpManager->mParams.reliable[num]);
			mChannel[num]->Send(packet);
			return(true);
			break;
		}
		default: // unhandled members (cUdpChannelUnreliable, etc...)
		{
			// 3 April 2002 - jrandall
			// moved this from beginning of statement to
			// 1) satisfy compiler warnings about unhandled enum member
			// 2) avoid the additional branch unnecessarily incurred
			//    when sending reliable messages
			if (channel < cUdpChannelReliable1)		// if going unreliably
				return(InternalSend(channel, (const uchar *)packet->GetDataPtr(), packet->GetDataLen()));
			break;
		}
	}
	return(false);
}

void UdpConnection::PingStatReset()
{
    mLastClockSyncTime = 0; // tells it to resync the clock pronto
	mSyncStatMasterFixupTime = 0;
	mSyncStatMasterRoundTime = 0;
	mSyncStatLow = 0;
	mSyncStatHigh = 0;
	mSyncStatLast = 0;
	mSyncStatTotal = 0;
	mSyncStatCount = 0;
	mConnectionStats.averagePingTime = 0;
	mConnectionStats.highPingTime = 0;
	mConnectionStats.lowPingTime = 0;
	mConnectionStats.lastPingTime = 0;
	mConnectionStats.masterPingTime = 0;
}

void UdpConnection::GetStats(UdpConnectionStatistics *cs) const
{
	assert(cs != NULL);

	if (mUdpManager == NULL)
		return;
	*cs = mConnectionStats;

	if (mUdpManager->mParams.clockSyncDelay == 0)
		cs->masterPingAge = -1;
	else
		cs->masterPingAge = UdpMisc::ClockElapsed(mSyncStatMasterFixupTime);

	cs->percentSentSuccess = 1.0;
	cs->percentReceivedSuccess = 1.0;
	if (cs->syncOurSent > 0)
		cs->percentSentSuccess = (float)cs->syncTheirReceived / (float)cs->syncOurSent;
	if (cs->syncTheirSent > 0)
		cs->percentReceivedSuccess = (float)cs->syncOurReceived / (float)cs->syncTheirSent;
    cs->reliableAveragePing = 0;
    if (mChannel[0] != NULL)
        cs->reliableAveragePing = mChannel[0]->GetAveragePing();
}

void UdpConnection::ProcessRawPacket(const UdpManager::PacketHistoryEntry *e)
{
	if (mUdpManager == NULL)
		return;

	if (e->mBuffer[0] != 0 || e->mBuffer[1] != cUdpPacketUnreachableConnection)
	{
			// if we get any type of packet other than an unreachable-connection packet, then we can assume that our remapping
			// request succeeded, and clear the timer for how long we should attempt to do the remapping.  The reason we need
			// to send requests for a certain amount of time, is the server may already have dozens of unreachable-connection packets
			// on the wire on the way to us, before we manage to request that the remapping occur.
		mPortRemapRequestStartStamp = 0;
	}

	mIcmpErrorRetryStartStamp = 0;		// we received a packet successfully, so assume we have recovered from any ICMP error state we may have been in, so we can reset the timer
	mLastReceiveTime = UdpMisc::Clock();
	mConnectionStats.totalPacketsReceived++;
	mConnectionStats.totalBytesReceived += e->mLen;

		// track incoming data rate
	mLastReceiveBin = ExpireReceiveBin();
	mReceiveBin[mLastReceiveBin % cBinCount] += e->mLen;
	mIncomingBytesLastSecond += e->mLen;

	if (e->mBuffer[0] == 0 && e->mBuffer[1] == cUdpPacketKeepAlive)
	{
			// encryption can't mess up the first two bytes of an internal packet, so this is safe to check
			// if it is a keep alive packet, then we don't need to do any more processing beyond setting
			// the mLastReceiveTime.  We do this check here instead of letting it pass on through harmlessly
			// like we used to do in order to avoid getting rescheduled in the priority queue.  There is absolutely
			// no reason to reschedule us due to an incoming keep alive packet since the keep-alive packet has the
			// longest rescheduling of anything that needs time, so the worst thing that might happen is we might
			// end up getting sheduled time sooner than we might otherwise need to.  And obviously scheduling
			// ourselves for immediate-time is even sooner than that, so there is no point.
			// This turns out to be important for applications that have lots of connections (tens of thousands)
			// that rarely talk but send keep alives...no reason to make the server do a lot work over these things.
		return;
	}

		// whenever we receive a packet, it could potentially change when we want time scheduled again
		// so effectively we should reprioritize ourself to the top.  By doing it this way instead of
		// simply giving time and recalculating, we can effectively avoid giving ourself time and reprioritizing
		// ourself over and over again as more and more packets arrive in rapid succession
		// note: this cannot happen while we are in our UdpConnection::GiveTime function, so there is no need to squeltch check 
		// it like we do the others.
		// note: this was moved to the top of the function from the bottom.  This doesn't effect anything as it doesn't matter
		// when we schedule ourself for future processing.  Moving it to the top allowed us to get scheduled even if the packet
		// we processed got rejected for some reason (crc mismatch or bad size).
	ScheduleTimeNow();

	if (e->mLen < 1)
	{
		CallbackCorruptPacket(e->mBuffer, e->mLen, cCorruptionReasonZeroLengthPacket);
		return;		// invalid packet len
	}

		// first see if we are a special connect/confirm/unreachable packet, if so, process us immediately
	if (IsNonEncryptPacket(e->mBuffer))
	{
		ProcessCookedPacket(e->mBuffer, e->mLen);
	}
	else
	{
			// if we are still awaiting confirmation packet, then we must ignore any other incoming data packets
			// this can happen if the confirm packet is lost and the server has dumped a load of data on the newly created connection
		if (mStatus == cStatusNegotiating)
			return;

		uchar *finalStart = e->mBuffer;
		int finalLen = e->mLen;

		if (mConnectionConfig.crcBytes > 0)
		{
			if (finalLen < mConnectionConfig.crcBytes)
			{
				CallbackCorruptPacket(e->mBuffer, e->mLen, cCorruptionReasonPacketShorterThanCrcBytes);
				return;		// invalid packet len
			}

			uchar *crcPtr = finalStart + (finalLen - mConnectionConfig.crcBytes);
			int actualCrc = UdpMisc::Crc32(finalStart, finalLen - mConnectionConfig.crcBytes, mConnectionConfig.encryptCode);
			int wantCrc = 0;
			switch(mConnectionConfig.crcBytes)
			{
				case 1:
					wantCrc = *crcPtr;
					actualCrc &= 0xff;
					break;
				case 2:
					wantCrc = UdpMisc::GetValue16(crcPtr);
					actualCrc &= 0xffff;
					break;
				case 3:
					wantCrc = UdpMisc::GetValue24(crcPtr);
					actualCrc &= 0xffffff;
					break;
				case 4:
					wantCrc = UdpMisc::GetValue32(crcPtr);
					break;
			}
			if (wantCrc != actualCrc)
			{
				mConnectionStats.crcRejectedPackets++;
				mUdpManager->mManagerStats.crcRejectedPackets++;
				if (mHandler != NULL)
					mHandler->OnCrcReject(this, e->mBuffer, e->mLen);
				return;
			}
			finalLen -= mConnectionConfig.crcBytes;
		}

		uchar tempDecryptBuffer[2][UdpManager::cHardMaxRawPacketSize];

		for (int j = UdpManager::cEncryptPasses - 1; j >= 0; j--)
		{
			if (mConnectionConfig.encryptMethod[j] != UdpManager::cEncryptMethodNone)
			{
					// connect/confirm/unreachable packets are not encrypted, other packets are encrypted from the second or third byte on as appropriate
				uchar *decryptPtr = tempDecryptBuffer[j % 2];
				*decryptPtr++ = finalStart[0];

				if (finalStart[0] == 0)
				{
					if (finalLen < 2)
					{
						CallbackCorruptPacket(e->mBuffer, e->mLen, cUdpCorruptionInternalPacketTooShort);
						return;		// invalid packet len
					}

					*decryptPtr++ = finalStart[1];
					int len = (this->*(mDecryptFunction[j]))(decryptPtr, finalStart + 2, finalLen - 2);
					if (len == -1)
					{
						CallbackCorruptPacket(e->mBuffer, e->mLen, cUdpCorruptionDecryptFailed);
						return;		// decrypt failed, throw away packet
					}
					decryptPtr += len;
				}
				else
				{
					int len = (this->*(mDecryptFunction[j]))(decryptPtr, finalStart + 1, finalLen - 1);
					if (len == -1)
					{
						CallbackCorruptPacket(e->mBuffer, e->mLen, cUdpCorruptionDecryptFailed);
						return;		// decrypt failed, throw away packet
					}
					decryptPtr += len;
				}

				finalStart = tempDecryptBuffer[j % 2];
				finalLen = decryptPtr - finalStart;
			}
		}

		ProcessCookedPacket(finalStart, finalLen);
	}
}

void UdpConnection::CallbackRoutePacket(const uchar *data, int dataLen)
{
	if (mStatus == cStatusConnected)
	{
		mUdpManager->mManagerStats.applicationPacketsReceived++;
		mConnectionStats.applicationPacketsReceived++;

		if (mHandler != NULL)
			mHandler->OnRoutePacket(this, data, dataLen);
	}
}

void UdpConnection::CallbackCorruptPacket(const uchar *data, int dataLen, UdpCorruptionReason reason)
{
	mConnectionStats.corruptPacketErrors++;
	mUdpManager->mManagerStats.corruptPacketErrors++;
	if (mHandler != NULL)
		mHandler->OnPacketCorrupt(this, data, dataLen, reason);
}

void UdpConnection::ProcessCookedPacket(const uchar *data, int dataLen)
{
	uchar buf[256];
	uchar *bufPtr;
	if (mUdpManager == NULL)
		return;

	if (data[0] == 0 && dataLen > 1)
	{
			// internal packet, so process it internally
		switch(data[1])
		{
			case cUdpPacketConnect:
			{
				int connectCode = UdpMisc::GetValue32(data + 6);

				if (mStatus == cStatusNegotiating)
				{
						// why are we receiving a connect-request coming from the guy we ourselves are currently
						// in the process of trying to connect to?  Odds are very high that what is actually
						// happening is we are trying to connect to ourself.  In either case, we should reply
						// back telling them they are terminated.
					if (connectCode == mConnectCode)
						SendTerminatePacket(connectCode, cDisconnectReasonConnectingToSelf);
					else
						SendTerminatePacket(connectCode, cDisconnectReasonMutualConnectError);
					return;
				}

				if (connectCode == mConnectCode)
				{
					mConnectionConfig.maxRawPacketSize = udpMin((int)UdpMisc::GetValue32(data + 10), mConnectionConfig.maxRawPacketSize);

						// send confirm packet (if our connect code matches up)
						// prepare UdpPacketConnect packet
					bufPtr = buf;
					*bufPtr++ = 0;
					*bufPtr++ = cUdpPacketConfirm;
					bufPtr += UdpMisc::PutValue32(bufPtr, mConnectCode);
					bufPtr += UdpMisc::PutValue32(bufPtr, mConnectionConfig.encryptCode);
					*bufPtr++ = (uchar)mConnectionConfig.crcBytes;
					for (int j = 0; j < UdpManager::cEncryptPasses; j++)
						*bufPtr++ = (uchar)mConnectionConfig.encryptMethod[j];
					bufPtr += UdpMisc::PutValue32(bufPtr, mConnectionConfig.maxRawPacketSize);
					RawSend(buf, bufPtr - buf);
				}
				else
				{
						// ok, we got a connect-request packet from the ip/port of something we thought we already had a connection to.
						// Additionally, the connect-request packet has a different code, meaning it is not just a stragling connect-request
						// packet that got sent after we accepted the connection.
						// This means that the other side has probably terminated the connection and is attempting to connect again.
						// if we just ignore the new connect-request, it will actually result in the new connection-attempt effectively
						// keeping this connection object alive.  So, instead, when we get this situation, we will terminate this connection
						// and ignore the connect-request packet.  The connect-request packet will be sent again 1 second later by the client
						// at which time we won't exist and out UdpManager will establish a new connection object for it.
					InternalDisconnect(0, cDisconnectReasonNewConnectionAttempt);
					return;
				}
				break;
			}
			case cUdpPacketConfirm:
			{
					// unpack UdpPacketConfirm packet
				Configuration config;
				int connectCode		= UdpMisc::GetValue32(data + 2);
				config.encryptCode	= UdpMisc::GetValue32(data + 6);
				config.crcBytes		= *(data + 10);
				for (int j = 0; j < UdpManager::cEncryptPasses; j++)
					config.encryptMethod[j] = (UdpManager::EncryptMethod)*(data + 11 + j);
				config.maxRawPacketSize = UdpMisc::GetValue32(data + 11 + UdpManager::cEncryptPasses);

				if (mStatus == cStatusNegotiating && mConnectCode == connectCode)
				{
					mConnectionConfig = config;
					SetupEncryptModel();
					mStatus = cStatusConnected;
					if (mHandler != NULL)
						mHandler->OnConnectComplete(this);
				}
				break;
			}
			case cUdpPacketRequestRemap:
			{
					// if a request remap packet managed to get routed to our connection, it is because
					// the mapping is already correct, so we can just ignore this packet at this point
					// this will happen when the client sends multiple remap-requests, the first one will
					// cause the actual remapping to occur, and the subsequent ones will manage to make
					// it into here
				break;
			}
			case cUdpPacketZeroEscape:
			{
				CallbackRoutePacket(data + 1, dataLen - 1);
				break;
			}
			case cUdpPacketOrdered:
			{
				ushort orderedStamp = UdpMisc::GetValue16(data + 2);
				int diff = (int)orderedStamp - (int)mOrderedStampLast;
				if (diff <= 0)		// equal here makes it strip dupes too
					diff += 0x10000;
				if (diff < 30000)
				{
					mOrderedStampLast = orderedStamp;
					CallbackRoutePacket(data + cUdpPacketOrderedSize, dataLen - cUdpPacketOrderedSize);
				}
				else
				{
					mConnectionStats.orderRejectedPackets++;
					mUdpManager->mManagerStats.orderRejectedPackets++;
				}
				break;
			}
			case cUdpPacketOrdered2:
			{
				ushort orderedStamp = UdpMisc::GetValue16(data + 2);
				int diff = (int)orderedStamp - (int)mOrderedStampLast2;
				if (diff <= 0)		// equal here makes it strip dupes too
					diff += 0x10000;
				if (diff < 30000)
				{
					mOrderedStampLast2 = orderedStamp;
					CallbackRoutePacket(data + cUdpPacketOrderedSize, dataLen - cUdpPacketOrderedSize);
				}
				else
				{
					mConnectionStats.orderRejectedPackets++;
					mUdpManager->mManagerStats.orderRejectedPackets++;
				}
				break;
			}
			case cUdpPacketTerminate:
			{
				int connectCode = UdpMisc::GetValue32(data + 2);
				if (dataLen >= 8)		// to remain protocol compatible with previous version, the other side disconnect reason is an optional field on this packet
				{
					mOtherSideDisconnectReason = (DisconnectReason)UdpMisc::GetValue16(data + 6);
				}

				if (mConnectCode == connectCode)
				{
						// since other side explicitly told us they had terminated, there is no reason for us to send a terminate
						// packet back to them as well (as it will almost always result in some for of unreachable-destination reply)
						// so, put ourselves in silent-disconnect mode when this happens
					SetSilentDisconnect(true);		
					InternalDisconnect(0, cDisconnectReasonOtherSideTerminated);
					return;
				}
				break;
			}
			case cUdpPacketUnreachableConnection:
			{
				if (mUdpManager->mParams.allowPortRemapping)
				{
					if (mPortRemapRequestStartStamp == 0)
					{
						mPortRemapRequestStartStamp = UdpMisc::Clock();
					}

					enum { cMaximumTimeAllowedForPortRemapping = 5000 };
					if (UdpMisc::ClockElapsed(mPortRemapRequestStartStamp) < cMaximumTimeAllowedForPortRemapping)
					{
						bufPtr = buf;
						*bufPtr++ = 0;
						*bufPtr++ = cUdpPacketRequestRemap;
						bufPtr += UdpMisc::PutValue32(bufPtr, mConnectCode);
						bufPtr += UdpMisc::PutValue32(bufPtr, mConnectionConfig.encryptCode);
						RawSend(buf, bufPtr - buf);		// since the destination doesn't have an associated connection for us to decrypt us, we must be sent unencrypted
						break;
					}
				}

				InternalDisconnect(0, cDisconnectReasonUnreachableConnection);
				return;
				break;
			}
			case cUdpPacketMulti:
			{
				const uchar *ptr = data + 2;
				const uchar *endPtr = data + dataLen;
				while (ptr < endPtr)
				{
					int len = *(const uchar *)ptr++;
					const uchar *nextPtr = ptr + len;
					if (nextPtr > endPtr)
					{
							// multi-packet lengths didn't properly add up to total packet length
							// meaning we likely got a corrupt packet.  If you have CRC bytes enabled, it seems
							// quite unlikely this could ever occur.  Odds are it has happened because the application
							// (while processing this packet) ended up touching the packet-data and corrupting the next
							// packet in the multi-sequence.
						CallbackCorruptPacket(data, dataLen, cUdpCorruptionMultiPacket);
					}
					else
					{
						ProcessCookedPacket(ptr, len);
					}
					ptr = nextPtr;
				}
				break;
			}
			case cUdpPacketClockSync:
			{
                if (mUdpManager->mProcessingInducedLag > 1000)   // if it has been over a second since our manager got processing time, then we should ignore clock-sync packets as we will have introduced too much lag ourselves.
                    break;

					// unpacket UdpPacketClockSync packet
				UdpPacketClockSync pp;
				pp.zeroByte			= *data;
				pp.packetType       = *(data + 1);
				pp.timeStamp		= UdpMisc::GetValue16(data + 2);
				pp.masterPingTime	= UdpMisc::GetValue32(data + 4);
				pp.averagePingTime	= UdpMisc::GetValue32(data + 8);
				pp.lowPingTime		= UdpMisc::GetValue32(data + 12);
				pp.highPingTime		= UdpMisc::GetValue32(data + 16);
				pp.lastPingTime		= UdpMisc::GetValue32(data + 20);
				pp.ourSent			= UdpMisc::GetValue64(data + 24);
				pp.ourReceived		= UdpMisc::GetValue64(data + 32);

						// prepare UdpPacketClockReflect packet
				bufPtr = buf;
				*bufPtr++ = 0;
				*bufPtr++ = cUdpPacketClockReflect;
				bufPtr += UdpMisc::PutValue16(bufPtr, pp.timeStamp);					// timeStamp
				bufPtr += UdpMisc::PutValue32(bufPtr, UdpMisc::LocalSyncStampLong());	// serverSyncStampLong
				bufPtr += UdpMisc::PutValue64(bufPtr, pp.ourSent);						// yourSent
				bufPtr += UdpMisc::PutValue64(bufPtr, pp.ourReceived);					// yourReceived
				bufPtr += UdpMisc::PutValue64(bufPtr, mConnectionStats.totalPacketsSent);			// ourSent
				bufPtr += UdpMisc::PutValue64(bufPtr, mConnectionStats.totalPacketsReceived);		// ourReceived
				PhysicalSend(buf, bufPtr - buf, true);

				mConnectionStats.averagePingTime = pp.averagePingTime;
				mConnectionStats.highPingTime = pp.highPingTime;
				mConnectionStats.lowPingTime = pp.lowPingTime;
				mConnectionStats.lastPingTime = pp.lastPingTime;
				mConnectionStats.masterPingTime = pp.masterPingTime;
				mConnectionStats.syncOurReceived = mConnectionStats.totalPacketsReceived;
				mConnectionStats.syncOurSent = mConnectionStats.totalPacketsSent - 1;	// minus 1 since we should not count the packet we just sent
				mConnectionStats.syncTheirReceived = pp.ourReceived;
				mConnectionStats.syncTheirSent = pp.ourSent;
				break;
			}
			case cUdpPacketClockReflect:
			{
                if (mUdpManager->mProcessingInducedLag > 1000)   // if it has been over a second since our manager got processing time, then we should ignore clock-sync packets as we will have introduced too much lag ourselves.
                    break;

				UdpPacketClockReflect pp;
				pp.zeroByte				= *data;
				pp.packetType			= *(data + 1);
				pp.timeStamp			= UdpMisc::GetValue16(data + 2);
				pp.serverSyncStampLong  = UdpMisc::GetValue32(data + 4);
				pp.yourSent				= UdpMisc::GetValue64(data + 8);
				pp.yourReceived			= UdpMisc::GetValue64(data + 16);
				pp.ourSent				= UdpMisc::GetValue64(data + 24);
				pp.ourReceived			= UdpMisc::GetValue64(data + 32);

				ushort curStamp = UdpMisc::LocalSyncStampShort();
				int roundTime = UdpMisc::SyncStampShortDeltaTime(pp.timeStamp, curStamp);

				mSyncStatCount++;
				mSyncStatTotal += roundTime;
				if (mSyncStatLow == 0 || roundTime < mSyncStatLow)
					mSyncStatLow = roundTime;
				if (roundTime > mSyncStatHigh)
					mSyncStatHigh = roundTime;
				mSyncStatLast = roundTime;

					// see if we should use this sync to reset the master sync time
					// if have better (or close to better) round time or it has been a while
				int elapsed = UdpMisc::ClockElapsed(mSyncStatMasterFixupTime);
				if (roundTime <= mSyncStatMasterRoundTime + 20 || elapsed > 120000)
				{
						// resync on this packet unless this packet is a real loser (unless it just been a very long time, then sync up anyhow)
					if (roundTime < mSyncStatMasterRoundTime * 2 || elapsed > 240000)
					{
						mSyncTimeDelta = (pp.serverSyncStampLong - UdpMisc::LocalSyncStampLong()) + (uint)(roundTime / 2);
						mSyncStatMasterFixupTime = UdpMisc::Clock();
						mSyncStatMasterRoundTime = roundTime;
					}
				}

					// update connection statistics
				mConnectionStats.averagePingTime = (mSyncStatCount > 0) ? (mSyncStatTotal / mSyncStatCount) : 0;
				mConnectionStats.highPingTime = mSyncStatHigh;
				mConnectionStats.lowPingTime = mSyncStatLow;
				mConnectionStats.lastPingTime = roundTime;
				mConnectionStats.masterPingTime = mSyncStatMasterRoundTime;
				mConnectionStats.syncOurReceived = pp.yourReceived;
				mConnectionStats.syncOurSent = pp.yourSent;
				mConnectionStats.syncTheirReceived = pp.ourReceived;
				mConnectionStats.syncTheirSent = pp.ourSent;
				break;
			}
			case cUdpPacketKeepAlive:
				break;
			case cUdpPacketReliable1:
			case cUdpPacketReliable2:
			case cUdpPacketReliable3:
			case cUdpPacketReliable4:
			case cUdpPacketFragment1:
			case cUdpPacketFragment2:
			case cUdpPacketFragment3:
			case cUdpPacketFragment4:
			{
				int num = (data[1] - cUdpPacketReliable1) % UdpManager::cReliableChannelCount;
				if (mChannel[num] == NULL)
					mChannel[num] = new UdpReliableChannel(num, this, &mUdpManager->mParams.reliable[num]);
				mChannel[num]->ReliablePacket(data, dataLen);
				break;
			}
			case cUdpPacketAck1:
			case cUdpPacketAck2:
			case cUdpPacketAck3:
			case cUdpPacketAck4:
			{
				int num = data[1] - cUdpPacketAck1;
				if (mChannel[num] != NULL)
					mChannel[num]->AckPacket(data, dataLen);
				break;
			}
			case cUdpPacketAckAll1:
			case cUdpPacketAckAll2:
			case cUdpPacketAckAll3:
			case cUdpPacketAckAll4:
			{
				int num = data[1] - cUdpPacketAckAll1;
				if (mChannel[num] != NULL)
					mChannel[num]->AckAllPacket(data, dataLen);
				break;
			}
			case cUdpPacketGroup:
			{
				const uchar *ptr = data + 2;
				const uchar *endPtr = data + dataLen;
				while (ptr < endPtr)
				{
					uint len;
					ptr += UdpMisc::GetVariableValue(ptr, &len);
					ProcessCookedPacket(ptr, len);
					ptr += len;
				}
				break;
			}
		}
	}
	else
	{
		CallbackRoutePacket(data, dataLen);
	}
}

void UdpConnection::FlushChannels()
{
	AddRef();		// in case application tries to delete us during this give time (could only occur due to a ConnectComplete callback timeout)
	GiveTime();		// gives our reliable channels time to send any data recently added to their queues.  Reschedules us as well, which is ok.
	FlushMultiBuffer();
	Release();
}

void UdpConnection::FlagPortUnreachable()
{
	mFlaggedPortUnreachable = true;
}

void UdpConnection::GiveTime()
{
	if (mUdpManager == NULL)
		return;
	UdpManager *myManager = mUdpManager;

	myManager->AddRef();		// hold a reference to the UdpManager so it doesn't disappear while we are inside our GiveTime
	mGettingTime = true;		// lets the internal code know we are in the process of getting time.  We do this so when actual packets are sent while we are getting time, we don't reprioritize ourselves to 0

	InternalGiveTime();

	mGettingTime = false;
	myManager->Release();
}

void UdpConnection::InternalGiveTime()
{
	uchar buf[256];
	uchar *bufPtr;

	int nextSchedule = 10 * 60 * 1000;		// give us time in 10 minutes (unless somebody wants it sooner)
	mConnectionStats.iterations++;

	if (mFlaggedPortUnreachable)
	{
		mFlaggedPortUnreachable = false;
		PortUnreachable();
	}

	switch(mStatus)
	{
		case cStatusNegotiating:
		{
			if (mConnectAttemptTimeout > 0 && ConnectionAge() > mConnectAttemptTimeout)
			{
				InternalDisconnect(0, cDisconnectReasonConnectFail);
				return;
				break;
			}

			if (UdpMisc::ClockElapsed(mLastSendTime) >= mUdpManager->mParams.connectAttemptDelay)
			{
					// prepare UdpPacketConnect packet
				bufPtr = buf;
				*bufPtr++ = 0;
				*bufPtr++ = cUdpPacketConnect;
				bufPtr += UdpMisc::PutValue32(bufPtr, UdpManager::cProtocolVersion);
				bufPtr += UdpMisc::PutValue32(bufPtr, mConnectCode);
				bufPtr += UdpMisc::PutValue32(bufPtr, mUdpManager->mParams.maxRawPacketSize);
				RawSend(buf, bufPtr - buf);
				nextSchedule = udpMin(nextSchedule, mUdpManager->mParams.connectAttemptDelay);
			}
			break;
		}
		case cStatusConnected:
		case cStatusDisconnectPending:
		{
				// sync clock if required
			if (mUdpManager->mParams.clockSyncDelay > 0)
			{
					// sync periodically.  If our current master round time is very bad, then sync more frequently (this is important to quickly get a sync up and running)
				int elapsed = UdpMisc::ClockElapsed(mLastClockSyncTime);
				if (elapsed > mUdpManager->mParams.clockSyncDelay 
							|| (mSyncStatMasterRoundTime > 3000 && elapsed > 2000) 
							|| (mSyncStatMasterRoundTime > 1000 && elapsed > 5000)
							|| (mSyncStatCount < 2 && elapsed > 10000))
				{
						// send a clock-sync packet
					int averagePing = (mSyncStatCount > 0) ? (mSyncStatTotal / mSyncStatCount) : 0;

					bufPtr = buf;
					*bufPtr++ = 0;
					*bufPtr++ = cUdpPacketClockSync;
					bufPtr += UdpMisc::PutValue16(bufPtr, UdpMisc::LocalSyncStampShort());	// timeStamp
					bufPtr += UdpMisc::PutValue32(bufPtr, mSyncStatMasterRoundTime);		// masterPingTime
					bufPtr += UdpMisc::PutValue32(bufPtr, averagePing);						// averagePingTime
					bufPtr += UdpMisc::PutValue32(bufPtr, mSyncStatLow);					// lowPingTime
					bufPtr += UdpMisc::PutValue32(bufPtr, mSyncStatHigh);					// highPingTime
					bufPtr += UdpMisc::PutValue32(bufPtr, mSyncStatLast);					// lastPingTime
					bufPtr += UdpMisc::PutValue64(bufPtr, mConnectionStats.totalPacketsSent + 1);	// ourSent (add 1 to include this packet we are about to send since other side will count it as received before getting it)
					bufPtr += UdpMisc::PutValue64(bufPtr, mConnectionStats.totalPacketsReceived);	// ourReceived
					PhysicalSend(buf, bufPtr - buf, true);		// don't buffer this, we need it to be as timely as possible, it still needs to be encrypted though, so don't raw send it.

					mLastClockSyncTime = UdpMisc::Clock();
					elapsed = 0;
				}

					// schedule us next time for a clock-sync packet
				nextSchedule = udpMin(nextSchedule, mUdpManager->mParams.clockSyncDelay - elapsed);
			}

				// give reliable channels processing time and see when they want more time
			int totalPendingBytes = 0;
			for (int i = 0; i < UdpManager::cReliableChannelCount; i++)
			{
				if (mChannel[i] != NULL)
				{
					totalPendingBytes += mChannel[i]->TotalPendingBytes();
					int myNext = mChannel[i]->GiveTime();
					if (mUdpManager == NULL)
						return;		// giving the reliable channel time caused it to callback the application which may disconnect us
					nextSchedule = udpMin(nextSchedule, myNext);
				}
			}

			if (mUdpManager->mParams.reliableOverflowBytes != 0 && totalPendingBytes >= mUdpManager->mParams.reliableOverflowBytes)
			{
				InternalDisconnect(0, cDisconnectReasonReliableOverflow);
				return;
			}
				
				// if we have multi-buffer data
			if (mMultiBufferPtr - mMultiBufferData > 2)
			{
				int elapsed = UdpMisc::ClockElapsed(mDataHoldTime);
				if (elapsed >= mUdpManager->mParams.maxDataHoldTime)
					FlushMultiBuffer();			// having just sent it, there is no data in the buffer so no reason to adjust the schedule for when it may be needed again
				else
					nextSchedule = udpMin(nextSchedule, mUdpManager->mParams.maxDataHoldTime - elapsed);	// schedule us processing time for when it does need to be sent
			}

				// see if we need to keep connection alive
			int elapsed = UdpMisc::ClockElapsed(mLastSendTime);
			if (mKeepAliveDelay > 0)
			{
				if (elapsed >= mKeepAliveDelay)
				{
						// send keep-alive packet
					bufPtr = buf;
					*bufPtr++ = 0;
					*bufPtr++ = cUdpPacketKeepAlive;
					PhysicalSend(buf, bufPtr - buf, true);
					elapsed = 0;
				}

					// schedule us next time for a keep-alive packet
				nextSchedule = udpMin(nextSchedule, mKeepAliveDelay - elapsed);
			}

				// see if we need to keep the port alive
			if (mUdpManager->mParams.portAliveDelay > 0)
			{
				int portElapsed = UdpMisc::ClockElapsed(mLastPortAliveTime);
				if (portElapsed >= mUdpManager->mParams.portAliveDelay)
				{
					mLastPortAliveTime = UdpMisc::Clock();
					mUdpManager->SendPortAlive(mIp, mPort);
					portElapsed = 0;
				}

					// schedule us next time for a keep-alive packet
				nextSchedule = udpMin(nextSchedule, mUdpManager->mParams.portAliveDelay - portElapsed);
			}

			if (mStatus == cStatusDisconnectPending)
			{
				int timeLeft = mDisconnectFlushTimeout - UdpMisc::ClockElapsed(mDisconnectFlushStamp);
				if (timeLeft < 0 || TotalPendingBytes() == 0)
				{
					InternalDisconnect(0, mDisconnectReason);
					return;
				}
				else
				{
					nextSchedule = udpMin(nextSchedule, timeLeft);
				}
			}

			if (mNoDataTimeout > 0)
			{
				int lrt = LastReceive();
				if (lrt >= mNoDataTimeout)
				{
					InternalDisconnect(0, cDisconnectReasonTimeout);
					return;
				}
				else
				{
					nextSchedule = udpMin(nextSchedule, mNoDataTimeout - lrt);
				}
			}

			break;
		}
		default:
			break;
	}

	if (mUdpManager != NULL)
	{
			// safety to prevent us for scheduling ourselves for a time period that has already passed,
			// as doing so could result in infinite looping in the priority queue processing.
			// in theory this cannot happen, I should likely assert here just to make sure...
		if (nextSchedule < 0)
			nextSchedule = 0;

		mUdpManager->SetPriority(this, UdpMisc::Clock() + nextSchedule + 5);		// add 5ms to ensure that we are indeed slightly past the scheduled time
	}
}

int UdpConnection::TotalPendingBytes() const
{
	int total = 0;
	for (int i = 0; i < UdpManager::cReliableChannelCount; i++)
	{
		if (mChannel[i] != NULL)
			total += mChannel[i]->TotalPendingBytes();
	}
	return(total);
}

void UdpConnection::RawSend(const uchar *data, int dataLen)
{
		// raw send resets last send time, so we need to potentially recalculate when we need time again
		// sends the actual physical packet (usually just after it has be prepped by PacketSend, but for connect/confirm/unreachable packets are bypass that step)
	mUdpManager->ActualSend(data, dataLen, mIp, mPort);
	mConnectionStats.totalPacketsSent++;
	mConnectionStats.totalBytesSent += dataLen;
	mLastPortAliveTime = mLastSendTime = UdpMisc::Clock();

		// track data rate
	mLastSendBin = ExpireSendBin();
	mSendBin[mLastSendBin % cBinCount] += dataLen;
	mOutgoingBytesLastSecond += dataLen;
	ScheduleTimeNow();
}

int UdpConnection::ExpireSendBin()
{
	int curBin = abs((int)(UdpMisc::Clock() / cBinResolution));
	int binDiff = curBin - mLastSendBin;
	if (binDiff > cBinCount)
	{
		memset(mSendBin, 0, sizeof(mSendBin));
		mOutgoingBytesLastSecond = 0;
	}
	else
	{
		for (int i = 0; i < binDiff; i++)
		{
			int clearBin = (curBin + i) % cBinCount;
			mOutgoingBytesLastSecond -= mSendBin[clearBin];
			mSendBin[clearBin] = 0;
		}
	}
	return(curBin);
}

int UdpConnection::ExpireReceiveBin()
{
	int curBin = abs((int)(UdpMisc::Clock() / cBinResolution));
	int binDiff = curBin - mLastReceiveBin;
	if (binDiff > cBinCount)
	{
		memset(mReceiveBin, 0, sizeof(mReceiveBin));
		mIncomingBytesLastSecond = 0;
	}
	else
	{
		for (int i = 0; i < binDiff; i++)
		{
			int clearBin = (curBin + i) % cBinCount;
			mIncomingBytesLastSecond -= mReceiveBin[clearBin];
			mReceiveBin[clearBin] = 0;
		}
	}
	return(curBin);
}

void UdpConnection::PhysicalSend(const uchar *data, int dataLen, bool appendAllowed)
{
	if (mUdpManager == NULL)
		return;

		// if we attempt to do a physical send (ie. encrypt/compress/crc a packet) while we are not connected
		// (especially if we are cStatusNegotiating), then it will potentially crash, because in the case of
		// cStatusNegotiating, we don't have the encryption method function pointer initialized yet, as the method
		// is part of the negotiations
	if (mStatus != cStatusConnected && mStatus != cStatusDisconnectPending)
		return;
	
		// this is physical packet send routine that compressed, encrypts the packet, and adds crc bytes to it as appropriate
		// no need to make sure we don't encrypt a connect/confirm/unreachable packet because those go directly to RawSend.
	uchar tempEncryptBuffer[2][UdpManager::cHardMaxRawPacketSize + sizeof(int)];
	const uchar *finalStart = data;
	int finalLen = dataLen;
	for (int j = 0; j < UdpManager::cEncryptPasses; j++)
	{
		if (mConnectionConfig.encryptMethod[j] != UdpManager::cEncryptMethodNone)
		{
			uchar *destStart = tempEncryptBuffer[j % 2];
			*(int *)(destStart + finalLen + mEncryptExpansionBytes) = (int)0xcececece;		// overwrite debug signature

			uchar *destPtr = destStart;
			*destPtr++ = finalStart[0];
			if (finalStart[0] == 0)
			{
					// we know this internal packet will not be a connect or confirm packet since they are sent directly to RawSend to avoid getting encrypted
				*destPtr++ = finalStart[1];
				int len = (this->*(mEncryptFunction[j]))(destPtr, finalStart + 2, finalLen - 2);

					// if this assert triggers, it means the encryption pass expanded the size of the encrypted
					// data more than was specified by the userSuppliedEncryptExpansionBytes setting, or at least
					// tampered with the destination buffer past that length.  This is considered a buffer overwrite
					// and will potentially cause bugs.
				assert(*(int *)(destStart + finalLen + mEncryptExpansionBytes) == (int)0xcececece);

				if (len == -1)
					return;		// would be really odd for encryption to return an error, but if it does, throw it away
				destPtr += len;
			}
			else
			{
				int len = (this->*(mEncryptFunction[j]))(destPtr, finalStart + 1, finalLen - 1);

					// if this assert triggers, it means the encryption pass expanded the size of the encrypted
					// data more than was specified by the userSuppliedEncryptExpansionBytes setting, or at least
					// tampered with the destination buffer past that length.  This is considered a buffer overwrite
					// and will potentially cause bugs.
				assert(*(int *)(destStart + finalLen + mEncryptExpansionBytes) == (int)0xcececece);

				if (len == -1)
					return;		// would be really odd for encryption to return an error, but if it does, throw it away
				destPtr += len;
			}

			finalStart = destStart;
			finalLen = destPtr - finalStart;
			appendAllowed = true;
		}
	}

	if (mConnectionConfig.crcBytes > 0)
	{
		if (!appendAllowed)
		{
				// if the buffer we are going to append onto was our original (ie. no encryption took place)
				// then we have to copy it all over to a temp buffer since we can't modify the original
			memcpy(tempEncryptBuffer[0], finalStart, finalLen);
			finalStart = tempEncryptBuffer[0];
		}

		int crc = UdpMisc::Crc32(finalStart, finalLen, mConnectionConfig.encryptCode);
		uchar *crcPtr = const_cast<uchar *>(finalStart) + finalLen;		// safe cast, since we make a copy of the data above if we would have ended up appending to the original
		switch(mConnectionConfig.crcBytes)
		{
			case 1:
				*crcPtr = (uchar)(crc & 0xff);
				break;
			case 2:
				UdpMisc::PutValue16(crcPtr, (ushort)(crc & 0xffff));
				break;
			case 3:
				UdpMisc::PutValue24(crcPtr, crc & 0xffffff);
				break;
			case 4:
				UdpMisc::PutValue32(crcPtr, crc);
				break;
		}
		finalLen += mConnectionConfig.crcBytes;
	}

	RawSend(finalStart, finalLen);
}

	// returns where it placed the data in the buffer (if it ended up in the buffer), such that the InternalAckSend
	// function can do its job
uchar *UdpConnection::BufferedSend(const uchar *data, int dataLen, const uchar *data2, int dataLen2, bool appendAllowed)
{
	if (mUdpManager == NULL)
		return(NULL);
	int used = mMultiBufferPtr - mMultiBufferData;

	int actualMaxDataHoldSize = udpMin(mUdpManager->mParams.maxDataHoldSize, mConnectionConfig.maxRawPacketSize);
		
	int totalDataLen = dataLen + dataLen2;
	if (totalDataLen > 255 || (totalDataLen + 3) > actualMaxDataHoldSize)
	{
			// too long of data to even attempt a multi-buffer of this packet, so let's just send it unbuffered
			// but first, to ensure the packet-order integrity is somewhat maintained, flush the multi-buffer
			// if it currently has something in it
		if (used > 2)
			FlushMultiBuffer();

			// now send it (the multi-buffer is empty if you need to use it temporarily to concatenate two data chunks -- it is large enough to hold the largest raw packet)
		if (data2 != NULL)
		{
			memcpy(mMultiBufferData, data, dataLen);
			memcpy(mMultiBufferData + dataLen, data2, dataLen2);
			PhysicalSend(mMultiBufferData, totalDataLen, true);
		}
		else
			PhysicalSend(data, dataLen, appendAllowed);
		return(NULL);
	}

		// if this data will not fit into buffer
		// note: we allow the multi-packet to grow as large as maxRawPacketSize, but down below we will flush it
		// as soon as it gets larger than maxDataHoldSize.
	if (used + totalDataLen + 1 > (mConnectionConfig.maxRawPacketSize - mConnectionConfig.crcBytes - mEncryptExpansionBytes))
	{
		FlushMultiBuffer();
		used = 0;
	}

		// add data to buffer
	if (used == 0)
	{
			// no buffered data yet, create multi-packet header
		*mMultiBufferPtr++ = 0;
		*mMultiBufferPtr++ = cUdpPacketMulti;

			// new multi-buffer started, so we need to potentially recalculate when we need time again
		mDataHoldTime = UdpMisc::Clock();			// set data hold time to when the first piece of data is stuck in the multi-buffer
		ScheduleTimeNow();
	}

	*(uchar *)mMultiBufferPtr++ = (uchar)totalDataLen;
	uchar *placementPtr = mMultiBufferPtr;
	memcpy(mMultiBufferPtr, data, dataLen);
	mMultiBufferPtr += dataLen;
	if (data2 != NULL)
	{
		memcpy(mMultiBufferPtr, data2, dataLen2);
		mMultiBufferPtr += dataLen2;
	}

	if ((mMultiBufferPtr - mMultiBufferData) >= actualMaxDataHoldSize)
	{
		FlushMultiBuffer();
		placementPtr = NULL;	// it got flushed
	}
	return(placementPtr);
}

uchar *UdpConnection::InternalAckSend(uchar *bufferedAckPtr, const uchar *ackPtr, int ackLen)
{
	if (bufferedAckPtr != NULL)
	{
		memcpy(bufferedAckPtr, ackPtr, ackLen);
		return(bufferedAckPtr);
	}

	BufferedSend(ackPtr, ackLen, NULL, 0, false);
	return(NULL);	// FIX THIS
}

void UdpConnection::FlushMultiBuffer()
{
	int len = mMultiBufferPtr - mMultiBufferData;
	if (len > 2)
	{
		if ((int)((uchar)mMultiBufferData[2]) + 3 == len)
			PhysicalSend(mMultiBufferData + 3, len - 3, true);		// only one packet so don't send it as a multi-packet
		else
			PhysicalSend(mMultiBufferData, len, true);

			// notify all the reliable channels to clear their buffered acks
		for (int i = 0; i < UdpManager::cReliableChannelCount; i++)
		{
			if (mChannel[i] != NULL)
			{
				mChannel[i]->ClearBufferedAck();
			}
		}

	}
	mMultiBufferPtr = mMultiBufferData;
}

int UdpConnection::EncryptNone(uchar *destData, const uchar *sourceData, int sourceLen)
{
	memcpy(destData, sourceData, sourceLen);
	return(sourceLen);
}

int UdpConnection::DecryptNone(uchar *destData, const uchar *sourceData, int sourceLen)
{
	memcpy(destData, sourceData, sourceLen);
	return(sourceLen);
}

int UdpConnection::EncryptUserSupplied(uchar *destData, const uchar *sourceData, int sourceLen)
{
	UdpManagerHandler *manHandler = mUdpManager->GetHandler();
	if (manHandler != NULL)
		return(manHandler->OnUserSuppliedEncrypt(this, destData, sourceData, sourceLen));
	assert(0);		// if user-supplied encryption is specified, then you must have a manager handler installed to provide the routines
	return(0);
}

int UdpConnection::DecryptUserSupplied(uchar *destData, const uchar *sourceData, int sourceLen)
{
	UdpManagerHandler *manHandler = mUdpManager->GetHandler();
	if (manHandler != NULL)
		return(manHandler->OnUserSuppliedDecrypt(this, destData, sourceData, sourceLen));
	assert(0);		// if user-supplied encryption is specified, then you must have a manager handler installed to provide the routines
	return(0);
}

int UdpConnection::EncryptUserSupplied2(uchar *destData, const uchar *sourceData, int sourceLen)
{
	UdpManagerHandler *manHandler = mUdpManager->GetHandler();
	if (manHandler != NULL)
		return(manHandler->OnUserSuppliedEncrypt2(this, destData, sourceData, sourceLen));
	assert(0);		// if user-supplied encryption is specified, then you must have a manager handler installed to provide the routines
	return(0);
}

int UdpConnection::DecryptUserSupplied2(uchar *destData, const uchar *sourceData, int sourceLen)
{
	UdpManagerHandler *manHandler = mUdpManager->GetHandler();
	if (manHandler != NULL)
		return(manHandler->OnUserSuppliedDecrypt2(this, destData, sourceData, sourceLen));
	assert(0);		// if user-supplied encryption is specified, then you must have a manager handler installed to provide the routines
	return(0);
}

int UdpConnection::EncryptXorBuffer(uchar *destData, const uchar *sourceData, int sourceLen)
{
	uchar *destPtr = destData;
	const uchar *walkPtr = sourceData;
	const uchar *endPtr = sourceData + sourceLen;
	uchar *encryptPtr = mEncryptXorBuffer;
	int prev = mConnectionConfig.encryptCode;
	while ((walkPtr + sizeof(int)) <= endPtr)
	{
		*(int *)destPtr = *(const int *)walkPtr ^ *(int *)encryptPtr ^ prev;
		prev = *(int *)destPtr;
		walkPtr += sizeof(int);
		destPtr += sizeof(int);
		encryptPtr += sizeof(int);
	}

	while (walkPtr != endPtr)
	{
		*destPtr = (uchar)(*walkPtr ^ *encryptPtr);
		destPtr++;
		walkPtr++;
		encryptPtr++;
	}
	return(sourceLen);
}

int UdpConnection::DecryptXorBuffer(uchar *destData, const uchar *sourceData, int sourceLen)
{
	const uchar *walkPtr = sourceData;
	const uchar *endPtr = sourceData + sourceLen;
	uchar *encryptPtr = mEncryptXorBuffer;
	uchar *destPtr = destData;
	int hold;
	int prev = mConnectionConfig.encryptCode;
	while ((walkPtr + sizeof(int)) <= endPtr)
	{
		hold = *(const int *)walkPtr;
		*(int *)destPtr = *(const int *)walkPtr ^ prev ^ *(int *)encryptPtr;
		prev = hold;
		walkPtr += sizeof(int);
		destPtr += sizeof(int);
		encryptPtr += sizeof(int);
	}

	while (walkPtr != endPtr)
	{
		*destPtr = (uchar)(*walkPtr ^ *encryptPtr);
		walkPtr++;
		destPtr++;
		encryptPtr++;
	}
	return(sourceLen);
}

int UdpConnection::EncryptXor(uchar *destData, const uchar *sourceData, int sourceLen)
{
	uchar *destPtr = destData;
	const uchar *walkPtr = sourceData;
	const uchar *endPtr = sourceData + sourceLen;
	int prev = mConnectionConfig.encryptCode;
	while ((walkPtr + sizeof(int)) <= endPtr)
	{
		*(int *)destPtr = *(const int *)walkPtr ^ prev;
		prev = *(int *)destPtr;
		walkPtr += sizeof(int);
		destPtr += sizeof(int);
	}

	while (walkPtr != endPtr)
	{
		*destPtr = (uchar)(*walkPtr ^ prev);
		destPtr++;
		walkPtr++;
	}
	return(sourceLen);
}

int UdpConnection::DecryptXor(uchar *destData, const uchar *sourceData, int sourceLen)
{
	const uchar *walkPtr = sourceData;
	const uchar *endPtr = sourceData + sourceLen;
	uchar *destPtr = destData;
	int hold;
	int prev = mConnectionConfig.encryptCode;
	while ((walkPtr + sizeof(int)) <= endPtr)
	{
		hold = *(const int *)walkPtr;
		*(int *)destPtr = *(const int *)walkPtr ^ prev;
		prev = hold;
		walkPtr += sizeof(int);
		destPtr += sizeof(int);
	}

	while (walkPtr != endPtr)
	{
		*destPtr = (uchar)(*walkPtr ^ prev);
		walkPtr++;
		destPtr++;
	}
	return(sourceLen);
}

void UdpConnection::SetupEncryptModel()
{
	mEncryptExpansionBytes = 0;
	for (int j = 0; j < UdpManager::cEncryptPasses; j++)
	{
		switch(mConnectionConfig.encryptMethod[j])
		{
			default:
				assert(0);	// unknown encryption method specified during in UdpManager construction
				break;
			case UdpManager::cEncryptMethodNone:
			{
					// point to method functions
				mDecryptFunction[j] = &UdpConnection::DecryptNone;
				mEncryptFunction[j] = &UdpConnection::EncryptNone;
				mEncryptExpansionBytes += 0;
				break;
			}
			case UdpManager::cEncryptMethodUserSupplied:
			{
					// point to method functions
				mDecryptFunction[j] = &UdpConnection::DecryptUserSupplied;
				mEncryptFunction[j] = &UdpConnection::EncryptUserSupplied;
				mEncryptExpansionBytes += mUdpManager->mParams.userSuppliedEncryptExpansionBytes;
				break;
			}
			case UdpManager::cEncryptMethodUserSupplied2:
			{
					// point to method functions
				mDecryptFunction[j] = &UdpConnection::DecryptUserSupplied2;
				mEncryptFunction[j] = &UdpConnection::EncryptUserSupplied2;
				mEncryptExpansionBytes += mUdpManager->mParams.userSuppliedEncryptExpansionBytes2;
				break;
			}
			case UdpManager::cEncryptMethodXorBuffer:
			{
					// point to method functions
				mDecryptFunction[j] = &UdpConnection::DecryptXorBuffer;
				mEncryptFunction[j] = &UdpConnection::EncryptXorBuffer;
				mEncryptExpansionBytes += 0;

					// set up encrypt buffer (random numbers generated based on seed)
				if (mEncryptXorBuffer == NULL)
				{
					int len = ((mUdpManager->mParams.maxRawPacketSize + 1) / 4) * 4;
					mEncryptXorBuffer = new uchar[len];
					int seed = mConnectionConfig.encryptCode;
					uchar *sptr = mEncryptXorBuffer;
					for (int i = 0; i < len; i++)
						*sptr++ = (uchar)(UdpMisc::Random(&seed) & 0xff);
				}
				break;
			}
			case UdpManager::cEncryptMethodXor:
			{
					// point to method functions
				mDecryptFunction[j] = &UdpConnection::DecryptXor;
				mEncryptFunction[j] = &UdpConnection::EncryptXor;
				mEncryptExpansionBytes += 0;
				break;
			}
		}
	}
}

void UdpConnection::GetChannelStatus(UdpChannel channel, ChannelStatus *channelStatus) const
{
	memset(channelStatus, 0, sizeof(*channelStatus));
	switch (channel)
	{
		case cUdpChannelReliable1:
		case cUdpChannelReliable2:
		case cUdpChannelReliable3:
		case cUdpChannelReliable4:
			if (mChannel[channel - cUdpChannelReliable1] != NULL)
			{
				mChannel[channel - cUdpChannelReliable1]->GetChannelStatus(channelStatus);
			}
			break;
		default:
			break;
	}
}

const char *UdpConnection::DisconnectReasonText(DisconnectReason reason)
{
	static bool sInitialized = false;
	static char *sDisconnectReason[cDisconnectReasonCount];
	
	if (!sInitialized)
	{
		sInitialized = true;
		memset(sDisconnectReason, 0, sizeof(sDisconnectReason));
		sDisconnectReason[cDisconnectReasonNone] = "DisconnectReasonNone";
		sDisconnectReason[cDisconnectReasonIcmpError] = "DisconnectReasonIcmpError";
		sDisconnectReason[cDisconnectReasonTimeout] = "DisconnectReasonTimeout";
		sDisconnectReason[cDisconnectReasonOtherSideTerminated] = "DisconnectReasonOtherSideTerminated";
		sDisconnectReason[cDisconnectReasonManagerDeleted] = "DisconnectReasonManagerDeleted";
		sDisconnectReason[cDisconnectReasonConnectFail] = "DisconnectReasonConnectFail";
		sDisconnectReason[cDisconnectReasonApplication] = "DisconnectReasonApplication";
		sDisconnectReason[cDisconnectReasonUnreachableConnection] = "DisconnectReasonUnreachableConnection";
		sDisconnectReason[cDisconnectReasonUnacknowledgedTimeout] = "DisconnectReasonUnacknowledgedTimeout";
		sDisconnectReason[cDisconnectReasonNewConnectionAttempt] = "DisconnectReasonNewConnectionAttempt";
		sDisconnectReason[cDisconnectReasonConnectionRefused] = "DisconnectReasonConnectionRefused";
		sDisconnectReason[cDisconnectReasonMutualConnectError] = "DisconnectReasonConnectError";
		sDisconnectReason[cDisconnectReasonConnectingToSelf] = "DisconnectReasonConnectingToSelf";
		sDisconnectReason[cDisconnectReasonReliableOverflow] = "DisconnectReasonReliableOverflow";
	}

	return(sDisconnectReason[reason]);
}




	/////////////////////////////////////////////////////////////////////////////////////////////////////
	// ReliableChannel implementation
	/////////////////////////////////////////////////////////////////////////////////////////////////////
UdpReliableChannel::UdpReliableChannel(int channelNumber, UdpConnection *con, UdpManager::ReliableConfig *config)
{
	mUdpConnection = con;
	mChannelNumber = channelNumber;
	mConfig = *config;
	mConfig.maxOutstandingPackets = udpMin(mConfig.maxOutstandingPackets, (int)UdpManager::cHardMaxOutstandingPackets);

	mAveragePingTime = 800;		// start out fairly high so we don't do a lot of resends on a bad connection to start out with
	mTrickleLastSend = 0;

	int fragmentSize = mConfig.fragmentSize;
	if (fragmentSize == 0 || fragmentSize > mUdpConnection->mConnectionConfig.maxRawPacketSize)
		fragmentSize = mUdpConnection->mConnectionConfig.maxRawPacketSize;
	mMaxDataBytes = (fragmentSize - UdpConnection::cUdpPacketReliableSize - mUdpConnection->mConnectionConfig.crcBytes - mUdpConnection->mEncryptExpansionBytes);
	assert(mMaxDataBytes > 0);		// fragment size/max-raw-packet-size set too small to allow for reliable deliver
	if (mConfig.trickleSize != 0)
		mMaxDataBytes = udpMin(mMaxDataBytes, mConfig.trickleSize);

	mMaxCoalesceAttemptBytes = -1;
	if (mConfig.coalesce)
	{
		mMaxCoalesceAttemptBytes = mMaxDataBytes - 5;	// 2 bytes for group-header, 3 bytes for length of packet
	}

	mReliableIncomingId = 0;
	mReliableOutgoingId = 0;
	mReliableOutgoingPendingId = 0;
	mReliableOutgoingBytes = 0;

	mLogicalPacketsQueued = 0;
	mLogicalBytesQueued = 0;

	mCoalescePacket = NULL;
	mCoalesceStartPtr = NULL;
	mCoalesceEndPtr = NULL;
	mCoalesceCount = 0;

	mBufferedAckPtr = NULL;

	mStatDuplicatePacketsReceived = 0;
	mStatResentPacketsAccelerated = 0;
	mStatResentPacketsTimedOut = 0;

	mCongestionWindowMinimum = udpMax(mMaxDataBytes, mConfig.congestionWindowMinimum);
	mCongestionWindowStart = udpMin(4 * mMaxDataBytes, udpMax(2 * mMaxDataBytes, 4380));
	mCongestionWindowStart = udpMax(mCongestionWindowStart, mCongestionWindowMinimum);
	mCongestionSlowStartThreshhold = udpMin(mConfig.maxOutstandingPackets * mMaxDataBytes, mConfig.maxOutstandingBytes);
	mCongestionWindowLargest = mCongestionWindowSize = mCongestionWindowStart;

	mBigDataLen = 0;
	mBigDataTargetLen = 0;
	mBigDataPtr = NULL;
	mFragmentNextPos = 0;
	mLastTimeStampAcknowledged = 0;
	mMaxxedOutCurrentWindow = false;
	mNextNeedTime = 0;

	mPhysicalPackets = new PhysicalPacket[mConfig.maxOutstandingPackets];
	mReliableIncoming = new IncomingQueueEntry[mConfig.maxInstandingPackets];

	mLogicalRoot = NULL;
	mLogicalEnd = NULL;
}

UdpReliableChannel::~UdpReliableChannel()
{
	if (mCoalescePacket != NULL)
	{
		mCoalescePacket->Release();
		mCoalescePacket = NULL;
	}

	const LogicalPacket *cur = mLogicalRoot;
	while (cur != NULL)
	{
		const LogicalPacket *next = cur->mReliableQueueNext;
		cur->mReliableQueueNext = NULL;	// make sure and mark it available so others could possibly use it (if it is a shared logical packet)
		cur->Release();
		if (cur == next)	// pointing to self, so this is end of list
			break;
		cur = next;
	}

	delete[] mPhysicalPackets;		// destructor will release any logical packets as appropriate
	delete[] mReliableIncoming;		// destructor will delete any data as appropriate

		// delete any big packet that might be under construction
	delete[] mBigDataPtr;
}

void UdpReliableChannel::Send(const uchar *data, int dataLen, const uchar *data2, int dataLen2)
{
	if (mLogicalPacketsQueued == 0)
	{
			// if we are adding something to a previously empty logical queue, then it is possible that
			// we may be able to send it, so mark ourselves to take time the next time it is offered
		mNextNeedTime = 0;
		mUdpConnection->ScheduleTimeNow();
	}

	if (dataLen + dataLen2 <= mMaxCoalesceAttemptBytes)
	{
		SendCoalesce(data, dataLen, data2, dataLen2);
	}
	else
	{
		FlushCoalesce();

		LogicalPacket *packet = mUdpConnection->mUdpManager->CreatePacket(data, dataLen, data2, dataLen2);
		QueueLogicalPacket(packet);
		packet->Release();
	}

	if (mConfig.processOnSend)		// make it give our channel time right now to determine outstanding and send this packet if there is room
		GiveTime();
}

void UdpReliableChannel::Send(const LogicalPacket *packet)
{
	if (mLogicalPacketsQueued == 0)
	{
			// if we are adding something to a previously empty logical queue, then it is possible that
			// we may be able to send it, so mark ourselves to take time the next time it is offered
		mNextNeedTime = 0;
		mUdpConnection->ScheduleTimeNow();
	}

	if (packet->GetDataLen() <= mMaxCoalesceAttemptBytes)
	{
		SendCoalesce((const uchar *)packet->GetDataPtr(), packet->GetDataLen());
	}
	else
	{
		FlushCoalesce();
		QueueLogicalPacket(packet);
	}

	if (mConfig.processOnSend)		// make it give our channel time right now to determine outstanding and send this packet if there is room
		GiveTime();
}

void UdpReliableChannel::FlushCoalesce()
{
	if (mCoalescePacket != NULL)
	{
		if (mCoalesceCount == 1)
		{
			int firstLen;
			int skipLen = UdpMisc::GetVariableValue(mCoalesceStartPtr + 2, (uint *)&firstLen);
			LogicalPacket *lp = mUdpConnection->mUdpManager->CreatePacket(mCoalesceStartPtr + 2 + skipLen, firstLen);
			QueueLogicalPacket(lp);
			lp->Release();
		}
		else
		{
			mCoalescePacket->SetDataLen(mCoalesceEndPtr - mCoalesceStartPtr);
			QueueLogicalPacket(mCoalescePacket);
		}

		mCoalescePacket->Release();
		mCoalescePacket = NULL;
	}
}

void UdpReliableChannel::SendCoalesce(const uchar *data, int dataLen, const uchar *data2, int dataLen2)
{
	int totalLen = dataLen + dataLen2;
	if (mCoalescePacket == NULL)
	{
		mCoalescePacket = mUdpConnection->mUdpManager->CreatePacket(NULL, mMaxDataBytes);
		mCoalesceEndPtr = mCoalesceStartPtr = (uchar *)mCoalescePacket->GetDataPtr();
		*mCoalesceEndPtr++ = 0;
		*mCoalesceEndPtr++ = UdpConnection::cUdpPacketGroup;
		mCoalesceCount = 0;
	}
	else
	{
		int spaceLeft = mMaxDataBytes - (mCoalesceEndPtr - mCoalesceStartPtr);
		if (totalLen + 3 > spaceLeft)		// 3 bytes to ensure PutVariableValue has room for the length indicator (this limits us to 64k coalescing, which is ok, since fragments can't get that big)
		{
			FlushCoalesce();
			SendCoalesce(data, dataLen, data2, dataLen2);
			return;
		}
	}

		// append on end of coalesce
	mCoalesceCount++;
	mCoalesceEndPtr += UdpMisc::PutVariableValue(mCoalesceEndPtr, totalLen);
	if (data != NULL)
		memcpy(mCoalesceEndPtr, data, dataLen);
	mCoalesceEndPtr += dataLen;
	if (data2 != NULL)
		memcpy(mCoalesceEndPtr, data2, dataLen2);
	mCoalesceEndPtr += dataLen2;
}

void UdpReliableChannel::QueueLogicalPacket(const LogicalPacket *packet)
{
	mLogicalPacketsQueued++;
	mLogicalBytesQueued += packet->GetDataLen();

	if (packet->mReliableQueueNext != NULL)
	{
		packet = mUdpConnection->mUdpManager->WrappedBorrow(packet);
	}
	else
	{
		packet->AddRef();
	}

	packet->mReliableQueueNext = packet;		// have it point to itself to signify that the mNext pointer is taken (ie. reserve it), yet still represents the end of the list
	if (mLogicalEnd != NULL)
	{
		mLogicalEnd->mReliableQueueNext = packet;
	}
	mLogicalEnd = packet;

	if (mLogicalRoot == NULL)
	{
		mLogicalRoot = packet;
	}
}

bool UdpReliableChannel::PullDown(int windowSpaceLeft)
{
		// the pull-down on-demand method will give us the opportunity to late-combine as many tiny logical packets as we can,
		// reducing the number of tracked-packets that are required.  This effectively reduces the number of acks that we are
		// going to get back, which can be substantial in situations where there are a LOT of tiny reliable packets being sent.
		// operating with fewer outstanding physical-packets to track is more CPU efficient as well.

		// (NOTE: as of this writing, the below implementation does not do the late-combine techique yet)
		// (NOTE: we could also combine-on-send if we so desired, I am not sure which way we will go)
		// (NOTE: doing it on send could allow us to avoid LogicalPacket allocations...)

	bool pulledDown = false;
	int physicalCount = (int)(mReliableOutgoingId - mReliableOutgoingPendingId);
	while (windowSpaceLeft > 0 && physicalCount < mConfig.maxOutstandingPackets)
	{
		if (mLogicalRoot == NULL)
		{
			FlushCoalesce();		// this is guaranteed to stick
			if (mLogicalRoot == NULL)
				break;		// nothing flushed, so we are done
		}

		int nextSpot = (int)(mReliableOutgoingId % mConfig.maxOutstandingPackets);

			// ok, we can move something down, even if it is only a fragment of the logical packet
		PhysicalPacket *entry = &mPhysicalPackets[nextSpot];
		entry->mParent = mLogicalRoot;
		entry->mParent->AddRef();		// add ref from physical packet
		entry->mFirstTimeStamp = 0;
		entry->mLastTimeStamp = 0;

			// calculate how much we can send based on our starting position (mFragmentNextPos) in the logical packet.
			// if we can't send it the rest of data to end of packet, then send the fragment portion and addref, otherwise send the whole thing and pop the logical packet
		int dataLen = entry->mParent->GetDataLen();
		const uchar *data = (const uchar *)entry->mParent->GetDataPtr();
		int bytesLeft = dataLen - mFragmentNextPos;
		int bytesToSend = udpMin(bytesLeft, mMaxDataBytes);

		entry->mDataPtr = data + mFragmentNextPos;

				// if not sending entire packet
		if (bytesToSend != dataLen)
		{
				// mark it as a fragment
			if (mFragmentNextPos == 0)
				bytesToSend -= sizeof(int);	// fragment start has a 4 byte header specifying size of following large data, so make room for it so we don't exceed max raw packet size
		}
		entry->mDataLen = bytesToSend;
		mReliableOutgoingBytes += bytesToSend;

		if (bytesToSend == bytesLeft)
		{
			mFragmentNextPos = 0;
			mLogicalPacketsQueued--;
			const LogicalPacket *lp = mLogicalRoot;
			mLogicalRoot = mLogicalRoot->mReliableQueueNext;
			if (mLogicalRoot == lp)		// ie, we were pointing to ourself, meaning we were the end of the list
			{
				mLogicalRoot = NULL;
				mLogicalEnd = NULL;
			}
			lp->mReliableQueueNext = NULL;	// clear our next link since we are no longer using it (so somebody else can use it potentially)
			lp->Release();					// release from logical queue
		}
		else
		{
			mFragmentNextPos += bytesToSend;
		}

		mLogicalBytesQueued -= bytesToSend;				// as fragments are sent, decrease the number of logical bytes queued
		mReliableOutgoingId++;
		physicalCount++;
		windowSpaceLeft -= bytesToSend;
		pulledDown = true;
	}
	return(pulledDown);
}

int UdpReliableChannel::GiveTime()
{
	uchar buf[256];
	uchar *bufPtr;

	UdpMisc::ClockStamp hotClock = UdpMisc::Clock();

	if (hotClock < mNextNeedTime)
		return(UdpMisc::ClockDiff(hotClock, mNextNeedTime));

		// if we are a trickle channel, then don't try sending more until trickleRate has expired.  We are only allowed
		// to send up to trickleBytes at a time every trickleRate milliseconds; however, if we don't send the full trickleBytes
		// in one GiveTime call, then it won't get to try sending more bytes until this timer has expired, even if we had not used
		// up the entire trickleBytes allotment the last time we were in here...this should not cause any significant problems
	if (mConfig.trickleRate > 0)
	{
		int nextAllowedSendTime = mConfig.trickleRate - UdpMisc::ClockDiff(mTrickleLastSend, hotClock);
		if (nextAllowedSendTime > 0)
			return(nextAllowedSendTime);
	}


		// lot a tweaking goes into calculating the optimal resend time.  Set it too large and you can stall the pipe
		// at the beginning of the connection fairly easily
	int optimalResendDelay = (mAveragePingTime * mConfig.resendDelayPercent / 100) + mConfig.resendDelayAdjust;		// percentage of average ping plus a fixed amount
	optimalResendDelay = udpMin(mConfig.resendDelayCap, optimalResendDelay);										// never let the resend delay get over max

		////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// see if any of the physical packets can actually be sent (either resends, or initial sends, whatever
		// if not, calculate when exactly somebody is expected to need sending
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	mMaxxedOutCurrentWindow = false;
	int outstandingNextSendTime = 10 * 60000;
			// if we have something to do

	// this next branch was replaced by JeffP in the latest UdpLibrary drop. Please integrate
	// that. If something catestrophic happens with reliable channels, uncomment this next line to 
	// replace the existing branch
	//if (mReliableOutgoingId < mReliableOutgoingPendingId || mLogicalRoot != NULL || mCoalescePacket != NULL)

	if (mReliableOutgoingPendingId < mReliableOutgoingId || mLogicalRoot != NULL || mCoalescePacket != NULL)
	{
			// first, let's calculate how many bytes we figure is outstanding based on who is still waiting for an ack-packet
		UdpMisc::ClockStamp oldestResendTime = udpMax(hotClock - optimalResendDelay, mLastTimeStampAcknowledged);	// anything older than this, we need to resend

		int useMaxOutstandingBytes = udpMin(mConfig.maxOutstandingBytes, mCongestionWindowSize);
		int outstandingBytes = 0;
		PhysicalPacket *readyQueue[10000];
		PhysicalPacket **readyEnd = readyQueue + (sizeof(readyQueue) / sizeof(PhysicalPacket *));
		PhysicalPacket **readyPtr = readyQueue;

		int windowSpaceLeft = useMaxOutstandingBytes;
		for (udp_int64 i = mReliableOutgoingPendingId; i <= mReliableOutgoingId; i++)
		{
			if (i == mReliableOutgoingId)
			{
					// this packet is not really here yet, we need to pull it down if possible
					// if not possible, we need to break out of the loop as we are done
				if (!PullDown(windowSpaceLeft))
					break;
			}

				// if this packet has not been acked and it is NOT ready to be sent (was recently sent) then we consider it outstanding
				// note: packets needing re-sending probably got lost and are therefore not outstanding
			PhysicalPacket *entry = &mPhysicalPackets[i % mConfig.maxOutstandingPackets];
			if (entry->mDataPtr != NULL)		// acked packets set the dataPtr to NULL
			{
					// if this packet is ready to be sent (ie: needs time now, or some later packet has already been ack'ed)
				windowSpaceLeft -= entry->mDataLen;		// window-space is effectively taken whether we have sent it yet or not
				if (entry->mLastTimeStamp < oldestResendTime)
				{
					if (readyPtr < readyEnd)		// if we have queue space
						*readyPtr++ = entry;
				}
				else
				{
					outstandingBytes += entry->mDataLen;
					outstandingNextSendTime = udpMin(outstandingNextSendTime, optimalResendDelay - UdpMisc::ClockDiff(entry->mLastTimeStamp, hotClock));
				}

					// if we have reached a point in the queue where there are no sent packets
					// and our outstanding bytes plus how much we intend to send is greater than the window we have
					// then we can quit step-2, since there is nothing else to be gained by continuing.
				if (entry->mFirstTimeStamp == 0 && (windowSpaceLeft <= 0))
					break;
			}
		}


			// second, send ready entries until the max outstanding is reached
		int trickleSent = 0;
		PhysicalPacket **readyWalk = readyQueue;
		PhysicalPacket *pendingReliableBasePtr = &mPhysicalPackets[mReliableOutgoingPendingId % mConfig.maxOutstandingPackets];
		while (readyWalk < readyPtr && outstandingBytes < useMaxOutstandingBytes)
		{
				// prepare packet and send it
			PhysicalPacket *entry = *readyWalk++;

				// prepare reliable header and send it with data
			const uchar *parentBase = (const uchar *)entry->mParent->GetDataPtr();

			bool fragment = false;
			if (entry->mDataPtr != parentBase || entry->mDataLen != entry->mParent->GetDataLen())
				fragment = true;

				// we can calculate what our reliableId should be based on our position in the array
				// need to handle the case where we wrap around the end of the array
			udp_int64 reliableId;
			if (entry >= pendingReliableBasePtr)
			{
				reliableId = mReliableOutgoingPendingId + (entry - pendingReliableBasePtr);
			}
			else
			{
				reliableId = mReliableOutgoingPendingId + (&mPhysicalPackets[mConfig.maxOutstandingPackets] - pendingReliableBasePtr) + (entry - &mPhysicalPackets[0]);
			}

				// prep the actual packet and send it
			bufPtr = buf;
			*bufPtr++ = 0;
			*bufPtr++ = (uchar)(((fragment) ? UdpConnection::cUdpPacketFragment1 : UdpConnection::cUdpPacketReliable1) + mChannelNumber);	// mark us as a fragment if we are one
			bufPtr += UdpMisc::PutValue16(bufPtr, (ushort)(reliableId & 0xffff));
			if (fragment && entry->mDataPtr == parentBase)
				bufPtr += UdpMisc::PutValue32(bufPtr, entry->mParent->GetDataLen());		// first fragment has a total-length byte after the reliable header
			mUdpConnection->BufferedSend(buf, bufPtr - buf, entry->mDataPtr, entry->mDataLen, false);

				// update state information
			if (entry->mFirstTimeStamp == 0)
			{
				entry->mFirstTimeStamp = hotClock;
			}
			else
			{
					// trying to send the packet again, let's see how long we have been trying to send this packet.  If we
					// have an unacknowledged timeout set and it is older than that, then terminate the connection.
					// note: we only check for the oldest unacknowledged age against the timeout at the point in time
					// that we are considering sending the packet again.  This can technically cause it to wait slightly
					// longer than the specified timeout setting before disconnecting the connection, but should be
					// close enough for all practical purposes and allows for more efficient processing of this setting internally.
				if (mUdpConnection->mUdpManager->mParams.oldestUnacknowledgedTimeout > 0)
				{
					int age = UdpMisc::ClockDiff(entry->mFirstTimeStamp, hotClock);
					if (age > mUdpConnection->mUdpManager->mParams.oldestUnacknowledgedTimeout)
					{
						mUdpConnection->InternalDisconnect(0, UdpConnection::cDisconnectReasonUnacknowledgedTimeout);
						return(0);
					}
				}

					// were we resent because of a later ack came in? or because we timed out?
				if (entry->mLastTimeStamp < mLastTimeStampAcknowledged)
				{
						// we are resending this packet due to an accelleration (receiving a later packet ack)
						// so recalc slow start threshhold and congestion window size as per Reno fast-recovery algorithm
					mCongestionWindowSize = mCongestionWindowSize * 2 / 3;
					mCongestionWindowSize = udpMax(mCongestionWindowMinimum, mCongestionWindowSize);	// never let congestion window get smaller than a single packet
					mCongestionSlowStartThreshhold = mCongestionWindowSize;
					useMaxOutstandingBytes = udpMin(mConfig.maxOutstandingBytes, mCongestionWindowSize);

					mStatResentPacketsAccelerated++;
					mUdpConnection->mConnectionStats.resentPacketsAccelerated++;
					mUdpConnection->mUdpManager->mManagerStats.resentPacketsAccelerated++;
				}
				else
				{
						// we are resending this packet due to a timeout, so we are seriously overloading things probably
						// so recalc slow start threshhold and congestion window size as per Tahoe algorithm
					mCongestionSlowStartThreshhold = udpMax(mMaxDataBytes * 2, outstandingBytes / 2);
					mCongestionWindowSize = mCongestionWindowStart;
					useMaxOutstandingBytes = udpMin(mConfig.maxOutstandingBytes, mCongestionWindowSize);

						// because a resend has occurred due to a timeout, slow down the resend times slightly
						// when things start flowing again, it will fix itself up quickly anyways
					mAveragePingTime += 100;

						// When a connection goes temporarily dead, everything that is in the current
						// window will end up getting timedout.  If the window were large, this could result in the
						// mAveragePingTime growing quite large and creating very long stalls in the pipe once it does
						// start moving again.  To prevent this, we cap mAveragePingTime when these events occur to prevent
						// long stalls when the pipe finally reopens.
					mAveragePingTime = udpMin(mConfig.resendDelayCap, mAveragePingTime);

					mStatResentPacketsTimedOut++;
					mUdpConnection->mConnectionStats.resentPacketsTimedOut++;
					mUdpConnection->mUdpManager->mManagerStats.resentPacketsTimedOut++;
				}
			}

			entry->mLastTimeStamp = hotClock;

			outstandingNextSendTime = udpMin(outstandingNextSendTime, optimalResendDelay);		// this packet is now outstanding, so factor it into the outstandingNextSendTime calculation
			outstandingBytes += entry->mDataLen;
			mTrickleLastSend = hotClock;
			trickleSent += entry->mDataLen;

			if (mConfig.trickleSize != 0 && trickleSent >= mConfig.trickleSize)
				break;
		}

		if (outstandingBytes >= useMaxOutstandingBytes)
			mMaxxedOutCurrentWindow = true;
	}
	else
	{
			// we have nothing in the pipe at all, reset the congestion window (this means everything has been acked, so the pipe is totally empty
			// we need to reset the window back to prevent a sudden flood next time a large chunk of data is sent.
			// we also need to avoid having the slowly sent reliable packets constantly increase the window size (since none will ever get lost)
			// such that when it does come time to send a big chunk of data, it thinks the window-size is enormous.
			// resetting the window back to small will only have an effect if a large chunk of data is then sent, at which time it will quickly
			// ramp up with the slow-start method.
			// we will reset the slow-start threshhold to maximum level that the congestion window has ever been allowed to grow.  This effectively
			// allows the threshhold to increase after getting smaller, something it otherwise has not been able to do.
		mCongestionWindowSize = mCongestionWindowStart;
		mCongestionSlowStartThreshhold = mCongestionWindowLargest;
	}

	int nextAllowedSendTime = mConfig.trickleRate - UdpMisc::ClockDiff(mTrickleLastSend, hotClock);
	nextAllowedSendTime = udpMax(0, udpMax(nextAllowedSendTime, outstandingNextSendTime));
	mNextNeedTime = hotClock + nextAllowedSendTime;
	return(nextAllowedSendTime);
}

void UdpReliableChannel::GetChannelStatus(UdpConnection::ChannelStatus *channelStatus) const
{
	int coalesceBytes = 0;
	if (mCoalescePacket != NULL)
		coalesceBytes = mCoalesceEndPtr - mCoalesceStartPtr;

	channelStatus->totalPendingBytes = mLogicalBytesQueued + mReliableOutgoingBytes + coalesceBytes;
	channelStatus->queuedPackets = mLogicalPacketsQueued;
	channelStatus->queuedBytes = mLogicalBytesQueued;
	channelStatus->incomingLargeTotal = mBigDataTargetLen;
	channelStatus->incomingLargeSoFar = mBigDataLen;
	channelStatus->duplicatePacketsReceived = mStatDuplicatePacketsReceived;
	channelStatus->resentPacketsAccelerated = mStatResentPacketsAccelerated;
	channelStatus->resentPacketsTimedOut = mStatResentPacketsTimedOut;
	channelStatus->congestionSlowStartThreshhold = mCongestionSlowStartThreshhold;
	channelStatus->congestionWindowSize = mCongestionWindowSize;
	channelStatus->ackAveragePing = mAveragePingTime;
	channelStatus->oldestUnacknowledgedAge = 0;

	if (mReliableOutgoingPendingId < mReliableOutgoingId)
	{
			// oldest pending packet will be definition be the oldestUnacknowledged, since it is impossible
			// for any packet after it to have possibly been sent before it was sent for its first time
			// since queue is effectively in first-send order.  It is also impossible for this packet to have
			// been acknowledged, since the pending id advances the moment the oldest is acknowledged, meaning
			// that the pendingId is always pointing to something that has either been sent (or not sent at all)
		PhysicalPacket *entry = &mPhysicalPackets[mReliableOutgoingPendingId % mConfig.maxOutstandingPackets];
		if (entry->mFirstTimeStamp != 0)		// if has been sent (we know it hasn't been acknowledged or we couldn't possibly be pointing at it as pending)
		{
			channelStatus->oldestUnacknowledgedAge = UdpMisc::ClockElapsed(entry->mFirstTimeStamp);
		}
	}
}

void UdpReliableChannel::ReliablePacket(const uchar *data, int dataLen)
{
	uchar buf[256];
	uchar *bufPtr;

	if (dataLen <= UdpConnection::cUdpPacketReliableSize)
	{
		mUdpConnection->CallbackCorruptPacket(data, dataLen, cUdpCorruptionReliablePacketTooShort);
		return;
	}

	int packetType = data[1];
	ushort reliableStamp = UdpMisc::GetValue16(data + 2);
	udp_int64 reliableId = GetReliableIncomingId(reliableStamp);

	if (reliableId >= mReliableIncomingId + mConfig.maxInstandingPackets)
		return;		// if we do not have buffer space to hold onto this packet, then we simply must pretend like it was lost

	if (reliableId >= mReliableIncomingId)
	{
		ReliablePacketMode mode = (ReliablePacketMode)((packetType - UdpConnection::cUdpPacketReliable1) / UdpManager::cReliableChannelCount);

			// is this the packet we are waiting for
		if (mReliableIncomingId == reliableId)
		{
				// if so, process it immediately
			ProcessPacket(mode, data + UdpConnection::cUdpPacketReliableSize, dataLen - UdpConnection::cUdpPacketReliableSize);
			mReliableIncomingId++;

				// process other packets that have arrived
			while (mReliableIncoming[mReliableIncomingId % mConfig.maxInstandingPackets].mPacket != NULL)
			{
				int spot = (int)(mReliableIncomingId % mConfig.maxInstandingPackets);
				if (mReliableIncoming[spot].mMode != cReliablePacketModeDelivered)
				{
					ProcessPacket(mReliableIncoming[spot].mMode, (uchar *)mReliableIncoming[spot].mPacket->GetDataPtr(), mReliableIncoming[spot].mPacket->GetDataLen());
				}
				
				mReliableIncoming[spot].mPacket->Release();
				mReliableIncoming[spot].mPacket = NULL;
				mReliableIncomingId++;
			}
		}
		else
		{
				// not the one we need next, but it is later than the one we need , so store it in our buffer until it's turn comes up
			int spot = (int)(reliableId % mConfig.maxInstandingPackets);
			if (mReliableIncoming[spot].mPacket == NULL)		// only make the copy of it if we don't already have it in our buffer (in cases where it was sent twice, there would be no harm in the copy again since it must be the same packet, it's just inefficient)
			{
				mReliableIncoming[spot].mMode = mode;
				mReliableIncoming[spot].mPacket = mUdpConnection->mUdpManager->CreatePacket(data + UdpConnection::cUdpPacketReliableSize, dataLen - UdpConnection::cUdpPacketReliableSize);

					// on out of order deliver, we need to keep a copy of it as if we were doing ordered-delivery in order to prevent duplicates
					// we will mark the packet in the queue as already delivered to prevent it from getting delivered a second time when the stalled packet
					// arrives and unwinds the queue
				if (mode == cReliablePacketModeReliable && mConfig.outOfOrder)
				{
					ProcessPacket(cReliablePacketModeReliable, (uchar *)mReliableIncoming[spot].mPacket->GetDataPtr(), mReliableIncoming[spot].mPacket->GetDataLen());
					mReliableIncoming[spot].mMode = cReliablePacketModeDelivered;
				}
			}
			else
			{
				mStatDuplicatePacketsReceived++;
				mUdpConnection->mConnectionStats.duplicatePacketsReceived++;
				mUdpConnection->mUdpManager->mManagerStats.duplicatePacketsReceived++;
			}
		}
	}
	else
	{
		mStatDuplicatePacketsReceived++;
		mUdpConnection->mConnectionStats.duplicatePacketsReceived++;
		mUdpConnection->mUdpManager->mManagerStats.duplicatePacketsReceived++;
	}

	bufPtr = buf;
	*bufPtr++ = 0;
	if (mReliableIncomingId > reliableId)
	{
			// ack everything up to the current head of our chain (minus one since the stamp represents the next one we want to get)
		*bufPtr++ = (uchar)(UdpConnection::cUdpPacketAckAll1 + mChannelNumber);
		bufPtr += UdpMisc::PutValue16(bufPtr, (ushort)((mReliableIncomingId - 1) & 0xffff));
	}
	else
	{
			// a simple ack for us only
		*bufPtr++ = (uchar)(UdpConnection::cUdpPacketAck1 + mChannelNumber);
		bufPtr += UdpMisc::PutValue16(bufPtr, (ushort)(reliableId & 0xffff));
		mBufferedAckPtr = NULL;	// not allowed to replace an old one with a selective-ack
	}

	if (mBufferedAckPtr != NULL && mConfig.ackDeduping)
	{
		memcpy(mBufferedAckPtr, buf, bufPtr - buf);
	}
	else
	{
		mBufferedAckPtr = mUdpConnection->BufferedSend(buf, bufPtr - buf, NULL, 0, true);	// safe to append on our data, it is stack data
	}
}

void UdpReliableChannel::ProcessPacket(ReliablePacketMode mode, const uchar *data, int dataLen)
{
	assert(dataLen > 0);

		// if we have a big packet under construction already, or we are a fragment and thus need to be constructing one, then append this on the end (will create new if it is the first fragment)
	if (mode == cReliablePacketModeReliable)
	{
			// we are not a fragment, nor was there a fragment in progress, so we are a simple reliable packet, just send it to the app
		mUdpConnection->ProcessCookedPacket(data, dataLen);
	}
	else if (mode == cReliablePacketModeFragment)
	{
			// append onto end of big packet (or create new big packet if not existing already)
		if (mBigDataPtr == NULL)
		{
			mBigDataTargetLen = UdpMisc::GetValue32(data);		// first fragment has a total-length int header on it.
			mBigDataPtr = new uchar[mBigDataTargetLen];
			mBigDataLen = 0;
			data += sizeof(int);
			dataLen -= sizeof(int);
		}

		int safetyMax = udpMin(mBigDataTargetLen - mBigDataLen, dataLen);	// can't happen in theory since they should add up exact, but protect against it if it does
		
		if(safetyMax != dataLen)
		{
			throw UdpLibraryException();	
		}


		memcpy(mBigDataPtr + mBigDataLen, data, safetyMax);
		mBigDataLen += safetyMax;

		if (mBigDataTargetLen == mBigDataLen)
		{
				// send big-packet off to application
			mUdpConnection->ProcessCookedPacket(mBigDataPtr, mBigDataLen);

				// delete big packet, and reset
			delete[] mBigDataPtr;
			mBigDataLen = 0;
			mBigDataTargetLen = 0;
			mBigDataPtr = NULL;
		}
	}
}

void UdpReliableChannel::AckAllPacket(const uchar *data, int /*dataLen*/)
{
	udp_int64 reliableId = GetReliableOutgoingId((ushort)UdpMisc::GetValue16(data + 2));

    if (mReliableOutgoingPendingId > reliableId)
    {
            // if we ackall'ed a packet and everything before the ackall address had already been acked, then we know
            // for certainty that we sent a packet over again that did not need to be sent over again (ie. wasn't lost, just slow)
            // so adjust the mAveragePingTime upward to slow down future resends
        mAveragePingTime += 400;
		mAveragePingTime = udpMin(mConfig.resendDelayCap, mAveragePingTime);
    }

	for (udp_int64 i = mReliableOutgoingPendingId; i <= reliableId; i++)
		Ack(i);
}

void UdpReliableChannel::Ack(udp_int64 reliableId)
{
		// if packet being acknowledged is possibly in our resend queue, then check for it
	if (reliableId >= mReliableOutgoingPendingId && reliableId < mReliableOutgoingId)
	{
		int pos = (int)(reliableId % mConfig.maxOutstandingPackets);
		PhysicalPacket *entry = &mPhysicalPackets[pos];

		if (entry->mDataPtr != NULL)		// if this packet has not been acknowledged yet (sometimes we get back two acks for the same packet)
		{
			mNextNeedTime = 0;		// something got acked, so we actually need to take the time next time it is offered

					// if the last time we gave this reliable channel processing time, it filled up the entire sliding window
					// then go ahead and increase the window-size when incoming acks come in.  However, if the window wasn't full
					// then don't increase the window size.  The problem is, a game application is likely to send reliable data
					// at a relatively slow rate (2k/second for example), never filling the window.  The net result would be that
					// every acknowledged packet would increase the window size, giving the reliable channel the impression that
					// it's window can be very very large, when in fact, it is only not losing packets because the application is pacing
					// itself.  The window could grow enormous, even 200k for a modem.  Then, if the application were to dump a load
					// of data onto us all at once, it would flush it all out at once thinking it had a big window.  By only increasing 
					// the window size when we have high enough volume to fill the window, we ensure this does not happen.  TCP does a similar
					// thing, but what they do is reset the window if there has been a long stall.  We do that too, but because we are a game
					// application that is likely to pace the data at the application level, we have a unique circumstances that need addressing.
			if (mMaxxedOutCurrentWindow)
			{
				if (mCongestionWindowSize < mCongestionSlowStartThreshhold)
					mCongestionWindowSize += mMaxDataBytes;	// slow-start mode
				else
					mCongestionWindowSize += udpMax(1, (mMaxDataBytes * mMaxDataBytes / mCongestionWindowSize));	// congestion mode

				mCongestionWindowLargest = udpMax(mCongestionWindowLargest, mCongestionWindowSize);
			}

			if (entry->mLastTimeStamp == entry->mFirstTimeStamp)
			{


					// if the packet that is being acknowledged was only sent once, then we can safely use
					// the round-trip time as an accurate measure of ping time.  By knowing ping time, we can
					// better (more agressively) schedule resends of lost packets.  We will use a moving average
					// that weights the current packet as 1/4 the average.
				int thisPingTime = UdpMisc::ClockElapsed(entry->mFirstTimeStamp);
				mAveragePingTime = (mAveragePingTime * 3 + thisPingTime) / 4;
			}

				// what this is doing is if we receive an ACK for a packet that was sent at TIME_X
				// we can assume that all packets sent before TIME_X that are not yet acknowledge were lost
				// and we can resend them immediately
                // since we do not know whether this ack is for last packet we sent, we have to assume it is for the first time this packet was sent (if sent multiple times)
				// otherwise, we could resend it, then receive the ack from the first packet, and think our last-ack time is the time of the second outgoing packet
				// which would cause about every packet in the queue to resend, even if they had just been sent
				// in situations where the first packet truely was lost and this is an ACK of the second packet, then the only
				// harm done is that the we may not resend some of the earlier sent packets quite as quickly.  This will only
				// happen in situations where a packet that was truely lost gets acked on it's second attempt...we just
				// won't be using that ack for the purposes of accelerating other resends...since odds are a non-lost packet
				// will accelerate those other resends shortly anyhow, there really is no loss
                // (note: we used to only set this value forward for packets that were never lost (one time sends); however, if this stamp
				// ever got set way high for some reason (in theory it can't happen), then we would get into a situation where it would
				// rapidly resend and possibly never get reset, causing infinite rapid resends, so we now set it every time to the first-stamp)
				// which will be safe, even if the packet were resent.)
			mLastTimeStampAcknowledged = entry->mFirstTimeStamp;


				// this packet we have queued has been acknowledged, so delete it from queue
			mReliableOutgoingBytes -= entry->mDataLen;
			entry->mDataLen = 0;
			entry->mDataPtr = NULL;
			entry->mParent->Release();
			entry->mParent = NULL;

				// advance the pending ptr until it reaches outgoingId or an entry that has yet to acknowledged
			while (mReliableOutgoingPendingId < mReliableOutgoingId)
			{
				if (mPhysicalPackets[mReliableOutgoingPendingId % mConfig.maxOutstandingPackets].mDataPtr != NULL)
					break;
				mReliableOutgoingPendingId++;
			}
		}
		else
		{
				// we got an ack for a packet that has already been acked.  This could be due to an ack-all packet that covered us so statistically
				// we can't do much with this information.
		}
	}

		// we don't need to try rescheduling ourself here, since our connection object reschedules to go immediately whenever any type
		// of packet arrives (including ack packets)
}





UdpReliableChannel::IncomingQueueEntry::IncomingQueueEntry()
{
	mPacket = NULL;
	mMode = UdpReliableChannel::cReliablePacketModeReliable;
}

UdpReliableChannel::IncomingQueueEntry::~IncomingQueueEntry()
{
	if (mPacket != NULL)
		mPacket->Release();
}


UdpReliableChannel::PhysicalPacket::PhysicalPacket()
{
	mParent = NULL;
}

UdpReliableChannel::PhysicalPacket::~PhysicalPacket()
{
	if (mParent != NULL)
		mParent->Release();
}



		/////////////////////////////////////////////////////
		// LogicalPacket implementation
		/////////////////////////////////////////////////////
LogicalPacket::LogicalPacket()
{
	mRefCount = 1;
	mReliableQueueNext = NULL;
}

LogicalPacket::~LogicalPacket()
{
}

void LogicalPacket::AddRef() const
{
	mRefCount++;
}

void LogicalPacket::Release() const
{
	if (--mRefCount == 0)
		delete this;
}

int LogicalPacket::GetRefCount() const
{
	return(mRefCount);
}

bool LogicalPacket::IsInternalPacket() const
{
	return(false);
}

		/////////////////////////////////////////////////////
		// SimpleLogicalPacket implementation
		/////////////////////////////////////////////////////
SimpleLogicalPacket::SimpleLogicalPacket(const void *data, int dataLen)
{
	mDataLen = dataLen;
	mData = new uchar[mDataLen];
	if (data != NULL)
		memcpy(mData, data, mDataLen);
}

SimpleLogicalPacket::~SimpleLogicalPacket()
{
	delete[] mData;
}

void *SimpleLogicalPacket::GetDataPtr()
{
	return(mData);
}

const void *SimpleLogicalPacket::GetDataPtr() const
{
	return(mData);
}

int SimpleLogicalPacket::GetDataLen() const
{
	return(mDataLen);
}

void SimpleLogicalPacket::SetDataLen(int len)
{
	assert(len <= mDataLen);
	mDataLen = len;
}
		/////////////////////////////////////////////////////
		// GroupLogicalPacket implementation
		/////////////////////////////////////////////////////
GroupLogicalPacket::GroupLogicalPacket() : LogicalPacket()
{
	mDataLen = 0;
	mData = NULL;
}

GroupLogicalPacket::~GroupLogicalPacket()
{
	UdpMisc::SmartResize(mData, 0);		// free it
}

void GroupLogicalPacket::AddPacket(const LogicalPacket *packet)
{
	assert(packet != NULL);
	AddPacketInternal(packet->GetDataPtr(), packet->GetDataLen(), packet->IsInternalPacket());
}

void GroupLogicalPacket::AddPacket(const void *data, int dataLen)
{
	assert(data != NULL);
	assert(dataLen >= 0);
	AddPacketInternal(data, dataLen, false);
}

void GroupLogicalPacket::AddPacketInternal(const void *data, int dataLen, bool isInternalPacket)
{
	if (dataLen == 0)
		return;
	mData = (uchar *)UdpMisc::SmartResize(mData, mDataLen + dataLen + 10, 512);		// 7 is the most bytes that could be needed to specify the length of the data to follow, 2 is for internal header-bytes, 1 is for zero-escape if needed (if they need to be added on)
	if (mDataLen == 0)
	{
		mData[0] = 0;
		mData[1] = UdpConnection::cUdpPacketGroup;
		mDataLen = 2;
	}

	uchar *ptr = mData + mDataLen;
	if (!isInternalPacket && *(const uchar *)data == 0)
	{
		ptr += UdpMisc::PutVariableValue(ptr, dataLen + 1);
		*ptr++ = 0;	// packet is not internal and starts with 0, so we need to zero-escape it so it knows it's an application packet
	}
	else
		ptr += UdpMisc::PutVariableValue(ptr, dataLen);

	memcpy(ptr, data, dataLen);
	ptr += dataLen;
	mDataLen = ptr - mData;
}

void *GroupLogicalPacket::GetDataPtr()
{
	return(mData);
}

const void *GroupLogicalPacket::GetDataPtr() const
{
	return(mData);
}

int GroupLogicalPacket::GetDataLen() const
{
	return(mDataLen);
}

void GroupLogicalPacket::SetDataLen(int /*len*/)
{
	assert(0);	// not allowed to set the len of a group logical packet
}

bool GroupLogicalPacket::IsInternalPacket() const
{
	return(true);
}

	///////////////////////////////////////////////////////////////////////////////////////////
	// PooledLogicalPacket implementation
	///////////////////////////////////////////////////////////////////////////////////////////
PooledLogicalPacket::PooledLogicalPacket(UdpManager *manager, int len)
{
	mMaxDataLen = len;
	mData = new uchar[mMaxDataLen];
	mDataLen = 0;

	mUdpManager = manager;
	mAvailableNext = NULL;
	mCreatedNext = NULL;
	mCreatedPrev = NULL;

	mUdpManager->PoolCreated(this);
}

PooledLogicalPacket::~PooledLogicalPacket()
{
	if (mUdpManager != NULL)
	{
		mUdpManager->PoolDestroyed(this);
	}

	delete[] mData;
}

void PooledLogicalPacket::AddRef() const
{
	LogicalPacket::AddRef();
}

void PooledLogicalPacket::Release() const
{
	if (mRefCount == 1 && mUdpManager != NULL)
		mUdpManager->PoolReturn(const_cast<PooledLogicalPacket *>(this));		// if pool wants to keep us, it will inc our ref count, preventing our destruction
																// we cast off our const, as when we are added back to the pool, we can be modified
	LogicalPacket::Release();
}

void *PooledLogicalPacket::GetDataPtr()
{
	return(mData);
}

const void *PooledLogicalPacket::GetDataPtr() const
{
	return(mData);
}

int PooledLogicalPacket::GetDataLen() const
{
	return(mDataLen);
}

void PooledLogicalPacket::SetDataLen(int len)
{
	assert(len <= mMaxDataLen);
	mDataLen = len;
}

void PooledLogicalPacket::SetData(const void *data, int dataLen, const void *data2, int dataLen2)
{
	mDataLen = dataLen + dataLen2;
	if (data != NULL)
		memcpy(mData, data, dataLen);
	if (data2 != NULL)
		memcpy(mData + dataLen, data2, dataLen2);
}



	///////////////////////////////////////////////////////////////////////////////////////////
	// WrappedLogicalPacket implementation
	///////////////////////////////////////////////////////////////////////////////////////////
WrappedLogicalPacket::WrappedLogicalPacket(UdpManager *udpManager)
{
	mPacket = NULL;
	mUdpManager = udpManager;
	mAvailableNext = NULL;
	mCreatedNext = NULL;
	mCreatedPrev = NULL;

	mUdpManager->WrappedCreated(this);
}

WrappedLogicalPacket::~WrappedLogicalPacket()
{
	if (mUdpManager != NULL)
	{
		mUdpManager->WrappedDestroyed(this);
	}

	if (mPacket != NULL)
	{
		mPacket->Release();
	}
}

void WrappedLogicalPacket::AddRef() const
{
	LogicalPacket::AddRef();
}

void WrappedLogicalPacket::Release() const
{
	if (mRefCount == 1 && mUdpManager != NULL)
		mUdpManager->WrappedReturn(const_cast<WrappedLogicalPacket *>(this));	// if pool wants to keep us, it will inc our ref count, preventing our destruction
																				// we cast off our const, as when we are added back to the pool, we can be modified
	LogicalPacket::Release();
}

void WrappedLogicalPacket::SetLogicalPacket(const LogicalPacket *packet)
{
	if (mPacket != NULL)
		mPacket->Release();
	mPacket = packet;
	if (mPacket != NULL)
		mPacket->AddRef();
}

void *WrappedLogicalPacket::GetDataPtr()
{
	return(const_cast<void *>(mPacket->GetDataPtr()));	// didn't have a choice really...
}

const void *WrappedLogicalPacket::GetDataPtr() const
{
	return(mPacket->GetDataPtr());
}

int WrappedLogicalPacket::GetDataLen() const
{
	return(mPacket->GetDataLen());
}

void WrappedLogicalPacket::SetDataLen(int /*len*/)
{
	assert(0);		// this should not be possible
}



	////////////////////////////////////////////////////////////////////////////////////////////////////
	// SimulateQueueEntry functions
	////////////////////////////////////////////////////////////////////////////////////////////////////
UdpManager::SimulateQueueEntry::SimulateQueueEntry(const uchar *data, int dataLen, UdpIpAddress ip, int port)
{
	mData = new uchar[dataLen];
	mDataLen = dataLen;
	memcpy(mData, data, dataLen);
	mIp = ip;
	mPort = port;
	mNext = NULL;
}

UdpManager::SimulateQueueEntry::~SimulateQueueEntry()
{
	delete[] mData;
}



	////////////////////////////////////////////////////////////////////////////////////////////////////
	// UdpMisc functions
	////////////////////////////////////////////////////////////////////////////////////////////////////

UdpMisc::ClockStamp UdpMisc::Clock()
{
#if defined(WIN32)
	static int sGlobalHigh = 0;
	static unsigned sGlobalLow = 0;

	unsigned low = GetTickCount();
	if (low < sGlobalLow)
	{
		sGlobalHigh++;		// not entirely safe, if the once every 47 days we happen to thread-slice right at this spot and some other thread called this, time could get messed for this call...I can live with those odds
	}
	sGlobalLow = low;
	return(((ClockStamp)sGlobalHigh << 32) | sGlobalLow);
#else
		// this implementation has the same sort of threading issues the windows version used to have
		// before I started using thread-local-storage to solve them.  The worst thing that can happen
		// is the time-correction will occur more than once from seperate threads, which would result
		// in time appearing to jump forward, which isn't that big of a deal.
	static ClockStamp sLastStamp = 0;
	static ClockStamp sCurrentCorrection = 0;
	struct timeval tv;
	gettimeofday(&tv, NULL);
	UdpMisc::ClockStamp cs = static_cast<UdpMisc::ClockStamp>(tv.tv_sec) * 1000 + static_cast<UdpMisc::ClockStamp>(tv.tv_usec / 1000);
	cs += sCurrentCorrection;
	if (cs < sLastStamp)
	{
			// clock moved backwards (somebody changed it), don't ever let this happen
			// if clock moves forward, there is no way we can recognize it, code will just
			// have to deal with it.  In the case of the UdpLibrary, it will likely result
			// in a ton of pending packets thinking they have gotten lost and being sent, fairly harmless.
		sCurrentCorrection += (sLastStamp - cs);
		cs = sLastStamp;
	}
	sLastStamp = cs;
	return(cs);
#endif	
}

int UdpMisc::SyncStampShortDeltaTime(ushort stamp1, ushort stamp2)
{
	ushort delta = (ushort)(stamp1 - stamp2);
	if (delta > 0x7fff)
		return((int)(0xffff - delta));
	return((int)delta);
}

int UdpMisc::SyncStampLongDeltaTime(uint stamp1, uint stamp2)
{
	uint delta = stamp1 - stamp2;
	if (delta > 0x7fffffff)
		return((int)(0xffffffff - delta));
	return((int)delta);
}

int UdpMisc::Random(int *seed)
{
	int hi = *seed / 127773;
	int lo = *seed % 127773;
	int t = lo * 16807 - hi * 2836 + 123;
	*seed = (t > 0) ? t : (t + 2147483647);
	return(*seed);
}

int UdpMisc::Crc32(const void *buffer, int bufferLen, int encryptValue)
{
	static unsigned crc32_table[256] = { 
	0x00000000, 0x77073096, 0xEE0E612C, 0x990951BA, 0x076DC419, 0x706AF48F,
	0xE963A535, 0x9E6495A3, 0x0EDB8832, 0x79DCB8A4, 0xE0D5E91E, 0x97D2D988,
	0x09B64C2B, 0x7EB17CBD, 0xE7B82D07, 0x90BF1D91, 0x1DB71064, 0x6AB020F2,
	0xF3B97148, 0x84BE41DE, 0x1ADAD47D, 0x6DDDE4EB, 0xF4D4B551, 0x83D385C7,
	0x136C9856, 0x646BA8C0, 0xFD62F97A, 0x8A65C9EC, 0x14015C4F, 0x63066CD9,
	0xFA0F3D63, 0x8D080DF5, 0x3B6E20C8, 0x4C69105E, 0xD56041E4, 0xA2677172,
	0x3C03E4D1, 0x4B04D447, 0xD20D85FD, 0xA50AB56B, 0x35B5A8FA, 0x42B2986C,
	0xDBBBC9D6, 0xACBCF940, 0x32D86CE3, 0x45DF5C75, 0xDCD60DCF, 0xABD13D59,
	0x26D930AC, 0x51DE003A, 0xC8D75180, 0xBFD06116, 0x21B4F4B5, 0x56B3C423,
	0xCFBA9599, 0xB8BDA50F, 0x2802B89E, 0x5F058808, 0xC60CD9B2, 0xB10BE924,
	0x2F6F7C87, 0x58684C11, 0xC1611DAB, 0xB6662D3D, 0x76DC4190, 0x01DB7106,
	0x98D220BC, 0xEFD5102A, 0x71B18589, 0x06B6B51F, 0x9FBFE4A5, 0xE8B8D433,
	0x7807C9A2, 0x0F00F934, 0x9609A88E, 0xE10E9818, 0x7F6A0DBB, 0x086D3D2D,
	0x91646C97, 0xE6635C01, 0x6B6B51F4, 0x1C6C6162, 0x856530D8, 0xF262004E,
	0x6C0695ED, 0x1B01A57B, 0x8208F4C1, 0xF50FC457, 0x65B0D9C6, 0x12B7E950,
	0x8BBEB8EA, 0xFCB9887C, 0x62DD1DDF, 0x15DA2D49, 0x8CD37CF3, 0xFBD44C65,
	0x4DB26158, 0x3AB551CE, 0xA3BC0074, 0xD4BB30E2, 0x4ADFA541, 0x3DD895D7,
	0xA4D1C46D, 0xD3D6F4FB, 0x4369E96A, 0x346ED9FC, 0xAD678846, 0xDA60B8D0,
	0x44042D73, 0x33031DE5, 0xAA0A4C5F, 0xDD0D7CC9, 0x5005713C, 0x270241AA,
	0xBE0B1010, 0xC90C2086, 0x5768B525, 0x206F85B3, 0xB966D409, 0xCE61E49F,
	0x5EDEF90E, 0x29D9C998, 0xB0D09822, 0xC7D7A8B4, 0x59B33D17, 0x2EB40D81,
	0xB7BD5C3B, 0xC0BA6CAD, 0xEDB88320, 0x9ABFB3B6, 0x03B6E20C, 0x74B1D29A,
	0xEAD54739, 0x9DD277AF, 0x04DB2615, 0x73DC1683, 0xE3630B12, 0x94643B84,
	0x0D6D6A3E, 0x7A6A5AA8, 0xE40ECF0B, 0x9309FF9D, 0x0A00AE27, 0x7D079EB1,
	0xF00F9344, 0x8708A3D2, 0x1E01F268, 0x6906C2FE, 0xF762575D, 0x806567CB,
	0x196C3671, 0x6E6B06E7, 0xFED41B76, 0x89D32BE0, 0x10DA7A5A, 0x67DD4ACC,
	0xF9B9DF6F, 0x8EBEEFF9, 0x17B7BE43, 0x60B08ED5, 0xD6D6A3E8, 0xA1D1937E,
	0x38D8C2C4, 0x4FDFF252, 0xD1BB67F1, 0xA6BC5767, 0x3FB506DD, 0x48B2364B,
	0xD80D2BDA, 0xAF0A1B4C, 0x36034AF6, 0x41047A60, 0xDF60EFC3, 0xA867DF55,
	0x316E8EEF, 0x4669BE79, 0xCB61B38C, 0xBC66831A, 0x256FD2A0, 0x5268E236,
	0xCC0C7795, 0xBB0B4703, 0x220216B9, 0x5505262F, 0xC5BA3BBE, 0xB2BD0B28,
	0x2BB45A92, 0x5CB36A04, 0xC2D7FFA7, 0xB5D0CF31, 0x2CD99E8B, 0x5BDEAE1D,
	0x9B64C2B0, 0xEC63F226, 0x756AA39C, 0x026D930A, 0x9C0906A9, 0xEB0E363F,
	0x72076785, 0x05005713, 0x95BF4A82, 0xE2B87A14, 0x7BB12BAE, 0x0CB61B38,
	0x92D28E9B, 0xE5D5BE0D, 0x7CDCEFB7, 0x0BDBDF21, 0x86D3D2D4, 0xF1D4E242,
	0x68DDB3F8, 0x1FDA836E, 0x81BE16CD, 0xF6B9265B, 0x6FB077E1, 0x18B74777,
	0x88085AE6, 0xFF0F6A70, 0x66063BCA, 0x11010B5C, 0x8F659EFF, 0xF862AE69,
	0x616BFFD3, 0x166CCF45, 0xA00AE278, 0xD70DD2EE, 0x4E048354, 0x3903B3C2,
	0xA7672661, 0xD06016F7, 0x4969474D, 0x3E6E77DB, 0xAED16A4A, 0xD9D65ADC,
	0x40DF0B66, 0x37D83BF0, 0xA9BCAE53, 0xDEBB9EC5, 0x47B2CF7F, 0x30B5FFE9,
	0xBDBDF21C, 0xCABAC28A, 0x53B39330, 0x24B4A3A6, 0xBAD03605, 0xCDD70693,
	0x54DE5729, 0x23D967BF, 0xB3667A2E, 0xC4614AB8, 0x5D681B02, 0x2A6F2B94,
	0xB40BBE37, 0xC30C8EA1, 0x5A05DF1B, 0x2D02EF8D};

	int crc = 0xffffffff;
	crc = ((crc >> 8) & 0x00FFFFFFL) ^ crc32_table[(crc ^ (encryptValue & 0xff)) & 0x000000FFL];
	crc = ((crc >> 8) & 0x00FFFFFFL) ^ crc32_table[(crc ^ ((encryptValue >> 8) & 0xff)) & 0x000000FFL];
	crc = ((crc >> 8) & 0x00FFFFFFL) ^ crc32_table[(crc ^ ((encryptValue >> 16) & 0xff)) & 0x000000FFL];
	crc = ((crc >> 8) & 0x00FFFFFFL) ^ crc32_table[(crc ^ ((encryptValue >> 24) & 0xff)) & 0x000000FFL];

	const uchar *bufPtr = (const uchar *)buffer;
	const uchar *endPtr = (const uchar *)buffer + bufferLen;
	while (bufPtr < endPtr)
	{
		crc = ((crc >> 8) & 0x00FFFFFFL) ^ crc32_table[(crc ^ *bufPtr) & 0x000000FFL];
		bufPtr++;
	}
	crc = ~crc;

	return(crc);
}

void *UdpMisc::SmartResize(void *ptr, int bytes, int round)
{
	enum { cAlignment = sizeof(int) };

		// rounding stuff for speed
	bytes = ((bytes + round - 1) / round) * round;

	if (bytes == 0)
	{
		if (ptr != NULL)
		{
			free((uchar *)ptr - cAlignment);
		}
		return(NULL);
	}

	uchar *ptr2;
	if (ptr == NULL)
	{
		ptr2 = (uchar *)malloc(bytes + cAlignment);
		if (ptr2 == NULL)
			return(NULL);
		*(int *)ptr2 = bytes;
		return(ptr2 + cAlignment);
	}

	int oldBytes = *((int *)((uchar *)ptr - cAlignment));
	if (bytes == oldBytes)
		return(ptr);

	ptr2 = (uchar *)realloc((uchar *)ptr - cAlignment, bytes + cAlignment);
	if (ptr2 == NULL)
		return(NULL);

	*(int *)ptr2 = bytes;
	return(ptr2 + cAlignment);
}

uint UdpMisc::PutVariableValue(void *buffer, uint value)
{
	uchar *bufptr = (uchar *)buffer;
	uint store = (uint)value;
	if (store < 254)
	{
		*bufptr = (uchar)store;
		return(1);
	}
	else if (store < 0xffff)
	{
		*bufptr = 0xff;
		*(bufptr + 1) = (uchar)(store >> 8);
		*(bufptr + 2) = (uchar)(store & 0xff);
		return(3);
	}
	else
	{
		*bufptr = 0xff;
		*(bufptr + 1) = 0xff;
		*(bufptr + 2) = 0xff;
		*(bufptr + 3) = (uchar)(store >> 24);
		*(bufptr + 4) = (uchar)((store >> 16) & 0xff);
		*(bufptr + 5) = (uchar)((store >> 8) & 0xff);
		*(bufptr + 6) = (uchar)(store & 0xff);
		return(7);
	}
}

uint UdpMisc::GetVariableValue(const void *buffer, uint *value)
{
	const uchar *bufptr = (const uchar *)buffer;
	if (*bufptr == 0xff)
	{
		if (*(bufptr + 1) == 0xff && *(bufptr + 2) == 0xff)
		{
			*value = (uint)((*(bufptr + 3) << 24) | (*(bufptr + 4) << 16) | (*(bufptr + 5) << 8) | *(bufptr + 6));
			return(7);
		}

		*value = (uint)((*(bufptr + 1) << 8) | *(bufptr + 2));
		return(3);
	}

	*value = (uint)*bufptr;
	return(1);
}

LogicalPacket *UdpMisc::CreateQuickLogicalPacket(const void *data, int dataLen, const void *data2, int dataLen2)
{
	enum { cQuickFactor = 128 };
	int totalDataLen = dataLen + dataLen2;
	int q = (totalDataLen - 1) / cQuickFactor;
	LogicalPacket *tlp;
	switch(q)
	{
		case 0:
			tlp = new FixedLogicalPacket<cQuickFactor>(NULL, totalDataLen);
			break;
		case 1:
			tlp = new FixedLogicalPacket<cQuickFactor * 2>(NULL, totalDataLen);
			break;
		case 2:
		case 3:
			tlp = new FixedLogicalPacket<cQuickFactor * 4>(NULL, totalDataLen);
			break;
		case 4:
		case 5:
		case 6:
		case 7:
			tlp = new FixedLogicalPacket<cQuickFactor * 8>(NULL, totalDataLen);
			break;
		default:
			tlp = new SimpleLogicalPacket(NULL, totalDataLen);
			break;
	}

	uchar *dest = (uchar *)tlp->GetDataPtr();
	if (data != NULL)
		memcpy(dest, data, dataLen);
	if (data2 != NULL)
		memcpy(dest + dataLen, data2, dataLen2);
	return(tlp);
}

UdpIpAddress UdpMisc::GetHostByName(const char *hostName)
{
	InitializeOperatingSystem();

	unsigned long address = inet_addr(hostName);
	if (address == INADDR_NONE)
	{
		struct hostent * lphp;
		lphp = gethostbyname(hostName);
		if (lphp == NULL)
		{
			address = 0;
		}
		else
		{
			address = ((struct in_addr *)(lphp->h_addr))->s_addr;
		}
	}

	TerminateOperatingSystem();
	return(UdpIpAddress(address));
}

void UdpMisc::Sleep(int milliseconds)
{
#if defined(WIN32)
	::Sleep((DWORD)milliseconds);
#else
	struct timeval tv;
	tv.tv_sec = milliseconds / 1000;
	tv.tv_usec = (milliseconds % 1000) * 1000;
	select(0, 0, 0, 0, &tv);
#endif
}

UdpLibraryException::UdpLibraryException()
{
}

UdpLibraryException::~UdpLibraryException()
{
}


