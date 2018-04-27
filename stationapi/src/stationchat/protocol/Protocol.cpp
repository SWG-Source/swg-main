#include "AddBan.hpp"

#include "ChatAvatarService.hpp"
#include "ChatRoomService.hpp"
#include "GatewayClient.hpp"
#include "GatewayNode.hpp"
#include "PersistentMessageService.hpp"
#include "RegistrarClient.hpp"
#include "RegistrarNode.hpp"
#include "StringUtils.hpp"
#include "StationChatConfig.hpp"

#include "protocol/AddBan.hpp"
#include "protocol/AddFriend.hpp"
#include "protocol/AddIgnore.hpp"
#include "protocol/AddInvite.hpp"
#include "protocol/AddModerator.hpp"
#include "protocol/CreateRoom.hpp"
#include "protocol/DestroyAvatar.hpp"
#include "protocol/DestroyRoom.hpp"
#include "protocol/EnterRoom.hpp"
#include "protocol/FailoverReLoginAvatar.hpp"
#include "protocol/FriendStatus.hpp"
#include "protocol/GetAnyAvatar.hpp"
#include "protocol/GetPersistentHeaders.hpp"
#include "protocol/GetPersistentMessage.hpp"
#include "protocol/GetRoom.hpp"
#include "protocol/GetRoomSummaries.hpp"
#include "protocol/IgnoreStatus.hpp"
#include "protocol/KickAvatar.hpp"
#include "protocol/LeaveRoom.hpp"
#include "protocol/LoginAvatar.hpp"
#include "protocol/LogoutAvatar.hpp"
#include "protocol/RegistrarGetChatServer.hpp"
#include "protocol/RemoveBan.hpp"
#include "protocol/RemoveFriend.hpp"
#include "protocol/RemoveIgnore.hpp"
#include "protocol/RemoveInvite.hpp"
#include "protocol/RemoveModerator.hpp"
#include "protocol/SendInstantMessage.hpp"
#include "protocol/SendPersistentMessage.hpp"
#include "protocol/SendRoomMessage.hpp"
#include "protocol/SetApiVersion.hpp"
#include "protocol/SetAvatarAttributes.hpp"
#include "protocol/UpdatePersistentMessage.hpp"

#include "easylogging++.h"

AddBan::AddBan(GatewayClient* client, const RequestType& request, ResponseType& response)
    : avatarService_{client->GetNode()->GetAvatarService()}
    , roomService_{client->GetNode()->GetRoomService()} {
    LOG(INFO) << "ADDBAN request received - adding ban for: "
              << FromWideString(request.destAvatarName) << "@"
              << FromWideString(request.destAvatarAddress) << " to "
              << FromWideString(request.destRoomAddress);

    auto srcAvatar = avatarService_->GetAvatar(request.srcAvatarId);
    if (!srcAvatar) {
        throw ChatResultException{ChatResultCode::SRCAVATARDOESNTEXIST};
    }

    auto bannedAvatar
        = avatarService_->GetAvatar(request.destAvatarName, request.destAvatarAddress);
    if (!bannedAvatar) {
        throw ChatResultException{ChatResultCode::DESTAVATARDOESNTEXIST};
    }

    auto room = roomService_->GetRoom(request.destRoomAddress);
    if (!room) {
        throw ChatResultException{ChatResultCode::ADDRESSNOTROOM};
    }

    response.destRoomId = room->GetRoomId();

    room->AddBanned(srcAvatar->GetAvatarId(), bannedAvatar);
}

AddFriend::AddFriend(GatewayClient* client, const RequestType& request, ResponseType& response)
    : avatarService_{client->GetNode()->GetAvatarService()} {
    LOG(INFO) << "ADDFRIEND request received - adding: " << FromWideString(request.destName) << "@"
              << FromWideString(request.destAddress) << " to " << request.srcAvatarId << "@"
              << FromWideString(request.srcAddress);
    auto srcAvatar = avatarService_->GetAvatar(request.srcAvatarId);
    if (!srcAvatar) {
        throw ChatResultException{ChatResultCode::SRCAVATARDOESNTEXIST};
    }

    auto destAvatar = avatarService_->GetAvatar(request.destName, request.destAddress);
    if (!destAvatar) {
        throw ChatResultException{ChatResultCode::DESTAVATARDOESNTEXIST};
    }

    srcAvatar->AddFriend(destAvatar);

    if (destAvatar->IsOnline()) {
        client->SendFriendLoginUpdate(srcAvatar, destAvatar);
    }
}

