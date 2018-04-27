#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <assert.h>
#include <conio.h>
#include <ctype.h>
#include <sys\stat.h>
#include <sys\types.h>
#include <math.h>
#include <malloc.h>

#include <windows.h>
#include <winsock.h>
#ifdef _DEBUG
	#include <crtdbg.h>
#endif

#include "UdpLibrary.hpp"

class Player : public UdpConnectionHandler
{
	public:
		Player(UdpConnection *con);
		virtual ~Player();
		virtual void OnRoutePacket(UdpConnection *con, const uchar *data, int dataLen);
	public:
		UdpConnection *mConnection;
};

class PlayerManager : public UdpManagerHandler
{
	public:
		PlayerManager();
		~PlayerManager();

		void AddPlayer(Player *player);
		void GiveTime();
		void DumpStats();
		void SendPacketToAll(UdpChannel channel, void *data, int dataLen);

		virtual void OnConnectRequest(UdpConnection *con);

	protected:
		Player *mPlayers[5000];
		int mPlayersCount;
		UdpMisc::ClockStamp mStartPacketTime;
		int mLastIncomingLargeSoFar;
};




void MyCallbackRoutePacket(void *mainPassThrough, UdpConnection *con, const uchar *data, int dataLen);
void MyCallbackConnectRequest(void *mainPassThrough, UdpConnection *con);

UdpManager *myUdpManager;

int main(int argc, char **argv)
{
	printf("UdpLibrary Test Server, press SHIFT-F12 to terminate.\n");
	printf("	/PORT:xxx\n");

	int listenPort = 9950;
	for (int i = 0; i < argc; i++)
	{
		if (memicmp(argv[i], "/PORT:", 6) == 0)
			listenPort = atoi(argv[i] + 6);
	}

#ifdef _DEBUG
	_CrtSetDbgFlag(_CrtSetDbgFlag(_CRTDBG_REPORT_FLAG) | _CRTDBG_LEAK_CHECK_DF);
#endif

		//////////////////////////////////////////////////
		// initialize everything
		//////////////////////////////////////////////////
	srand(clock());

	PlayerManager *myPlayerManager = new PlayerManager();

	UdpManager::Params params;
	params.handler = myPlayerManager;
	params.crcBytes = 2;
	params.encryptMethod[0] = UdpManager::cEncryptMethodXorBuffer;
	params.hashTableSize = 1000;
	params.incomingBufferSize = 256 * 1024;
	params.outgoingBufferSize = 256 * 1024;
	params.clockSyncDelay = 0;
	params.keepAliveDelay = 0;
	params.maxConnections = 4000;
	params.maxDataHoldSize = 400;
	params.maxDataHoldTime = 60;
	params.maxRawPacketSize = 256;
	params.packetHistoryMax = 1000;
	params.port = listenPort;
	params.pooledPacketMax = 5000;
	params.pooledPacketSize = 512;

#if 0
	params.simulateIncomingByteRate = 2000;
	params.simulateIncomingLossPercent = 0;
	params.simulateOutgoingByteRate = 2000;
	params.simulateOutgoingLossPercent = 0;
	params.simulateDestinationOverloadLevel = 8000;
	params.simulateOutgoingOverloadLevel = 8000;
#endif
	params.reliable[0].maxInstandingPackets = 500;
	params.reliable[0].maxOutstandingBytes = 200000;
	params.reliable[0].maxOutstandingPackets = 500;
	params.reliable[0].outOfOrder = false;
	params.reliable[0].trickleRate = 0;
	params.reliable[0].trickleSize = 0;
	params.reliable[1].maxInstandingPackets = 30;
	params.reliable[1].maxOutstandingBytes = 200000;
	params.reliable[1].maxOutstandingPackets = 30;
	params.reliable[1].outOfOrder = false;
	params.reliable[1].trickleRate = 200;
	params.reliable[1].trickleSize = 200;
	params.reliable[2] = params.reliable[0];
	params.reliable[2].outOfOrder = true;
	params.reliable[3] = params.reliable[1];
	params.reliable[3].outOfOrder = true;
	myUdpManager = new UdpManager(&params);

		//////////////////////////////////////////////////
		// master loop (processing incoming data/connections)
		//////////////////////////////////////////////////
	printf("Listening on port %d\n", listenPort);
	int count = 0;
	for (;;)
	{
			// check for shutdown keys
		if (kbhit())
		{
			int k = getch();
			if ((k == 0 || k == 0xe0) && (getch() == 0x88))
				break;
			if (k == 32)
				myPlayerManager->DumpStats();
		}

		if ((rand() % 300) == 0)
		{
			count++;
			char buf[2000];
			*(ushort *)buf = (ushort)count;
			int len = (rand() % 1000) + 10;
			*(ushort *)(buf + len - 2) = (ushort)count;
			myPlayerManager->SendPacketToAll(cUdpChannelReliable1, buf, len);
			printf("OUT=%d/%d  LEN=%d      \n", *(ushort *)buf, *(ushort *)(buf + len - 2), len);
		}

		myUdpManager->GiveTime();
		myPlayerManager->GiveTime();
		Sleep(10);
	}

		//////////////////////////////////////////////////
		// terminate everything
		//////////////////////////////////////////////////
	delete myPlayerManager;
	myUdpManager->Release();
	return(0);
}


	////////////////////////////////////////
	// Player implementation
	////////////////////////////////////////
