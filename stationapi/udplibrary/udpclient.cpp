#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <assert.h>
#ifdef WIN32
#include <conio.h>
#endif
#include <ctype.h>
#include <sys\stat.h>
#include <sys\types.h>
#include <math.h>
#include <malloc.h>

#include <windows.h>

#ifdef WIN32
#ifdef _DEBUG
	#include <crtdbg.h>
#endif
#endif

#include "UdpLibrary.hpp"


class MyConnectionHandler : public UdpConnectionHandler
{
	public:
		virtual void OnRoutePacket(UdpConnection *con, const uchar *data, int dataLen);
};


int main(int argc, char **argv)
{
#ifdef _DEBUG
	_CrtSetDbgFlag(_CrtSetDbgFlag(_CRTDBG_REPORT_FLAG) | _CRTDBG_LEAK_CHECK_DF);
#endif

	printf("UdpLibrary Test Client, press SHIFT-F12 to terminate.\n");
	printf("	/IP:xxx.xxx.xxx.xxx\n");
	printf("	/PORT:xxx\n");

	char connectIp[256];
	strcpy(connectIp, "127.0.0.1");
	int connectPort = 9950;
	for (int i = 0; i < argc; i++)
	{
		if (memicmp(argv[i], "/IP:", 4) == 0)
			strcpy(connectIp, argv[i] + 4);
		if (memicmp(argv[i], "/PORT:", 6) == 0)
			connectPort = atoi(argv[i] + 6);
	}

		//////////////////////////////////////////////////
		// initialize everything
		//////////////////////////////////////////////////
	srand(clock());
	UdpManager::Params params;
	params.clockSyncDelay = 45000;
	params.crcBytes = 2;
	params.hashTableSize = 10;
	params.incomingBufferSize = 32 * 1024;
	params.keepAliveDelay = 8000;
	params.portAliveDelay = 5000;
	params.maxConnections = 3;
	params.maxDataHoldSize = 400;
	params.maxDataHoldTime = 60;
	params.maxRawPacketSize = 496;
	params.outgoingBufferSize = 32 * 1024;
	params.packetHistoryMax = 1000;
	params.port = 0;
	params.pooledPacketMax = 50;
	params.pooledPacketSize = 512;

#if 0
	params.simulateIncomingByteRate = 0;
	params.simulateIncomingLossPercent = 10;
	params.simulateOutgoingByteRate = 0;
	params.simulateOutgoingLossPercent = 10;
	params.simulateDestinationOverloadLevel = 0;
	params.simulateOutgoingOverloadLevel = 0;
#endif

	params.reliable[0].maxInstandingPackets = 500;
	params.reliable[0].maxOutstandingBytes = 200000;
	params.reliable[0].maxOutstandingPackets = 500;
	params.reliable[0].outOfOrder = false;
	params.reliable[0].trickleRate = 0;
	params.reliable[0].trickleSize = 0;
	params.reliable[0].processOnSend = true;
	params.reliable[1].maxInstandingPackets = 20;
	params.reliable[1].maxOutstandingBytes = 5000;
	params.reliable[1].maxOutstandingPackets = 30;
	params.reliable[1].outOfOrder = false;
	params.reliable[1].trickleRate = 200;
	params.reliable[1].trickleSize = 200;
	params.reliable[2] = params.reliable[0];
	params.reliable[2].outOfOrder = true;
	params.reliable[3] = params.reliable[1];
	params.reliable[3].outOfOrder = true;
	UdpManager *myUdpManager = new UdpManager(&params);


		// establish connection
	MyConnectionHandler myConnectionHandler;
	printf("Connecting to: %s,%d.", connectIp, connectPort);
	UdpConnection *myConnection = myUdpManager->EstablishConnection(connectIp, connectPort);
	myConnection->SetHandler(&myConnectionHandler);
	assert(myConnection != NULL);
	int count = 0;
	while (myConnection->GetStatus() == UdpConnection::cStatusNegotiating)
	{
		myUdpManager->GiveTime();
		Sleep(50);
		if ((count++ % 20) == 0)
			printf(".");
	}
	printf("\n");

	

		//////////////////////////////////////////////////
		// master loop (sending data)
		//////////////////////////////////////////////////
	count = 0;
	for (;;)
	{
			// check for shutdown keys
		if (kbhit())
		{
			int k = getch();
			if ((k == 0 || k == 0xe0) && (getch() == 0x88))		// hit shift-F12 to exit gracefully
				break;
			if (k == 32)
			{
					// hit space bar to see statistics
				UdpConnectionStatistics stats;
				myConnection->GetStats(&stats);
				char hold[256];
				printf("%s,%d  AVE=%d HIGH=%d LOW=%d MSTR=%d,%d CRC=%I64d ORD=%I64d  %I64d<<%I64d  %I64d>>%I64d\n", myConnection->GetDestinationIp().GetAddress(hold), myConnection->GetDestinationPort()
							, stats.averagePingTime, stats.highPingTime, stats.lowPingTime, stats.masterPingTime, stats.masterPingAge, stats.crcRejectedPackets, stats.orderRejectedPackets, stats.syncOurReceived, stats.syncTheirSent
							, stats.syncOurSent, stats.syncTheirReceived);
			}

			if (k == 'd')
			{
				myConnection->Disconnect(5000);		// disconnect when channel is clear
				printf("Disconnecting...  (giving connection time to flush)\n");
			}
		}

			// see if server terminated out connection, if so, break out and exit app
		if (myConnection->GetStatus() == UdpConnection::cStatusDisconnected)
		{
			printf("Connection broken.\n");
			break;
		}


#if 1
			// randomly send a medium sized packet on a random channel
		if (rand() % 200 == 0)
		{
			char buf[8000];
			for (int i = 1; i < sizeof(buf); i++)
			{
				buf[i] = (char)(i % 100);
			}

			int pc = rand() % 5;
			for (i = 0; i < pc; i++)
			{
				buf[0] = (char)(rand() % 50);
				int len = (rand() % 1800 + 2);
				printf("OUTLEN=%d  \n", len);
				myConnection->Send(cUdpChannelReliable1, buf, len);
			}
		}
#elif 0
			// send a very large packet one after the other (don't send next packet til the previous one has made it)
		if (myConnection->TotalPendingBytes() == 0)
		{
				// send another packet
			SimpleLogicalPacket *lp = new SimpleLogicalPacket(NULL, 30000000);
			int dlen = lp->GetDataLen();
			char *ptr = (char *)lp->GetDataPtr();

			ptr[0] = (char)(rand() % 50);
			for (int i = 1; i < dlen; i++)
			{
				ptr[i] = (char)(i % 100);
			}

			printf("OUT LEN=%d  \n", dlen);
			myConnection->Send(cUdpChannelReliable1, lp);
			lp->Release();
		}
#else
			// prepare a random sized group of medium packets and then send the group, don't prepare next group until previous one has made it
		UdpConnection::ChannelStatus cs;
		myConnection->GetChannelStatus(cUdpChannelReliable1, &cs);
		if (cs.queuedBytes == 0)
		{
			int count = 0;
			GroupLogicalPacket *glp = new GroupLogicalPacket();
			int di = rand() % 20 + 1;
			for (int i = 0; i < di; i++)
			{
				GroupLogicalPacket *sub = new GroupLogicalPacket();
				for (int j = 0; j < di; j++)
				{
					char buf[8000];
					*(ushort *)buf = count;
					int len = (rand() % 1000) + 10;
					*(ushort *)(buf + len - 2) = count;
					sub->AddPacket(buf, len);
					count++;
				}
				glp->AddPacket(sub);
				sub->Release();
			}
			myConnection->Send(cUdpChannelReliable1, glp);
			glp->Release();
			printf("Group of %d packets sent\n", count);
		}
#endif

		myUdpManager->GiveTime();
		Sleep(10);
	}

		//////////////////////////////////////////////////
		// terminate everything
		//////////////////////////////////////////////////
	myConnection->Release();
	myUdpManager->Release();
	return(0);
}


void MyConnectionHandler::OnRoutePacket(UdpConnection * /*con*/, const uchar *data, int dataLen)
{
	printf("IN=%d/%d LEN=%d    \n", *(ushort *)data, *(ushort *)(data + dataLen - 2), dataLen);
}

