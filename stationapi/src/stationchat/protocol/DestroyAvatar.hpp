
#pragma once

#include "ChatEnums.hpp"

class ChatAvatarService;
class ChatRoomService;
class GatewayClient;

/** Begin DESTROYAVATAR */

struct ReqDestroyAvatar {
    const ChatRequestType type = ChatRequestType::LOGOUTAVATAR;
    uint32_t track;
    uint32_t avatarId;
    std::u16string address;
};

template <typename StreamT>
void read(StreamT& ar, ReqDestroyAvatar& data) {
    read(ar, data.track);
    read(ar, data.avatarId);
    read(ar, data.address);
}

/** Begin DESTROYAVATAR */

struct ResDestroyAvatar {
    explicit ResDestroyAvatar(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::DESTROYAVATAR;
    uint32_t track;
    ChatResultCode result;
};

template <typename StreamT>
void write(StreamT& ar, const ResDestroyAvatar& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);
}

class DestroyAvatar {
public:
    using RequestType = ReqDestroyAvatar;
    using ResponseType = ResDestroyAvatar;

    DestroyAvatar(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatAvatarService* avatarService_;
    ChatRoomService* roomService_;
};
