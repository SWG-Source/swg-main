
#pragma once

#include "ChatEnums.hpp"

class ChatAvatarService;
class ChatRoomService;
class GatewayClient;

/** Begin DESTROYROOM */

struct ReqDestroyRoom {
    const ChatRequestType type = ChatRequestType::DESTROYROOM;
    uint32_t track;
    uint32_t srcAvatarId;
    std::u16string roomAddress;
    std::u16string srcAddress;
};

template <typename StreamT>
void read(StreamT& ar, ReqDestroyRoom& data) {
    read(ar, data.track);
    read(ar, data.srcAvatarId);
    read(ar, data.roomAddress);
    read(ar, data.srcAddress);
}

/** Begin DESTROYROOM */

struct ResDestroyRoom {
    explicit ResDestroyRoom(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::DESTROYROOM;
    uint32_t track;
    ChatResultCode result;
    uint32_t roomId;
};

template <typename StreamT>
void write(StreamT& ar, const ResDestroyRoom& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);
    write(ar, data.roomId);
}

class DestroyRoom {
public:
    using RequestType = ReqDestroyRoom;
    using ResponseType = ResDestroyRoom;

    DestroyRoom(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatAvatarService* avatarService_;
    ChatRoomService* roomService_;
};
