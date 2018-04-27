
#pragma once

#include "ChatEnums.hpp"
#include "PersistentMessage.hpp"

#include <boost/optional.hpp>

#include <cstdint>
#include <vector>

struct sqlite3;

class PersistentMessageService {
public:
    explicit PersistentMessageService(sqlite3* db);
    ~PersistentMessageService();

    void StoreMessage(PersistentMessage& message);

    std::vector<PersistentHeader> GetMessageHeaders(uint32_t avatarId);

    PersistentMessage GetPersistentMessage(uint32_t avatarId, uint32_t messageId);

    void UpdateMessageStatus(
        uint32_t avatarId, uint32_t messageId, PersistentState status);

private:
    sqlite3* db_;
};
