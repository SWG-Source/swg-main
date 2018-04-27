
#pragma once

#include "ChatAvatar.hpp"
#include "ChatEnums.hpp"

class ChatAvatarService;
class GatewayClient;

/** Begin SETAVATARATTRIBUTES */

struct ReqSetAvatarAttributes {
    const ChatRequestType type = ChatRequestType::SETAVATARATTRIBUTES;
    uint32_t track;
    uint32_t avatarId;
    uint32_t avatarAttributes;
    uint32_t persistent;
    std::u16string srcAddress;
};

template <typename StreamT>
void read(StreamT& ar, ReqSetAvatarAttributes& data) {
    read(ar, data.track);
    read(ar, data.avatarId);
    read(ar, data.avatarAttributes);
    read(ar, data.persistent);
    read(ar, data.srcAddress);
}

/** Begin SETAVATARATTRIBUTES */

struct ResSetAvatarAttributes {
    ResSetAvatarAttributes(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::SETAVATARATTRIBUTES;
    uint32_t track;
    ChatResultCode result;
    const ChatAvatar* avatar;
};

template <typename StreamT>
void write(StreamT& ar, const ResSetAvatarAttributes& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);

    if (data.result == ChatResultCode::SUCCESS) {
        write(ar, data.avatar);
    }
}

class SetAvatarAttributes {
public:
    using RequestType = ReqSetAvatarAttributes;
    using ResponseType = ResSetAvatarAttributes;

    SetAvatarAttributes(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatAvatarService* avatarService_;
};
