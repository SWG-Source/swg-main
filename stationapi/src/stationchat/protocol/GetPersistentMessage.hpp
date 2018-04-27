
#pragma once

#include "ChatEnums.hpp"
#include "PersistentMessage.hpp"

class PersistentMessageService;
class GatewayClient;

/** Begin GETPERSISTENTMESSAGE */

struct ReqGetPersistentMessage {
    const ChatRequestType type = ChatRequestType::GETPERSISTENTMESSAGE;
    uint32_t track;
    uint32_t srcAvatarId;
    uint32_t messageId;
};

template <typename StreamT>
void read(StreamT& ar, ReqGetPersistentMessage& data) {
    read(ar, data.track);
    read(ar, data.srcAvatarId);
    read(ar, data.messageId);
}

/** Begin GETPERSISTENTMESSAGE */

struct ResGetPersistentMessage {
    ResGetPersistentMessage(
        uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::GETPERSISTENTMESSAGE;
    uint32_t track;
    ChatResultCode result;
    PersistentMessage message;
};

template <typename StreamT>
void write(StreamT& ar, const ResGetPersistentMessage& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);

    if (data.result == ChatResultCode::SUCCESS) {
        write(ar, data.message);
    }
}

class GetPersistentMessage {
public:
    using RequestType = ReqGetPersistentMessage;
    using ResponseType = ResGetPersistentMessage;

    GetPersistentMessage(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    PersistentMessageService* messageService_;
};