AddIgnore::AddIgnore(GatewayClient* client, const RequestType& request, ResponseType& response)
    : avatarService_{client->GetNode()->GetAvatarService()} {
    LOG(INFO) << "ADDIGNORE request received - adding: " << FromWideString(request.destName) << "@"
              << FromWideString(request.destAddress) << " to " << request.srcAvatarId << "@"
              << FromWideString(request.srcAddress);
    auto srcAvatar = avatarService_->GetAvatar(request.srcAvatarId);
    if (!srcAvatar) {
        throw ChatResultException{ChatResultCode::SRCAVATARDOESNTEXIST};
    }

    auto destAvatar = avatarService_->GetAvatar(request.destName, request.destAddress);
    if (!destAvatar) {
        throw ChatResultException{ChatResultCode::DESTAVATARDOESNTEXIST};
    }

    srcAvatar->AddIgnore(destAvatar);
}

AddInvite::AddInvite(GatewayClient* client, const RequestType& request, ResponseType& response)
    : avatarService_{client->GetNode()->GetAvatarService()}
    , roomService_{client->GetNode()->GetRoomService()} {
    LOG(INFO) << "ADDINVITE request received - adding invitation for: "
              << FromWideString(request.destAvatarName) << "@"
              << FromWideString(request.destAvatarAddress) << " to "
              << FromWideString(request.destRoomAddress);

    auto srcAvatar = avatarService_->GetAvatar(request.srcAvatarId);
    if (!srcAvatar) {
        throw ChatResultException{ChatResultCode::SRCAVATARDOESNTEXIST};
    }

    auto invitedAvatar
        = avatarService_->GetAvatar(request.destAvatarName, request.destAvatarAddress);
    if (!invitedAvatar) {
        throw ChatResultException{ChatResultCode::DESTAVATARDOESNTEXIST};
    }

    auto room = roomService_->GetRoom(request.destRoomAddress);
    if (!room) {
        throw ChatResultException{ChatResultCode::ADDRESSNOTROOM};
    }

    response.destRoomId = room->GetRoomId();

    room->AddInvite(srcAvatar->GetAvatarId(), invitedAvatar);
}

AddModerator::AddModerator(
    GatewayClient* client, const RequestType& request, ResponseType& response)
    : avatarService_{client->GetNode()->GetAvatarService()}
    , roomService_{client->GetNode()->GetRoomService()} {
    LOG(INFO) << "ADDMODERATOR request recieved - adding: "
              << FromWideString(request.destAvatarName) << "@"
              << FromWideString(request.destAvatarAddress) << " to "
              << FromWideString(request.destRoomAddress);

    auto srcAvatar = avatarService_->GetAvatar(request.srcAvatarId);
    if (!srcAvatar) {
        throw ChatResultException{ChatResultCode::SRCAVATARDOESNTEXIST};
    }

    auto moderatorAvatar
        = avatarService_->GetAvatar(request.destAvatarName, request.destAvatarAddress);
    if (!moderatorAvatar) {
        throw ChatResultException{ChatResultCode::DESTAVATARDOESNTEXIST};
    }

    auto room = roomService_->GetRoom(request.destRoomAddress);
    if (!room) {
        throw ChatResultException{ChatResultCode::ADDRESSNOTROOM};
    }

    response.destRoomId = room->GetRoomId();

    room->AddModerator(srcAvatar->GetAvatarId(), moderatorAvatar);
}

