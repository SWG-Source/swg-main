#include "ChatAvatarService.hpp"
#include "ChatAvatar.hpp"
#include "SQLite3.hpp"
#include "StringUtils.hpp"

#include <easylogging++.h>

ChatAvatarService::ChatAvatarService(sqlite3* db)
    : db_{db} {}

ChatAvatarService::~ChatAvatarService() {}

ChatAvatar* ChatAvatarService::GetAvatar(const std::u16string& name, const std::u16string& address) {
    ChatAvatar* avatar = GetCachedAvatar(name, address);

    if (!avatar) {
        auto loadedAvatar = LoadStoredAvatar(name, address);
        if (loadedAvatar != nullptr) {
            avatar = loadedAvatar.get();
            avatarCache_.emplace_back(std::move(loadedAvatar));

            LoadFriendList(avatar);
            LoadIgnoreList(avatar);
        }
    }

    return avatar;
}

ChatAvatar* ChatAvatarService::GetAvatar(uint32_t avatarId) {
    ChatAvatar* avatar = GetCachedAvatar(avatarId);

    if (!avatar) {
        auto loadedAvatar = LoadStoredAvatar(avatarId);
        if (loadedAvatar != nullptr) {
            avatar = loadedAvatar.get();
            avatarCache_.emplace_back(std::move(loadedAvatar));

            LoadFriendList(avatar);
            LoadIgnoreList(avatar);
        }
    }

    return avatar;
}

ChatAvatar* ChatAvatarService::CreateAvatar(const std::u16string& name, const std::u16string& address,
    uint32_t userId, uint32_t loginAttributes, const std::u16string& loginLocation) {
    auto tmp
        = std::make_unique<ChatAvatar>(this, name, address, userId, loginAttributes, loginLocation);
    auto avatar = tmp.get();

    InsertAvatar(avatar);

    avatarCache_.emplace_back(std::move(tmp));

    return avatar;
}

void ChatAvatarService::DestroyAvatar(ChatAvatar* avatar) {
    DeleteAvatar(avatar);
    LogoutAvatar(avatar);
    RemoveCachedAvatar(avatar->GetAvatarId());
}

void ChatAvatarService::LoginAvatar(ChatAvatar* avatar) {
    avatar->isOnline_ = true;

    if (!IsOnline(avatar)) {
        onlineAvatars_.push_back(avatar);
    }
}

void ChatAvatarService::LogoutAvatar(ChatAvatar* avatar) {
    avatar->isOnline_ = false;

    onlineAvatars_.erase(std::remove_if(
        std::begin(onlineAvatars_), std::end(onlineAvatars_), [avatar](auto onlineAvatar) {
            return onlineAvatar->GetAvatarId() == avatar->GetAvatarId();
        }));
}

void ChatAvatarService::PersistAvatar(const ChatAvatar* avatar) { UpdateAvatar(avatar); }

void ChatAvatarService::PersistFriend(
    uint32_t srcAvatarId, uint32_t destAvatarId, const std::u16string& comment) {
    sqlite3_stmt* stmt;
    char sql[] = "INSERT INTO friend (avatar_id, friend_avatar_id, comment) VALUES (@avatar_id, "
                 "@friend_avatar_id, @comment)";

    auto result = sqlite3_prepare_v2(db_, sql, -1, &stmt, 0);
    if (result != SQLITE_OK) {
        throw SQLite3Exception{result, sqlite3_errmsg(db_)};
    }

    int avatarIdIdx = sqlite3_bind_parameter_index(stmt, "@avatar_id");
    int friendAvatarIdIdx = sqlite3_bind_parameter_index(stmt, "@friend_avatar_id");
    int commentIdx = sqlite3_bind_parameter_index(stmt, "@comment");

    std::string commentStr = FromWideString(comment);

    sqlite3_bind_int(stmt, avatarIdIdx, srcAvatarId);
    sqlite3_bind_int(stmt, friendAvatarIdIdx, destAvatarId);
    sqlite3_bind_text(stmt, commentIdx, commentStr.c_str(), -1, 0);

    result = sqlite3_step(stmt);
    if (result != SQLITE_DONE) {
        throw SQLite3Exception{result, sqlite3_errmsg(db_)};
    }
}

