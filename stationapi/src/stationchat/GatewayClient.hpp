
#pragma once

#include "ChatEnums.hpp"
#include "NodeClient.hpp"
#include "SQLite3.hpp"
#include "easylogging++.h"

class ChatAvatar;
class ChatAvatarService;
class ChatRoom;
class ChatRoomService;
class GatewayNode;
class PersistentMessageService;
class UdpConnection;

struct PersistentHeader;

struct ReqSetAvatarAttributes;
struct ReqGetAnyAvatar;

class GatewayClient : public NodeClient {
public:
    GatewayClient(UdpConnection* connection, GatewayNode* node);
    virtual ~GatewayClient();

    GatewayNode* GetNode() { return node_; }

    void SendFriendLoginUpdate(const ChatAvatar* srcAvatar, const ChatAvatar* destAvatar);
    void SendFriendLoginUpdates(const ChatAvatar* avatar);
    void SendFriendLogoutUpdates(const ChatAvatar* avatar);
    void SendDestroyRoomUpdate(const ChatAvatar* srcAvatar, uint32_t roomId, std::vector<std::u16string> targets);
    void SendInstantMessageUpdate(const ChatAvatar* srcAvatar, const ChatAvatar* destAvatar, const std::u16string& message, const std::u16string& oob);
    void SendRoomMessageUpdate(const ChatAvatar* srcAvatar, const ChatRoom* room, uint32_t messageId, const std::u16string& message, const std::u16string& oob);
    void SendEnterRoomUpdate(const ChatAvatar* srcAvatar, const ChatRoom* room);
    void SendLeaveRoomUpdate(const std::vector<std::u16string>& addresses, uint32_t srcAvatarId, uint32_t roomId);
    void SendPersistentMessageUpdate(const ChatAvatar* destAvatar, const PersistentHeader& header);
    void SendKickAvatarUpdate(const std::vector<std::u16string>& addresses, const ChatAvatar* srcAvatar, const ChatAvatar* destAvatar, const ChatRoom* room);

private:
    void OnIncoming(std::istringstream& istream) override;

    template<typename HandlerT, typename StreamT>
    void HandleIncomingMessage(StreamT& istream) {
        typedef typename HandlerT::RequestType RequestT;
        typedef typename HandlerT::ResponseType ResponseT;

        RequestT request;
        read(istream, request);
        ResponseT response(request.track);

        try {
            HandlerT(this, request, response);
        } catch (const ChatResultException& e) {
            response.result = e.code;
            LOG(ERROR) << "ChatAPI Result Exception: [" << ToString(e.code) << "] " << e.message;
        } catch (const SQLite3Exception& e) {
            response.result = ChatResultCode::DATABASE;
            LOG(ERROR) << "Database Error: [" << e.code << "] " << e.message;
        }

        Send(response);
    }
    
    GatewayNode* node_;
    ChatAvatarService* avatarService_;
    ChatRoomService* roomService_;
    PersistentMessageService* messageService_;
};