CreateRoom::CreateRoom(GatewayClient* client, const RequestType& request, ResponseType& response)
    : avatarService_{client->GetNode()->GetAvatarService()}
    , roomService_{client->GetNode()->GetRoomService()} {
    LOG(INFO) << "CREATEROOM request received - creator: " << request.creatorId << "@"
              << FromWideString(request.srcAddress)
              << " room: " << FromWideString(request.roomAddress);

    response.room = roomService_->CreateRoom(avatarService_->GetAvatar(request.creatorId),
        request.roomName, request.roomTopic, request.roomPassword, request.roomAttributes,
        request.roomMaxSize, request.roomAddress, request.srcAddress);
}

DestroyAvatar::DestroyAvatar(
    GatewayClient* client, const RequestType& request, ResponseType& response)
    : avatarService_{client->GetNode()->GetAvatarService()}
    , roomService_{client->GetNode()->GetRoomService()} {
    auto avatar = avatarService_->GetAvatar(request.avatarId);
    if (!avatar) {
        throw ChatResultException{ChatResultCode::SRCAVATARDOESNTEXIST};
    }

    // Remove From All Rooms
    for (auto room : roomService_->GetJoinedRooms(avatar)) {
        auto addresses = room->GetConnectedAddresses();
        room->LeaveRoom(avatar);

        client->SendLeaveRoomUpdate(addresses, avatar->GetAvatarId(), room->GetRoomId());
    }

    // Destroy avatar
    avatarService_->DestroyAvatar(avatar);
}

DestroyRoom::DestroyRoom(GatewayClient* client, const RequestType& request, ResponseType& response)
    : avatarService_{client->GetNode()->GetAvatarService()}
    , roomService_{client->GetNode()->GetRoomService()} {
    LOG(INFO) << "DESTROYROOM request received " << request.srcAvatarId << "@"
              << FromWideString(request.srcAddress)
              << " room: " << FromWideString(request.roomAddress);

    auto srcAvatar = avatarService_->GetAvatar(request.srcAvatarId);
    if (!srcAvatar) {
        throw ChatResultException(ChatResultCode::SRCAVATARDOESNTEXIST);
    }

    auto room = roomService_->GetRoom(request.roomAddress);
    if (!room) {
        throw ChatResultException(ChatResultCode::ADDRESSNOTROOM);
    }

    auto addresses = room->GetRemoteAddresses();
    auto roomId = room->GetRoomId();

    response.roomId = roomId;

    roomService_->DestroyRoom(room);

    client->SendDestroyRoomUpdate(srcAvatar, roomId, addresses);
}

EnterRoom::EnterRoom(GatewayClient* client, const RequestType& request, ResponseType& response)
    : avatarService_{client->GetNode()->GetAvatarService()}
    , roomService_{client->GetNode()->GetRoomService()} {
    LOG(INFO) << "ENTERROOM request received - avatar: " << request.srcAvatarId << "@"
              << FromWideString(request.srcAddress)
              << " room: " << FromWideString(request.roomAddress);

    auto srcAvatar = avatarService_->GetAvatar(request.srcAvatarId);
    if (!srcAvatar) {
        throw ChatResultException{ChatResultCode::SRCAVATARDOESNTEXIST};
    }

    response.room = roomService_->GetRoom(request.roomAddress);
    if (!response.room) {
        throw ChatResultException{ChatResultCode::ADDRESSNOTROOM};
    }

    response.roomId = response.room->GetRoomId();
    response.room->EnterRoom(srcAvatar, request.roomPassword);

    client->SendEnterRoomUpdate(srcAvatar, response.room);
}

