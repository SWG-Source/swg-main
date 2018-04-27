#ifndef UDPLIBRARY_HPP
#define UDPLIBRARY_HPP

#include <stdio.h>
#include "UdpHandler.hpp"
#include "priority.hpp"
#include "hashtable.hpp"

#if defined(WIN32)
	typedef unsigned int SOCKET;	// avoids us having to include winsock.h just for this
	typedef __int64 udp_int64;
#else
	typedef int SOCKET;
	typedef long long udp_int64;
#endif

class UdpReliableChannel;
class SimpleLogicalPacket;
class GroupLogicalPacket;

enum UdpChannel { cUdpChannelUnreliable					// unreliable/unordered/buffered
				, cUdpChannelUnreliableUnbuffered		// unreliable/unordered/unbuffered
				, cUdpChannelOrdered					// unreliable/ordered/buffered
				, cUdpChannelOrderedUnbuffered			// unreliable/ordered/unbuffered
				, cUdpChannelReliable1					// reliable (as per channel config)
				, cUdpChannelReliable2					// reliable (as per channel config)
				, cUdpChannelReliable3					// reliable (as per channel config)
				, cUdpChannelReliable4					// reliable (as per channel config)
				, cUdpChannelCount			// count of number of channels
				};

struct UdpManagerStatistics
{
	udp_int64 bytesSent;
	udp_int64 packetsSent;
	udp_int64 bytesReceived;
	udp_int64 packetsReceived;
	udp_int64 connectionRequests;
	udp_int64 crcRejectedPackets;
	udp_int64 orderRejectedPackets;
	udp_int64 duplicatePacketsReceived;
	udp_int64 resentPacketsAccelerated;		// number of times we have resent a packet due to receiving a later packet in the series
	udp_int64 resentPacketsTimedOut;		// number of times we have resent a packet due to the ack-timeout expiring
    udp_int64 priorityQueueProcessed;		// cumulative number of times a priority-queue entry has received processing time
    udp_int64 priorityQueuePossible;		// cumalative number of priority-queue entries that could have received processing time
    udp_int64 applicationPacketsSent;
    udp_int64 applicationPacketsReceived;
    udp_int64 iterations;					// number of times GiveTime has been called
	udp_int64 corruptPacketErrors;			// number of misformed/corrupt packets
	udp_int64 socketOverflowErrors;			// number of times the socket buffer was full when a send was attempted.
	int poolCreated;		// number of packets created in the pool
	int poolAvailable;		// number of packets available in the pool
	int elapsedTime;		// how long these statistics have been gathered (in milliseconds), useful for figuring out averages
};

struct UdpConnectionStatistics
{
		/////////////////////////////////////////////////////////////////////////
		// these statistics are valid even if clock-sync is not used
		// these statistics are never reset and should not be as the negotiated
		// packetloss stats would get messed up if they were
		// as such, use UdpConnection::ConnectionAge to determine how long they have been accumulating
		/////////////////////////////////////////////////////////////////////////
	udp_int64 totalBytesSent;
	udp_int64 totalBytesReceived;
	udp_int64 totalPacketsSent;			// total packets we have sent
	udp_int64 totalPacketsReceived;		// total packets we have received
	udp_int64 crcRejectedPackets;		// total packets on our connection that have been rejected due to a crc error
	udp_int64 orderRejectedPackets;		// total packets on our connection that have been rejected due to an order error (only applicable for ordered channel)
	udp_int64 duplicatePacketsReceived; // total reliable packets that we received where we had already received it before and threw it away
	udp_int64 resentPacketsAccelerated;	// number of times we have resent a packet due to receiving a later packet in the series
	udp_int64 resentPacketsTimedOut;	// number of times we have resent a packet due to the ack-timeout expiring
    udp_int64 applicationPacketsSent;
    udp_int64 applicationPacketsReceived;
    udp_int64 iterations;				// number of times this connection has been given processing time
	udp_int64 corruptPacketErrors;		// number of misformed/corrupt packets

		/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// these statistics are only valid if clock-sync'ing is enabled (highly recommended) (will be valid on both client and server side)
		// these statistics are reset by PingStatReset and are negotiated periodically by the clock-sync stuff (Params::clockSyncDelay)
		/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	int masterPingAge;		// only valid (and applicable) on client side
	int masterPingTime;
	int averagePingTime;
	int lowPingTime;
	int highPingTime;
	int lastPingTime;
    int reliableAveragePing;    // the average time (over last 3 acks) for a reliable packet to get acked (when packet is not lost)
	udp_int64 syncOurSent;		// total packets we have sent at time they reported their numbers
	udp_int64 syncOurReceived;	// total packets we have received at time they reported their numbers
	udp_int64 syncTheirSent;		// total packets they have sent
	udp_int64 syncTheirReceived;	// total packets they have received
	float percentSentSuccess;
	float percentReceivedSuccess;
};

class UdpIpAddress
{
	public:
		UdpIpAddress(unsigned int ip = 0);
		unsigned int GetAddress() const { return(mIp); }
		char *GetAddress(char *buffer) const;
		bool operator==(const UdpIpAddress& e) const { return(mIp == e.mIp); }
	protected:
		unsigned int mIp;
};

class UdpMisc
{
		////////////////////////////////////////////////////////////////////////////////////////////
		// This is a group of miscellaneous function used as part of the implementation
		// The application is free to use these helper functions as well if finds them useful.
		// they are stuck into this class so as to avoid conflicts with the application
		////////////////////////////////////////////////////////////////////////////////////////////
	public:


			// note: on these clock functions, ClockElapsed and ClockDiff are designed to provide a time difference that will safely not overflow an 'int'.  
			// overflowing can occur in situations where the initial stamp is 0.  Since a ClockStamp is a 64-bit number, we also avoid promoting
			// other application values involved in the calculation to the 64-bit level by using these helper-functions.  If you don't mind doing everything
			// in 64-bit values, then feel free to do simple math on the clock-stamps instead of using the functions.
		typedef udp_int64 ClockStamp;
		static ClockStamp Clock();									// returns a timestamp (most likely in milliseconds)
		static int ClockElapsed(ClockStamp stamp);					// returns a elapsed time since stamp in milliseconds (if elapsed is over 23 days, it returns 23 days)
		static int ClockDiff(ClockStamp start, ClockStamp stop);	// returns a time difference in milliseconds (if difference is over 23 days, it returns 23 days)

		static int Crc32(const void *buffer, int bufferLen, int encryptValue = 0);				// calculate a 32-bit crc for a buffer (encrypt value simple scrambles the crc at the beginning so the same packet doesn't produce the same crc on different connections)
		static int Random(int *seed);								// random number generator
		static void Sleep(int milliseconds);

		static ushort LocalSyncStampShort();						// gets a local-clock based sync-stamp. (only good for timings up to 32 seconds)
		static uint LocalSyncStampLong();							// gets a local-clock based sync-stamp. (good for timings up to 23 days)

				// returns the time difference between two sync-stamps that are based on the same clock
				// for example, two LocalSyncStampShort stamps can be compared.  Only differences up to
				// 32 seconds can be timed.  There is also a UdpConnect::ServerSyncStampShort function that returns
				// you a sync-stamp that you can compare with ServerSyncStampShort values generated on other 
				// machines that are synchronized against the same server.  This ServerSyncStampShort function and
				// this delta time function serve as the basis for calculating one-way travel times for packets.
		static int SyncStampShortDeltaTime(ushort stamp1, ushort stamp2);
		static int SyncStampLongDeltaTime(uint stamp1, uint stamp2);	// same as Short version only no limit

			// used to alloc/resize/free an allocation previously created with this function
			// rounding causes that it pre-allocates additional space up to the rounded buffer size
			// this allows the function to be called over and over again as tiny members are added, yet
			// only do an actual realloc periodically.  A 4-byte header is invisibly prepended on the
			// allocated block such that it can keep track of the actual size of the block.  The built-in
			// memory manager does a little bit of this, but if you know you have an allocation that is likely
			// to grow quite a bit, you can set the round'ing size up to a fairly large number and avoid
			// unnecessary reallocs at the cost of a little potentially wasted space
			// initial allocations are done by passing in ptr==NULL, freeing is done by passing in bytes==0
		static void *SmartResize(void *ptr, int bytes, int round = 1);

			// the following two functions store values in the buffer as a variable length (B1, 0xffB2B1, 0xffffffB4B3B2B1)
			// such that values under 254 take one byte, values under 65535 take three bytes, and larger values take seven bytes
		static uint PutVariableValue(void *buffer, uint value);			// returns the number of bytes it took to store the value in the buffer
		static uint GetVariableValue(const void *buffer, uint *value);	// returns the number of bytes it took to get the value from the buffer

			// these functions are used to aid in portability and serve to ensure that the packet-headers are interpretted in the same
			// manner on all platforms
		static int PutValue64(void *buffer, udp_int64 value);	// puts a 64-bit value into the buffer in big-endian format, returns number of bytes used(8)
		static int PutValue32(void *buffer, uint value);		// puts a 32-bit value into the buffer in big-endian format, returns number of bytes used(4)
		static int PutValue24(void *buffer, uint value);		// puts a 24-bit value into the buffer in big-endian format, returns number of bytes used(4)
		static int PutValue16(void *buffer, ushort value);		// puts a 16-bit value into the buffer in big-endian format, returns number of bytes used(2)

		static udp_int64 GetValue64(const void *buffer);		// gets a 64-bit value from the buffer in big-endian format
		static uint GetValue32(const void *buffer);				// gets a 32-bit value from the buffer in big-endian format
		static uint GetValue24(const void *buffer);				// gets a 24-bit value from the buffer in big-endian format
		static ushort GetValue16(const void *buffer);			// gets a 16-bit value from the buffer in big-endian format

		static LogicalPacket *CreateQuickLogicalPacket(const void *data, int dataLen, const void *data2 = NULL, int dataLen2 = 0);

			// looks up the specified name and translates it to an IP address
			// this is a blocking call that can at times take a significant amount of time, but will generally be fast (less than 300ms)
		static UdpIpAddress GetHostByName(const char *hostName);
};


	////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The purpose of the LogicalPacket class is to provide means whereby multiple connections can share
	// a queued packet to save having each connection make its own copy.  It is highly recommended that
	// logical packets be used for optimal performance when sending reliable data as well, since internally
	// it will just end up creating one for you anyhow (LogicalPackets are used by the reliable layer to
	// hold onto the data until it is acknowledged)
	//
	// Logical packets passed in are never modified by the udp library.
	// After calling Send, application should immediately Release the logical packet if they don't need it for
	// something else (like sending to another connection).  The udp library will addref it if it decided it
	// wants to keep it around past the Send call (for reliable data, it will always hang onto it, for unreliable
	// data, it will only hang onto it if it gets promoted to reliable due to size.)
	//
	// Application is encouraged to derive their own application-specific packet classes from the LogicalPacket
	// The object is required to be able to provide a pointer to the raw packet data that will remain valid
	// for as long as the LogicalPacket object exists.
	//
	// for example:
	//   class PlayerLoginPacket : public LogicalPacket
	//   {
	//		public:
	//  		PlayerLoginPacket(char *userName, char *password) { mData.packetType = cPacketTypePlayerLogin; strcpy(mData.userName, userName); strcpy(mData.password, password); }
	//   		virtual const void *GetDataPtr() const { return(&mData); }
	//   		virtual int GetDataLen() const { return(sizeof(mData)); }
	//   	protected:
	//   		virtual ~PlayerLoginPacket() {};
	//   		struct
	//   		{
	//   			uchar packetType;
	//   			char userName[32];
	//   			char password[32];
	//   		} mData;
	//   };
	////////////////////////////////////////////////////////////////////////////////////////////////////////////
class LogicalPacket
{
	public:
		LogicalPacket();
		virtual void AddRef() const;
		virtual void Release() const;
		virtual int GetRefCount() const;

		virtual void *GetDataPtr() = 0;
		virtual const void *GetDataPtr() const = 0;
		virtual int GetDataLen() const = 0;
		virtual void SetDataLen(int len) = 0;

