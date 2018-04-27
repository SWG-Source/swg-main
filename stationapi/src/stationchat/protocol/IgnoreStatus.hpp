
#pragma once

#include "ChatAvatar.hpp"
#include "ChatEnums.hpp"

class ChatAvatarService;
class ChatRoomService;
class GatewayClient;

/** Begin IGNORESTATUS */

struct ReqIgnoreStatus {
    const ChatRequestType type = ChatRequestType::IGNORESTATUS;
    uint32_t track;
    uint32_t srcAvatarId;
    std::u16string srcAddress;
};

template <typename StreamT>
void read(StreamT& ar, ReqIgnoreStatus& data) {
    read(ar, data.track);
    read(ar, data.srcAvatarId);
    read(ar, data.srcAddress);
}

/** Begin IGNORESTATUS */

struct ResIgnoreStatus {
    ResIgnoreStatus(uint32_t track_)
        : track{track_}
        , result{ChatResultCode::SUCCESS} {}

    const ChatResponseType type = ChatResponseType::IGNORESTATUS;
    uint32_t track;
    ChatResultCode result;
    const ChatAvatar* srcAvatar;
};

template <typename StreamT>
void write(StreamT& ar, const ResIgnoreStatus& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.result);

    if (data.result == ChatResultCode::SUCCESS && data.srcAvatar) {
        const auto& ignored = data.srcAvatar->GetIgnoreList();

        write(ar, static_cast<uint32_t>(ignored.size()));
        for (auto& ignoredContact : ignored) {
            write(ar, ignoredContact);
        }
    } else {
        write(ar, static_cast<uint32_t>(0));
    }
}

class IgnoreStatus {
public:
    using RequestType = ReqIgnoreStatus;
    using ResponseType = ResIgnoreStatus;

    IgnoreStatus(GatewayClient* client, const RequestType& request, ResponseType& response);

private:
    ChatAvatarService* avatarService_;
};
