
#pragma once

#include "ChatAvatar.hpp"
#include "ChatEnums.hpp"

class ChatAvatarService;
class GatewayClient;

/** Begin GETANYAVATAR */

struct ReqGetAnyAvatar {
    const ChatRequestType type = ChatRequestType::GETANYAVATAR;
    uint32_t track;
    std::u16string name;
    std::u16string address;
};

template <typename StreamT>
void read(StreamT& ar, ReqGetAnyAvatar& data) {
    read(ar, data.track);
    read(ar, data.name);
    read(ar, data.address);
}

/** Begin GETANYAVATAR */

struct ResGetAnyAvatar {
    explicit ResGetAnyAvatar(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    ResGetAnyAvatar(uint32_t track_, ChatResultCode result_, bool isOnline_,
                    const ChatAvatar* avatar_)
        : track{track_}
        , result{result_}
        , isOnline{isOnline_}
        , avatar{avatar_} {}

    const ChatResponseType type = ChatResponseType::GETANYAVATAR;
    uint32_t track;
    ChatResultCode result;
    bool isOnline;
    const ChatAvatar* avatar;
};

template <typename StreamT>
void write(StreamT& ar, const ResGetAnyAvatar& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);
    write(ar, data.isOnline);

    if (data.result == ChatResultCode::SUCCESS) {
        write(ar, data.avatar);
    }
}

class GetAnyAvatar {
public:
    using RequestType = ReqGetAnyAvatar;
    using ResponseType = ResGetAnyAvatar;

    GetAnyAvatar(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatAvatarService* avatarService_;
};
