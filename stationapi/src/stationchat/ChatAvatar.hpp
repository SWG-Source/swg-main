
#pragma once

#include "Serialization.hpp"

#include <cstdint>
#include <string>
#include <vector>

class ChatAvatar;
class ChatAvatarService;
class ChatRoom;

enum class AvatarAttribute : uint32_t {
    INVISIBLE = 1 << 0,
    GM = 1 << 1,
    SUPERGM = 1 << 2,
    SUPERSNOOP = 1 << 3,
    EXTENDED = 1 << 4
};

struct FriendContact {
    FriendContact(const ChatAvatar* frnd_, const std::u16string& comment_)
            : frnd{frnd_}
            , comment{comment_} {}

    const ChatAvatar* frnd;
    std::u16string comment = u"";
};

struct IgnoreContact {
    IgnoreContact(const ChatAvatar* ignored_)
            : ignored{ignored_} {}

    const ChatAvatar* ignored;
};

class ChatAvatar {
public:
    explicit ChatAvatar(ChatAvatarService* avatarService);
    ChatAvatar(ChatAvatarService* avatarService, const std::u16string& name, const std::u16string& address, uint32_t userId,
               uint32_t attributes, const std::u16string& loginLocation);

    bool IsInvisible() const { return (attributes_ & static_cast<uint32_t>(AvatarAttribute::INVISIBLE)) != 0; }
    bool IsGm() const { return (attributes_ & static_cast<uint32_t>(AvatarAttribute::GM)) != 0; }
    bool IsSuperGm() const { return (attributes_ & static_cast<uint32_t>(AvatarAttribute::SUPERGM)) != 0; }
    bool IsSuperSnoop() const { return (attributes_ & static_cast<uint32_t>(AvatarAttribute::SUPERSNOOP)) != 0; }

    const uint32_t GetAvatarId() const { return avatarId_; }
    const uint32_t GetUserId() const { return userId_; }
    const std::u16string& GetName() const { return name_; }
    const std::u16string& GetAddress() const { return address_; }
    const uint32_t GetAttributes() const { return attributes_; }
    void SetAttributes(const uint32_t attributes);
    const std::u16string& GetLoginLocation() const { return loginLocation_; }
    const std::u16string& GetServer() const { return server_; }
    const std::u16string& GetGateway() const { return gateway_; }
    const uint32_t GetServerId() const { return serverId_; }
    const uint32_t GetGatewayId() const { return gatewayId_; }
    const std::u16string& GetEmail() const { return email_; }
    const uint32_t GetInboxLimit() const { return inboxLimit_; }
    const std::u16string& GetStatusMessage() const { return statusMessage_; }
    const bool IsOnline() const { return isOnline_; }

    void AddFriend(ChatAvatar* avatar, const std::u16string& comment = u"");
    void RemoveFriend(const ChatAvatar* avatar);
    void UpdateFriendComment(const ChatAvatar* avatar, const std::u16string& comment);
    bool IsFriend(const ChatAvatar* avatar);

    const std::vector<FriendContact> GetFriendList() const { return friendList_; }

    void AddIgnore(ChatAvatar* avatar);
    void RemoveIgnore(const ChatAvatar* avatar);
    bool IsIgnored(const ChatAvatar* avatar);

    const std::vector<IgnoreContact> GetIgnoreList() const { return ignoreList_; }

private:
    friend class ChatAvatarService;

    ChatAvatarService* avatarService_;

    uint32_t avatarId_ = 0;
    uint32_t userId_ = 0;
    std::u16string name_ = u"";
    std::u16string address_ = u"";
    uint32_t attributes_ = 0;
    std::u16string loginLocation_ = u"";
    std::u16string server_ = u"";
    std::u16string gateway_ = u"";
    uint32_t serverId_ = 0;
    uint32_t gatewayId_ = 0;
    std::u16string email_ = u"";
    uint32_t inboxLimit_ = 0;
    std::u16string statusMessage_ = u"";
    bool isOnline_ = false;

    std::vector<FriendContact> friendList_;
    std::vector<IgnoreContact> ignoreList_;

    std::vector<ChatRoom*> rooms_;
};

template <typename StreamT>
void write(StreamT& ar, const ChatAvatar* data) {
    write(ar, data->GetAvatarId());
    write(ar, data->GetUserId());
    write(ar, data->GetName());
    write(ar, data->GetAddress());
    write(ar, data->GetAttributes());
    write(ar, data->GetLoginLocation());
    write(ar, data->GetServer());
    write(ar, data->GetGateway());
    write(ar, data->GetServerId());
    write(ar, data->GetGatewayId());
}


template <typename StreamT>
void write(StreamT& ar, const FriendContact& data) {
    write(ar, data.frnd->GetName());
    write(ar, data.frnd->GetAddress());
    write(ar, data.comment);
    write(ar, static_cast<short>(data.frnd->IsOnline() ? 1 : 0));
}

template <typename StreamT>
void write(StreamT& ar, const IgnoreContact& data) {
    write(ar, data.ignored->GetName());
    write(ar, data.ignored->GetAddress());
}