			// returns true if this logical packet is an internal packet
			// by default this returns false, and applications should not override this function to do
			// otherwise.  Basically, if this returns true, it tells the udp library that the packet has
			// an internal-packet header (starts with a zero byte) on it that should not be escaped when sent.
			// The packet will ultimately be processed by the internal udp library code on the other side.
			// The purpose of this is to support features such as GroupLogicalPacket, such that the application
			// can prep grouped packets and then send them via traditional means (it's how the udp library
			// knows that the packet is a group packet instead of just a application-packet that happens to start with 0)
		virtual bool IsInternalPacket() const;
	protected:
		virtual ~LogicalPacket();			// protected since the class should only be deleted by Releasing it

	protected:
		mutable int mRefCount;

	protected:
		friend class UdpReliableChannel;
		mutable const LogicalPacket *mReliableQueueNext;	// owned/managed by the reliable channel object as an optimizations, do not touch
											// NULL = unclaimed, point-to-self = claimed, but end of list
};

class SimpleLogicalPacket : public LogicalPacket
{
		// this class is a simply dynamically allocated packet.  Applications are welcome to use it, but
		// it was originally created to allow the internal code to handle reliable data that was sent
		// via the Send(char *, int) api call.
	public:
		SimpleLogicalPacket(const void *data, int dataLen);		// data can be NULL if you want to populate it after it is allocated (get the pointer and write to it)
		virtual void *GetDataPtr();
		virtual const void *GetDataPtr() const;
		virtual int GetDataLen() const;
		virtual void SetDataLen(int len);
	protected:
		virtual ~SimpleLogicalPacket();
		uchar *mData;
		int mDataLen;
};

class WrappedLogicalPacket : public LogicalPacket
{
		// this class is used internally by the library such that it can get a free and clear mNext pointer
		// in cases where a logical packet is being shared by multiple connections (such that the packet
		// can reside in the linked-list for the reliable channel queue)
	public:
		WrappedLogicalPacket(UdpManager *manager);	// lives in a pool

		virtual void AddRef() const;
		virtual void Release() const;
		virtual void *GetDataPtr();
		virtual const void *GetDataPtr() const;
		virtual int GetDataLen() const;
		virtual void SetDataLen(int len);
	protected:
		virtual ~WrappedLogicalPacket();
		const LogicalPacket *mPacket;

	protected:
		friend class UdpManager;
		void SetLogicalPacket(const LogicalPacket *packet);
		UdpManager *mUdpManager;
		WrappedLogicalPacket *mAvailableNext;

		WrappedLogicalPacket *mCreatedNext;
		WrappedLogicalPacket *mCreatedPrev;
};

template<int t_quickSize> class FixedLogicalPacket : public LogicalPacket
{
		// this class is similar to the SimpleLogicalPacket in that it is designed to just store raw
		// data of various sizes.  The difference here is that this class may be created at compile
		// time to be any size desired (via template parameters), and is more efficient than the
		// SimpleLogicalPacket when used (it avoid the internal alloc as the data is inline).  The
		// UdpMisc::CreateQuickLogicalPacket function automatically attempts to use this for small
		// packets and will fall back and use SimpleLogicalPackets for larger packets.
	public:
		FixedLogicalPacket(const void *data, int dataLen);
		virtual void *GetDataPtr();
		virtual const void *GetDataPtr() const;
		virtual int GetDataLen() const;
		virtual void SetDataLen(int len);
	protected:
		uchar mData[t_quickSize];
		int mDataLen;
};

template<typename T> class StructLogicalPacket : public LogicalPacket
{
		// this class is designed to turn any raw struct into a logical packet.  The application
		// can then access the struct through thisLogicalPacket->mStruct.structMember.  The template
		// will take care of all the wrappings necessary to turn the struct into a fully functional
		// logical packet that can be sent to a connection.  As a word of caution, sending struct's
		// across the wire is not considered very portable.  There are byte-ordering and structure-packing
		// issues that are platform dependent.  At a minimum, you will probably want to make sure that
		// struct's you use in this way are packed to 1-byte boundaries, such that you are not sending
		// wasteful information.  Do not attempt to send the member-content of classes (particularly classes 
		// with virtual functions) via this method as they may contain hidden data-members (such as pointers
		// to vtables).
	public:
		StructLogicalPacket(T *initData = NULL);
		virtual void *GetDataPtr();
		virtual const void *GetDataPtr() const;
		virtual int GetDataLen() const;
		virtual void SetDataLen(int len);
	protected:
		T mStruct;
};

class GroupLogicalPacket : public LogicalPacket
{
		// this class is a helper object intended for use by the application (it is not used internally)
		// It allows you to add multiple application-packets and them send them all as an autonomous unit.
		// The receiving end will automatically split the packet up and send them to the application callback function
		// as if the individual packets had all been sent one at at time.
		//
		// This facility is primarily intended for reliable data, though it can be used to group unreliable data as well.
		// Grouping unreliable data together would effectively give you an all-or-nothing type of delivery system.  Be
		// mindful that if the group of packets gets larger than max-raw-packet-size, it will end up getting
		// promoted to being a reliable-packet with the associated overhead involved in that.
		//
		// You might be wondering what the advantage would be of grouping packets together at the application level as opposed to
		// just letting the internal multi-buffer take care of the problem for you.  For starters, the internal multi-buffer
		// is incapable of combining partial-packets, so you end up sending less than maximum-size packets if you let the
		// internal layer take care of it.  Additionally, there is additional overhead in that if you send 100 tiny logical
		// packets, each one will need to be ack'ed by the receiving end (even though they are getting combined down at the physical-packet
		// level in order to reduce UDP overhead).  Finally, grouping them together at the higher level will allow the
		// logical-packet compression helper routines to operate on larger chunks of data at a time, which tends to improve
		// compression efficiency.  The downside to combining is that none of the application packets get delivered until the
		// entire group arrives, then all are delivered in one fell swoop...the net effect being that in order to gain these efficeincies,
		// the first-packet takes longer to be delivered to the application than it otherwise would have (while the last packet will in theory
		// get there is less time as there will be less overhead).
		//
		// Internal packets can be added to the group (though that is somewhat unlikely), which means you can add a group to a group
	public:
		GroupLogicalPacket();
		void AddPacket(const LogicalPacket *packet);		// cannot add internal logical packets to the group
		void AddPacket(const void *data, int dataLen);
		virtual void *GetDataPtr();
		virtual const void *GetDataPtr() const;
		virtual int GetDataLen() const;
		virtual void SetDataLen(int len);
		virtual bool IsInternalPacket() const;		// returns true if this is considering an internal logical packet type

	protected:
		virtual ~GroupLogicalPacket();
		void AddPacketInternal(const void *data, int dataLen, bool isInternalPacket);

		uchar *mData;
		int mDataLen;
};

class PooledLogicalPacket : public LogicalPacket
{
		// a pooled logical packet is like other logical packets, only when it's refCount gets down to 1, it notifies
		// its manager to add it back to the pool.  (The manager keeps the last ref count on the packet)
	public:
		PooledLogicalPacket(UdpManager *manager, int len);

		virtual void AddRef() const;
		virtual void Release() const;
		virtual void *GetDataPtr();
		virtual const void *GetDataPtr() const;
		virtual int GetDataLen() const;
		virtual void SetDataLen(int len);
	protected:
		virtual ~PooledLogicalPacket();

		uchar *mData;
		int mDataLen;
		int mMaxDataLen;
	protected:
		friend class UdpManager;
		void SetData(const void *data, int dataLen, const void *data2 = NULL, int dataLen2 = 0);
		UdpManager *mUdpManager;
		PooledLogicalPacket *mAvailableNext;
		PooledLogicalPacket *mCreatedNext;
		PooledLogicalPacket *mCreatedPrev;
};


class AddressHashTableMember : public HashTableMember
{
};

class ConnectCodeHashTableMember : public HashTableMember
{
};

	////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The purpose of the UdpManager is to manage a set of connections that are coming in on a particular port.
	// Typically an application will only have one UdpManager taking care of all incoming connections.  The
	// exception is if the application is talking to two distinct sets of individuals.  For example, the leaf
	// server application might have a UdpManager to manage the connections to all the users/players who will
	// be connecting.  It may then have a second UdpManager to manage its connection to a master server
	// someplace (though in theory it could use one UdpManager for everything).
	//
	// The UdpManager owns the solitary socket that all data being sent/received by any of the managed connections uses.
	// When the UdpManager is created, it is given a port-number that it uses for this purpose.  The UdpManager is capable
	// of establishing new connections to other UdpManager, or it is also capable of accepting new connections.
	////////////////////////////////////////////////////////////////////////////////////////////////////////////
class UdpManager
{
	public:
			// encryption methods are allowed to change the packet-size, so raw packet level compression
			// would actually be implemented as a new encryption-method if needed
			// the user-supplied method requires that the both ends of the connection have the user-supplied
			// encrypt handler functions setup to correspond to each other.
		enum EncryptMethod { cEncryptMethodNone
						   , cEncryptMethodUserSupplied		// use the UdpConnectionHandler::OnUserSuppliedEncrypt function
						   , cEncryptMethodUserSupplied2	// use the UdpConnectionHandler::OnUserSuppliedEncrypt2 function
						   , cEncryptMethodXorBuffer		// slower xor method, but slightly more encrypted
						   , cEncryptMethodXor				// faster using less memory, slightly less well encrypted, use this one as first choice typically
						   , cEncryptMethodCount };

		enum ErrorCondition { cErrorConditionNone, cErrorConditionCouldNotAllocateSocket, cErrorConditionCouldNotBindSocket };

		enum { cReliableChannelCount = 4 };
		enum { cEncryptPasses = 2 };
		enum { cProtocolVersion = 2 };		// protocol version must match on both ends, or connect packets are simply ignored by the server
		enum { cHardMaxRawPacketSize = 16384 };
		enum { cHardMaxOutstandingPackets = 30000 };	// don't change this

		struct ReliableConfig
		{
			int maxOutstandingBytes;		// maximum number of bytes that are allowed to be outstanding without an acknowledgement before more are sent (default=200k)
			int maxOutstandingPackets;		// maximum number of physical reliable packets that are allowed to be outstanding (default=400)
			int maxInstandingPackets;		// maximum number of incoming reliable packets it will queue for ordered delivery while waiting for the missing packet to arrive (should generally be same as maxOutstandingPackets setting on other side) (default=400)
			int fragmentSize;				// this is the size it should fragment large logical packets into (default=0=max allowed=maxRawPacketSize)
			int trickleSize;				// maximum number of bytes to send per trickleRate period of time (default=0=max allowed=fragmentSize)
			int trickleRate;				// how often trickleSize bytes are sent on the channel. (default=0=no trickle control)
			int resendDelayAdjust;			// amount of additional time (in ms) above the average ack-time before a packet should be deemed lost and resent (default=300)
			int resendDelayPercent;			// percent average ack-time it should use in calculating the resend delay (default = 125 or 125%)
			int resendDelayCap;				// maximum length of resend-delay that will ever be assigned to an outstanding packet.  (default=5000)
			int congestionWindowMinimum;	// the minimum size to allow the congestion-window to shrink.  This defaults to 0, though internally it the implementation will never let the window get smaller than a single raw packet (512 bytes by default).
											// This setting is more intended to allow the application to set a higher minimum than that, effectively allowing the application to tell the connection to refuse to slow itself
											// down as much.  See release notes for more details.
			bool outOfOrder;				// whether incoming packets on this channel should be allowed to be delivered out of order (default=false)
			bool processOnSend;				// whether a packet sent on this channel should immediately be processed to determine if it can be sent, or whether it should wait for the next give time (default=false)
			bool coalesce;					// whether the reliable-channel should attempt to coalesce data to reduce ack's needed (note: rarely change this to false)(default=true)
			bool ackDeduping;				// whether ack-packets stuck into the low-level multi-buffer should be deduped (note: rarely change this to false)(default=true)
		};

		struct Params
		{
			Params();		// constructor merely sets default values for the structure members