FailoverReLoginAvatar::FailoverReLoginAvatar(
    GatewayClient* client, const RequestType& request, ResponseType& response)
    : avatarService_{client->GetNode()->GetAvatarService()}
    , roomService_{client->GetNode()->GetRoomService()} {
    LOG(INFO) << "FAILOVER_RELOGINAVATAR request received " << FromWideString(request.name) << "@"
              << FromWideString(request.address);

    auto avatar = avatarService_->GetAvatar(request.name, request.address);
    if (!avatar) {
        LOG(INFO) << "Login avatar does not exist, creating a new one " << FromWideString(request.name) << "@"
                  << FromWideString(request.address);
        avatar = avatarService_->CreateAvatar(request.name, request.address, request.userId,
            request.attributes, request.loginLocation);
    }

    avatarService_->LoginAvatar(CHECK_NOTNULL(avatar));

    if (avatar->GetName().compare(u"SYSTEM") == 0) {
        client->GetNode()->RegisterClientAddress(avatar->GetAddress(), client);
        roomService_->LoadRoomsFromStorage(request.address);
    } else {
        client->SendFriendLoginUpdates(avatar);
    }

    for (auto room : roomService_->GetJoinedRooms(avatar)) {
        client->SendEnterRoomUpdate(avatar, room);
    }
}

FriendStatus::FriendStatus(
    GatewayClient* client, const RequestType& request, ResponseType& response)
    : avatarService_{client->GetNode()->GetAvatarService()} {
    LOG(INFO) << "FRIENDSTATUS request received - for " << request.srcAvatarId << "@"
              << FromWideString(request.srcAddress);

    auto srcAvatar = avatarService_->GetAvatar(request.srcAvatarId);
    if (!srcAvatar) {
        throw ChatResultException{ChatResultCode::SRCAVATARDOESNTEXIST};
    }

    response.srcAvatar = srcAvatar;
}

GetAnyAvatar::GetAnyAvatar(
    GatewayClient* client, const RequestType& request, ResponseType& response)
    : avatarService_{client->GetNode()->GetAvatarService()} {
    LOG(INFO) << "GETANYAVATAR request received - avatar: " << FromWideString(request.name) << "@"
              << FromWideString(request.address);

    auto avatar = avatarService_->GetAvatar(request.name, request.address);
    if (!avatar) {
        throw ChatResultException{ChatResultCode::SRCAVATARDOESNTEXIST};
    }

    response.isOnline = avatar->IsOnline();
    response.avatar = avatar;
}

GetPersistentHeaders::GetPersistentHeaders(
    GatewayClient* client, const RequestType& request, ResponseType& response)
    : messageService_{client->GetNode()->GetMessageService()} {
    LOG(INFO) << "GETPERSISTENTHEADERS request recieved - avatar: " << request.avatarId
              << " category: " << FromWideString(request.category);

    response.headers = messageService_->GetMessageHeaders(request.avatarId);
}

GetPersistentMessage::GetPersistentMessage(
    GatewayClient* client, const RequestType& request, ResponseType& response)
    : messageService_{client->GetNode()->GetMessageService()} {
    LOG(INFO) << "GETPERSISTENTMESSAGE request received - avatar: " << request.srcAvatarId
              << " message: " << request.messageId;

    response.message
        = messageService_->GetPersistentMessage(request.srcAvatarId, request.messageId);
}

GetRoom::GetRoom(GatewayClient* client, const RequestType& request, ResponseType& response)
    : roomService_{client->GetNode()->GetRoomService()} {
    LOG(INFO) << "GETROOM request received - room: " << FromWideString(request.roomAddress);

    auto room = roomService_->GetRoom(request.roomAddress);
    if (!room) {
        throw ChatResultException{ChatResultCode::ADDRESSDOESNTEXIST};
    }

    response.room = room;
}

GetRoomSummaries::GetRoomSummaries(
    GatewayClient* client, const RequestType& request, ResponseType& response)
    : roomService_{client->GetNode()->GetRoomService()} {
    LOG(INFO) << "GETROOMSUMMARIES request received - start node: "
              << FromWideString(request.startNodeAddress)
              << " filter: " << FromWideString(request.roomFilter);

    response.rooms = roomService_->GetRoomSummaries(request.startNodeAddress, request.roomFilter);
}