Player::Player(UdpConnection *con)
{
	mConnection = con;
	mConnection->AddRef();
	mConnection->SetHandler(this);

	char hold[256];
	printf("CONNECTION %s,%d   \n", mConnection->GetDestinationIp().GetAddress(hold), mConnection->GetDestinationPort());
}

Player::~Player()
{
	char hold[256];
	printf("TERMINATE %s,%d   \n", mConnection->GetDestinationIp().GetAddress(hold), mConnection->GetDestinationPort());
	mConnection->SetHandler(NULL);
	mConnection->Disconnect();
	mConnection->Release();
}

void Player::OnRoutePacket(UdpConnection * /*con*/, const uchar *data, int dataLen)
{
	for (int i = 1; i < dataLen; i++)
	{
		bool match = (data[i] == (i % 100));
		assert(match);
	}

	char hold[256];
	printf("FROM=%s,%d  LEN=%d    \n", mConnection->GetDestinationIp().GetAddress(hold), mConnection->GetDestinationPort(), dataLen);

#if 0
		// reflect exact packet back to client
	mConnection->Send(cUdpChannelReliable1, data, dataLen);
#endif
}




	////////////////////////////////////////
	// PlayerManager implementation
	////////////////////////////////////////
PlayerManager::PlayerManager()
{
	mPlayersCount = 0;
	mStartPacketTime = 0;
	mLastIncomingLargeSoFar = 90000000;
}

PlayerManager::~PlayerManager()
{
	for (int i = mPlayersCount - 1; i >= 0; i--)
		delete mPlayers[i];
}

void PlayerManager::OnConnectRequest(UdpConnection *con)
{
	AddPlayer(new Player(con));
}

void PlayerManager::AddPlayer(Player *player)
{
	mPlayers[mPlayersCount++] = player;
}

void PlayerManager::GiveTime()
{
		// see if the player object is no longer connected
	for (int i = 0; i < mPlayersCount; i++)
	{
		if (mPlayers[i]->mConnection->GetStatus() == UdpConnection::cStatusDisconnected || mPlayers[i]->mConnection->LastReceive() > 2000000)
		{
			Player *p = mPlayers[i];
			mPlayersCount--;
			memmove(&mPlayers[i], &mPlayers[i + 1], (mPlayersCount - i) * sizeof(Player *));
			i--;
			delete p;
		}
	}

	if (mPlayersCount > 0)
	{
		UdpConnection::ChannelStatus cs;
		mPlayers[0]->mConnection->GetChannelStatus(cUdpChannelReliable1, &cs);
		UdpManagerStatistics ms;
		myUdpManager->GetStats(&ms);
		if (cs.incomingLargeSoFar < mLastIncomingLargeSoFar)
			mStartPacketTime = UdpMisc::Clock();

		mLastIncomingLargeSoFar = cs.incomingLargeSoFar;
		int e = UdpMisc::ClockElapsed(mStartPacketTime);
		if (e > 0)
			fprintf(stderr, "%d of %d (%d bps)(%d)  \r", cs.incomingLargeSoFar, cs.incomingLargeTotal, (int)(((__int64)cs.incomingLargeSoFar * 1000) / (__int64)e), ms.packetsReceived);
	}
}

void PlayerManager::SendPacketToAll(UdpChannel channel, void *data, int dataLen)
{
	LogicalPacket *lp = myUdpManager->CreatePacket(data, dataLen);
	for (int i = 0; i < mPlayersCount; i++)
	{
		mPlayers[i]->mConnection->Send(channel, lp);
	}
	lp->Release();
}

void PlayerManager::DumpStats()
{
	for (int i = 0; i < mPlayersCount; i++)
	{
		UdpConnectionStatistics stats;
		mPlayers[i]->mConnection->GetStats(&stats);

		char hold[256];
		printf("%s,%d  AVE=%d HIGH=%d LOW=%d MSTR=%d,%d CRC=%I64d ORD=%I64d  %I64d<<%I64d  %I64d>>%I64d\n", mPlayers[i]->mConnection->GetDestinationIp().GetAddress(hold), mPlayers[i]->mConnection->GetDestinationPort()
					, stats.averagePingTime, stats.highPingTime, stats.lowPingTime, stats.masterPingTime, stats.masterPingAge, stats.crcRejectedPackets, stats.orderRejectedPackets, stats.syncOurReceived, stats.syncTheirSent
					, stats.syncOurSent, stats.syncTheirReceived);
	}
}

