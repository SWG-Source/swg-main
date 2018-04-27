
#pragma once

#include "ChatEnums.hpp"

class ChatAvatarService;
class ChatRoomService;
class GatewayClient;

/** Begin SENDROOMMESSAGE */

struct ReqSendRoomMessage {
    const ChatRequestType type = ChatRequestType::SENDROOMMESSAGE;
    uint32_t track;
    uint32_t srcAvatarId;
    std::u16string destRoomAddress;
    std::u16string message;
    std::u16string oob;
    std::u16string srcAddress;
};

template <typename StreamT>
void read(StreamT& ar, ReqSendRoomMessage& data) {
    read(ar, data.track);
    read(ar, data.srcAvatarId);
    read(ar, data.destRoomAddress);
    read(ar, data.message);
    read(ar, data.oob);
    read(ar, data.srcAddress);
}

/** Begin SENDROOMMESSAGE */

struct ResSendRoomMessage {
    explicit ResSendRoomMessage(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    ResSendRoomMessage(uint32_t track_, ChatResultCode result_, uint32_t roomId_)
        : track{track_}
        , result{result_}
        , roomId{roomId_} {}

    const ChatResponseType type = ChatResponseType::SENDROOMMESSAGE;
    uint32_t track;
    ChatResultCode result;
    uint32_t roomId;
};

template <typename StreamT>
void write(StreamT& ar, const ResSendRoomMessage& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);
    write(ar, data.roomId);
}

class SendRoomMessage {
public:
    using RequestType = ReqSendRoomMessage;
    using ResponseType = ResSendRoomMessage;

    SendRoomMessage(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatAvatarService* avatarService_;
    ChatRoomService* roomService_;
};
