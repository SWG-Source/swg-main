
#pragma once

#include "ChatEnums.hpp"
#include "ChatRoom.hpp"

class ChatAvatarService;
class ChatRoomService;
class GatewayClient;

/** Begin GETROOM */

struct ReqGetRoom {
    const ChatRequestType type = ChatRequestType::GETROOMSUMMARIES;
    uint32_t track;
    std::u16string roomAddress;
};

template <typename StreamT>
void read(StreamT& ar, ReqGetRoom& data) {
    read(ar, data.track);
    read(ar, data.roomAddress);
}

/** Begin GETROOM */

struct ResGetRoom {
    ResGetRoom(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS}
        , room{nullptr} {}

    const ChatResponseType type = ChatResponseType::GETROOM;
    uint32_t track;
    ChatResultCode result;
    ChatRoom* room;
    std::vector<ChatRoom*> extraRooms;
};

template <typename StreamT>
void write(StreamT& ar, const ResGetRoom& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);

    if (data.result == ChatResultCode::SUCCESS) {
        write(ar, *data.room);

        write(ar, static_cast<uint32_t>(data.extraRooms.size()));
        for (auto room : data.extraRooms) {
            write(ar, *room);
        }
    }
}

class GetRoom {
public:
    using RequestType = ReqGetRoom;
    using ResponseType = ResGetRoom;

    GetRoom(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatRoomService* roomService_;
};
