
#include "ChatRoom.hpp"
#include "ChatAvatar.hpp"
#include "ChatRoomService.hpp"

#include <algorithm>

inline unsigned IS_SET(unsigned var, unsigned bit) { return (var & bit); }

ChatRoom::ChatRoom(ChatRoomService* roomService, uint32_t roomId, const ChatAvatar* creator,
    const std::u16string& roomName, const std::u16string& roomTopic, const std::u16string& roomPassword,
    uint32_t roomAttributes, uint32_t maxRoomSize, const std::u16string& roomAddress,
    const std::u16string& srcAddress)
    : roomService_{roomService}
    , roomId_{roomId}
    , creatorName_{creator->GetName()}
    , creatorAddress_{creator->GetAddress()}
    , roomName_{roomName}
    , roomTopic_{roomTopic}
    , roomPassword_{roomPassword}
    , roomAddress_{roomAddress + u"+" + roomName}
    , creatorId_{creator->GetAvatarId()}
    , roomAttributes_{roomAttributes}
    , maxRoomSize_{maxRoomSize} {
    administrators_.push_back(creator);
    moderators_.push_back(creator);
}

bool ChatRoom::IsPrivate() const {
    return (roomAttributes_ & static_cast<uint32_t>(RoomAttributes::PRIVATE)) != 0;
}

bool ChatRoom::IsModerated() const {
    return (roomAttributes_ & static_cast<uint32_t>(RoomAttributes::MODERATED)) != 0;
}

bool ChatRoom::IsPersistent() const {
    return (roomAttributes_ & static_cast<uint32_t>(RoomAttributes::PERSISTENT)) != 0;
}

bool ChatRoom::IsLocalWorld() const {
    return (roomAttributes_ & static_cast<uint32_t>(RoomAttributes::LOCAL_WORLD)) != 0;
}

bool ChatRoom::IsLocalGame() const {
    return (roomAttributes_ & static_cast<uint32_t>(RoomAttributes::LOCAL_GAME)) != 0;
}

void ChatRoom::EnterRoom(ChatAvatar* avatar, const std::u16string& password) {
    if (roomPassword_.length() > 0 && roomPassword_.compare(password) != 0) {
        throw ChatResultException{ChatResultCode::ROOM_PRIVATEROOM};
    }

    if (IsBanned(avatar->GetAvatarId())) {
        throw ChatResultException{ChatResultCode::ROOM_BANNEDAVATAR};
    }

    if (IsInRoom(avatar)) {
        throw ChatResultException{ChatResultCode::ROOM_ALREADYINROOM};
    }

    if (IsPrivate() && !IsCreator(avatar->GetAvatarId()) && !IsInvited(avatar->GetAvatarId())) {
        throw ChatResultException{ChatResultCode::ROOM_PRIVATEROOM};
    }

    avatars_.push_back(avatar);
}

bool ChatRoom::IsInRoom(ChatAvatar* avatar) const { return IsInRoom(avatar->GetAvatarId()); }

bool ChatRoom::IsInRoom(uint32_t avatarId) const {
    return std::find_if(std::begin(avatars_), std::end(avatars_),
               [avatarId](ChatAvatar* roomAvatar) { return roomAvatar->GetAvatarId() == avatarId; })
        != std::end(avatars_);
}

void ChatRoom::LeaveRoom(ChatAvatar* avatar) {
    auto avatarsIter = std::remove_if(std::begin(avatars_), std::end(avatars_),
        [avatar](auto roomAvatar) { return roomAvatar->GetAvatarId() == avatar->GetAvatarId(); });

    if (avatarsIter != std::end(avatars_)) {
        avatars_.erase(avatarsIter);
    }
}

std::vector<uint32_t> ChatRoom::GetAvatarIds(const ChatAvatar * srcAvatar) const {
    std::vector<uint32_t> avatarIds;

    for (auto roomAvatar : avatars_) {
        if (!roomAvatar->IsIgnored(srcAvatar)) {
            avatarIds.push_back(roomAvatar->GetAvatarId());
        }
    }

    return avatarIds;
}

