
#pragma once

#include "ChatEnums.hpp"

class ChatAvatarService;
class ChatRoomService;
class GatewayClient;

/** Begin REMOVEINVITE */

struct ReqRemoveInvite {
    const ChatRequestType type = ChatRequestType::REMOVEINVITE;
    uint32_t track;
    uint32_t srcAvatarId;
    std::u16string destAvatarName;
    std::u16string destAvatarAddress;
    std::u16string destRoomAddress;
    std::u16string srcAddress;
};

template <typename StreamT>
void read(StreamT& ar, ReqRemoveInvite& data) {
    read(ar, data.track);
    read(ar, data.srcAvatarId);
    read(ar, data.destAvatarName);
    read(ar, data.destAvatarAddress);
    read(ar, data.destRoomAddress);
    read(ar, data.srcAddress);
}

/** Begin REMOVEINVITE */

struct ResRemoveInvite {
    explicit ResRemoveInvite(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::REMOVEINVITE;
    uint32_t track;
    ChatResultCode result;
    uint32_t destRoomId;
};

template <typename StreamT>
void write(StreamT& ar, const ResRemoveInvite& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);
    write(ar, data.destRoomId);
}

class RemoveInvite {
public:
    using RequestType = ReqRemoveInvite;
    using ResponseType = ResRemoveInvite;

    RemoveInvite(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatAvatarService* avatarService_;
    ChatRoomService* roomService_;
};
