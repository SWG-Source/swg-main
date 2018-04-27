
#pragma once

#include "ChatAvatar.hpp"
#include "ChatEnums.hpp"

class ChatAvatarService;
class ChatRoomService;
class GatewayClient;

/** Begin LOGINAVATAR */

struct ReqLoginAvatar {
    const ChatRequestType type = ChatRequestType::LOGINAVATAR;
    uint32_t track;
    uint32_t userId;
    std::u16string name;
    std::u16string address;
    std::u16string loginLocation;
    int32_t loginPriority;
    int32_t loginAttributes;
};

template <typename StreamT>
void read(StreamT& ar, ReqLoginAvatar& data) {
    read(ar, data.track);
    read(ar, data.userId);
    read(ar, data.name);
    read(ar, data.address);
    read(ar, data.loginLocation);
    read(ar, data.loginPriority);
    read(ar, data.loginAttributes);
}

/** Begin LOGINAVATAR */

struct ResLoginAvatar {
    explicit ResLoginAvatar(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::LOGINAVATAR;
    uint32_t track;
    ChatResultCode result;
    const ChatAvatar* avatar;
};

template <typename StreamT>
void write(StreamT& ar, const ResLoginAvatar& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);

    if (data.result == ChatResultCode::SUCCESS) {
        write(ar, data.avatar);
    }
}

class LoginAvatar {
public:
    using RequestType = ReqLoginAvatar;
    using ResponseType = ResLoginAvatar;

    LoginAvatar(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatAvatarService* avatarService_;
    ChatRoomService* roomService_;
};
