
#pragma once

#include "Node.hpp"
#include "GatewayClient.hpp"

#include <map>
#include <memory>

class ChatAvatarService;
class ChatRoomService;
class PersistentMessageService;
struct StationChatConfig;
struct sqlite3;

class GatewayNode : public Node<GatewayNode, GatewayClient> {
public:
    explicit GatewayNode(StationChatConfig& config);
    ~GatewayNode();

    ChatAvatarService* GetAvatarService();
    ChatRoomService* GetRoomService();
    PersistentMessageService* GetMessageService();
    StationChatConfig& GetConfig();

    void RegisterClientAddress(const std::u16string& address, GatewayClient* client);

    template<typename MessageT>
    void SendTo(const std::u16string& address, const MessageT& message) {
        auto find_iter = clientAddressMap_.find(address);
        if (find_iter != std::end(clientAddressMap_)) {
            find_iter->second->Send(message);
        }
    }

private:
    void OnTick() override;

    std::unique_ptr<ChatAvatarService> avatarService_;
    std::unique_ptr<ChatRoomService> roomService_;
    std::unique_ptr<PersistentMessageService> messageService_;
    std::map<std::u16string, GatewayClient*> clientAddressMap_;
    StationChatConfig& config_;
    sqlite3* db_;
};
