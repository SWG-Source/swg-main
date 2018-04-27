
#pragma once

#include "ChatEnums.hpp"

class ChatAvatarService;
class ChatRoomService;
class GatewayClient;

/** Begin SENDINSTANTMESSAGE */

struct ReqSendInstantMessage {
    const ChatRequestType type = ChatRequestType::SENDINSTANTMESSAGE;
    uint32_t track;
    uint32_t srcAvatarId;
    std::u16string destName;
    std::u16string destAddress;
    std::u16string message;
    std::u16string oob;
    std::u16string srcAddress;
};

template <typename StreamT>
void read(StreamT& ar, ReqSendInstantMessage& data) {
    read(ar, data.track);
    read(ar, data.srcAvatarId);
    read(ar, data.destName);
    read(ar, data.destAddress);
    read(ar, data.message);
    read(ar, data.oob);
    read(ar, data.srcAddress);
}

/** Begin SENDINSTANTMESSAGE */

struct ResSendInstantMessage {
    ResSendInstantMessage(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::SENDINSTANTMESSAGE;
    uint32_t track;
    ChatResultCode result;
};

template <typename StreamT>
void write(StreamT& ar, const ResSendInstantMessage& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);
}

class SendInstantMessage {
public:
    using RequestType = ReqSendInstantMessage;
    using ResponseType = ResSendInstantMessage;

    SendInstantMessage(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatAvatarService* avatarService_;
};
