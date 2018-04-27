
#pragma once

#include "ChatEnums.hpp"
#include "ChatRoom.hpp"

class ChatAvatarService;
class ChatRoomService;
class GatewayClient;

/** Begin ENTERROOM */

struct ReqEnterRoom {
    const ChatRequestType type = ChatRequestType::ENTERROOM;
    uint32_t track;
    uint32_t srcAvatarId;
    std::u16string roomAddress;
    std::u16string roomPassword;
    bool passiveCreate;
    std::u16string paramRoomTopic;
    uint32_t paramRoomAttributes;
    uint32_t paramRoomMaxSize;
    bool requestingEntry;
    std::u16string srcAddress;
};

template <typename StreamT>
void read(StreamT& ar, ReqEnterRoom& data) {
    read(ar, data.track);
    read(ar, data.srcAvatarId);
    read(ar, data.roomAddress);
    read(ar, data.roomPassword);
    read(ar, data.passiveCreate);

    if (data.passiveCreate) {
        read(ar, data.paramRoomTopic);
        read(ar, data.paramRoomAttributes);
        read(ar, data.paramRoomMaxSize);
    }

    read(ar, data.requestingEntry);
    read(ar, data.srcAddress);
}

/** Begin ENTERROOM */

struct ResEnterRoom {
    ResEnterRoom(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::ENTERROOM;
    uint32_t track;
    ChatResultCode result;
    uint32_t roomId;
    bool gotRoomObj = false;
    ChatRoom* room = nullptr;
    std::vector<ChatRoom*> extraRooms;
};

template <typename StreamT>
void write(StreamT& ar, const ResEnterRoom& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);
    write(ar, data.roomId);
    write(ar, data.gotRoomObj);

    if (data.gotRoomObj) {
        write(ar, *data.room);

        write(ar, static_cast<uint32_t>(data.extraRooms.size()));
        for (auto room : data.extraRooms) {
            write(ar, *room);
        }
    }
}

class EnterRoom {
public:
    using RequestType = ReqEnterRoom;
    using ResponseType = ResEnterRoom;

    EnterRoom(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatAvatarService* avatarService_;
    ChatRoomService* roomService_;
};