void ChatAvatarService::PersistIgnore(uint32_t srcAvatarId, uint32_t destAvatarId) {
    sqlite3_stmt* stmt;
    char sql[] = "INSERT INTO ignore (avatar_id, ignore_avatar_id, comment) VALUES (@avatar_id, "
                 "@ignore_avatar_id)";

    auto result = sqlite3_prepare_v2(db_, sql, -1, &stmt, 0);
    if (result != SQLITE_OK) {
        throw SQLite3Exception{result, sqlite3_errmsg(db_)};
    }

    int avatarIdIdx = sqlite3_bind_parameter_index(stmt, "@avatar_id");
    int ignoreAvatarIdIdx = sqlite3_bind_parameter_index(stmt, "@ignore_avatar_id");

    sqlite3_bind_int(stmt, avatarIdIdx, srcAvatarId);
    sqlite3_bind_int(stmt, ignoreAvatarIdIdx, destAvatarId);

    result = sqlite3_step(stmt);
    if (result != SQLITE_DONE) {
        throw SQLite3Exception{result, sqlite3_errmsg(db_)};
    }
}

void ChatAvatarService::RemoveFriend(uint32_t srcAvatarId, uint32_t destAvatarId) {
    sqlite3_stmt* stmt;

    char sql[] = "DELETE FROM friend WHERE avatar_id = @avatar_id AND friend_avatar_id = "
                 "@friend_avatar_id";

    auto result = sqlite3_prepare_v2(db_, sql, -1, &stmt, 0);
    if (result != SQLITE_OK) {
        throw SQLite3Exception{result, sqlite3_errmsg(db_)};
    }

    int avatarIdIdx = sqlite3_bind_parameter_index(stmt, "@avatar_id");
    int friendAvatarIdIdx = sqlite3_bind_parameter_index(stmt, "@friend_avatar_id");

    sqlite3_bind_int(stmt, avatarIdIdx, srcAvatarId);
    sqlite3_bind_int(stmt, friendAvatarIdIdx, destAvatarId);

    result = sqlite3_step(stmt);
    if (result != SQLITE_DONE) {
        throw SQLite3Exception{result, sqlite3_errmsg(db_)};
    }
}

void ChatAvatarService::RemoveIgnore(uint32_t srcAvatarId, uint32_t destAvatarId) {
    sqlite3_stmt* stmt;

    char sql[] = "DELETE FROM ignore WHERE avatar_id = @avatar_id AND ignore_avatar_id = "
                 "@ignore_avatar_id";

    auto result = sqlite3_prepare_v2(db_, sql, -1, &stmt, 0);
    if (result != SQLITE_OK) {
        throw SQLite3Exception{result, sqlite3_errmsg(db_)};
    }

    int avatarIdIdx = sqlite3_bind_parameter_index(stmt, "@avatar_id");
    int ignoreAvatarIdIdx = sqlite3_bind_parameter_index(stmt, "@ignore_avatar_id");

    sqlite3_bind_int(stmt, avatarIdIdx, srcAvatarId);
    sqlite3_bind_int(stmt, ignoreAvatarIdIdx, destAvatarId);

    result = sqlite3_step(stmt);
    if (result != SQLITE_DONE) {
        throw SQLite3Exception{result, sqlite3_errmsg(db_)};
    }
}

void ChatAvatarService::UpdateFriendComment(
    uint32_t srcAvatarId, uint32_t destAvatarId, const std::u16string& comment) {
    sqlite3_stmt* stmt;
    char sql[] = "UDPATE friend SET comment = @comment WHERE avatar_id = @avatar_id AND "
                 "friend_avatar_id = @friend_avatar_id";

    auto result = sqlite3_prepare_v2(db_, sql, -1, &stmt, 0);
    if (result != SQLITE_OK) {
        throw SQLite3Exception{result, sqlite3_errmsg(db_)};
    }

    int commentIdx = sqlite3_bind_parameter_index(stmt, "@comment");
    int avatarIdIdx = sqlite3_bind_parameter_index(stmt, "@avatar_id");
    int friendAvatarIdIdx = sqlite3_bind_parameter_index(stmt, "@friend_avatar_id");

    std::string commentStr = FromWideString(comment);

    sqlite3_bind_text(stmt, commentIdx, commentStr.c_str(), -1, 0);
    sqlite3_bind_int(stmt, avatarIdIdx, srcAvatarId);
    sqlite3_bind_int(stmt, friendAvatarIdIdx, destAvatarId);

    result = sqlite3_step(stmt);
    if (result != SQLITE_DONE) {
        throw SQLite3Exception{result, sqlite3_errmsg(db_)};
    }
}

