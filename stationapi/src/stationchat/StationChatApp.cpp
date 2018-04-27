#include "StationChatApp.hpp"

#include "easylogging++.h"

StationChatApp::StationChatApp(StationChatConfig config)
    : config_{std::move(config)} {
    registrarNode_ = std::make_unique<RegistrarNode>(config_);
    LOG(INFO) << "Registrar listening @" << config_.registrarAddress << ":" << config_.registrarPort;

    gatewayNode_ = std::make_unique<GatewayNode>(config_);
    LOG(INFO) << "Gateway listening @" << config_.gatewayAddress << ":" << config_.gatewayPort;
}

void StationChatApp::Tick() {
    registrarNode_->Tick();
    gatewayNode_->Tick();
}