IgnoreStatus::IgnoreStatus(
    GatewayClient* client, const RequestType& request, ResponseType& response)
    : avatarService_{client->GetNode()->GetAvatarService()} {
    LOG(INFO) << "IGNORESTATUS request received - for " << request.srcAvatarId << "@"
              << FromWideString(request.srcAddress);

    auto srcAvatar = avatarService_->GetAvatar(request.srcAvatarId);
    if (!srcAvatar) {
        throw ChatResultException{ChatResultCode::SRCAVATARDOESNTEXIST};
    }

    response.srcAvatar = srcAvatar;
}

KickAvatar::KickAvatar(GatewayClient* client, const RequestType& request, ResponseType& response)
    : avatarService_{client->GetNode()->GetAvatarService()}
    , roomService_{client->GetNode()->GetRoomService()} {
    LOG(INFO) << "KICKAVATAR request received - kicking: " << FromWideString(request.destAvatarName)
              << "@" << FromWideString(request.destAvatarAddress) << " from "
              << FromWideString(request.destRoomAddress);

    auto srcAvatar = avatarService_->GetAvatar(request.srcAvatarId);
    if (!srcAvatar) {
        throw ChatResultException{ChatResultCode::SRCAVATARDOESNTEXIST};
    }

    auto destAvatar = avatarService_->GetAvatar(request.destAvatarName, request.destAvatarAddress);
    if (!destAvatar) {
        throw ChatResultException{ChatResultCode::DESTAVATARDOESNTEXIST};
    }

    auto room = roomService_->GetRoom(request.destRoomAddress);
    if (!room) {
        throw ChatResultException{ChatResultCode::ADDRESSNOTROOM};
    }

    response.destRoomId = room->GetRoomId();

    auto addresses = room->GetConnectedAddresses();
    room->KickAvatar(srcAvatar->GetAvatarId(), destAvatar);

    client->SendKickAvatarUpdate(addresses, srcAvatar, destAvatar, room);
}

LeaveRoom::LeaveRoom(GatewayClient* client, const RequestType& request, ResponseType& response)
    : avatarService_{client->GetNode()->GetAvatarService()}
    , roomService_{client->GetNode()->GetRoomService()} {
    auto srcAvatar = avatarService_->GetAvatar(request.srcAvatarId);
    if (!srcAvatar) {
        throw ChatResultException{ChatResultCode::SRCAVATARDOESNTEXIST};
    }

    auto room = roomService_->GetRoom(request.roomAddress);
    if (!room) {
        throw ChatResultException{ChatResultCode::ADDRESSNOTROOM};
    }

    response.roomId = room->GetRoomId();

    // Cache the addresses before leaving the room in case this avatar was the
    // last on their server, to ensure the update messages goes out.
    auto addresses = room->GetConnectedAddresses();
    room->LeaveRoom(srcAvatar);

    client->SendLeaveRoomUpdate(addresses, srcAvatar->GetAvatarId(), room->GetRoomId());
}

LoginAvatar::LoginAvatar(GatewayClient* client, const RequestType& request, ResponseType& response)
    : avatarService_{client->GetNode()->GetAvatarService()}
    , roomService_{client->GetNode()->GetRoomService()} {
    LOG(INFO) << "LOGINAVATAR request received " << FromWideString(request.name) << "@"
              << FromWideString(request.address);

    auto avatar = avatarService_->GetAvatar(request.name, request.address);
    if (!avatar) {
        LOG(INFO) << "Login avatar does not exist, creating a new one "
                  << FromWideString(request.name) << "@" << FromWideString(request.address);
        avatar = avatarService_->CreateAvatar(request.name, request.address, request.userId,
            request.loginAttributes, request.loginLocation);
    }

    avatarService_->LoginAvatar(CHECK_NOTNULL(avatar));

    if (avatar->GetName().compare(u"SYSTEM") == 0) {
        client->GetNode()->RegisterClientAddress(avatar->GetAddress(), client);
        roomService_->LoadRoomsFromStorage(request.address);
    } else {
        client->SendFriendLoginUpdates(avatar);
    }

    response.avatar = avatar;
}