std::vector<std::u16string> ChatRoom::GetConnectedAddresses() const {
    std::vector<std::u16string> connectedAddresses;

    std::u16string address;
    for (auto avatar : avatars_) {
        address = avatar->GetAddress();
        if (connectedAddresses.empty()
            || std::none_of(std::begin(connectedAddresses), std::end(connectedAddresses),
                   [&address](const auto& connectedAddress) {
                       return connectedAddress.compare(address) == 0;
                   })) {
            connectedAddresses.push_back(address);
        }
    }

    return connectedAddresses;
}

std::vector<std::u16string> ChatRoom::GetRemoteAddresses() const {
    std::vector<std::u16string> connectedAddresses;

    std::u16string address;
    for (auto avatar : avatars_) {
        address = avatar->GetAddress();
        if (creatorAddress_.compare(address) != 0 && (connectedAddresses.empty()
            || std::none_of(std::begin(connectedAddresses), std::end(connectedAddresses),
                            [&address](const auto& connectedAddress) {
            return connectedAddress.compare(address) == 0;
        }))) {
            connectedAddresses.push_back(address);
        }
    }

    return connectedAddresses;
}

bool ChatRoom::IsCreator(uint32_t avatarId) const { return avatarId == creatorId_; }

bool ChatRoom::IsModerator(uint32_t avatarId) const {
    if (moderators_.empty())
        return false;

    auto find_iter = std::find_if(std::begin(moderators_), std::end(moderators_),
        [avatarId](const auto& moderator) { return moderator->GetAvatarId() == avatarId; });

    return find_iter != std::end(moderators_);
}

bool ChatRoom::IsAdministrator(uint32_t avatarId) const {
    if (administrators_.empty())
        return false;

    auto find_iter = std::find_if(std::begin(administrators_), std::end(administrators_),
        [avatarId](const auto& administrator) { return administrator->GetAvatarId() == avatarId; });

    return find_iter != std::end(administrators_);
}

bool ChatRoom::IsBanned(uint32_t avatarId) const {
    if (banned_.empty())
        return false;

    auto find_iter = std::find_if(std::begin(banned_), std::end(banned_),
        [avatarId](const auto& banned) { return banned->GetAvatarId() == avatarId; });

    return find_iter != std::end(banned_);
}

bool ChatRoom::IsInvited(uint32_t avatarId) const {
    if (invited_.empty())
        return false;

    auto find_iter = std::find_if(std::begin(invited_), std::end(invited_),
        [avatarId](const auto& invited) { return invited->GetAvatarId() == avatarId; });

    return find_iter != std::end(invited_);
}

void ChatRoom::KickAvatar(uint32_t srcAvatarId, ChatAvatar* destAvatar) {
    if (!IsModerator(srcAvatarId)) {
        throw ChatResultException{ChatResultCode::ROOM_NOPRIVILEGES};
    }

    if (!IsInRoom(destAvatar)) {
        throw ChatResultException{ChatResultCode::ROOM_NOTINROOM};
    }

    LeaveRoom(destAvatar);
}

void ChatRoom::AddAdministrator(uint32_t srcAvatarId, ChatAvatar* administrator) {
    if (!IsCreator(srcAvatarId)) {
        throw ChatResultException{ChatResultCode::ROOM_NOPRIVILEGES};
    }

    if (!IsAdministrator(administrator->GetAvatarId())) {
        administrators_.push_back(administrator);

        if (IsPersistent()) {
            roomService_->PersistBanned(administrator->GetAvatarId(), roomId_);
        }
    }
}

