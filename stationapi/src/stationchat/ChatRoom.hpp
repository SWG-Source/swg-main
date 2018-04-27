
#pragma once

#include "ChatEnums.hpp"

#include <string>
#include <vector>

class ChatAvatar;
class ChatRoomService;

enum class RoomAttributes : uint32_t {
    PRIVATE = 1 << 0,
    MODERATED = 1 << 1,
    PERSISTENT = 1 << 2,
    LOCAL_WORLD = 1 << 4,
    LOCAL_GAME = 1 << 5
};

class ChatRoom {
public:
    ChatRoom() = default;
    ChatRoom(ChatRoomService* roomService, uint32_t roomId, const ChatAvatar* creator,
             const std::u16string& roomName, const std::u16string& roomTopic, const std::u16string& roomPassword,
             uint32_t roomAttributes, uint32_t maxRoomSize, const std::u16string& roomAddress,
             const std::u16string& srcAddress);

    bool IsPrivate() const;
    bool IsModerated() const;
    bool IsPersistent() const;
    bool IsLocalWorld() const;
    bool IsLocalGame() const;
    
    void EnterRoom(ChatAvatar* avatar, const std::u16string& password);
    bool IsInRoom(ChatAvatar* avatar) const;
    bool IsInRoom(uint32_t avatarId) const;
    void LeaveRoom(ChatAvatar* avatar);

    uint32_t GetCreatorId() const { return creatorId_; }
    const std::u16string& GetCreatorName() const { return creatorName_; }
    const std::u16string& GetCreatorAddress() const { return creatorAddress_; }
    const std::u16string& GetRoomName() const { return roomName_; }
    const std::u16string& GetRoomAddress() const { return roomAddress_; }
    const std::u16string& GetRoomTopic() const { return roomTopic_; }
    const std::u16string& GetRoomPassword() const { return roomPassword_; }
    const std::u16string& GetRoomPrefix() const { return roomPrefix_; }
    uint32_t GetRoomAttributes() const { return roomAttributes_; }
    uint32_t GetCurrentRoomSize() const { return avatars_.size(); }
    uint32_t GetMaxRoomSize() const { return maxRoomSize_; }
    uint32_t GetRoomId() const { return roomId_; }
    uint32_t GetCreateTime() const { return createTime_; }
    uint32_t GetNodeLevel() const { return nodeLevel_; }

    const std::vector<ChatAvatar*> GetAvatars() const { return avatars_; }    
    /** Returns a list of id's in the room that are not ignoring the srcAvatar.
    */
    std::vector<uint32_t> GetAvatarIds(const ChatAvatar* srcAvatar) const;
    const std::vector<const ChatAvatar*> GetAdminstrators() const { return administrators_; }
    const std::vector<const ChatAvatar*> GetModerators() const { return moderators_; }
    const std::vector<const ChatAvatar*> GetTempModerators() const { return tempModerators_; }
    const std::vector<const ChatAvatar*> GetBanned() const { return banned_; }
    const std::vector<const ChatAvatar*> GetInvited() const { return invited_; }
    const std::vector<const ChatAvatar*> GetVoice() const { return voice_; }

    /* Returns the addresses of the different game servers currently with avatars
    * connected to this room.
    */
    std::vector<std::u16string> GetConnectedAddresses() const;
    std::vector<std::u16string> GetRemoteAddresses() const;

    bool IsCreator(uint32_t avatarId) const;
    bool IsModerator(uint32_t avatarId) const;
    bool IsAdministrator(uint32_t avatarId) const;
    bool IsBanned(uint32_t avatarId) const;
    bool IsInvited(uint32_t avatarId) const;

    void KickAvatar(uint32_t srcAvatarId, ChatAvatar* destAvatar);

    void AddAdministrator(uint32_t srcAvatarId, ChatAvatar* administrator);
    void AddModerator(uint32_t srcAvatarId, ChatAvatar* moderator);
    void AddBanned(uint32_t srcAvatarId, ChatAvatar* banned);
    void AddInvite(uint32_t srcAvatarId, ChatAvatar* invited);

    void RemoveAdministrator(uint32_t srcAvatarId, uint32_t avatarId);
    void RemoveModerator(uint32_t srcAvatarId, uint32_t avatarId);
    void RemoveBanned(uint32_t srcAvatarId, uint32_t avatarId);
    void RemoveInvite(uint32_t srcAvatarId, uint32_t avatarId);

    uint32_t GetNextMessageId() { return roomMessageId_++; }

private:
    friend class ChatRoomService;
    ChatRoomService* roomService_;
    std::u16string creatorName_;
    std::u16string creatorAddress_;
    std::u16string roomName_;
    std::u16string roomTopic_;
    std::u16string roomPassword_;
    std::u16string roomPrefix_ = u"";
    std::u16string roomAddress_;

    uint32_t creatorId_;
    uint32_t roomAttributes_;
    uint32_t maxRoomSize_;
    uint32_t roomId_ = 0;
    uint32_t createTime_ = 0;
    uint32_t nodeLevel_ = 0;
    uint32_t roomMessageId_ = 1;
    int32_t dbId_ = -1;

    std::vector<ChatAvatar*> avatars_;
    std::vector<const ChatAvatar*> administrators_;
    std::vector<const ChatAvatar*> moderators_;
    std::vector<const ChatAvatar*> tempModerators_;
    std::vector<const ChatAvatar*> banned_;
    std::vector<const ChatAvatar*> invited_;
    std::vector<const ChatAvatar*> voice_;
};

template <typename StreamT>
void write(StreamT& ar, const ChatRoom& data) {
    write(ar, data.GetCreatorName());
    write(ar, data.GetCreatorAddress());
    write(ar, data.GetCreatorId());
    write(ar, data.GetRoomName());
    write(ar, data.GetRoomTopic());
    write(ar, data.GetRoomPrefix());
    write(ar, data.GetRoomAddress());
    write(ar, data.GetRoomPassword());
    write(ar, data.GetRoomAttributes());
    write(ar, data.GetMaxRoomSize());
    write(ar, data.GetRoomId());
    write(ar, data.GetCreateTime());
    write(ar, data.GetNodeLevel());

    auto& avatars = data.GetAvatars();
    write(ar, static_cast<uint32_t>(avatars.size()));
    for (auto& avatar : avatars)
        write(ar, avatar);

    auto& administrators = data.GetAdminstrators();
    write(ar, static_cast<uint32_t>(administrators.size()));
    for (auto& avatar : administrators)
        write(ar, avatar);

    auto& moderators = data.GetModerators();
    write(ar, static_cast<uint32_t>(moderators.size()));
    for (auto& avatar : moderators)
        write(ar, avatar);

    auto& tempModerators = data.GetTempModerators();
    write(ar, static_cast<uint32_t>(tempModerators.size()));
    for (auto& avatar : tempModerators)
        write(ar, avatar);

    auto& banned = data.GetBanned();
    write(ar, static_cast<uint32_t>(banned.size()));
    for (auto& avatar : banned)
        write(ar, avatar);

    auto& invited = data.GetInvited();
    write(ar, static_cast<uint32_t>(invited.size()));
    for (auto& avatar : invited)
        write(ar, avatar);

    auto& voice = data.GetVoice();
    write(ar, static_cast<uint32_t>(voice.size()));
    for (auto& avatar : voice)
        write(ar, avatar);
}
