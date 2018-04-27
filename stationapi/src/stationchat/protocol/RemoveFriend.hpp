
#pragma once

#include "ChatEnums.hpp"

class ChatAvatarService;
class ChatRoomService;
class GatewayClient;

/** Begin REMOVEFRIEND */

struct ReqRemoveFriend {
    const ChatRequestType type = ChatRequestType::REMOVEFRIEND;
    uint32_t track;
    uint32_t srcAvatarId;
    std::u16string destName;
    std::u16string destAddress;
    std::u16string srcAddress;
};

template <typename StreamT>
void read(StreamT& ar, ReqRemoveFriend& data) {
    read(ar, data.track);
    read(ar, data.srcAvatarId);
    read(ar, data.destName);
    read(ar, data.destAddress);
    read(ar, data.srcAddress);
}

/** Begin REMOVEFRIEND */

struct ResRemoveFriend {
    ResRemoveFriend(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::REMOVEFRIEND;
    uint32_t track;
    ChatResultCode result;
};

template <typename StreamT>
void write(StreamT& ar, const ResRemoveFriend& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);
}

class RemoveFriend {
public:
    using RequestType = ReqRemoveFriend;
    using ResponseType = ResRemoveFriend;

    RemoveFriend(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatAvatarService* avatarService_;
};
