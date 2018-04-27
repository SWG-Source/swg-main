
#pragma once

#include "ChatEnums.hpp"

class ChatAvatarService;
class ChatRoomService;
class GatewayClient;

/** Begin ADDMODERATOR */

struct ReqAddModerator {
    const ChatRequestType type = ChatRequestType::ADDMODERATOR;
    uint32_t track;
    uint32_t srcAvatarId;
    std::u16string destAvatarName;
    std::u16string destAvatarAddress;
    std::u16string destRoomAddress;
    std::u16string srcAddress;
};

template <typename StreamT>
void read(StreamT& ar, ReqAddModerator& data) {
    read(ar, data.track);
    read(ar, data.srcAvatarId);
    read(ar, data.destAvatarName);
    read(ar, data.destAvatarAddress);
    read(ar, data.destRoomAddress);
    read(ar, data.srcAddress);
}

/** Begin ADDMODERATOR */

struct ResAddModerator {
    ResAddModerator(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::ADDMODERATOR;
    uint32_t track;
    ChatResultCode result;
    uint32_t destRoomId;
};

template <typename StreamT>
void write(StreamT& ar, const ResAddModerator& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);
    write(ar, data.destRoomId);
}

class AddModerator {
public:
    using RequestType = ReqAddModerator;
    using ResponseType = ResAddModerator;

    AddModerator(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatAvatarService* avatarService_;
    ChatRoomService* roomService_;
};
