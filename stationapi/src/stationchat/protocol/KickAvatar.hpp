
#pragma once

#include "ChatEnums.hpp"

class ChatAvatarService;
class ChatRoomService;
class GatewayClient;

/** Begin KICKAVATAR */

struct ReqKickAvatar {
    const ChatRequestType type = ChatRequestType::KICKAVATAR;
    uint32_t track;
    uint32_t srcAvatarId;
    std::u16string destAvatarName;
    std::u16string destAvatarAddress;
    std::u16string destRoomAddress;
    std::u16string srcAddress;
};

template <typename StreamT>
void read(StreamT& ar, ReqKickAvatar& data) {
    read(ar, data.track);
    read(ar, data.srcAvatarId);
    read(ar, data.destAvatarName);
    read(ar, data.destAvatarAddress);
    read(ar, data.destRoomAddress);
    read(ar, data.srcAddress);
}

/** Begin KICKAVATAR */

struct ResKickAvatar {
    ResKickAvatar(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::KICKAVATAR;
    uint32_t track;
    ChatResultCode result;
    uint32_t destRoomId;
};

template <typename StreamT>
void write(StreamT& ar, const ResKickAvatar& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);
    write(ar, data.destRoomId);
}

class KickAvatar {
public:
    using RequestType = ReqKickAvatar;
    using ResponseType = ResKickAvatar;

    KickAvatar(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatAvatarService* avatarService_;
    ChatRoomService* roomService_;
};
