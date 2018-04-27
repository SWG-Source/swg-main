
#pragma once

#include "ChatAvatar.hpp"
#include "ChatEnums.hpp"

#include <string>

class ChatAvatarService;
class ChatRoomService;
class GatewayClient;

/** Begin FRIENDSTATUS */

struct ReqFriendStatus {
    const ChatRequestType type = ChatRequestType::FRIENDSTATUS;
    uint32_t track;
    uint32_t srcAvatarId;
    std::u16string srcAddress;
};

template <typename StreamT>
void read(StreamT& ar, ReqFriendStatus& data) {
    read(ar, data.track);
    read(ar, data.srcAvatarId);
    read(ar, data.srcAddress);
}

/** Begin FRIENDSTATUS */

struct ResFriendStatus {
    ResFriendStatus(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::FRIENDSTATUS;
    uint32_t track;
    ChatResultCode result;
    const ChatAvatar* srcAvatar;
};

template <typename StreamT>
void write(StreamT& ar, const ResFriendStatus& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);

    if (data.result == ChatResultCode::SUCCESS && data.srcAvatar) {
        const auto& friends = data.srcAvatar->GetFriendList();

        write(ar, static_cast<uint32_t>(friends.size()));
        for (auto& friendContact : friends) {
            write(ar, friendContact);
        }
    } else {
        write(ar, static_cast<uint32_t>(0));
    }
}

class FriendStatus {
public:
    using RequestType = ReqFriendStatus;
    using ResponseType = ResFriendStatus;

    FriendStatus(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatAvatarService* avatarService_;
    ChatRoomService* roomService_;
};
