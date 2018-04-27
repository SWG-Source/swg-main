
#include "RegistrarNode.hpp"

#include "StationChatConfig.hpp"

RegistrarNode::RegistrarNode(StationChatConfig& config)
    : Node(this, config.registrarAddress, config.registrarPort, config.bindToIp)
    , config_{config} {}

RegistrarNode::~RegistrarNode() {}

StationChatConfig& RegistrarNode::GetConfig() {
    return config_;
}

void RegistrarNode::OnTick() {}