					// instead of specifying a callbackConnectRequest pointer, you can also specify a handler object to receive
					// the callback directly.  To have the UdpManager call your object directly when connection requests come in, you
					// simply need to derive your class (multiply if necessary) from UdpManagerHandler, then you can set this
					// pointer equal to your object and the UdpManager will call it as appropriate.  The UdpConnection object
					// also has a handler mechanism that replaces the other callback functions below, see UdpConnection::SetHandler
					// if a handler is specified, the callback function is ignored, even if specified.
					// default = NULL (not used)
			UdpManagerHandler *handler;

					// this is the maximum number of connections that can be established by this manager, any incoming/outgoing connections
					// over this limit will be refused.  On the client side, this typically only needs to be set to 1, though there
					// is little harm in setting this number larger.
					// default = 10
			int maxConnections;

					// this is the port number that this manager will use for all incoming and outgoing data. On the client side
					// this is typically set to 0, which causes the manager object to randomly pick an available port.  On the server
					// side, this port should be set to a specific value as it will represent the port number that clients will use
					// to connect to the server (ie. the listening port).  It's generally a good idea to give the user on the client
					// side the option of fixing this port number at a specific value as well as it is often necessary for them to
					// do so in order to navigate company firewalls which may have specific port numbers open to them for this purpose.
					// default = 0
			int port;

					// if port is not zero, setting this to a value greater than zero causes it to randomly pick a port in the range
					// (port to port+portRange).  This is desireable when you wish to have the manager bind to a random port within
					// a specified range.  If you specify a portRange to use, then port must not be 0 (since 0 means to let the OS
					// pick the port to use).  0=don't use a range, bind only to the port specified in 'port' setting.
					// default = 0
			int portRange;

					// the size of the outgoing socket buffer.  The client will want to set this fairly small (32k or so), but the server
					// will want to set this fairly large (512k)
					// default = 64k
			int outgoingBufferSize;

					// the size of the incoming socket buffer.  The client will want to set this fairly small (32k or so), but the server
					// will want to set this fairly large (512k)
					// default = 64k
			int incomingBufferSize;								

					// the purpose of the packet history is to make debugging easier.  Sometimes a processed packet will cause the server
					// to crash (due to a bug or possibly just corruption).  Typically the application will put an exception handler around
					// the main loop and call UdpManager::DumpPacketHistory when it is triggered.  This will dump a history of the last
					// packets received such that they can be analyzed by hand to determine if one of them caused the problem and why.
					// The packet history is done at the raw packet level (before logical packet re-assembly).  This is the number of raw
					// packets to buffer in the history.  Typically this can be set fairly small (maybe 1000) since packets older than
					// that have little debug value. (uses maxRawPacketSize * thisValue of memory)
					// default = 100
			int packetHistoryMax;

					// how long a connection will wait before sending a keep-alive packet to the other side of the connection
					// set this to 0 to never send keep-alive packets (typically the server will set this to 0 and never keep alive
					// the client, but the client will typically set this some value that will ensure that the server will not kick them
					// for inactivity.  Keep alive packets are only sent if no other data is being sent.
					// default = 0
			int keepAliveDelay;

					// this is very similar to the keep alive delay, but serves a completely different purpose and may not have the desired
					// effect on all platforms.  The purpose of the keepAliveDelay above is generally to keep data flowing to the server
					// so it knows that the client is still there.  In this manner if the server doesn't get data within a certain period
					// of time, it can know that the connection is probably dead.  Sometimes it is the case that the server does not need
					// to be kept alive, or at least kept alive very often (like for a chat server perhaps where nobody is talking much).
					// For some people, it may be necessary to send data more frequently in order to keep their NAT mapping fresh, or their
					// firewall software happy.  However, we don't want to be in a situation where our server is receiving a lot more data
					// than it needs to just so these people can keep their port open.  I have seen NAT's that lose mappings in as short
					// as 20 seconds.  What this feature does is a bit tricky.  It changes the time-to-live (TTL) for a special keep-alive
					// packet to some small value (4) which is enough for the packet to get past firewalls and NAT's, but not make it all
					// the way to our server.  In this manner, the port gets kept alive, but we don't waste bandwidth with these packets.
					// These special packets are not counted statistically in any way and they do not reset any timers of any kind.  Their 
					// sole purpose is to keep the port alive on the client side.  Any other data (include standard keepAlive packets will
					// reset the timer for this packet, so obviously the portAliveDelay must be smaller than the keepAliveDelay in order
					// to be meaningful.
					// default = 0 = off
			int portAliveDelay;

					// whether this UdpManager should send back an unreachable-connection packet when it receives incoming data from
					// a destination it does not have a UdpConnection object representing.  This is the equivalent of a port-unreachable
					// ICMP error packet, only taken up one level further to the virtual-connection object (UdpConnection).  Imagine a
					// server that has terminated a client's connection, but the client didn't get notice that such termination had occurred.
					// The client would still think the connection was good and continue to try and send data to the server, but the data
					// would simply be getting lost and queued up indefinately on the client.  The client doesn't get port unreachable errors
					// since the server is using the same port for lots of people.  Having this true causes the server to notify the client
					// that its connection is dead.  If a client finds out it is terminated in this manner, it will set its disconnect reason
					// to cDisconnectReasonUnreachableConnection.
					// default = true
			bool replyUnreachableConnection;

					// the UdpLibrary supports a feature whereby a connection can remap its ip/port on-the-fly.  How it works is, if a client
					// gets back a connection-unreachable error, it will send out a request for the server to remap its connection to the
					// new port that it is coming from.  This will happen if a NAT expires and the next outgoing packet causes a different
					// port-mapping to be selected.  The UdpLibrary can recover from this situation.  The icmpErrorRetryPeriod must be
					// set to a reasonably high value, such that the client has time to send data and request the remapping before icmp
					// errors are processed.  This value determines not only whether a server will honor a remapping request, but also
					// whether the client will attempt a remapping request.  The terms client as server are used loosely here, as it is
					// possible for the server to request the remapping (though it is extremely unlikely that the server end
					// of a connection will have its port changed on-the-fly).
					// default = true
			bool allowPortRemapping;		

					// this is the same as allowPortRemapping, only it allows the full IP address to be remapped on-the-fly.  I
					// recommend that you do NOT enable this, as it represents a fairly serious security loophole, whereby a hacker could
					// cause random people to be disconnected, and in theory possibly even hi-jack their connection.  The odds of this
					// actually being able to happen are incredibly rare unless the hacker has been snooping your packet stream, as they
					// would effectively have to guess two 32-bit random numbers (one generated by the client and one generated by the server)
					// default = false
			bool allowAddressRemapping;


					// how long (in milliseconds) the manager will ignore ICMP errors to a particular connection before it will act upon
					// them and terminate the connection.  When a packet is successfully received into the connection in question, the
					// retry period is reset, such that the next time an ICMP error comes in, it has another period of time for it
					// to resolve the issue.  This servers a couple purpose, 1) it can allow for momentary outages that can be recovered
					// from in short order, and 2) it is necessary for the port-remapping feature to work properly in situations where
					// the server may send data to the old-port before the remapping negotiations are completed.  In order for the
					// remapping feature to work properly, this value should be set to larger than the longest time a connection typically
					// goes without receiving data from the other side. (0=no grace period)
					// default = 5000
			int icmpErrorRetryPeriod;

					// how long a connection will go without receiving any data before it will terminate the connection
					// set this to 0 to never have the connection terminated automatically for receiving no data.
					// the application will receive an OnTerminated callback when the connection is terminated due to this timeout
					// this setting can be overridden on a per-connection basis by calling UdpConnection::SetNoDataTimeout
					// default = 0
			int noDataTimeout;
			
					// when reliable data is sent, it remains in the queue until it is acknowledged by the other side.  When you query
					// the reliable channel status, you can find out the age of the oldest piece of data in the queue that has been sent
					// yet has not been acknowledged yet.  As a general rule, if things are operating correctly, it should be very rare
					// for something that has been sent to not be acknowledged within a few seconds, even if resending had to occur.
					// Eventually, the sender could use this statistic to determine that the other side is no longer talking and terminate
					// the connection.  In past version of the UdpLibrary, the sending-application has checked this statistic itself.  This
					// parameter will cause the UdpLibrary to monitor this for you and automatically change the connection to a disconnected
					// state when the value goes over this setting (in milliseconds) (0 means do not perform this check at all)
					// The default is set fairly liberally, on client-side connections, you could safely set this to as low as 30 seconds
					// allowing for quicker realization of lost connections.  Often times the connection will realize it is dead much quicker
					// for other reasons.  When disconnected due to this, the disconnect reason is set to cDisconnectReasonUnacknowledgedTimeout
					// default = 90000
			int oldestUnacknowledgedTimeout;

					// maximum number of bytes that are allowed to be pending in all the reliable channels combined
					// before it will terminate the connection with a cDisconnectReasonReliableOverflow.  If this value is set to
					// zero, then it will never overflow (it will run out of memory and crash first).  If your application wants
					// to do something other than disconnect on this condition, then the application will have to periodically check the status
					// itself using UdpConnection::TotalPendingBytes and act as appropriate.
					// default = 0
			int reliableOverflowBytes;

					// how long a connection will hold onto outgoing data in hopes of bundling together future outgoing data in the same
					// raw packet (specified in milliseconds)
					// setting this to 0 will cause it to effectively flush at the end of every frame.  This is generally desireable in
					// cases where frame-rates are slow (less than 10 fps), or for internal LAN connections.
					// default = 50
			int maxDataHoldTime;

					// how much data a connection will hold onto before sending out a raw packet
					// (0=no multi-packet buffering, all application sends result in immediate raw packet sends)
					// (-1=use same value as maxRawPacketSize)
					// this value will be effectively ignored if it is larger than the maxRawPacketSize specified below)
					// default = -1
			int maxDataHoldSize;

					// maximum size that a raw packet is allowed to be, this must be set the same on both client and server side
					// the reason for this is the incoming packets need some handling before the connection object they are associated
					// with is determined.  This means we can't have different connection objects using different sizes, so this
					// effectively means all clients must be the same size as the server.  Normally this won't be a problem, this value
					// should likely be set to something like 496 or 1400 and then just kept there forever.
					// the raw packet size won't have a significant effect on anything.  Must be at least 64 bytes.
					// default = 512
			int maxRawPacketSize;

					// how large the hash-table is for looking up connections.  It takes 4*hashTableSize memory and it is recommended
					// you set it fairly large to prevent collisions (10 times maximum number of connections should be fine)
					// default = 100
			int hashTableSize;

					// whether a priority queue should be used.  If a priority queue is not used, then everytime
					// UdpManager::GiveTime is called, every UdpConnection object gets processing time as well.
					// It is thought that if traffic is heavy enough, that managing the priority queue may end up being more
					// cpu time than giving everybody time (as it is possible everybody would end up getting time anyways)
					// if not using a priority queue, it is recommended that you GiveTime only periodically (every 50ms for example)
					// the more often you GiveTime, the more critical the priority-queue is at reducing load compared to not using it
					// default = false
			bool avoidPriorityQueue;

					// how often the client synchronizes its timing-clock to the servers (0=never)(specified in ms).
					// the server-side MUST specify this as 0, or else the server will attempt to synchronize it's clock with
					// the client as well (which would just be a waste of packets generally, though would work)
					// the client should generally always set this feature on by setting it to something like 45000 ms.
					// the clock-sync is used to negotiate statistics as well, so if you are not using clock sync, then you
					// will not be able to get packetloss/lag statistics for the connection.  If you are using it, then you will
					// be able to get these statistics from either end of the connection.
					// default = 0
			int clockSyncDelay;


