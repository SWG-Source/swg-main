
#pragma once

#include "ChatAvatar.hpp"
#include "PersistentMessage.hpp"

#include <cstdint>
#include <string>

enum class ChatMessageType : uint16_t {
    // ChatAvatar message types
    INSTANTMESSAGE = 0, // 0
    ROOMMESSAGE,
    BROADCASTMESSAGE,
    FRIENDLOGIN,
    FRIENDLOGOUT,
    KICKROOM, // 5

    // ChatRoom message types
    ADDMODERATORROOM,
    REMOVEMODERATORROOM,
    REMOVEMODERATORAVATAR,
    ADDBANROOM,
    REMOVEBANROOM, // 10
    REMOVEBANAVATAR,
    ADDINVITEROOM,
    ADDINVITEAVATAR,
    REMOVEINVITEROOM,
    REMOVEINVITEAVATAR, // 15
    ENTERROOM,
    LEAVEROOM,
    DESTROYROOM,
    SETROOMPARAMS,
    PERSISTENTMESSAGE, // 20
    FORCEDLOGOUT,
    UNREGISTERROOMREADY,
    KICKAVATAR,
    ADDMODERATORAVATAR,
    ADDBANAVATAR, // 25
    ADDADMIN,
    REMOVEADMIN,
    FRIENDCONFIRMREQUEST,
    FRIENDCONFIRMRESPONSE,
    CHANGEROOMOWNER, // 30
    FORCEROOMFAILOVER,
    ADDTEMPORARYMODERATORROOM,
    ADDTEMPORARYMODERATORAVATAR,
    REMOVETEMPORARYMODERATORROOM,
    REMOVETEMPORARYMODERATORAVATAR, // 35
    GRANTVOICEROOM,
    GRANTVOICEAVATAR,
    REVOKEVOICEROOM,
    REVOKEVOICEAVATAR,
    SNOOP, // 40
    UIDLIST,
    REQUESTROOMENTRY,
    DELAYEDROOMENTRY,
    DENIEDROOMENTRY,
    FRIENDSTATUS, // 45
    FRIENDCONFIRMRECIPROCATE_REQUEST,
    FRIENDCONFIRMRECIPROCATE_RESPONSE,
    FILTERMESSAGE,
    FAILOVER_AVATAR_LIST,
    NOTIFY_FRIENDS_LIST_CHANGE, // 50
    NOTIFY_FRIEND_IS_REMOVED
};

/** Begin INSTANTMESSAGE */

struct MInstantMessage {
    MInstantMessage(const ChatAvatar* srcAvatar_, uint32_t destAvatarId_,
        const std::u16string& message_, const std::u16string& oob_)
        : srcAvatar{srcAvatar_}
        , destAvatarId{destAvatarId_}
        , message{message_}
        , oob{oob_} {}

    const ChatMessageType type = ChatMessageType::INSTANTMESSAGE;
    const uint32_t track = 0;
    const ChatAvatar* srcAvatar;
    uint32_t destAvatarId;
    std::u16string message;
    std::u16string oob;
};

template <typename StreamT>
void write(StreamT& ar, const MInstantMessage& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.srcAvatar);
    write(ar, data.destAvatarId);
    write(ar, data.message);
    write(ar, data.oob);
}

/** Begin ROOMMESSAGE */

struct MRoomMessage {
    MRoomMessage(const ChatAvatar* srcAvatar_, uint32_t roomId_, std::vector<uint32_t> destList_,
        const std::u16string& message_, const std::u16string& oob_, uint32_t messageId_)
        : srcAvatar{srcAvatar_}
        , roomId{roomId_}
        , destList{destList_}
        , message{message_}
        , oob{oob_}
        , messageId{messageId_} {}

    const ChatMessageType type = ChatMessageType::ROOMMESSAGE;
    const uint32_t track = 0;
    const ChatAvatar* srcAvatar;
    uint32_t roomId;
    std::vector<uint32_t> destList; // list of destination avatars to see the message
    std::u16string message;
    std::u16string oob;
    uint32_t messageId = 0;
};

template <typename StreamT>
void write(StreamT& ar, const MRoomMessage& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.srcAvatar);
    write(ar, data.roomId);

    write(ar, static_cast<uint32_t>(data.destList.size()));
    for (auto destAvatarId : data.destList) {
        write(ar, destAvatarId);
    }

    write(ar, data.message);
    write(ar, data.oob);
    write(ar, data.messageId);
}

/** Begin FRIENDLOGIN */

