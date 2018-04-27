
#pragma once

#include "ChatEnums.hpp"

class ChatAvatarService;
class ChatRoomService;
class GatewayClient;

/** Begin REMOVEMODERATOR */

struct ReqRemoveModerator {
    const ChatRequestType type = ChatRequestType::REMOVEMODERATOR;
    uint32_t track;
    uint32_t srcAvatarId;
    std::u16string destAvatarName;
    std::u16string destAvatarAddress;
    std::u16string destRoomAddress;
    std::u16string srcAddress;
};

template <typename StreamT>
void read(StreamT& ar, ReqRemoveModerator& data) {
    read(ar, data.track);
    read(ar, data.srcAvatarId);
    read(ar, data.destAvatarName);
    read(ar, data.destAvatarAddress);
    read(ar, data.destRoomAddress);
    read(ar, data.srcAddress);
}

/** Begin REMOVEMODERATOR */

struct ResRemoveModerator {
    ResRemoveModerator(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::REMOVEMODERATOR;
    uint32_t track;
    ChatResultCode result;
    uint32_t destRoomId;
};

template <typename StreamT>
void write(StreamT& ar, const ResRemoveModerator& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);
    write(ar, data.destRoomId);
}

class RemoveModerator {
public:
    using RequestType = ReqRemoveModerator;
    using ResponseType = ResRemoveModerator;

    RemoveModerator(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatAvatarService* avatarService_;
    ChatRoomService* roomService_;
};
