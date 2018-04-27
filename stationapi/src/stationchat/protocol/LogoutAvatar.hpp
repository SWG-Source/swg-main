
#pragma once

#include "ChatEnums.hpp"

class ChatAvatarService;
class ChatRoomService;
class GatewayClient;

/** Begin LOGOUTAVATAR */

struct ReqLogoutAvatar {
    const ChatRequestType type = ChatRequestType::LOGOUTAVATAR;
    uint32_t track;
    uint32_t avatarId;
};

template <typename StreamT>
void read(StreamT& ar, ReqLogoutAvatar& data) {
    read(ar, data.track);
    read(ar, data.avatarId);
}

/** Begin LOGOUTAVATAR */

struct ResLogoutAvatar {
    explicit ResLogoutAvatar(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::LOGOUTAVATAR;
    uint32_t track;
    ChatResultCode result;
};

template <typename StreamT>
void write(StreamT& ar, const ResLogoutAvatar& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);
}


class LogoutAvatar {
public:
    using RequestType = ReqLogoutAvatar;
    using ResponseType = ResLogoutAvatar;

    LogoutAvatar(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatAvatarService* avatarService_;
    ChatRoomService* roomService_;
};
