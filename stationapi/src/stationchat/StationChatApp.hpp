
#pragma once

#include "GatewayNode.hpp"
#include "RegistrarNode.hpp"
#include "StationChatConfig.hpp"

#include <cstdint>
#include <memory>
#include <string>

class StationChatApp {
public:
    explicit StationChatApp(StationChatConfig config);

    bool IsRunning() const { return isRunning_; }

    void Tick();

private:
    StationChatConfig config_;
    bool isRunning_ = true;
    std::unique_ptr<GatewayNode> gatewayNode_;
    std::unique_ptr<RegistrarNode> registrarNode_;    
};