LogoutAvatar::LogoutAvatar(GatewayClient* client, const RequestType& request, ResponseType& response)
    : avatarService_{client->GetNode()->GetAvatarService()}
    , roomService_{client->GetNode()->GetRoomService()} {
    LOG(INFO) << "LOGOUTAVATAR request received - avatar id:" << request.avatarId;

    auto avatar = avatarService_->GetAvatar(request.avatarId);

    for (auto room : roomService_->GetJoinedRooms(avatar)) {
        auto addresses = room->GetConnectedAddresses();
        room->LeaveRoom(avatar);

        client->SendLeaveRoomUpdate(addresses, avatar->GetAvatarId(), room->GetRoomId());
    }

    client->SendFriendLogoutUpdates(avatar);

    avatarService_->LogoutAvatar(avatar);
}

RegistrarGetChatServer::RegistrarGetChatServer(RegistrarClient* client, const RequestType& request, ResponseType& response) {
    auto& config = client->GetNode()->GetConfig();

    response.hostname = ToWideString(config.gatewayAddress);
    response.port = config.gatewayPort;
}

RemoveBan::RemoveBan(GatewayClient* client, const RequestType& request, ResponseType& response)
    : avatarService_{client->GetNode()->GetAvatarService()}
    , roomService_{client->GetNode()->GetRoomService()} {
    LOG(INFO) << "REMOVEBAN request received - removing ban for: "
              << FromWideString(request.destAvatarName) << "@"
              << FromWideString(request.destAvatarAddress) << " from "
              << FromWideString(request.destRoomAddress);

    auto srcAvatar = avatarService_->GetAvatar(request.srcAvatarId);
    if (!srcAvatar) {
        throw ChatResultException{ChatResultCode::SRCAVATARDOESNTEXIST};
    }

    auto bannedAvatar
        = avatarService_->GetAvatar(request.destAvatarName, request.destAvatarAddress);
    if (!bannedAvatar) {
        throw ChatResultException{ChatResultCode::DESTAVATARDOESNTEXIST};
    }

    auto room = roomService_->GetRoom(request.destRoomAddress);
    if (!room) {
        throw ChatResultException{ChatResultCode::ADDRESSNOTROOM};
    }

    response.destRoomId = room->GetRoomId();

    room->RemoveBanned(srcAvatar->GetAvatarId(), bannedAvatar->GetAvatarId());
}

RemoveFriend::RemoveFriend(
    GatewayClient* client, const RequestType& request, ResponseType& response)
    : avatarService_{client->GetNode()->GetAvatarService()} {
    LOG(INFO) << "REMOVEFRIEND request received - removing: " << FromWideString(request.destName)
              << "@" << FromWideString(request.destAddress) << " from " << request.srcAvatarId
              << "@" << FromWideString(request.srcAddress);

    auto srcAvatar = avatarService_->GetAvatar(request.srcAvatarId);
    if (!srcAvatar) {
        throw ChatResultException{ChatResultCode::SRCAVATARDOESNTEXIST};
    }

    auto destAvatar = avatarService_->GetAvatar(request.destName, request.destAddress);
    if (!destAvatar) {
        throw ChatResultException{ChatResultCode::DESTAVATARDOESNTEXIST};
    }

    srcAvatar->RemoveFriend(destAvatar);
}

RemoveIgnore::RemoveIgnore(GatewayClient* client, const RequestType& request, ResponseType& response)
    : avatarService_{client->GetNode()->GetAvatarService()} {
    LOG(INFO) << "REMOVEIGNORE request received - removing: " << FromWideString(request.destName) << "@"
              << FromWideString(request.destAddress) << " from " << request.srcAvatarId << "@"
              << FromWideString(request.srcAddress);

    auto srcAvatar = avatarService_->GetAvatar(request.srcAvatarId);
    if (!srcAvatar) {
        throw ChatResultException{ChatResultCode::SRCAVATARDOESNTEXIST};
    }

    auto destAvatar = avatarService_->GetAvatar(request.destName, request.destAddress);
    if (!srcAvatar) {
        throw ChatResultException{ChatResultCode::DESTAVATARDOESNTEXIST};
    }

    srcAvatar->RemoveIgnore(destAvatar);
}

