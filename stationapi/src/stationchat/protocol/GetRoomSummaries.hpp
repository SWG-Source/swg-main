
#pragma once

#include "ChatEnums.hpp"
#include "ChatRoom.hpp"

#include <vector>

class ChatAvatarService;
class ChatRoomService;
class GatewayClient;

/** Begin GETROOMSUMMARIES */

struct ReqGetRoomSummaries {
    const ChatRequestType type = ChatRequestType::GETROOMSUMMARIES;
    uint32_t track;
    std::u16string startNodeAddress;
    std::u16string roomFilter;
};

template <typename StreamT>
void read(StreamT& ar, ReqGetRoomSummaries& data) {
    read(ar, data.track);
    read(ar, data.startNodeAddress);
    read(ar, data.roomFilter);
}

/** Begin GETROOMSUMMARIES */

struct ResGetRoomSummaries {
    ResGetRoomSummaries(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::GETROOMSUMMARIES;
    uint32_t track;
    ChatResultCode result;
    std::vector<ChatRoom*> rooms;
};

template <typename StreamT>
void write(StreamT& ar, const ResGetRoomSummaries& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);

    write(ar, static_cast<uint32_t>(data.rooms.size()));
    for (auto room : data.rooms) {
        write(ar, room->GetRoomAddress());
        write(ar, room->GetRoomTopic());
        write(ar, room->GetRoomAttributes());
        write(ar, room->GetCurrentRoomSize());
        write(ar, room->GetMaxRoomSize());
    }
}

class GetRoomSummaries {
public:
    using RequestType = ReqGetRoomSummaries;
    using ResponseType = ResGetRoomSummaries;

    GetRoomSummaries(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatRoomService* roomService_;
};