					// these two values control the number of packets that the UdpManager will create in its packet pool.  The packet pool
					// is a means by which the UdpManager avoid allocating logical packets for every send, by instead using them from the pool.
					// you need to specify the size of the packets that are in the pool.  Then, when somebody calls UdpManager::CreatePacket,
					// if the packet being created is small enough and there is room available, it grabs one from the pool, otherwise it
					// creates a new non-pooled one.  The largest the pool will ever grow is pooledPacketMax, and the memory used will be roughly
					// pooledPacketMax * pooledPacketSize.  You should be generous with the pool packet size and the pool max in order
					// to avoid having to do allocations as much as possible
					// pooledPacketMax default = 1000, (0 = don't use memory pooling at all)
			int pooledPacketMax;
					// pooledPacketInitial is the number of packets to allocate in the initial pool.  The only reason to set this to 
					// something other than the default, which is 0, is to avoid having your memory fragmented as the pool grows on demand.
			int pooledPacketInitial;
					// as a general rule, ou should leave this at -1.  This is critical.  If the pooledPacketSize is smaller than the
					// maxRawPacketSize, then all the coalescing that occurs in the reliable channel will result in allocations.  You
					// would just as well not have a pool if you don't set this at least as large as the maxRawPacketSize.  If your application
					// tends to send largish packets (larger than maxRawPacketSize), setting this large enough to cover those might buy you
					// some speed as well.
					// pooledPacketSize defaults to -1, which means use the same as maxRawPacketSize
			int pooledPacketSize;

					// the maximum number of entries to allow in WrappedLogicalPacket pool before they start getting destroyed
					// depending on the nature of the sending that you are doing, and the volume that you are doing, you may
					// want to increase this value.  WrappedLogicalPacket objects are used in situations where you send the
					// same LogicalPacket object to multiple connections, and that LogicalPacket object is larger than the
					// maxRawPacketSize.  As you can imagine, this is a relatively rare event, so the pool doesn't need to be
					// very large.  Like hte standard pool, this is merely an optimization to avoid allocations, it will work
					// either way.  A server application may wish to to set this number a little bit higher.  Unlike the
					// packet-pool, we don't bother to even pre-create these things, they are just created for the first time
					// when demanded.
					// default = 1000
			int wrappedPoolMax;
			
					// whether ICMP error packets should be used to determine if a connection has gone dead.  
					// when the destination machine is not available, or there is no process on the destination machine
					// talking on the port, then a ICMP error packet will sometimes be returned to the client when a packet is sent.
					// Processing ICMP errors will often allow the client machine to quickly determine that the other end of the
					// connection is no longer reachable, allowing it to quickly change to a disconnected state.  The downside
					// of having this feature enabled is that it is possible that if there is a network problem along the route, that
					// the connection will be terminated, even though the hardware along the route may correct the problem by re-routing
					// within a couple seconds.  If you are having problems with clients getting disconnected for ICMP errors (see
					// disconnect reason), and you know the server should have remained reachable the entire time, then you might
					// want to set this setting to false.  The only downside of setting this to false is that it might take the
					// client a bit longer to realize when a server goes down.
					// default = true
			bool processIcmpErrors;

					// whether ICMP errors should be used to terminate connection negotiations.  By default, this is set to 
					// false, since generally when you are trying to establish a new connection (ie. negotiating), you are
					// are willing to wait for timeout specified in the EstablishConnection call, since it may be a case
					// that the client process gets started slightly sooner than the server process.
					// default = false
			bool processIcmpErrorsDuringNegotiating;


					// during connection negotiation, the client sends connect-attempt packets on a periodic basis until the
					// server responds acknowledging the connection.  This value represents how often the client sends those packets.
					// By default this is set to 1000 or 1 second and generally should not be messed with.
			int connectAttemptDelay;


					// This settings allows you to bind the socket used by the library to a specific IP address on the machine.
					// Normally, and by default, the library will bind the socket to any address in the machine.  This setting should
					// not be messed with unless you really know what you are doing.  In multi-homed machines it is generally NOT
					// necessary to bind to a particular address, even if there are firewall issues involved, and even if you want
					// to limit traffic to a particular network (firewalls do a better job of serving that purpose).  If you are having
					// problems communicating with a server on a multi-homed machine and think this might solve the problem, think again.
					// You most likely need to configure the OS to route data appropriately, or make sure that internal network clients
					// are connecting to the machine via the machines internal IP address (or vice versa).
					// by default this string is empty meaning the socket is bound to any address.  To bind to specific IP address, it
					// should be entered in a.b.c.d form (DNS names are not allowed).  Figuring out what IP addresses are in the machine
					// and which one should be bound to is left as an exercise for the user.
			char bindIpAddress[32];

					// you need to specify the characteristics of the various reliable channels here, generally you will want
					// to make sure the client and server sides set these characteristics the same, though it is technically not
					// required.  Each channel decides locally whether it will accept out of order delivery on a particular channel or not.
					// (note: out of order delivery is a tiny optimization that simply lets the channel deliver the packet the moment it
					// arrives, even if previous packets have not yet arrived).  Likewise trickle-rates are for outgoing data only obviously.
					// reliable channel managers are not actually created internally until data is actually sent on the channel, so there
					// is no overhead associated with channels that are not used, and you need not specify characteristics for channels
					// that you know you will not be using.
					// default = 400 packets in&out/200k outstanding, ordered, no trickle (all channels)
			ReliableConfig reliable[cReliableChannelCount];


					// when user supplied encrypt and decrypt routines are specified, it becomes necessary to tell the UdpManager
					// how many bytes the encryption process could possibly expand the chunk of data it was given.  Often times this	
					// will simply be 0, but if the user supplied routines attempt compression, then it's possible that expansion could
					// could actually occur.  Typically I would have the compression routines put a leader-byte on the chunk of data
					// specifying whether it was compressed or not.  Then if the compression didn't pan out, it could alway abort and just
					// prepend the byte in question and the rest of the data.  In that sort of algorithm, you would set this value to 1
					// since the most it could ever expand beyond the original is the 1-byte indicator on the front.  It's possible that
					// a particular encryption routine might want to append a 4-byte encryption key on the end of the chunk of data, in
					// which case you would need to reserve 4 bytes.  This is necessary as it allows the udp library to guarantee that
					// no packet will be larger than maxRawPacketSize, and at the same time ensures that the destination buffers supplied
					// to the encrypt/decrypt functions will have enough room.  Obviously this value is ignored if the encryptMethod
					// is not set to cEncryptMethodUserSupplied.
					// default = 0
			int userSuppliedEncryptExpansionBytes;
			int userSuppliedEncryptExpansionBytes2;

					// the following parameters are used to simulate various line conditions that may occur. This allows the application
					// program to test how well it performs under various conditions
					// simulating an incoming byte-rate is simply done by internally not polling the port for a certain period of time
					// after receiving a packet based on the amount of data in the last packet received
					// simulating outgoing byte-rate is a bit more difficult as it requires queuing the data to be sent and slowly trickling
					// it out to the socket.  Simulating is very much akin to simulating lag; however, it is not exactly the same thing.  It's
					// possible to have low-bandwidth, yet good or bad ping times depending on how many hops away you are, but this should good
					// enough for most testing.
					// default = 0
			int simulateOutgoingLossPercent;		// 0=no loss, 100=100% loss
			int simulateIncomingLossPercent;		// 0=no loss, 100=100% loss
			int simulateIncomingByteRate;			// simulates the incoming bandwidth specified (in bytes/second) (0=off)


				// simulates the outgoing bandwidth specified (in bytes/second) (0=off)
				// an interesting side-note of the outgoing byte-rate limit.  In order to accomplish
				// this we to queue stuff on the client and then pace the sending of it.  When the client
				// terminates the connection, the last thing it does is send a terminate packet to the other side
				// The UdpManager is playing the role of the operating system when byte-limiting is on insofar as it
				// is the UdpManager that is managing the virutal socket buffer.  Most of the time when the client
				// terminates, it also terminates the UdpManager.  When you are using the outgoing byte rate simulator,
				// terminating the UdpManager is akin to rebooting the box.  The net effect is that any outgong packets
				// in the queue are lost.  This includes the ever important 'terminate-packet' that is sent to the server
				// at the last moment.  This means that when you are simulating an outgoing byte rate, that the server
				// will never see the client properly terminate, UNLESS the client gives the UdpManager processing time
				// for several seconds (long enough to flush the queue at the specified byte-rate) after the connection
				// is destroyed, but before the UdpManager is destroyed.
				// note: when using this setting, it is critical that you also set the simulateOutgoingOverloadLevel as
				// well in order to simulate the limited-size socket buffer that the OS would have.
			int simulateOutgoingByteRate;


				// this is the number of bytes in the outgoing queue total before packets are simply lost
				// this number is used to simulate the condition where you can't simply throw tons of data at a modem
				// and expect it to not lose any of it.  Normally this data would queue up in the socket buffer for however
				// big your outgoing socket buffer is; however, if you are simulating limited outgoing bandwidth, then
				// the socket buffer never actually has any data in it, instead all the queuing is taking place in the
				// simulation queue.  In order to handle this properly, we have to cap the outgoing simulation queue size
				// total for all connection.
			int simulateOutgoingOverloadLevel;


				// this is the number of bytes in the outgoing queue/connection before packets are simply lost (0=infinite)
				// this number is used to simulate the condition where some router or terminal-server down
				// the line has a limited buffer size and once it gets overloaded it just throws away new incoming
				// packets.  The reason we have to do this is because otherwise our internal simulation queue
				// would grow forever.  The loss of packets is necessary for the flow control stuff to do its
				// job.  The incoming side uses the socket-buffer for this purpose and as such can simply
				// set the incoming socket buffer to the desired size and the OS will throw away stuff that comes
				// in yet doesn't fit.  Since this parameter is supposed to simulate a line condition downward
				// toward the destination and we may have multiple destinations in our queue, this handles it properly
				// by tracking the amount of data queued for each destination ip/port address (it does this by actually
				// back-link up to the UdpConnection object).
			int simulateDestinationOverloadLevel;


				///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
				// the following values are ignored by connections initiated by this manager (ie. client side) since the server will tell 
				// the client the values that are in effect during the connection initialization process.
				///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

					// how many additional bytes of CRC data is added to raw packets to ensure integrity (0 through 4 allowed)
					// default = 0
			int crcBytes;

					// which encryption method is to be used (see enumeration) (this occurs at the raw packet level)
					// default = cEncryptMethodNone
			EncryptMethod encryptMethod[cEncryptPasses];
		};

		UdpManager(const Params *params);

		void SetHandler(UdpManagerHandler *handler);
		UdpManagerHandler *GetHandler() const;
		void SetPassThroughData(void *passThroughData);
		void *GetPassThroughData() const;
		ErrorCondition GetErrorCondition() const;

			// standard AddRef/Release scheme
		void AddRef();
		void Release();
		int GetRefCount() const;


			// this function MUST be called on a regular basis in order to give the manager object time to service the socket
			// and give time to various connection objects that may need processing time to send/resend packets, etc.
			//
			// If you set maxPollingTime to 0, it will not attempt to receive any packets out of the socket.  If no
			// packets are gotten from the socket, then it is impossible for any packets to be forwarded to the application;
			// hence, this is a good way to give the manager processing time for outgoing packets in situations
			// where the application does not want to have to worry about processing incoming packets.
			//
			// If you set maxPollingTime to -1, it will poll at most 1 packet out of the socket at a time and process it.  You
			// should know that a single packet on the socket can possibly result in multiple data-packets being delivered to the application.
			// For example, the incoming packet could be a previous lost reliable packet, which would cause all the stalled reliable packets to be
			// delivered.  Multi-buffering could also result in multiple route-packet callbacks from one physical packet coming off the socket.
			// The purpose of this 1-packet feature is primarily to support the EstablishConnection process.  By processing only one packet at a
			// time, it gives the application a chance to check the status of a negotiating connection before any data is possibly delivered to
			// that connection.  This allows the client-app to loop on GetStatus checking for the connection to get established, then create all
			// the infrastructure necessary to support that connection once it is established, without fear of packets being delivered before said
			// infrastructure is in place.  This is safe since connection-confirmation packets do not multi-buffer up.
			//
			// The only reason you might want to avoid giving the connections time is if you are a fairly non-packet-time critical application
			// and are using the avoidPriorityQueue setting (and want to avoid using up too much CPU time while at the same
			// time you don't want to avoid processing the socket).
			// returns true if any incoming packets were processed during this time slice, otherwise returns false
		bool GiveTime(int maxPollingTime = 50, bool giveConnectionsTime = true);

