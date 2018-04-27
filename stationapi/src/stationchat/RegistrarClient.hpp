
#pragma once

#include "NodeClient.hpp"

class RegistrarNode;
class UdpConnection;

struct ReqRegistrarGetChatServer;

class RegistrarClient : public NodeClient {
public:
    RegistrarClient(UdpConnection* connection, RegistrarNode* node);
    virtual ~RegistrarClient();

    RegistrarNode* GetNode();

private:
    void OnIncoming(std::istringstream& istream) override;

    RegistrarNode* node_;
};
