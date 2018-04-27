
#include "NodeClient.hpp"
#include "StreamUtils.hpp"

NodeClient::NodeClient(UdpConnection* connection)
    : connection_{connection}
    , ostream_{std::stringstream::out | std::stringstream::binary}
    , istream_{std::stringstream::in | std::stringstream::binary} {
    connection_->AddRef();
}

NodeClient::~NodeClient() {
    connection_->SetHandler(nullptr);
    connection_->Disconnect();
    connection_->Release();
}

void NodeClient::Send(const char* data, uint32_t length) {
    logNetworkMessage(
        connection_, "Message To ->", reinterpret_cast<const unsigned char*>(data), length);
    connection_->Send(cUdpChannelReliable1, data, length);
}

void NodeClient::OnRoutePacket(UdpConnection* connection, const uchar* data, int length) {
    logNetworkMessage(connection, "Message From <-", data, length);

    istream_.clear();
    istream_.str({reinterpret_cast<const char*>(data), static_cast<uint32_t>(length)});
    OnIncoming(istream_);
}