			// used to establish a connection to a server that is listening at the specified address and port.
			// the serverAddress will do a DNS lookup as appropriate.  This call will block long enough to resolve
			// the DNS lookup, but then will return a UdpConnection object that will be in a cStatusNegotiating
			// state until the connection is actually established.  The application must give the manager
			// object time after calling EstablishConnection or else the negotiation process to establish the
			// connection will never have time to actually occur.  Typically the client establishing the connection
			// will call EstablishConnection, then sit in a loop calling UdpManager::GiveTime and checking to see
			// if the status of the returned UdpConnection object is changed from cStatusNegotiating.  This allows
			// the application to look for the ESC key or timeout an attempted connection.
			// This function will return NULL if the manager object has exceeded its maximum number of connections
			// or if the serverAddress cannot be resolved to an IP address
			// as is noted in the declaration, it is the responsibility of the application establishing the connection to delete it
			// setting the timeout value (in milliseconds) to something greater than 0 will cause the UdpConnection object to change
			// from a cStatusNegotiating state to a cStatusDisconnected state after the timeout has expired.  It will also cause
			// the connect-complete callback to be called.
		UdpConnection *EstablishConnection(const char *serverAddress, int serverPort, int timeout = 0);

			// gets statistical information about this manager, which covers all connections going through this manager 
			// (useful for getting server-wide statistics)
		void GetStats(UdpManagerStatistics *stats) const;
		void ResetStats();

			// this function will dump the packet history out to the specified filename.  If no packet history is being kept (see UdmManagerParams::packetHistoryMax)
			// then this function does nothing.
		void DumpPacketHistory(const char *filename) const;

			// returns the ip address of this machine.  If the machine is multi-homed, this value may be blank.
		UdpIpAddress GetLocalIp() const;

			// returns the port the manager is actually using.  This value will be the same as is specified in Params::port (or if Params::port was set to 0, this will be the dynamically assigned port number)
		int GetLocalPort() const;

			// returns how long it has been (in milliseconds) since this manager last received data
		int LastReceive() const;

			// returns how long it has been (in milliseconds) since this manager last sent data
		int LastSend() const;

			// manually forces all live connections to flush their multi buffers immediately
		void FlushAllMultiBuffer();

			// creates a logical packet and populates it with data.  data can be NULL, in which case it gives you logical packet
			// of the size specified, but copies no data into it.  If you are using pool management (see Params::poolPacketMax),
			// it will give you a packet out of the pool if possible, otherwise it will create a packet for you.  When logical
			// are packets are needed internally for various things (like reliable channel sends that use the (void *, int) interface)
			// they are gotten from this function, so your application can likely take advantage of pooling, even if it never bothers
			// to explicitly call this function.
		LogicalPacket *CreatePacket(const void *data, int dataLen, const void *data2 = NULL, int dataLen2 = 0);

	protected:
		friend class PooledLogicalPacket;
		void PoolReturn(PooledLogicalPacket *packet);		// so pooled packets can add themselves back to the pool
		void PoolCreated(PooledLogicalPacket *packet);
		void PoolDestroyed(PooledLogicalPacket *packet);

	protected:
		friend class WrappedLogicalPacket;

		WrappedLogicalPacket *WrappedBorrow(const LogicalPacket *lp);		// used by reliable channels
		void WrappedReturn(WrappedLogicalPacket *wp);

		void WrappedCreated(WrappedLogicalPacket *wp);
		void WrappedDestroyed(WrappedLogicalPacket *wp);

	protected:
		friend class UdpConnection;
		friend class UdpReliableChannel;

		class PacketHistoryEntry
		{
			public:
				PacketHistoryEntry(int maxRawPacketSize);
				~PacketHistoryEntry();

			public:
				uchar *mBuffer;
				UdpIpAddress mIp;
				int mPort;
				int mLen;
		};

		Params mParams;
		PacketHistoryEntry **mPacketHistory;
		int mPacketHistoryPosition;

		void *mPassThroughData;

		UdpConnection *mConnectionList;		// linked listed of connections
		int mConnectionListCount;

		UdpConnection *mDisconnectPendingList;		// linked list of connections to be released when they go to cStatusDisconnected

		ObjectHashTable<AddressHashTableMember *> *mAddressHashTable;
		ObjectHashTable<ConnectCodeHashTableMember *> *mConnectCodeHashTable;
		PriorityQueue<UdpConnection,UdpMisc::ClockStamp> *mPriorityQueue;
		UdpMisc::ClockStamp mMinimumScheduledStamp;		// soonest anybody is allowed to schedule themselves for more processing time

		SOCKET mUdpSocket;
		UdpMisc::ClockStamp mLastReceiveTime;
		UdpMisc::ClockStamp mLastSendTime;
        UdpMisc::ClockStamp mLastEmptySocketBufferStamp;
        int mProcessingInducedLag;      // how long the currently being processed packet could have possibly been sitting in the socket-buffer waiting for processing (which is effectively how long it has been since we last quit polling packets from the socket queue)
		unsigned long int mStartTtl;	// initial TTL for packets (used if it is changed by the application for port-alive packets)
		ErrorCondition mErrorCondition;

		UdpManagerStatistics mManagerStats;
		UdpMisc::ClockStamp mManagerStatsResetTime;

			// stuff for managing the outgoing packet-rate simulation
		class SimulateQueueEntry
		{
			public:
				SimulateQueueEntry(const uchar *data, int dataLen, UdpIpAddress ip, int port);
				~SimulateQueueEntry();
			public:
				uchar *mData;
				int mDataLen;
				UdpIpAddress mIp;
				int mPort;
				SimulateQueueEntry *mNext;
		};
		friend class SimulateQueueEntry;
		int mSimulateQueueBytes;
		SimulateQueueEntry *mSimulateQueueStart;
		SimulateQueueEntry *mSimulateQueueEnd;
		UdpMisc::ClockStamp mSimulateNextIncomingTime;
		UdpMisc::ClockStamp mSimulateNextOutgoingTime;

			// pool management
		int mPoolCreated;
		int mPoolAvailable;
		PooledLogicalPacket *mPoolAvailableRoot;	// those available
		PooledLogicalPacket *mPoolCreatedRoot;		// all those created

			// pool management
		int mWrappedCreated;
		int mWrappedAvailable;
		WrappedLogicalPacket *mWrappedAvailableRoot;	// those available
		WrappedLogicalPacket *mWrappedCreatedRoot;		// those created (available or not)

	protected:		// internal functions
		int AddressHashValue(UdpIpAddress ip, int port) const;
		UdpConnection *AddressGetConnection(UdpIpAddress ip, int port) const;
		UdpConnection *ConnectCodeGetConnection(int connectCode) const;

		PacketHistoryEntry *ActualReceive();
		void ActualSend(const uchar *data, int dataLen, UdpIpAddress ip, int port);
		void ActualSendHelper(const uchar *data, int dataLen, UdpIpAddress ip, int port);
		void SendPortAlive(UdpIpAddress ip, int port);
		void ProcessRawPacket(const PacketHistoryEntry *e);
		void AddConnection(UdpConnection *con);
		void RemoveConnection(UdpConnection *con);
		void SetPriority(UdpConnection *con, UdpMisc::ClockStamp stamp);
		void ProcessIcmpErrors();
		void KeepUntilDisconnected(UdpConnection *con);
		void ProcessDisconnectPending();
		void CloseSocket();
		void CreateAndBindSocket(int usePort);

	private:
		~UdpManager();	// does not destroy UdpConnection objects since it does not own them; however, it has a pointer to all the active
						// ones and it will notify them that it no longer exists and set their state to cStatusDisconnected
						// typically it is recommended that all UdpConnection objects be destroyed before destroying this manager object

		int mRefCount;
};

	////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The purpose of the UdpConnection is to manage a single logical connection
	////////////////////////////////////////////////////////////////////////////////////////////////////////////
class UdpConnection : public PriorityQueueMember, public AddressHashTableMember, public ConnectCodeHashTableMember
{
	public:
		enum Status { cStatusNegotiating, cStatusConnected, cStatusDisconnected, cStatusDisconnectPending, cStatusCount };

		enum DisconnectReason { cDisconnectReasonNone, cDisconnectReasonIcmpError, cDisconnectReasonTimeout
							  , cDisconnectReasonOtherSideTerminated, cDisconnectReasonManagerDeleted
							  , cDisconnectReasonConnectFail, cDisconnectReasonApplication
							  , cDisconnectReasonUnreachableConnection, cDisconnectReasonUnacknowledgedTimeout
							  , cDisconnectReasonNewConnectionAttempt, cDisconnectReasonConnectionRefused
							  , cDisconnectReasonMutualConnectError, cDisconnectReasonConnectingToSelf
							  , cDisconnectReasonReliableOverflow
							  , cDisconnectReasonCount };
		
			// standard AddRef/Release scheme
		void AddRef();
		void Release();
		int GetRefCount() const;

			// returns the current status of this connection
		Status GetStatus() const;

			// returns the reason that a connection was disconnected.  See the enum above for a list of all the reasons
		DisconnectReason GetDisconnectReason() const;
		DisconnectReason GetOtherSideDisconnectReason() const;
		static const char *DisconnectReasonText(DisconnectReason reason);	// text-description of disconnect reason to aid in logging

			// sets the handler object for this connection.  If a handler object is specified, then the callback functions specified
			// in UdpManager::Params are ignored for this connection and the handler is used for the callback instead.
			// by default there is no handler.
		void SetHandler(UdpConnectionHandler *handler);
		UdpConnectionHandler *GetHandler() const;

			// set and get the pass-through data value.  Typically the application will set the pass through data
			// in the callback function for establishing a connection, then it will use the pass through data
			// in the callback function for routing packets.
		void SetPassThroughData(void *passThroughData);
		void *GetPassThroughData() const;

			// when called this connection is marked as terminated.  It is the responsibility of the application
			// to explicitly destroy connections that are no longer connected.  When this object is disconnected
			// it calls the UdpManager and has itself removed from the list of active connections, at which point
			// the only person having a pointer to this object is the application itself (which owns it)
			// (if the UdpManager is deleted before all UdpConnections are destroyed, the UdpManager loops through
			// all of the connections it has calling Disconnect on them such that they know that they no longer
			// have a udp manager that they can send data through)
			//
			// setting a flushTimeout tells the connection to stay alive for that amount of time trying to send any pending
			// reliable data before shutting down.  Once the application calls Disconnect even with a flushTimeout, the application
			// should not attempt to use the connection in any significant way (see docs and release notes for details)
			// note: the notifyApplication parameter was removed from this function and the functionality of the library
			// was changed such that ANYTIME the connection objects state changes to cStatusDisconnected, the OnTerminated callback
			// function gets called.
		void Disconnect(int flushTimeout = 0);

			// sends a logical packet on the specified channel, returns FALSE if packet could not be queued for sending (should never happen)
			// Internally, a packet that starts with a 0 byte is considered an internal control packet.  If a logical packet starts with a 0
			// byte, then there will an extra control byte of overhead in order to facilitate it.  It is recommended that if packet size
			// is critical, that you don't start the packet with a 0 byte. Typically an application will have a packet-type byte on the front 
			// of application packets; the application packet types should simply start at 1.
		bool Send(UdpChannel channel, const void *data, int dataLen);

			// same as the regular Send only it takes a LogicalPacket instead.  There are two huge advantages to having it take a
			// LogicalPacket.  First, we can send the same LogicalPacket to multiple locations and each connection will not necessarily
			// have to make its own copy of the data at the time it is put into the send queue (instead each connection just increments
			// the buffer ref-count).  Second, it allows the application to pre-generate very large packets (like file update packets potentially)
			// and hold onto them for the entire length of the application, then, whenever any player needs that chunk of data, it can send them
			// the already formatted LogicalPacket.
		bool Send(UdpChannel channel, const LogicalPacket *packet);

			// manually forces all channels to send-off any data they have queued up waiting for processing time to send
			// this mainly applies to reliable channels.  When you send a reliable packet, it actually only adds it to the reliable
			// queue until the connection is given processing time by the manager object.  This call forces it to attempt to
			// send that queued data immediately (subject to normal flow control restrictions).  This also flushes the multi-buffer
			// for the channel.  If you send reliable data and want to ensure that it goes out immediately after the send, this is the
			// best call to make.
		void FlushChannels();