RemoveInvite::RemoveInvite(
    GatewayClient* client, const RequestType& request, ResponseType& response)
    : avatarService_{client->GetNode()->GetAvatarService()}
    , roomService_{client->GetNode()->GetRoomService()} {
    LOG(INFO) << "REMOVEINVITE request received - removing invitation for: "
              << FromWideString(request.destAvatarName) << "@"
              << FromWideString(request.destAvatarAddress) << " to "
              << FromWideString(request.destRoomAddress);

    auto srcAvatar = avatarService_->GetAvatar(request.srcAvatarId);
    if (!srcAvatar) {
        throw ChatResultException{ChatResultCode::SRCAVATARDOESNTEXIST};
    }

    auto invitedAvatar
        = avatarService_->GetAvatar(request.destAvatarName, request.destAvatarAddress);
    if (!invitedAvatar) {
        throw ChatResultException{ChatResultCode::DESTAVATARDOESNTEXIST};
    }

    auto room = roomService_->GetRoom(request.destRoomAddress);
    if (!room) {
        throw ChatResultException{ChatResultCode::ADDRESSNOTROOM};
    }

    response.destRoomId = room->GetRoomId();

    room->RemoveInvite(srcAvatar->GetAvatarId(), invitedAvatar->GetAvatarId());
}

RemoveModerator::RemoveModerator(GatewayClient* client, const RequestType& request, ResponseType& response)
    : avatarService_{client->GetNode()->GetAvatarService()}
    , roomService_{client->GetNode()->GetRoomService()} {
    LOG(INFO) << "REMOVEMODERATOR request recieved - removing: " << FromWideString(request.destAvatarName) << "@"
              << FromWideString(request.destAvatarAddress) << " from " << FromWideString(request.destRoomAddress);

    auto srcAvatar = avatarService_->GetAvatar(request.srcAvatarId);
    if (!srcAvatar) {
        throw ChatResultException{ChatResultCode::SRCAVATARDOESNTEXIST};
    }

    auto moderatorAvatar = avatarService_->GetAvatar(request.destAvatarName, request.destAvatarAddress);
    if (!moderatorAvatar) {
        throw ChatResultException{ChatResultCode::DESTAVATARDOESNTEXIST};
    }

    auto room = roomService_->GetRoom(request.destRoomAddress);
    if (!room) {
        throw ChatResultException{ChatResultCode::ADDRESSNOTROOM};
    }

    response.destRoomId = room->GetRoomId();

    room->RemoveModerator(srcAvatar->GetAvatarId(), moderatorAvatar->GetAvatarId());
}

SendInstantMessage::SendInstantMessage(
    GatewayClient* client, const RequestType& request, ResponseType& response)
    : avatarService_{client->GetNode()->GetAvatarService()} {
    LOG(INFO) << "SENDINSTANTMESSAGE request received "
              << " - from " << request.srcAvatarId << "@" << FromWideString(request.srcAddress) << " to "
              << FromWideString(request.destName) << "@" << FromWideString(request.destAddress);

    auto srcAvatar = avatarService_->GetAvatar(request.srcAvatarId);
    if (!srcAvatar) {
        throw ChatResultException(ChatResultCode::SRCAVATARDOESNTEXIST);
    }

    auto destAvatar = avatarService_->GetAvatar(request.destName, request.destAddress);
    if (!destAvatar) {
        throw ChatResultException(ChatResultCode::DESTAVATARDOESNTEXIST);
    }

    if (destAvatar->IsIgnored(srcAvatar)) {
        throw ChatResultException(ChatResultCode::IGNORING);
    }

    client->SendInstantMessageUpdate(srcAvatar, destAvatar, request.message, request.oob);
}

