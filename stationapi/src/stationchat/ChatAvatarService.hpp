
#pragma once

#include "ChatAvatar.hpp"
#include "ChatEnums.hpp"

#include <boost/optional.hpp>

#include <memory>
#include <string>
#include <unordered_map>

struct sqlite3;

class ChatAvatarService {
public:
    explicit ChatAvatarService(sqlite3* db);
    ~ChatAvatarService();
    
    ChatAvatar* GetAvatar(const std::u16string& name, const std::u16string& address);
    ChatAvatar* GetAvatar(uint32_t avatarId);

    ChatAvatar* CreateAvatar(const std::u16string& name,
                             const std::u16string& address, uint32_t userId, uint32_t loginAttributes,
                             const std::u16string& loginLocation);

    void DestroyAvatar(ChatAvatar* avatar);

    void LoginAvatar(ChatAvatar* avatar);
    void LogoutAvatar(ChatAvatar* avatar);

    void PersistAvatar(const ChatAvatar* avatar);
    void PersistFriend(uint32_t srcAvatarId, uint32_t destAvatarId, const std::u16string& comment);
    void PersistIgnore(uint32_t srcAvatarId, uint32_t destAvatarId);

    void RemoveFriend(uint32_t srcAvatarId, uint32_t destAvatarId);
    void RemoveIgnore(uint32_t srcAvatarId, uint32_t destAvatarId);

    void UpdateFriendComment(uint32_t srcAvatarId, uint32_t destAvatarId, const std::u16string& comment);

    const std::vector<ChatAvatar*>& GetOnlineAvatars() const { return onlineAvatars_; }
    
private:
    ChatAvatar* GetCachedAvatar(const std::u16string& name, const std::u16string& address);
    ChatAvatar* GetCachedAvatar(uint32_t avatarId);

    void RemoveCachedAvatar(uint32_t avatarId);
    void RemoveAsFriendOrIgnoreFromAll(const ChatAvatar* avatar);
    
    std::unique_ptr<ChatAvatar> LoadStoredAvatar(const std::u16string& name, const std::u16string& address);
    std::unique_ptr<ChatAvatar> LoadStoredAvatar(uint32_t avatarId);

    void InsertAvatar(ChatAvatar* avatar);
    void UpdateAvatar(const ChatAvatar* avatar);
    void DeleteAvatar(ChatAvatar* avatar);

    void LoadFriendList(ChatAvatar* avatar);
    void LoadIgnoreList(ChatAvatar* avatar);

    bool IsOnline(const ChatAvatar* avatar) const;

    std::vector<std::unique_ptr<ChatAvatar>> avatarCache_;
    std::vector<ChatAvatar*> onlineAvatars_;
    sqlite3* db_;
};