			// manually forces buffered data to be sent immediately
		void FlushMultiBuffer();

			// returns the number of bytes sent/received in the last second to this connection (accurate to within cBinResolution(25) milliseconds)
			// these functions are not const as they expire the older bin data internally in order to calculate the number
		int OutgoingBytesLastSecond();
		int IncomingBytesLastSecond();

			// returns the total number of bytes outstanding in all reliable channels.  When this is zero, you know for sure
			// that all sent reliable data has arrived at destination and is confirmed.
		int TotalPendingBytes() const;

			// returns how long has elapsed since this connection received data (in milliseconds)
		int LastReceive() const;

			// returns how long has elapsed since this connection received data (in milliseconds), using useStamp as the current time (optimization)
		int LastReceive(UdpMisc::ClockStamp useStamp) const;

			// returns how long has elapsed since this connection sent data (in milliseconds)
		int LastSend() const;

			// returns how long this connection has been in existence (in milliseconds)
		int ConnectionAge() const;

			// returns the UdpManager object that is managing this connection
			// will return NULL if the connection has been disconnected for some reason (because disconnecting severes the link to UdpManager)
		UdpManager *GetUdpManager() const;

			// returns the 32-bit encryption-code that was negotiated as part of the connection-establishment process.
			// this is a randomly generated number that both the client and the server have in common.  It is exposed
			// via this interface primarily to allow user-supplied encrypt routines access to it.
			// this code is generated by the server side in response to a connect request.
		int GetEncryptCode() const;

			// this returns the connection-code.  This is very similar to the encrypt-code in that it is randomly
			// generated and both ends of the connection will report the same value.  The difference is that this
			// code's purpose is part of the internal protocol to ensure that old connections don't try to process
			// new connection request packets.  Unlike the encrypt-code, this value is generated by the client
			// and is part of the connect-request packet.  Nevertheless, since this number will be the same random
			// number on both ends of the connection, it too can be used as a potential encryption key for the user
			// supplied encrypt routines.  It's not quite as secure as the encrypt code since this value in theory
			// could be hacked to be something predictable on the client side.
		int GetConnectCode() const;

			// returns a sync-stamp that can be compared to other ServerSyncStamp's generated on other machines
			// in order to calculate the one-way travel time for a packet.  It can only accurate calculate
			// packet travel times under 32 seconds, would should be completely safe.  You must use the
			// UdpManager::SyncStampDeltaTime function in order to calculate the elapsed time between
			// the two stamps.
		ushort ServerSyncStampShort() const;
		uint ServerSyncStampLong() const;
		int ServerSyncStampShortElapsed(ushort syncStamp) const;
		int ServerSyncStampLongElapsed(uint syncStamp) const;

			// returns the IP address/port this connection is linked to
		UdpIpAddress GetDestinationIp() const;
		int GetDestinationPort() const;

			// statistical functions
		void GetStats(UdpConnectionStatistics *cs) const;
		void PingStatReset();		// resets the ping-stat information, causing it to resync the clock etc (if in clock-sync mode).  Generally this is not done, it was added for backward compatibility


			// functions for manipulating the automatic no-data-disconnect stuff on a per-connection basis
		void SetNoDataTimeout(int noDataTimeout);		// 0=never timeout, otherwise in milliseconds (overrides UdpManager::Params::noDataTimeout setting, which is the default)
		int GetNoDataTimeout() const;

			// functions for manipulating the keep-alive packet sending on a per-connection basis
		void SetKeepAliveDelay(int keepAliveDelay);
		int GetKeepAliveDelay() const;

			// configures whether this connection is in silent-disconnect mode or not.  By default, the connection is not in silent
			// disconnect mode, which means that when this connection is terminated, it will send a final terminate-packet to the
			// other side telling them that we are disconnected, allowing them to quickly realize that the connection is now dead.
			// In some circumstances, it may be desireable to not do this, and this can be accomplished by calling this function
			// passing in 'true' to put it in silent mode.  This may be desireable in cases where you are disconnecting a cheater
			// and don't want them to have immediate notification that they did something bad.  Or, if you are attempting to test
			// timeout functionality on the other end and want to simulate a truly dead connection.  Normally, you will not want
			// to mess with this.  It was added to the API to support some internal functionality, see its use in the source-code
			// or release-notes for details.
		void SetSilentDisconnect(bool silent);


			// returns the current queue-status of the reliable channel specified.  Unreliable channels will always report zero.
		struct ChannelStatus
		{
			int totalPendingBytes;			// total bytes of data in channel that have yet to be acknowledged (includes queuedBytes plus physical-packet bytes that have yet to be acknowledged)
			int queuedPackets;				// number of logical packets in the queue
			int queuedBytes;				// number of bytes in the logical queue (the logical queue does NOT include pending physical packets)
			int incomingLargeTotal;			// total number of bytes in the currently incoming logical packet (only meaningful obviously if a fragmented file is in tranist)
			int incomingLargeSoFar;			// number of bytes received so far in the currently incoming logical packet
			int oldestUnacknowledgedAge;	// age of the oldest unacknowledged (but sent) packet (in milliseconds)
			int duplicatePacketsReceived;	// number of times we received a packet that we had already received
			int resentPacketsAccelerated;	// number of times we have resent a packet due to receiving a later packet in the series
			int resentPacketsTimedOut;		// number of times we have resent a packet due to the ack-timeout expiring
			int congestionSlowStartThreshhold;	// current threshhold for slow-start algorithm
			int congestionWindowSize;			// current sliding window size
			int ackAveragePing;					// average time for a packet to be acknowledged (used in calculating optimal resend timeouts)
		};
		void GetChannelStatus(UdpChannel channel, ChannelStatus *channelStatus) const;

	protected:
		friend class UdpManager;
		friend class UdpReliableChannel;

			// note: if connectPacket is NULL, that means this connection object is being created to establish
			// a new connection to the specified ip/port (ie. the connection starts out in cStatusNegotiating mode)
			// if connectPacket is non-NULL, that menas this connection object is being created to handle an
			// incoming connect request and it will start out in cStatusConnected mode.
		UdpConnection(UdpManager *udpManager, UdpIpAddress destIp, int destPort, int timeout);	// starts connection-establishment protocol
		UdpConnection(UdpManager *udpManager, const UdpManager::PacketHistoryEntry *e);				// starts already connected, replying to connection request

			// gives this connection processing time (only given processing time by the manager object and then
			// only when the connection has scheduled itself to receive processing time)
		void GiveTime();
		void ProcessRawPacket(const UdpManager::PacketHistoryEntry *e);
		void PortUnreachable();
		void FlagPortUnreachable();
	protected:
		UdpConnection *mNextConnection;		// used by UdpManager to maintain list of connections
		UdpConnection *mPrevConnection;		// used by UdpManager to maintain list of connections
		UdpConnection *mDisconnectPendingNextConnection;	// used by UdpManager to maintain list of connections pending disconnect
		UdpIpAddress mIp;
		int mPort;
		int mSimulateQueueBytes;			// used by UdpManager to track how many bytes are in it's simulation queue headed to each destination

	private:
		friend class GroupLogicalPacket;

		~UdpConnection();
		void Init(UdpManager *udpManager, UdpIpAddress destIp, int destPort);

			// note: BufferedSend is capable of optionally taking two chunks of data at once, which are then concatenated together as if they were one chunk of data
			// into the multi-buffer.  Providing this facility prevents the UdpReliableChannel object from having to make a copy of all the data it sends
			// in order to stick a realiable header on it.
			// we don't bother extending this down to the PhysicalSend (in case the BufferedSend does a pass through due to size) because the encryption code
			// is incapable of sourcing from two different chunks and outputting to one chunk.  It's not possible to change that either, since the encyption
			// takes place 32 bits at a time and you could end up straddling boundaries between chunks.
		void RawSend(const uchar *data, int dataLen);				// nothing happens to the data here, it is given to the udpmanager and sent out the port
		void PhysicalSend(const uchar *data, int dataLen, bool appendAllowed);		// sends a physical packet (encrypts and adds crc bytes)
		uchar *BufferedSend(const uchar *data, int dataLen, const uchar *data2, int dataLen2, bool appendAllowed);		// buffers logical packets waiting til we have more data (makes multi-packets)
		bool InternalSend(UdpChannel channel, const LogicalPacket *packet);
		bool InternalSend(UdpChannel channel, const uchar *data, int dataLen, const uchar *data2 = NULL, int dataLen2 = 0);

		uchar *InternalAckSend(uchar *bufferedAckPtr, const uchar *ackPtr, int ackLen);		// used by reliable channel to send acks (special send that allows for deduping ack feature)

		void InternalGiveTime();
		void InternalDisconnect(int flushTimeout, DisconnectReason reason);
		void ProcessCookedPacket(const uchar *data, int dataLen);
		void DecryptIt(const uchar *data, int dataLen);
		void ScheduleTimeNow();
		int ExpireSendBin();
		int ExpireReceiveBin();
		void SendTerminatePacket(int connectCode, DisconnectReason reason);
		void CallbackRoutePacket(const uchar *data, int dataLen);
		void CallbackCorruptPacket(const uchar *data, int dataLen, UdpCorruptionReason reason);
		bool IsNonEncryptPacket(const uchar *data) const;

			// these encrypt-method functions return the length of the encrypted/decrypted data
			// new methods of encryption/compression can be easily added by simply creating the
			// functions for them and changing the SetupEncryptModel function as appropriate
			// since raw packets are encrypted in the first place and have a limited size
			// the decrypted data will never be larger than a maxRawPacketSize.  Both of encrypt
			// and decrypt are guaranteed to have enough room in dest buffers to hold the results.
			// Encryption function is allowed to expand the data at most the number of bytes
			// it reserves for this purpose in the SetupEncryptModel function.
		int EncryptNone(uchar *destData, const uchar *sourceData, int sourceLen);
		int DecryptNone(uchar *destData, const uchar *sourceData, int sourceLen);
		int EncryptXor(uchar *destData, const uchar *sourceData, int sourceLen);
		int DecryptXor(uchar *destData, const uchar *sourceData, int sourceLen);
		int EncryptXorBuffer(uchar *destData, const uchar *sourceData, int sourceLen);
		int DecryptXorBuffer(uchar *destData, const uchar *sourceData, int sourceLen);
		int EncryptUserSupplied(uchar *destData, const uchar *sourceData, int sourceLen);
		int DecryptUserSupplied(uchar *destData, const uchar *sourceData, int sourceLen);
		int EncryptUserSupplied2(uchar *destData, const uchar *sourceData, int sourceLen);
		int DecryptUserSupplied2(uchar *destData, const uchar *sourceData, int sourceLen);
		void SetupEncryptModel();

		int mRefCount;
		Status mStatus;
		void *mPassThroughData;
		UdpManager *mUdpManager;
		int mConnectCode;
		UdpConnectionStatistics mConnectionStats;
		UdpMisc::ClockStamp mConnectionCreateTime;
		int mConnectAttemptTimeout;
		int mNoDataTimeout;
		DisconnectReason mDisconnectReason;
		DisconnectReason mOtherSideDisconnectReason;
		bool mFlaggedPortUnreachable;
		bool mSilentDisconnect;

		UdpReliableChannel *mChannel[UdpManager::cReliableChannelCount];

		struct Configuration
		{
			int encryptCode;
			int crcBytes;
			UdpManager::EncryptMethod encryptMethod[UdpManager::cEncryptPasses];
			int maxRawPacketSize;		// negotiated maxRawPacketSize (ie. smaller of what two sides are set to)
		};

		Configuration mConnectionConfig;

		UdpMisc::ClockStamp mLastClockSyncTime;
		UdpMisc::ClockStamp mDataHoldTime;
		UdpMisc::ClockStamp mLastSendTime;
		UdpMisc::ClockStamp mLastReceiveTime;
		UdpMisc::ClockStamp mLastPortAliveTime;
		uchar* mMultiBufferData;
		uchar* mMultiBufferPtr;

		int mOrderedCountOutgoing;
		int mOrderedCountOutgoing2;
		ushort mOrderedStampLast;
		ushort mOrderedStampLast2;

