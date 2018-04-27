
#pragma once

#include "ChatEnums.hpp"
#include "PersistentMessage.hpp"

#include <vector>

class PersistentMessageService;
class GatewayClient;

/** Begin GETPERSISTENTHEADERS */

struct ReqGetPersistentHeaders {
    const ChatRequestType type = ChatRequestType::GETPERSISTENTHEADERS;
    uint32_t track;
    uint32_t avatarId;
    std::u16string category;
};

template <typename StreamT>
void read(StreamT& ar, ReqGetPersistentHeaders& data) {
    read(ar, data.track);
    read(ar, data.avatarId);
    read(ar, data.category);
}

/** Begin GETPERSISTENTHEADERS */

struct ResGetPersistentHeaders {
    ResGetPersistentHeaders(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::GETPERSISTENTHEADERS;
    uint32_t track;
    ChatResultCode result;
    std::vector<PersistentHeader> headers;
};

template <typename StreamT>
void write(StreamT& ar, const ResGetPersistentHeaders& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);
    write(ar, static_cast<uint32_t>(data.headers.size()));

    for (auto& header : data.headers) {
        write(ar, header);
    }
}

class GetPersistentHeaders {
public:
    using RequestType = ReqGetPersistentHeaders;
    using ResponseType = ResGetPersistentHeaders;

    GetPersistentHeaders(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    PersistentMessageService* messageService_;
};
