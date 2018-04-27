
#include "GatewayNode.hpp"

#include "ChatAvatarService.hpp"
#include "ChatRoomService.hpp"
#include "PersistentMessageService.hpp"
#include "StationChatConfig.hpp"

#include <sqlite3.h>

GatewayNode::GatewayNode(StationChatConfig& config)
    : Node(this, config.gatewayAddress, config.gatewayPort, config.bindToIp)
    , config_{config} {
    if (sqlite3_open(config.chatDatabasePath.c_str(), &db_) != SQLITE_OK) {
        throw std::runtime_error("Can't open database: " + std::string{sqlite3_errmsg(db_)});
    }

    avatarService_ = std::make_unique<ChatAvatarService>(db_);
    roomService_ = std::make_unique<ChatRoomService>(avatarService_.get(), db_);
    messageService_ = std::make_unique<PersistentMessageService>(db_);
}

GatewayNode::~GatewayNode() { sqlite3_close(db_); }

ChatAvatarService* GatewayNode::GetAvatarService() { return avatarService_.get(); }

ChatRoomService* GatewayNode::GetRoomService() { return roomService_.get(); }

PersistentMessageService* GatewayNode::GetMessageService() {
    return messageService_.get();
}

StationChatConfig& GatewayNode::GetConfig() { return config_; }

void GatewayNode::RegisterClientAddress(const std::u16string & address, GatewayClient * client) {
    clientAddressMap_[address] = client;
}

void GatewayNode::OnTick() {}