		typedef int (UdpConnection::* IEncryptFunction)(uchar *destData, const uchar *sourceData, int sourceLen);
		typedef int (UdpConnection::* IDecryptFunction)(uchar *destData, const uchar *sourceData, int sourceLen);
		IEncryptFunction mEncryptFunction[UdpManager::cEncryptPasses];
		IDecryptFunction mDecryptFunction[UdpManager::cEncryptPasses];

		uchar *mEncryptXorBuffer;
		int mEncryptExpansionBytes;

		uint mSyncTimeDelta;
		int mSyncStatTotal;
		int mSyncStatCount;
		int mSyncStatLow;
		int mSyncStatHigh;
		int mSyncStatLast;
		int mSyncStatMasterRoundTime;
		UdpMisc::ClockStamp mSyncStatMasterFixupTime;

		bool mGettingTime;
		UdpConnectionHandler *mHandler;
		
		int mKeepAliveDelay;

		UdpMisc::ClockStamp mIcmpErrorRetryStartStamp;
		UdpMisc::ClockStamp mPortRemapRequestStartStamp;

		UdpMisc::ClockStamp mDisconnectFlushStamp;
		int mDisconnectFlushTimeout;


			// data rate management functions
		enum { cBinResolution = 25, cBinCount = 1000 / cBinResolution };
		int mLastSendBin;
		int mLastReceiveBin;
		int mOutgoingBytesLastSecond;
		int mIncomingBytesLastSecond;
		int mSendBin[cBinCount];
		int mReceiveBin[cBinCount];



			// note: cUdpPacketReliable, cUdpPacketFragment both indicate a reliable-packet header.  They are marked
			// differently such that we can support large packets without any additional header overhead, a fragment marked packet means
			// that the packet is part of a larger packet being assembled.  The first fragment has an additional 4 bytes on the header specifying
			// the length to follow.  The order of those entries is important
		enum UdpPacketType { cUdpPacketZeroEscape, cUdpPacketConnect, cUdpPacketConfirm, cUdpPacketMulti, cUdpPacketBig
						, cUdpPacketTerminate, cUdpPacketKeepAlive
						, cUdpPacketClockSync, cUdpPacketClockReflect
						, cUdpPacketReliable1, cUdpPacketReliable2, cUdpPacketReliable3, cUdpPacketReliable4
						, cUdpPacketFragment1, cUdpPacketFragment2, cUdpPacketFragment3, cUdpPacketFragment4
						, cUdpPacketAck1, cUdpPacketAck2, cUdpPacketAck3, cUdpPacketAck4
						, cUdpPacketAckAll1, cUdpPacketAckAll2, cUdpPacketAckAll3, cUdpPacketAckAll4
						, cUdpPacketGroup, cUdpPacketOrdered, cUdpPacketOrdered2, cUdpPacketPortAlive
						, cUdpPacketUnreachableConnection, cUdpPacketRequestRemap };

			//////////////////////////////////////////////////////////////////////////////////////////////////////
			// The following structs represent what the internal packets look like.  In practice, most of these
			// structs are never used and exist only for documentation clarity.  Internally packets are
			// manually assembled such that struct packing and byte-ordering issues won't be an issue.
			//////////////////////////////////////////////////////////////////////////////////////////////////////
		struct UdpPacketConnect
		{
			uchar zeroByte;
			uchar packetType;
			int protocolVersion;
			int connectCode;
			int maxRawPacketSize;
		};

		struct UdpPacketConfirm
		{
			uchar zeroByte;
			uchar packetType;
			int connectCode;
			Configuration config;
			int maxRawPacketSize;
		};

		struct UdpPacketTerminate
		{
			uchar zeroByte;
			uchar packetType;
			int connectCode;
		};

		struct UdpPacketKeepAlive
		{
			uchar zeroByte;
			uchar packetType;
		};

		struct UdpPacketGroup
		{
				// this format is prepped by the GroupLogicalPacket object, which reports itself to the UdpConnection object as an internal packet
				// type such that it doesn't get treated as an application-packet even though the application is the one sending it
			uchar zeroByte;
			uchar packetType;
				// variableValue/data, repeated...
		};

		struct UdpPacketClockSync
		{
			uchar zeroByte;
			uchar packetType;
			ushort timeStamp;
			int masterPingTime;
			int averagePingTime;
			int lowPingTime;
			int highPingTime;
			int lastPingTime;
			udp_int64 ourSent;	
			udp_int64 ourReceived;
		};

		struct UdpPacketClockReflect
		{
			uchar zeroByte;
			uchar packetType;
			ushort timeStamp;
			uint serverSyncStampLong;
			udp_int64 yourSent;
			udp_int64 yourReceived;
			udp_int64 ourSent;
			udp_int64 ourReceived;
		};

		struct UdpPacketReliable
		{
			uchar zeroByte;
			uchar packetType;
			ushort reliableStamp;
		};

		struct UdpPacketReliableFragmentStart
		{
			UdpPacketReliable reliable;
			int length;
		};

		struct UdpPacketAck
		{
			uchar zeroByte;
			uchar packetType;
			ushort reliableStamp;
		};

		struct UdpPacketOrdered
		{
			uchar zeroByte;
			uchar packetType;
			ushort orderStamp;
		};


		enum { cUdpPacketReliableSize = 4 };
		enum { cUdpPacketOrderedSize = 4 };
		enum { cUdpPacketConnectSize = 14 };
};

	//////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The purpose of this class is to manage the reliable transmission of packets on top of the inherently
	// unreliable UDP layer.  This is an internal object and should not be manually created or talked to by the user.
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////
class UdpReliableChannel
{
	protected:
		friend class UdpConnection;

		UdpReliableChannel(int channelNumber, UdpConnection *connection, UdpManager::ReliableConfig *config);
		~UdpReliableChannel();
		void GetChannelStatus(UdpConnection::ChannelStatus *channelStatus) const;
        int GetAveragePing() const;
		int TotalPendingBytes() const;		// returns total bytes outstanding

		void ReliablePacket(const uchar *data, int dataLen);
		void Send(const LogicalPacket *packet);
		void Send(const uchar *data, int dataLen, const uchar *data2, int dataLen2);
		void AckPacket(const uchar *data, int dataLen);
		void AckAllPacket(const uchar *data, int dataLen);
		void ClearBufferedAck();
		int GiveTime();

	protected:
		enum ReliablePacketMode { cReliablePacketModeReliable, cReliablePacketModeFragment, cReliablePacketModeDelivered };

		class PhysicalPacket
		{
			public:
				PhysicalPacket();
				~PhysicalPacket();

			public:
				UdpMisc::ClockStamp mFirstTimeStamp;
				UdpMisc::ClockStamp mLastTimeStamp;
				const LogicalPacket *mParent;			// physical packets hold an addref on the logical packet.  Once all of the logical packet data has been divied out to physical packets, the logical queue releases it
				const uchar *mDataPtr;				// within parent's data (it's possible it is not pointing to the beginning in the case of large packets)
				int mDataLen;
		};

		class IncomingQueueEntry
		{
			public:
				IncomingQueueEntry();
				~IncomingQueueEntry();

			public:
				LogicalPacket *mPacket;
				ReliablePacketMode mMode;
		};
		friend class IncomingQueueEntry;

		udp_int64 GetReliableOutgoingId(int reliableStamp) const;
		udp_int64 GetReliableIncomingId(int reliableStamp) const;
		void Ack(udp_int64 reliableId);
		void ProcessPacket(ReliablePacketMode mode, const uchar *data, int dataLen);
		bool PullDown(int windowSpaceLeft);
		void FlushCoalesce();
		void SendCoalesce(const uchar *data, int dataLen, const uchar *data2 = NULL, int dataLen2 = 0);
		void QueueLogicalPacket(const LogicalPacket *packet);

		UdpManager::ReliableConfig mConfig;
		UdpConnection *mUdpConnection;
		UdpMisc::ClockStamp mLastTimeStampAcknowledged;
		UdpMisc::ClockStamp mTrickleLastSend;
		UdpMisc::ClockStamp mNextNeedTime;
		int mChannelNumber;
		udp_int64 mReliableOutgoingId;
		udp_int64 mReliableOutgoingPendingId;
		int mReliableOutgoingBytes;
		int mLogicalBytesQueued;
		int mLogicalPacketsQueued;
		uchar *mBigDataPtr;
		int mBigDataLen;
		int mBigDataTargetLen;
		int mAveragePingTime;
		int mMaxDataBytes;
		int mFragmentNextPos;
		PhysicalPacket *mPhysicalPackets;
		const LogicalPacket *mLogicalRoot;
		const LogicalPacket *mLogicalEnd;

		int mCongestionWindowStart;
		int mCongestionWindowSize;
		int mCongestionWindowLargest;
		int mCongestionSlowStartThreshhold;
		int mCongestionWindowMinimum;
		bool mMaxxedOutCurrentWindow;

		udp_int64 mReliableIncomingId;
		IncomingQueueEntry *mReliableIncoming;

		LogicalPacket *mCoalescePacket;
		uchar *mCoalesceStartPtr;
		uchar *mCoalesceEndPtr;
		int mCoalesceCount;
		int mMaxCoalesceAttemptBytes;

		uchar *mBufferedAckPtr;

		int mStatDuplicatePacketsReceived;
		int mStatResentPacketsAccelerated;
		int mStatResentPacketsTimedOut;
};


		/////////////////////////////////////////////////////////////////////////
		// FixedLogicalPacket implementation
		/////////////////////////////////////////////////////////////////////////
template<int t_quickSize> FixedLogicalPacket<t_quickSize>::FixedLogicalPacket(const void *data, int dataLen)
{
	mDataLen = dataLen;
	if (data != NULL)
		memcpy(mData, data, mDataLen);
}

template<int t_quickSize> void *FixedLogicalPacket<t_quickSize>::GetDataPtr()
{
	return(mData);
}

template<int t_quickSize> const void *FixedLogicalPacket<t_quickSize>::GetDataPtr() const
{
	return(mData);
}

template<int t_quickSize> int FixedLogicalPacket<t_quickSize>::GetDataLen() const
{
	return(mDataLen);
}

template<int t_quickSize> void FixedLogicalPacket<t_quickSize>::SetDataLen(int len)
{
	mDataLen = len;
}


		/////////////////////////////////////////////////////////////////////////
		// StructLogicalPacket implementation
		/////////////////////////////////////////////////////////////////////////
template<typename T> StructLogicalPacket<T>::StructLogicalPacket(T *initData)
{
	if (initData != NULL)
		mStruct = *initData;
}

template<typename T> void *StructLogicalPacket<T>::GetDataPtr()
{
	return(&mStruct);
}

template<typename T> const void *StructLogicalPacket<T>::GetDataPtr() const
{
	return(&mStruct);
}

template<typename T> int StructLogicalPacket<T>::GetDataLen() const
{
	return(sizeof(mStruct));
}

template<typename T> void StructLogicalPacket<T>::SetDataLen(int len)
{
}


		/////////////////////////////////////////////////////////////////////////
		// inline implementations
		/////////////////////////////////////////////////////////////////////////

		// UdpMisc
inline int UdpMisc::ClockElapsed(ClockStamp stamp)
{
	ClockStamp t = (UdpMisc::Clock() - stamp);
	if (t > 2000000000)		// only time differences up to 23 days can be measured with this function
		return(2000000000);
	return((int)t);
}

inline int UdpMisc::ClockDiff(ClockStamp start, ClockStamp stop)
{
	ClockStamp t = (stop - start);
	if (t > 2000000000)		// only time differences up to 23 days can be measured with this function
		return(2000000000);
	return((int)t);
}

inline ushort UdpMisc::LocalSyncStampShort()
{
	return((ushort)(Clock() & 0xffff));
}

inline uint UdpMisc::LocalSyncStampLong()
{
	return((uint)(Clock() & 0xffffffff));
}


