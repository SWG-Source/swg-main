
#pragma once

#include "ChatEnums.hpp"

class ChatAvatarService;
class ChatRoomService;
class GatewayClient;

/** Begin REMOVEBAN */

struct ReqRemoveBan {
    const ChatRequestType type = ChatRequestType::REMOVEBAN;
    uint32_t track;
    uint32_t srcAvatarId;
    std::u16string destAvatarName;
    std::u16string destAvatarAddress;
    std::u16string destRoomAddress;
    std::u16string srcAddress;
};

template <typename StreamT>
void read(StreamT& ar, ReqRemoveBan& data) {
    read(ar, data.track);
    read(ar, data.srcAvatarId);
    read(ar, data.destAvatarName);
    read(ar, data.destAvatarAddress);
    read(ar, data.destRoomAddress);
    read(ar, data.srcAddress);
}

/** Begin REMOVEBAN */

struct ResRemoveBan {
    explicit ResRemoveBan(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::REMOVEBAN;
    uint32_t track;
    ChatResultCode result;
    uint32_t destRoomId;
};

template <typename StreamT>
void write(StreamT& ar, const ResRemoveBan& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);
    write(ar, data.destRoomId);
}

class RemoveBan {
public:
    using RequestType = ReqRemoveBan;
    using ResponseType = ResRemoveBan;

    RemoveBan(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatAvatarService* avatarService_;
    ChatRoomService* roomService_;
};
