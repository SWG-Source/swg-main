#include "RegistrarClient.hpp"

#include "ChatEnums.hpp"
#include "RegistrarNode.hpp"
#include "Serialization.hpp"
#include "StationChatConfig.hpp"
#include "StringUtils.hpp"

#include "protocol/RegistrarGetChatServer.hpp"

#include "easylogging++.h"

RegistrarClient::RegistrarClient(UdpConnection* connection, RegistrarNode* node)
    : NodeClient(connection)
    , node_{node} {
    connection->SetHandler(this);
}

RegistrarClient::~RegistrarClient() {}

RegistrarNode* RegistrarClient::GetNode() { return node_; }

void RegistrarClient::OnIncoming(std::istringstream& istream) {
    ChatRequestType request_type = ::read<ChatRequestType>(istream);

    switch (request_type) {
    case ChatRequestType::REGISTRAR_GETCHATSERVER: {
        auto request = ::read<ReqRegistrarGetChatServer>(istream);
        RegistrarGetChatServer::ResponseType response{request.track};

        try {
            RegistrarGetChatServer(this, request, response);
        } catch (const ChatResultException& e) {
            response.result = e.code;
            LOG(ERROR) << "ChatAPI Error: [" << static_cast<uint32_t>(e.code) << "] " << e.message;
        }

        Send(response);
    } break;
    default:
        LOG(ERROR) << "Invalid registrar message type received: "
                   << static_cast<uint16_t>(request_type);
        break;
    }
}
