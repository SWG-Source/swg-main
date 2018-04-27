#ifndef UDPHANDLER_HPP
#define UDPHANDLER_HPP

class UdpManager;
class UdpConnection;
class LogicalPacket;

typedef unsigned char uchar;
typedef unsigned short ushort;
typedef unsigned int uint;
typedef unsigned long ulong;

enum UdpCorruptionReason { cUdpCorruptionNone
						 , cUdpCorruptionMultiPacket
						 , cUdpCorruptionReliablePacketTooShort
						 , cUdpCorruptionInternalPacketTooShort
						 , cUdpCorruptionDecryptFailed 
						 , cCorruptionReasonZeroLengthPacket
						 , cCorruptionReasonPacketShorterThanCrcBytes
                         };



class UdpManagerHandler
{
	public:
			// This function is called when a listening UdpManager receives a new connection request.  If the application wishes to
			// accept this connection, it is the responsibility of the application to AddRef the UdpConnection object such that it
			// doesn't get destroyed upon returning from the callback.  Additionally, the application should set the handler object
			// for the connection.  See sample code in the UdpLibrary.doc file for an example.
		virtual void OnConnectRequest(UdpConnection *con);

			// The following functions are called when user-supplied encryption is specified.  In particular, the functions may wish 
			// to query the connection object for the encryption-code it is using.  The encryption code is simply a randomly generated
			// 32-bit value that the client and server negotiated during the connection-establishment.  It can be used as a key
			// of sorts for encrypting data uniquely on a per-connection basis.  (see UdpConnection::GetEncryptCode())
		virtual int OnUserSuppliedEncrypt(UdpConnection *con, uchar *destData, const uchar *sourceData, int sourceLen);
		virtual int OnUserSuppliedDecrypt(UdpConnection *con, uchar *destData, const uchar *sourceData, int sourceLen);
		virtual int OnUserSuppliedEncrypt2(UdpConnection *con, uchar *destData, const uchar *sourceData, int sourceLen);
		virtual int OnUserSuppliedDecrypt2(UdpConnection *con, uchar *destData, const uchar *sourceData, int sourceLen);
};

class UdpConnectionHandler
{
	public:
			// This function is called whenever an application-packet is ready to be delivered to the application.
			// Packets will only ever be delivered to the application during UdpManager::GiveTime calls, so the application
			// has complete control of when it willing/able to receive packets.
		virtual void OnRoutePacket(UdpConnection *con, const uchar *data, int dataLen) = 0;

			// This function is called whenever a UdpManager::EstablishConnection call succeeds in establishing the connection.
			// Generally on client-side establishment of a connection, I prefer to sit in a tight loop polling the connection
			// to see if it has connected yet or not, rather than using this callback (see sample code)
			// note: If it is unable to establish the connection, the OnTerminated callback will be called.
			// note: this is a change from previous behavior, see release notes for details.
		virtual void OnConnectComplete(UdpConnection *con);

			// This function is called anytime the UdpConnection object changes to a cStatusDisconnected state.  Every UdpConnection
			// object is guaranteed to eventually call this once and only once, even connections that never successfully established.
			// note: this is a change from previous behavior, see release notes for details
		virtual void OnTerminated(UdpConnection *con);

			// This function is called anytime an incoming packet fails the CRC check.  Normally these packets are just ignored, as
			// corruption does occur from time to time; however, some applications may wish to log these events as often times, they
			// are an indication of somebody attempting to hack the data stream.
		virtual void OnCrcReject(UdpConnection *con, const uchar *data, int dataLen);

			// This function is called anytime a corrupt packet is sensed for some reason.
			// The reason we give a callback for it is because you may wish to log it as it could be an early indicator of
			// somebody trying to hack the protocol.
			
		virtual void OnPacketCorrupt(UdpConnection *con, const uchar *data, int dataLen, UdpCorruptionReason reason);
};

#endif

