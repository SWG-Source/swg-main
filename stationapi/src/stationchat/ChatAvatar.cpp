#include "ChatAvatar.hpp"
#include "ChatAvatarService.hpp"
#include "ChatRoom.hpp"

#include <algorithm>

ChatAvatar::ChatAvatar(ChatAvatarService * avatarService)
    : avatarService_{avatarService} {}

ChatAvatar::ChatAvatar(ChatAvatarService* avatarService, const std::u16string& name, const std::u16string& address, uint32_t userId,
    uint32_t attributes, const std::u16string& loginLocation)
    : avatarService_{avatarService}
    , userId_{userId}
    , name_{name}
    , address_{address}
    , attributes_{attributes}
    , loginLocation_{loginLocation} {}

void ChatAvatar::SetAttributes(const uint32_t attributes) { attributes_ = attributes; }

void ChatAvatar::AddFriend(ChatAvatar* avatar, const std::u16string& comment) {
    if (IsFriend(avatar)) return;    
    if (IsIgnored(avatar)) RemoveIgnore(avatar);

    friendList_.push_back(FriendContact{avatar, comment});

    avatarService_->PersistFriend(avatarId_, avatar->avatarId_, comment);
}

void ChatAvatar::RemoveFriend(const ChatAvatar* avatar) {
    auto del_iter = std::remove_if(std::begin(friendList_), std::end(friendList_),
        [avatar](auto& frnd) { return frnd.frnd->GetAvatarId() == avatar->GetAvatarId(); });

    if (del_iter != std::end(friendList_)) {
        friendList_.erase(del_iter);

        avatarService_->RemoveFriend(avatarId_, avatar->avatarId_);
    }
}

void ChatAvatar::UpdateFriendComment(const ChatAvatar* avatar, const std::u16string& comment) {
    auto find_iter = std::find_if(std::begin(friendList_), std::end(friendList_),
        [avatar](auto& frnd) { return frnd.frnd->GetAvatarId() == avatar->GetAvatarId(); });

    if (find_iter != std::end(friendList_)) {
        find_iter->comment = comment;
        avatarService_->UpdateFriendComment(avatarId_, avatar->avatarId_, comment);
    }
}

bool ChatAvatar::IsFriend(const ChatAvatar* avatar) {
    auto find_iter = std::find_if(std::begin(friendList_), std::end(friendList_),
        [avatar](auto& frnd) { return frnd.frnd->GetAvatarId() == avatar->GetAvatarId(); });

    if (find_iter != std::end(friendList_)) {
        return true;
    }

    return false;
}

void ChatAvatar::AddIgnore(ChatAvatar* avatar) {
    if (IsIgnored(avatar)) return;
    if (IsFriend(avatar)) RemoveFriend(avatar);

    ignoreList_.push_back(IgnoreContact{avatar});

    avatarService_->PersistIgnore(avatarId_, avatar->avatarId_);
}

void ChatAvatar::RemoveIgnore(const ChatAvatar* avatar) {
    auto del_iter = std::remove_if(std::begin(ignoreList_), std::end(ignoreList_),
        [avatar](auto& ignored) { return ignored.ignored->GetAvatarId() == avatar->GetAvatarId(); });

    if (del_iter != std::end(ignoreList_)) {
        ignoreList_.erase(del_iter);

        avatarService_->RemoveIgnore(avatarId_, avatar->avatarId_);
    }
}

bool ChatAvatar::IsIgnored(const ChatAvatar* avatar) {
    auto find_iter = std::find_if(std::begin(ignoreList_), std::end(ignoreList_),
                                  [avatar](auto& ignored) { return ignored.ignored->GetAvatarId() == avatar->GetAvatarId(); });

    if (find_iter != std::end(ignoreList_)) {
        return true;
    }

    return false;
}
