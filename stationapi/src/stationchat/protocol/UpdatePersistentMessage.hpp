
#pragma once

#include "ChatEnums.hpp"
#include "PersistentMessage.hpp"

class PersistentMessageService;
class GatewayClient;

/** Begin UPDATEPERSISTENTMESSAGE */

struct ReqUpdatePersistentMessage {
    const ChatRequestType type = ChatRequestType::UPDATEPERSISTENTMESSAGE;
    uint32_t track;
    uint32_t srcAvatarId;
    uint32_t messageId;
    PersistentState status;
};

template <typename StreamT>
void read(StreamT& ar, ReqUpdatePersistentMessage& data) {
    read(ar, data.track);
    read(ar, data.srcAvatarId);
    read(ar, data.messageId);
    read(ar, data.status);
}

/** Begin UPDATEPERSISTENTMESSAGE */

struct ResUpdatePersistentMessage {
    ResUpdatePersistentMessage(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::UPDATEPERSISTENTMESSAGE;
    uint32_t track;
    ChatResultCode result;
};

template <typename StreamT>
void write(StreamT& ar, const ResUpdatePersistentMessage& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);
}

class UpdatePersistentMessage {
public:
    using RequestType = ReqUpdatePersistentMessage;
    using ResponseType = ResUpdatePersistentMessage;

    UpdatePersistentMessage(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    PersistentMessageService* messageService_;
};
