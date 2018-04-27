
#pragma once

#include "ChatEnums.hpp"

class ChatAvatarService;
class ChatRoomService;
class GatewayClient;

/** Begin ADDFRIEND */

struct ReqAddFriend {
    const ChatRequestType type = ChatRequestType::ADDFRIEND;
    uint32_t track;
    uint32_t srcAvatarId;
    std::u16string destName;
    std::u16string destAddress;
    std::u16string comment;
    bool confirm;
    std::u16string srcAddress;
};

template <typename StreamT>
void read(StreamT& ar, ReqAddFriend& data) {
    read(ar, data.track);
    read(ar, data.srcAvatarId);
    read(ar, data.destName);
    read(ar, data.destAddress);
    read(ar, data.comment);
    read(ar, data.confirm);
    read(ar, data.srcAddress);
}

/** Begin ADDFRIEND */

struct ResAddFriend {
    ResAddFriend(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::ADDFRIEND;
    uint32_t track;
    ChatResultCode result;
};

template <typename StreamT>
void write(StreamT& ar, const ResAddFriend& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);
}

class AddFriend {
public:
    using RequestType = ReqAddFriend;
    using ResponseType = ResAddFriend;

    AddFriend(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatAvatarService* avatarService_;
};
