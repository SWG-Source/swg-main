
#pragma once

#include "Serialization.hpp"

#include <string>

class ChatAvatar;

struct FriendContact {
    FriendContact(const ChatAvatar* frnd_, const std::wstring& comment_)
        : frnd{frnd_}
        , comment{comment_} {}

    const ChatAvatar* frnd;
    std::wstring comment = L"";
};

template <typename StreamT>
void write(StreamT& ar, const FriendContact& data) {
    write(ar, data.frnd->GetName());
    write(ar, data.frnd->GetAddress());
    write(ar, data.comment);
    write(ar, static_cast<short>(data.frnd->IsOnline() ? 1 : 0));
}

struct IgnoreContact {
    IgnoreContact(const ChatAvatar* ignored_)
        : ignored{ignored_} {}

    const ChatAvatar* ignored;
};

template <typename StreamT>
void write(StreamT& ar, const IgnoreContact& data) {
    write(ar, data.ignored->GetName());
    write(ar, data.ignored->GetAddress());
}
