
#pragma once

#include "ChatEnums.hpp"

#include <cstdint>
#include <string>

class ChatAvatarService;
class ChatRoomService;
class GatewayClient;

struct ReqFailoverReLoginAvatar{
    const ChatRequestType type = ChatRequestType::FAILOVER_RELOGINAVATAR;
    uint32_t track;
    uint32_t avatarId;
    uint32_t userId;
    std::u16string name;
    std::u16string address;
    std::u16string loginLocation;
    int32_t loginPriority;
    uint32_t attributes;
};

struct ResFailoverReLoginAvatar {
    ResFailoverReLoginAvatar(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::FAILOVER_RELOGINAVATAR;
    uint32_t track;
    ChatResultCode result;
};

class FailoverReLoginAvatar {
public:
    using RequestType = ReqFailoverReLoginAvatar;
    using ResponseType = ResFailoverReLoginAvatar;

    FailoverReLoginAvatar(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatAvatarService* avatarService_;
    ChatRoomService* roomService_;
};

template <typename StreamT>
void read(StreamT& ar, ReqFailoverReLoginAvatar& data) {
    read(ar, data.track);
    read(ar, data.avatarId);
    read(ar, data.userId);
    read(ar, data.name);
    read(ar, data.address);
    read(ar, data.loginLocation);
    read(ar, data.loginPriority);
    read(ar, data.attributes);
}

template <typename StreamT>
void write(StreamT& ar, const ResFailoverReLoginAvatar& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);
}