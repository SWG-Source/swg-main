
#pragma once

#include "ChatEnums.hpp"

class ChatAvatarService;
class ChatRoomService;
class GatewayClient;

/** Begin REMOVEIGNORE */

struct ReqRemoveIgnore {
    const ChatRequestType type = ChatRequestType::REMOVEIGNORE;
    uint32_t track;
    uint32_t srcAvatarId;
    std::u16string destName;
    std::u16string destAddress;
    std::u16string srcAddress;
};

template <typename StreamT>
void read(StreamT& ar, ReqRemoveIgnore& data) {
    read(ar, data.track);
    read(ar, data.srcAvatarId);
    read(ar, data.destName);
    read(ar, data.destAddress);
    read(ar, data.srcAddress);
}

/** Begin REMOVEIGNORE */

struct ResRemoveIgnore {
    ResRemoveIgnore(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::REMOVEIGNORE;
    uint32_t track;
    ChatResultCode result;
};

template <typename StreamT>
void write(StreamT& ar, const ResRemoveIgnore& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);
}

class RemoveIgnore {
public:
    using RequestType = ReqRemoveIgnore;
    using ResponseType = ResRemoveIgnore;

    RemoveIgnore(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatAvatarService* avatarService_;
};
