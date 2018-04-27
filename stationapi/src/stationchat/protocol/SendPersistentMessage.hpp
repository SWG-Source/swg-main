
#pragma once

#include "ChatEnums.hpp"

class ChatAvatarService;
class PersistentMessageService;
class GatewayClient;

/** Begin SENDPERSISTENTMESSAGE */

struct ReqSendPersistentMessage {
    const ChatRequestType type = ChatRequestType::SENDPERSISTENTMESSAGE;
    uint32_t track;
    uint16_t avatarPresence;
    uint32_t srcAvatarId;
    std::u16string srcName;
    std::u16string destName;
    std::u16string destAddress;
    std::u16string subject;
    std::u16string msg;
    std::u16string oob;
    std::u16string category;
    bool enforceInboxLimit;
    uint32_t categoryLimit;
};

template <typename StreamT>
void read(StreamT& ar, ReqSendPersistentMessage& data) {
    read(ar, data.track);
    read(ar, data.avatarPresence);

    if (data.avatarPresence) {
        read(ar, data.srcAvatarId);
    } else {
        read(ar, data.srcName);
    }

    read(ar, data.destName);
    read(ar, data.destAddress);
    read(ar, data.subject);
    read(ar, data.msg);
    read(ar, data.oob);
    read(ar, data.category);
    read(ar, data.enforceInboxLimit);
    read(ar, data.categoryLimit);
}

/** Begin SENDPERSISTENTMESSAGE */

struct ResSendPersistentMessage {
    ResSendPersistentMessage(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::SENDPERSISTENTMESSAGE;
    uint32_t track;
    ChatResultCode result;
    uint32_t messageId;
};

template <typename StreamT>
void write(StreamT& ar, const ResSendPersistentMessage& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);

    if (data.result == ChatResultCode::SUCCESS) {
        write(ar, data.messageId);
    }
}

class SendPersistentMessage {
public:
    using RequestType = ReqSendPersistentMessage;
    using ResponseType = ResSendPersistentMessage;

    SendPersistentMessage(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatAvatarService* avatarService_;
    PersistentMessageService* messageService_;
};
