
#pragma once

#include "ChatEnums.hpp"

class ChatAvatarService;
class ChatRoomService;
class GatewayClient;

/** Begin ADDIGNORE */

struct ReqAddIgnore {
    const ChatRequestType type = ChatRequestType::ADDIGNORE;
    uint32_t track;
    uint32_t srcAvatarId;
    std::u16string destName;
    std::u16string destAddress;
    std::u16string srcAddress;
};

template <typename StreamT>
void read(StreamT& ar, ReqAddIgnore& data) {
    read(ar, data.track);
    read(ar, data.srcAvatarId);
    read(ar, data.destName);
    read(ar, data.destAddress);
    read(ar, data.srcAddress);
}

/** Begin ADDIGNORE */

struct ResAddIgnore {
    ResAddIgnore(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::ADDIGNORE;
    uint32_t track;
    ChatResultCode result;
};

template <typename StreamT>
void write(StreamT& ar, const ResAddIgnore& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);
}

class AddIgnore {
public:
    using RequestType = ReqAddIgnore;
    using ResponseType = ResAddIgnore;

    AddIgnore(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatAvatarService* avatarService_;
};