ChatAvatar* ChatAvatarService::GetCachedAvatar(
    const std::u16string& name, const std::u16string& address) {
    ChatAvatar* avatar = nullptr;

    // First look for the avatar in the cache
    auto find_iter = std::find_if(
        std::begin(avatarCache_), std::end(avatarCache_), [name, address](const auto& avatar) {
            return avatar->name_.compare(name) == 0 && avatar->address_.compare(address) == 0;
        });

    if (find_iter != std::end(avatarCache_)) {
        avatar = find_iter->get();
    }

    return avatar;
}

ChatAvatar* ChatAvatarService::GetCachedAvatar(uint32_t avatarId) {
    ChatAvatar* avatar = nullptr;

    // First look for the avatar in the cache
    auto find_iter = std::find_if(std::begin(avatarCache_), std::end(avatarCache_),
        [avatarId](const auto& avatar) { return avatar->avatarId_ == avatarId; });

    if (find_iter != std::end(avatarCache_)) {
        avatar = find_iter->get();
    }

    return avatar;
}

void ChatAvatarService::RemoveCachedAvatar(uint32_t avatarId) {
    auto remove_iter = std::remove_if(std::begin(avatarCache_), std::end(avatarCache_),
                                  [avatarId](const auto& avatar) { return avatar->avatarId_ == avatarId; });

    if (remove_iter != std::end(avatarCache_)) {
        avatarCache_.erase(remove_iter);
    }
}

void ChatAvatarService::RemoveAsFriendOrIgnoreFromAll(const ChatAvatar* avatar) {
    for (auto& cachedAvatar : avatarCache_) {
        if (cachedAvatar->IsFriend(avatar)) {
            cachedAvatar->RemoveFriend(avatar);
        }

        if (cachedAvatar->IsIgnored(avatar)) {
            cachedAvatar->RemoveIgnore(avatar);
        }
    }
}

std::unique_ptr<ChatAvatar> ChatAvatarService::LoadStoredAvatar(
    const std::u16string& name, const std::u16string& address) {
    std::unique_ptr<ChatAvatar> avatar{nullptr};

    sqlite3_stmt* stmt;

    char sql[] = "SELECT id, user_id, name, address, attributes FROM avatar WHERE name = @name AND "
                 "address = @address";

    auto result = sqlite3_prepare_v2(db_, sql, -1, &stmt, 0);
    if (result != SQLITE_OK) {
        throw SQLite3Exception{result, sqlite3_errmsg(db_)};
    }

    std::string nameStr = FromWideString(name);
    std::string addressStr = FromWideString(address);

    int nameIdx = sqlite3_bind_parameter_index(stmt, "@name");
    int addressIdx = sqlite3_bind_parameter_index(stmt, "@address");

    sqlite3_bind_text(stmt, nameIdx, nameStr.c_str(), -1, 0);
    sqlite3_bind_text(stmt, addressIdx, addressStr.c_str(), -1, 0);

    if (sqlite3_step(stmt) == SQLITE_ROW) {
        avatar = std::make_unique<ChatAvatar>(this);
        avatar->avatarId_ = sqlite3_column_int(stmt, 0);
        avatar->userId_ = sqlite3_column_int(stmt, 1);

        auto tmp = std::string(reinterpret_cast<const char*>(sqlite3_column_text(stmt, 2)));
        avatar->name_ = std::u16string{std::begin(tmp), std::end(tmp)};

        tmp = std::string(reinterpret_cast<const char*>(sqlite3_column_text(stmt, 3)));
        avatar->address_ = std::u16string(std::begin(tmp), std::end(tmp));

        avatar->attributes_ = sqlite3_column_int(stmt, 4);
    }

    sqlite3_finalize(stmt);

    return avatar;
}