struct MFriendLogin {
    MFriendLogin(const ChatAvatar* avatar_, const std::u16string& friendAddress_,
        uint32_t destAvatarId_, const std::u16string& friendStatus_)
        : avatar{avatar_}
        , friendAddress{friendAddress_}
        , destAvatarId{destAvatarId_}
        , friendStatus{friendStatus_} {}

    const ChatMessageType type = ChatMessageType::FRIENDLOGIN;
    const uint32_t track = 0;
    const ChatAvatar* avatar;
    std::u16string friendAddress;
    uint32_t destAvatarId;
    std::u16string friendStatus;
};

template <typename StreamT>
void write(StreamT& ar, const MFriendLogin& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.avatar);
    write(ar, data.friendAddress);
    write(ar, data.destAvatarId);
    write(ar, data.friendStatus);
}

/** Begin FRIENDLOGOUT */

struct MFriendLogout {
    MFriendLogout(
        const ChatAvatar* avatar_, const std::u16string& friendAddress_, uint32_t destAvatarId_)
        : avatar{avatar_}
        , friendAddress{friendAddress_}
        , destAvatarId{destAvatarId_} {}

    const ChatMessageType type = ChatMessageType::FRIENDLOGOUT;
    const uint32_t track = 0;
    const ChatAvatar* avatar;
    uint32_t destAvatarId;
    std::u16string friendAddress;
};

template <typename StreamT>
void write(StreamT& ar, const MFriendLogout& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.avatar);
    write(ar, data.friendAddress);
    write(ar, data.destAvatarId);
}

/** Begin ENTERROOM */

struct MEnterRoom {
    MEnterRoom(const ChatAvatar* srcAvatar_, uint32_t roomId_)
        : srcAvatar{srcAvatar_}
        , roomId{roomId_} {}

    const ChatMessageType type = ChatMessageType::ENTERROOM;
    const uint32_t track = 0;
    const ChatAvatar* srcAvatar;
    uint32_t roomId;
};

template <typename StreamT>
void write(StreamT& ar, const MEnterRoom& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.srcAvatar);
    write(ar, data.roomId);
}

/** Begin LEAVEROOM */

struct MLeaveRoom {
    MLeaveRoom(uint32_t avatarId_, uint32_t roomId_)
        : avatarId{avatarId_}
        , roomId{roomId_} {}

    const ChatMessageType type = ChatMessageType::LEAVEROOM;
    const uint32_t track = 0;
    uint32_t avatarId;
    uint32_t roomId;
};

template <typename StreamT>
void write(StreamT& ar, const MLeaveRoom& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.avatarId);
    write(ar, data.roomId);
}

/** Begin DESTROYROOM */

struct MDestroyRoom {
    MDestroyRoom(const ChatAvatar* srcAvatar_, uint32_t roomId_)
        : srcAvatar{srcAvatar_}
        , roomId{roomId_} {}

    const ChatMessageType type = ChatMessageType::DESTROYROOM;
    const uint32_t track = 0;
    const ChatAvatar* srcAvatar;
    uint32_t roomId;
};

template <typename StreamT>
void write(StreamT& ar, const MDestroyRoom& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.srcAvatar);
    write(ar, data.roomId);
}

/** Begin PERSISTENTMESSAGE */

struct MPersistentMessage {
    MPersistentMessage(uint32_t destAvatarId_, PersistentHeader header_)
        : destAvatarId{destAvatarId_}
        , header{header_} {}

    const ChatMessageType type = ChatMessageType::PERSISTENTMESSAGE;
    const uint32_t track = 0;
    uint32_t destAvatarId;
    PersistentHeader header;
};

template <typename StreamT>
void write(StreamT& ar, const MPersistentMessage& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.destAvatarId);
    write(ar, data.header);
}

/** Begin KICKAVATAR */

struct MKickAvatar {
    MKickAvatar(const ChatAvatar* srcAvatar_, const ChatAvatar* destAvatar_,
        const std::u16string& roomName_, const std::u16string& roomAddress_)
        : srcAvatar{srcAvatar_}
        , destAvatar{destAvatar_}
        , roomName{roomName_}
        , roomAddress{roomAddress_} {}

    const ChatMessageType type = ChatMessageType::KICKAVATAR;
    const uint32_t track = 0;
    const ChatAvatar* srcAvatar;
    const ChatAvatar* destAvatar;
    std::u16string roomName;
    std::u16string roomAddress;
};

template <typename StreamT>
void write(StreamT& ar, const MKickAvatar& data) {
    write(ar, data.type);
    write(ar, data.track);
    write(ar, data.srcAvatar);
    write(ar, data.destAvatar);
    write(ar, data.roomName);
    write(ar, data.roomAddress);
}