inline int UdpMisc::PutValue64(void *buffer, udp_int64 value)
{
	uchar *bufptr = (uchar *)buffer;
	*bufptr++ = (uchar)(value >> 56);
	*bufptr++ = (uchar)((value >> 48) & 0xff);
	*bufptr++ = (uchar)((value >> 40) & 0xff);
	*bufptr++ = (uchar)((value >> 32) & 0xff);
	*bufptr++ = (uchar)((value >> 24) & 0xff);
	*bufptr++ = (uchar)((value >> 16) & 0xff);
	*bufptr++ = (uchar)((value >> 8) & 0xff);
	*bufptr = (uchar)(value & 0xff);
	return(8);
}

inline udp_int64 UdpMisc::GetValue64(const void *buffer)
{
	const uchar *bufptr = (const uchar *)buffer;
	return(((udp_int64)*bufptr << 56) | ((udp_int64)*(bufptr + 1) << 48) | ((udp_int64)*(bufptr + 2) << 40) | ((udp_int64)*(bufptr + 3) << 32) | ((udp_int64)*(bufptr + 4) << 24) | ((udp_int64)*(bufptr + 5) << 16) | ((udp_int64)*(bufptr + 6) << 8) | (udp_int64)*(bufptr + 7));
}

inline int UdpMisc::PutValue32(void *buffer, uint value)
{
	uchar *bufptr = (uchar *)buffer;
	*bufptr++ = (uchar)(value >> 24);
	*bufptr++ = (uchar)((value >> 16) & 0xff);
	*bufptr++ = (uchar)((value >> 8) & 0xff);
	*bufptr = (uchar)(value & 0xff);
	return(4);
}

inline uint UdpMisc::GetValue32(const void *buffer)
{
	const uchar *bufptr = (const uchar *)buffer;
	return((*bufptr << 24) | (*(bufptr + 1) << 16) | (*(bufptr + 2) << 8) | *(bufptr + 3));
}

inline int UdpMisc::PutValue24(void *buffer, uint value)
{
	uchar *bufptr = (uchar *)buffer;
	*bufptr++ = (uchar)((value >> 16) & 0xff);
	*bufptr++ = (uchar)((value >> 8) & 0xff);
	*bufptr = (uchar)(value & 0xff);
	return(3);
}

inline uint UdpMisc::GetValue24(const void *buffer)
{
	const uchar *bufptr = (const uchar *)buffer;
	return((*bufptr << 16) | (*(bufptr + 1) << 8) | *(bufptr + 2));
}

inline int UdpMisc::PutValue16(void *buffer, ushort value)
{
	uchar *bufptr = (uchar *)buffer;
	*bufptr++ = (uchar)((value >> 8) & 0xff);
	*bufptr = (uchar)(value & 0xff);
	return(2);
}

inline ushort UdpMisc::GetValue16(const void *buffer)
{
	const uchar *bufptr = (const uchar *)buffer;
	return((ushort)((*bufptr << 8) | *(bufptr + 1)));
}

		// UdpManager
inline int UdpManager::LastReceive() const
{
	return(UdpMisc::ClockElapsed(mLastReceiveTime));
}

inline int UdpManager::LastSend() const
{
	return(UdpMisc::ClockElapsed(mLastSendTime));
}

inline int UdpManager::AddressHashValue(UdpIpAddress ip, int port) const
{
	return((int)((ip.GetAddress() ^ port) & 0x7fffffff));
}

inline void UdpManager::SetPriority(UdpConnection *con, UdpMisc::ClockStamp stamp)
{
		// do not ever let anybody schedule themselves for processing time sooner then mMinimumScheduledStamp
		// otherwise, they could end up getting processing time multiple times in a single UdpManager::GiveTime iteration
		// of the priority queue, which under odd circumstances could result in an infinite loop
	if (stamp < mMinimumScheduledStamp)
		stamp = mMinimumScheduledStamp;

	if (mPriorityQueue != NULL)
		mPriorityQueue->Add(con, stamp);
}

inline void UdpManager::SetHandler(UdpManagerHandler *handler)
{
	mParams.handler = handler;
}

inline UdpManagerHandler *UdpManager::GetHandler() const
{
	return(mParams.handler);
}

inline void UdpManager::PoolReturn(PooledLogicalPacket *packet)
{
	if (mPoolAvailable < mParams.pooledPacketMax)
	{
		packet->AddRef();
		mPoolAvailable++;
		packet->mAvailableNext = mPoolAvailableRoot;
		mPoolAvailableRoot = packet;
	}
}

inline void UdpManager::WrappedReturn(WrappedLogicalPacket *wp)
{
	wp->SetLogicalPacket(NULL);

	if (mWrappedAvailable < mParams.wrappedPoolMax)
	{
		wp->AddRef();
		mWrappedAvailable++;
		wp->mAvailableNext = mWrappedAvailableRoot;
		mWrappedAvailableRoot = wp;
	}
}

inline void UdpManager::AddRef()
{
	mRefCount++;
}

inline void UdpManager::Release()
{
	mRefCount--;
	if (mRefCount == 0)
		delete this;
}

inline int UdpManager::GetRefCount() const
{
	return(mRefCount);
}

inline void UdpManager::SetPassThroughData(void *passThroughData)
{
	mPassThroughData = passThroughData;
}

inline void *UdpManager::GetPassThroughData() const
{
	return(mPassThroughData);
}



		// UdpConnection
inline void UdpConnection::ScheduleTimeNow()
{
		// if we are current in our GiveTime function getting time, then there is no need to reprioritize to 0 when we send a raw packet, since
		// the last thing we do in out GiveTime is do a scheduling calculation based on the last time a packet was sent.  This little check
		// prevents us from reprioritizing to 0, only to shortly thereafter be reprioritized to where we actually belong.
	if (!mGettingTime)
	{
		if (mUdpManager != NULL)
			mUdpManager->SetPriority(this, 0);
	}
}

inline void UdpConnection::SetHandler(UdpConnectionHandler *handler)
{
	mHandler = handler;
}

inline UdpConnectionHandler *UdpConnection::GetHandler() const
{
	return(mHandler);
}

inline void UdpConnection::AddRef()
{
	mRefCount++;
}

inline void UdpConnection::Release()
{
	mRefCount--;
	if (mRefCount == 0)
		delete this;
}

inline bool UdpConnection::IsNonEncryptPacket(const uchar *data) const
{
	if (data[0] == 0)
	{
		if (data[1] == cUdpPacketConnect || data[1] == cUdpPacketConfirm || data[1] == cUdpPacketUnreachableConnection || data[1] == cUdpPacketRequestRemap)
			return(true);
	}
	return(false);
}


inline int UdpConnection::GetRefCount() const
{
	return(mRefCount);
}

inline int UdpConnection::GetEncryptCode() const
{
	return(mConnectionConfig.encryptCode);
}

inline int UdpConnection::GetConnectCode() const
{
	return(mConnectCode);
}

inline int UdpConnection::LastReceive(UdpMisc::ClockStamp useStamp) const
{
	return(UdpMisc::ClockDiff(mLastReceiveTime, useStamp));
}

inline int UdpConnection::LastReceive() const
{
	return(UdpMisc::ClockElapsed(mLastReceiveTime));
}

inline int UdpConnection::ConnectionAge() const
{
	return(UdpMisc::ClockElapsed(mConnectionCreateTime));
}

inline int UdpConnection::LastSend() const
{
	return(UdpMisc::ClockElapsed(mLastSendTime));
}

inline ushort UdpConnection::ServerSyncStampShort() const
{
	return((ushort)(UdpMisc::LocalSyncStampShort() + (mSyncTimeDelta & 0xffff)));
}

inline uint UdpConnection::ServerSyncStampLong() const
{
	return(UdpMisc::LocalSyncStampLong() + mSyncTimeDelta);
}

inline int UdpConnection::ServerSyncStampShortElapsed(ushort syncStamp) const
{
	return(UdpMisc::SyncStampShortDeltaTime(syncStamp, ServerSyncStampShort()));
}

inline int UdpConnection::ServerSyncStampLongElapsed(uint syncStamp) const
{
	return(UdpMisc::SyncStampLongDeltaTime(syncStamp, ServerSyncStampLong()));
}

inline UdpManager *UdpConnection::GetUdpManager() const
{
	return(mUdpManager);
}

inline UdpConnection::Status UdpConnection::GetStatus() const
{
	return(mStatus);
}

inline UdpConnection::DisconnectReason UdpConnection::GetDisconnectReason() const
{
	return(mDisconnectReason);
}

inline UdpConnection::DisconnectReason UdpConnection::GetOtherSideDisconnectReason() const
{
	return(mOtherSideDisconnectReason);
}

inline int UdpConnection::OutgoingBytesLastSecond()
{
	ExpireSendBin();
	return(mOutgoingBytesLastSecond);
}

inline int UdpConnection::IncomingBytesLastSecond()
{
	ExpireReceiveBin();
	return(mIncomingBytesLastSecond);
}

inline void UdpConnection::SetPassThroughData(void *passThroughData)
{
	mPassThroughData = passThroughData;
}

inline void *UdpConnection::GetPassThroughData() const
{
	return(mPassThroughData);
}

inline UdpIpAddress UdpConnection::GetDestinationIp() const
{
	return(mIp);
}

inline int UdpConnection::GetDestinationPort() const
{
	return(mPort);
}

inline void UdpConnection::SetNoDataTimeout(int noDataTimeout)
{
	mNoDataTimeout = noDataTimeout;
}

inline int UdpConnection::GetNoDataTimeout() const
{
	return(mNoDataTimeout);
}

inline void UdpConnection::Disconnect(int flushTimeout)
{
	InternalDisconnect(flushTimeout, cDisconnectReasonApplication);
}

inline void UdpConnection::SetKeepAliveDelay(int keepAliveDelay)
{
	mKeepAliveDelay = keepAliveDelay;
}

inline int UdpConnection::GetKeepAliveDelay() const
{
	return(mKeepAliveDelay);
}


		// UdpReliableChannel
inline void UdpReliableChannel::AckPacket(const uchar *data, int /*dataLen*/)
{
	Ack(GetReliableOutgoingId((ushort)UdpMisc::GetValue16(data + 2)));
}

inline int UdpReliableChannel::GetAveragePing() const
{
    return(mAveragePingTime);
}

inline int UdpReliableChannel::TotalPendingBytes() const
{
	return(mLogicalBytesQueued + mReliableOutgoingBytes);
}

inline void UdpReliableChannel::ClearBufferedAck()
{
	mBufferedAckPtr = NULL;
}

inline udp_int64 UdpReliableChannel::GetReliableOutgoingId(int reliableStamp) const
{
		// since we can never have anywhere close to 65000 packets outstanding, we only need to
		// to send the low order word of the reliableId in the UdpPacketReliable and UdpPacketAck
		// packets, because we can reconstruct the full id from that, we just need to take
		// into account the wrap around issue.  We calculate it based of the high-word of the
		// next packet we are going to send.  If it ends up being larger then we know
		// we wrapped and can fix it up by simply subtracting 1 from the high-order word.
	udp_int64 reliableId = reliableStamp | (mReliableOutgoingId & (~(udp_int64)0xffff));
	if (reliableId > mReliableOutgoingId)
		reliableId -= 0x10000;
	return(reliableId);
}

inline udp_int64 UdpReliableChannel::GetReliableIncomingId(int reliableStamp) const
{
		// since we can never have anywhere close to 65000 packets outstanding, we only need to
		// to send the low order word of the reliableId in the UdpPacketReliable and UdpPacketAck
		// packets, because we can reconstruct the full id from that, we just need to take
		// into account the wrap around issue.  We basically prepend the last-known
		// high-order word.  If we end up significantly below the head of our chain, then we
		// know we need to pick the entry 0x10000 higher.  If we fall significantly above
		// our previous high-end, then we know we need to go the other way.
	udp_int64 reliableId = reliableStamp | (mReliableIncomingId & (~(udp_int64)0xffff));
	if (reliableId < mReliableIncomingId - UdpManager::cHardMaxOutstandingPackets)
		reliableId += 0x10000;
	if (reliableId > mReliableIncomingId + UdpManager::cHardMaxOutstandingPackets)
		reliableId -= 0x10000;
	return(reliableId);
}

class UdpLibraryException
{
public:
	UdpLibraryException();
	~UdpLibraryException();
private:
};


#endif

