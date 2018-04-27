
#pragma once

#include "ChatEnums.hpp"

class ChatAvatarService;
class ChatRoomService;
class GatewayClient;

/** Begin SETAPIVERSION */

struct ReqSetApiVersion {
    const ChatRequestType type = ChatRequestType::SETAPIVERSION;
    uint32_t track;
    uint32_t version;
};

template <typename StreamT>
void read(StreamT& ar, ReqSetApiVersion& data) {
    read(ar, data.track);
    read(ar, data.version);
}

/** Begin SETAPIVERSION */

struct ResSetApiVersion {
    ResSetApiVersion(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::SETAPIVERSION;
    uint32_t track;
    ChatResultCode result;
    uint32_t version;
};

template <typename StreamT>
void write(StreamT& ar, const ResSetApiVersion& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);
    write(ar, data.version);
}

class SetApiVersion {
public:
    using RequestType = ReqSetApiVersion;
    using ResponseType = ResSetApiVersion;

    SetApiVersion(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatAvatarService* avatarService_;
    ChatRoomService* roomService_;
};
