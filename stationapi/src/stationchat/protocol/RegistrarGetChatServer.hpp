
#pragma once

#include "ChatEnums.hpp"

class RegistrarClient;

/** Begin REGISTRAR_GETCHATSERVER */

struct ReqRegistrarGetChatServer {
    const ChatRequestType type = ChatRequestType::REGISTRAR_GETCHATSERVER;
    uint32_t track;
    std::u16string hostname;
    uint16_t port;
};

template <typename StreamT>
void read(StreamT& ar, ReqRegistrarGetChatServer& data) {
    read(ar, data.track);
    read(ar, data.hostname);
    read(ar, data.port);
}

/** Begin REGISTRAR_GETCHATSERVER */

struct ResRegistrarGetChatServer {
    ResRegistrarGetChatServer(
        uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::REGISTRAR_GETCHATSERVER;
    uint32_t track;
    ChatResultCode result;
    std::u16string hostname;
    uint16_t port;
};

template <typename StreamT>
void write(StreamT& ar, const ResRegistrarGetChatServer& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);
    write(ar, data.hostname);
    write(ar, data.port);
}

class RegistrarGetChatServer {
public:
    using RequestType = ReqRegistrarGetChatServer;
    using ResponseType = ResRegistrarGetChatServer;

    RegistrarGetChatServer(RegistrarClient* client, const RequestType& request, ResponseType& response);
};