std::unique_ptr<ChatAvatar> ChatAvatarService::LoadStoredAvatar(uint32_t avatarId) {
    std::unique_ptr<ChatAvatar> avatar{nullptr};

    sqlite3_stmt* stmt;

    char sql[] = "SELECT id, user_id, name, address, attributes FROM avatar WHERE id = @avatar_id";

    auto result = sqlite3_prepare_v2(db_, sql, -1, &stmt, 0);
    if (result != SQLITE_OK) {
        throw SQLite3Exception{result, sqlite3_errmsg(db_)};
    }

    int avatarIdIdx = sqlite3_bind_parameter_index(stmt, "@avatar_id");

    sqlite3_bind_int(stmt, avatarIdIdx, avatarId);

    if (sqlite3_step(stmt) == SQLITE_ROW) {
        avatar = std::make_unique<ChatAvatar>(this);
        avatar->avatarId_ = sqlite3_column_int(stmt, 0);
        avatar->userId_ = sqlite3_column_int(stmt, 1);

        auto tmp = std::string(reinterpret_cast<const char*>(sqlite3_column_text(stmt, 2)));
        avatar->name_ = std::u16string{std::begin(tmp), std::end(tmp)};

        tmp = std::string(reinterpret_cast<const char*>(sqlite3_column_text(stmt, 3)));
        avatar->address_ = std::u16string(std::begin(tmp), std::end(tmp));

        avatar->attributes_ = sqlite3_column_int(stmt, 4);
    }

    sqlite3_finalize(stmt);

    return avatar;
}

void ChatAvatarService::InsertAvatar(ChatAvatar* avatar) {
    CHECK_NOTNULL(avatar);
    sqlite3_stmt* stmt;

    char sql[] = "INSERT INTO avatar (user_id, name, address, attributes) VALUES (@user_id, @name, "
                 "@address, @attributes)";

    auto result = sqlite3_prepare_v2(db_, sql, -1, &stmt, 0);
    if (result != SQLITE_OK) {
        throw SQLite3Exception{result, sqlite3_errmsg(db_)};
    }

    std::string nameStr = FromWideString(avatar->name_);
    std::string addressStr = FromWideString(avatar->address_);

    int userIdIdx = sqlite3_bind_parameter_index(stmt, "@user_id");
    int nameIdx = sqlite3_bind_parameter_index(stmt, "@name");
    int addressIdx = sqlite3_bind_parameter_index(stmt, "@address");
    int attributesIdx = sqlite3_bind_parameter_index(stmt, "@attributes");

    sqlite3_bind_int(stmt, userIdIdx, avatar->userId_);
    sqlite3_bind_text(stmt, nameIdx, nameStr.c_str(), -1, 0);
    sqlite3_bind_text(stmt, addressIdx, addressStr.c_str(), -1, 0);
    sqlite3_bind_int(stmt, attributesIdx, avatar->attributes_);

    result = sqlite3_step(stmt);
    if (result != SQLITE_DONE) {
        throw SQLite3Exception{result, sqlite3_errmsg(db_)};
    }

    avatar->avatarId_ = static_cast<uint32_t>(sqlite3_last_insert_rowid(db_));

    sqlite3_finalize(stmt);
}