SendPersistentMessage::SendPersistentMessage(GatewayClient* client, const RequestType& request, ResponseType& response)
    : avatarService_{client->GetNode()->GetAvatarService()}
    , messageService_{client->GetNode()->GetMessageService()} {
    LOG(INFO) << "SENDPERSISTENTMESSAGE request received:";

    auto destAvatar = avatarService_->GetAvatar(request.destName, request.destAddress);
    if (!destAvatar) {
        throw ChatResultException{ChatResultCode::DESTAVATARDOESNTEXIST};
    }

    PersistentMessage message;

    if (request.avatarPresence) {
        auto srcAvatar = avatarService_->GetAvatar(request.srcAvatarId);
        if (!srcAvatar) {
            throw ChatResultException{ChatResultCode::SRCAVATARDOESNTEXIST};
        }

        if (destAvatar->IsIgnored(srcAvatar)) {
            throw ChatResultException(ChatResultCode::IGNORING);
        }

        message.header.fromName = srcAvatar->GetName();
        message.header.fromAddress = srcAvatar->GetAddress();
    } else {
        message.header.fromName = request.srcName;
        message.header.fromAddress = destAvatar->GetAddress();
    }

    message.header.sentTime = static_cast<uint32_t>(std::time(nullptr));
    message.header.avatarId = destAvatar->GetAvatarId();
    message.header.subject = request.subject;
    message.header.category = request.category;
    message.message = request.msg;
    message.oob = request.oob;

    messageService_->StoreMessage(message);

    response.messageId = message.header.messageId;

    client->SendPersistentMessageUpdate(destAvatar, message.header);
}

SendRoomMessage::SendRoomMessage(
    GatewayClient* client, const RequestType& request, ResponseType& response)
    : avatarService_{client->GetNode()->GetAvatarService()}
    , roomService_{client->GetNode()->GetRoomService()} {
    LOG(INFO) << "SENDROOMMESSAGE request received "
              << " - from " << request.srcAvatarId << "@" << FromWideString(request.srcAddress)
              << " to " << FromWideString(request.destRoomAddress);

    auto srcAvatar = avatarService_->GetAvatar(request.srcAvatarId);
    if (!srcAvatar) {
        throw ChatResultException(ChatResultCode::SRCAVATARDOESNTEXIST);
    }

    auto room = roomService_->GetRoom(request.destRoomAddress);
    if (!room) {
        throw ChatResultException(ChatResultCode::ADDRESSNOTROOM);
    }

    response.roomId = room->GetRoomId();

    client->SendRoomMessageUpdate(
        srcAvatar, room, room->GetNextMessageId(), request.message, request.oob);
}

SetApiVersion::SetApiVersion(
    GatewayClient* client, const RequestType& request, ResponseType& response) {
    LOG(INFO) << "SETAPIVERSION request received - version: " << request.version;
    response.version = client->GetNode()->GetConfig().version;
    response.result = (response.version == request.version)
        ? ChatResultCode::SUCCESS
        : ChatResultCode::WRONGCHATSERVERFORREQUEST;
}

SetAvatarAttributes::SetAvatarAttributes(GatewayClient* client, const RequestType& request, ResponseType& response)
    : avatarService_{client->GetNode()->GetAvatarService()} {
    LOG(INFO) << "SETAVATARATTRIBUTES request received - avatar: " << request.avatarId;

    auto avatar = avatarService_->GetAvatar(request.avatarId);
    if (!avatar) {
        throw ChatResultException{ChatResultCode::SRCAVATARDOESNTEXIST};
    }

    response.avatar = avatar;

    if (avatar->GetAttributes() != request.avatarAttributes) {
        avatar->SetAttributes(request.avatarAttributes);

        if (request.persistent != 0) {
            avatarService_->PersistAvatar(avatar);
        }
    }
}

UpdatePersistentMessage::UpdatePersistentMessage(GatewayClient* client, const RequestType& request, ResponseType& response)
    : messageService_{client->GetNode()->GetMessageService()} {
    LOG(INFO) << "UPDATEPERSISTENTMESSAGE request received";
    messageService_->UpdateMessageStatus(
        request.srcAvatarId, request.messageId, request.status);
}
