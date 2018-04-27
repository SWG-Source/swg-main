
#pragma once

#include <cstdint>
#include <string>

struct StationChatConfig {
    StationChatConfig() = default;
    StationChatConfig(const std::string& gatewayAddress_, uint16_t gatewayPort_,
        const std::string& registrarAddress_, uint16_t registrarPort_, const std::string& chatDatabasePath_,
        bool bindToIp_)
        : gatewayAddress{gatewayAddress_}
        , gatewayPort{gatewayPort_}
        , registrarAddress{registrarAddress_}
        , registrarPort{registrarPort_}
        , chatDatabasePath{chatDatabasePath_}
        , bindToIp{bindToIp_} {}

    const uint32_t version = 2;
    std::string gatewayAddress;
    uint16_t gatewayPort;
    std::string registrarAddress;
    uint16_t registrarPort;
    std::string chatDatabasePath;
    std::string loggerConfig;
    bool bindToIp;
};