void ChatAvatarService::UpdateAvatar(const ChatAvatar* avatar) {
    CHECK_NOTNULL(avatar);
    sqlite3_stmt* stmt;

    char sql[] = "UPDATE avatar SET user_id = @user_id, name = @name, address = @address, "
                 "attributes = @attributes "
                 "WHERE id = @avatar_id";

    auto result = sqlite3_prepare_v2(db_, sql, -1, &stmt, 0);
    if (result != SQLITE_OK) {
        throw SQLite3Exception{result, sqlite3_errmsg(db_)};
    }

    std::string nameStr = FromWideString(avatar->name_);
    std::string addressStr = FromWideString(avatar->address_);

    int userIdIdx = sqlite3_bind_parameter_index(stmt, "@user_id");
    int nameIdx = sqlite3_bind_parameter_index(stmt, "@name");
    int addressIdx = sqlite3_bind_parameter_index(stmt, "@address");
    int attributesIdx = sqlite3_bind_parameter_index(stmt, "@attributes");
    int avatarIdIdx = sqlite3_bind_parameter_index(stmt, "@avatar_id");

    sqlite3_bind_int(stmt, userIdIdx, avatar->userId_);
    sqlite3_bind_text(stmt, nameIdx, nameStr.c_str(), -1, 0);
    sqlite3_bind_text(stmt, addressIdx, addressStr.c_str(), -1, 0);
    sqlite3_bind_int(stmt, attributesIdx, avatar->attributes_);
    sqlite3_bind_int(stmt, avatarIdIdx, avatar->avatarId_);

    result = sqlite3_step(stmt);
    if (result != SQLITE_DONE) {
        throw SQLite3Exception{result, sqlite3_errmsg(db_)};
    }

    sqlite3_finalize(stmt);
}

void ChatAvatarService::DeleteAvatar(ChatAvatar* avatar) {
    CHECK_NOTNULL(avatar);
    sqlite3_stmt* stmt;

    char sql[] = "DELETE FROM avatar WHERE id = @avatar_id";

    auto result = sqlite3_prepare_v2(db_, sql, -1, &stmt, 0);
    if (result != SQLITE_OK) {
        throw SQLite3Exception{result, sqlite3_errmsg(db_)};
    }

    int avatarIdIdx = sqlite3_bind_parameter_index(stmt, "@avatar_id");

    sqlite3_bind_int(stmt, avatarIdIdx, avatar->avatarId_);

    result = sqlite3_step(stmt);
    if (result != SQLITE_DONE) {
        throw SQLite3Exception{result, sqlite3_errmsg(db_)};
    }

    sqlite3_finalize(stmt);
}

void ChatAvatarService::LoadFriendList(ChatAvatar* avatar) {
    sqlite3_stmt* stmt;

    char sql[] = "SELECT friend_avatar_id, comment FROM friend WHERE avatar_id = @avatar_id";

    auto result = sqlite3_prepare_v2(db_, sql, -1, &stmt, 0);
    if (result != SQLITE_OK) {
        throw SQLite3Exception{result, sqlite3_errmsg(db_)};
    }

    int avatarIdIdx = sqlite3_bind_parameter_index(stmt, "@avatar_id");

    sqlite3_bind_int(stmt, avatarIdIdx, avatar->avatarId_);

    uint32_t tmpFriendId;
    std::string tmpComment;
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        tmpFriendId = sqlite3_column_int(stmt, 0);
        tmpComment = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 1));

        auto friendAvatar = GetAvatar(tmpFriendId);

        avatar->friendList_.emplace_back(friendAvatar, ToWideString(tmpComment));
    }
}

void ChatAvatarService::LoadIgnoreList(ChatAvatar* avatar) {
    sqlite3_stmt* stmt;

    char sql[] = "SELECT ignore_avatar_id FROM ignore WHERE avatar_id = @avatar_id";

    auto result = sqlite3_prepare_v2(db_, sql, -1, &stmt, 0);
    if (result != SQLITE_OK) {
        throw SQLite3Exception{result, sqlite3_errmsg(db_)};
    }

    int avatarIdIdx = sqlite3_bind_parameter_index(stmt, "@avatar_id");

    sqlite3_bind_int(stmt, avatarIdIdx, avatar->avatarId_);

    uint32_t tmpIgnoreId;
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        tmpIgnoreId = sqlite3_column_int(stmt, 0);

        auto ignoreAvatar = GetAvatar(tmpIgnoreId);

        avatar->ignoreList_.emplace_back(ignoreAvatar);
    }
}

bool ChatAvatarService::IsOnline(const ChatAvatar * avatar) const {
    for (auto onlineAvatar : onlineAvatars_) {
        if (onlineAvatar->GetAvatarId() == avatar->GetAvatarId()) {
            return true;
        }
    }

    return false;
}
