
#pragma once

#include "ChatEnums.hpp"
#include "ChatRoom.hpp"

#include <cstdint>
#include <string>
#include <vector>

class ChatAvatarService;
class ChatRoomService;
class GatewayClient;

/** Begin CREATEROOM */

struct ReqCreateRoom {
    const ChatRequestType type = ChatRequestType::CREATEROOM;
    uint32_t track;
    uint32_t creatorId;
    std::u16string roomName;
    std::u16string roomTopic;
    std::u16string roomPassword;
    uint32_t roomAttributes;
    uint32_t roomMaxSize;
    std::u16string roomAddress;
    std::u16string srcAddress;
};

template <typename StreamT>
void read(StreamT& ar, ReqCreateRoom& data) {
    read(ar, data.track);
    read(ar, data.creatorId);
    read(ar, data.roomName);
    read(ar, data.roomTopic);
    read(ar, data.roomPassword);
    read(ar, data.roomAttributes);
    read(ar, data.roomMaxSize);
    read(ar, data.roomAddress);
    read(ar, data.srcAddress);
}

/** Begin CREATEROOM */

struct ResCreateRoom {
    explicit ResCreateRoom(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::CREATEROOM;
    uint32_t track;
    ChatResultCode result;
    ChatRoom* room;
    std::vector<ChatRoom*> extraRooms;
};

template <typename StreamT>
void write(StreamT& ar, const ResCreateRoom& data) {
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

class CreateRoom {
public:
    using RequestType = ReqCreateRoom;
    using ResponseType = ResCreateRoom;

    CreateRoom(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatAvatarService* avatarService_;
    ChatRoomService* roomService_;
};
