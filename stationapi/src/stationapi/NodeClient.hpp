
#pragma once

#include "UdpLibrary.hpp"

#include <sstream>

class NodeClient : public UdpConnectionHandler {
public:
    explicit NodeClient(UdpConnection* connection);

    virtual ~NodeClient();

    template <typename T>
    void Send(const T& message) {
        ostream_.clear();
        ostream_.str("");
        write(ostream_, message);
        auto data = ostream_.str();
        Send(data.c_str(), data.length());
    }

    UdpConnection* GetConnection() { return connection_; }

private:
    void Send(const char* data, uint32_t length);

    virtual void OnIncoming(std::istringstream& istream) = 0;

    void OnRoutePacket(UdpConnection* connection, const uchar* data, int length) override;

    std::ostringstream ostream_;
    std::istringstream istream_;
    UdpConnection* connection_;
};
