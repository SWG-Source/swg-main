
#pragma once

#include "ChatEnums.hpp"

class ChatAvatarService;
class ChatRoomService;
class GatewayClient;

/** Begin LEAVEROOM */

struct ReqLeaveRoom {
    const ChatRequestType type = ChatRequestType::LEAVEROOM;
    uint32_t track;
    uint32_t srcAvatarId;
    std::u16string roomAddress;
    std::u16string srcAddress;
};

template <typename StreamT>
void read(StreamT& ar, ReqLeaveRoom& data) {
    read(ar, data.track);
    read(ar, data.srcAvatarId);
    read(ar, data.roomAddress);
    read(ar, data.srcAddress);
}

/** Begin LEAVEROOM */

struct ResLeaveRoom {
    ResLeaveRoom(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::LEAVEROOM;
    uint32_t track;
    ChatResultCode result;
    uint32_t roomId;
};

template <typename StreamT>
void write(StreamT& ar, const ResLeaveRoom& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);
    write(ar, data.roomId);
}

class LeaveRoom {
public:
    using RequestType = ReqLeaveRoom;
    using ResponseType = ResLeaveRoom;

    LeaveRoom(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatAvatarService* avatarService_;
    ChatRoomService* roomService_;
};
