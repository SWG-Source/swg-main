
#pragma once

#include "Node.hpp"
#include "RegistrarClient.hpp"

struct StationChatConfig;

class RegistrarNode : public Node<RegistrarNode, RegistrarClient> {
public:
    explicit RegistrarNode(StationChatConfig& config);
    ~RegistrarNode();

    StationChatConfig& GetConfig();

private:
    void OnTick() override;

    StationChatConfig& config_;
};