void ChatRoom::AddModerator(uint32_t srcAvatarId, ChatAvatar* moderator) {
    if (!IsCreator(srcAvatarId)) {
        throw ChatResultException{ChatResultCode::ROOM_NOPRIVILEGES};
    }

    if (IsModerator(moderator->GetAvatarId())) {
        throw ChatResultException{ChatResultCode::ROOM_DUPLICATEMODERATOR};
    }

    moderators_.push_back(moderator);

    if (IsPersistent()) {
        roomService_->PersistBanned(moderator->GetAvatarId(), roomId_);
    }
}

void ChatRoom::AddBanned(uint32_t srcAvatarId, ChatAvatar* banned) {
    if (!IsModerator(srcAvatarId)) {
        throw ChatResultException{ChatResultCode::ROOM_NOPRIVILEGES};
    }

    if (IsBanned(banned->GetAvatarId())) {
        throw ChatResultException{ChatResultCode::ROOM_DUPLICATEBAN};
    }

    banned_.push_back(banned);

    if (IsPersistent()) {
        roomService_->PersistBanned(banned->GetAvatarId(), roomId_);
    }
}

void ChatRoom::AddInvite(uint32_t srcAvatarId, ChatAvatar* invited) {
    if (!IsModerator(srcAvatarId)) {
        throw ChatResultException{ChatResultCode::ROOM_NOPRIVILEGES};
    }

    if (IsInvited(invited->GetAvatarId())) {
        throw ChatResultException{ChatResultCode::ROOM_DUPLICATEINVITE};
    }

    invited_.push_back(invited);
}

void ChatRoom::RemoveAdministrator(uint32_t srcAvatarId, uint32_t avatarId) {
    if (!IsCreator(srcAvatarId)) {
        throw ChatResultException{ChatResultCode::ROOM_NOPRIVILEGES};
    }

    if (administrators_.empty())
        return;

    administrators_.erase(std::remove_if(std::begin(administrators_), std::end(administrators_),
        [avatarId](auto administrator) { return administrator->GetAvatarId() == avatarId; }));

    if (IsPersistent()) {
        roomService_->DeleteAdministrator(avatarId, roomId_);
    }
}

void ChatRoom::RemoveModerator(uint32_t srcAvatarId, uint32_t avatarId) {
    if (!IsCreator(srcAvatarId)) {
        throw ChatResultException{ChatResultCode::ROOM_NOPRIVILEGES};
    }

    if (moderators_.empty() || !IsModerator(avatarId)) {
        throw ChatResultException{ChatResultCode::ROOM_DESTAVATARNOTMODERATOR};
    }

    moderators_.erase(std::remove_if(std::begin(moderators_), std::end(moderators_),
        [avatarId](auto moderator) { return moderator->GetAvatarId() == avatarId; }));

    if (IsPersistent()) {
        roomService_->DeleteModerator(avatarId, roomId_);
    }
}

void ChatRoom::RemoveBanned(uint32_t srcAvatarId, uint32_t avatarId) {
    if (!IsModerator(srcAvatarId)) {
        throw ChatResultException{ChatResultCode::ROOM_NOPRIVILEGES};
    }

    if (banned_.empty() || !IsBanned(avatarId)) {
        throw ChatResultException{ChatResultCode::ROOM_DESTAVATARNOTBANNED};
    }

    banned_.erase(std::remove_if(std::begin(banned_), std::end(banned_),
        [avatarId](auto banned) { return banned->GetAvatarId() == avatarId; }));

    if (IsPersistent()) {
        roomService_->DeleteBanned(avatarId, roomId_);
    }
}

void ChatRoom::RemoveInvite(uint32_t srcAvatarId, uint32_t avatarId) {
    if (!IsModerator(srcAvatarId)) {
        throw ChatResultException{ChatResultCode::ROOM_NOPRIVILEGES};
    }

    if (invited_.empty() || !IsInvited(avatarId)) {
        throw ChatResultException{ChatResultCode::ROOM_DESTAVATARNOTINVITED};
    }

    invited_.erase(std::remove_if(std::begin(invited_), std::end(invited_),
        [avatarId](auto invited) { return invited->GetAvatarId() == avatarId; }));
}
