
#pragma once

#include <ostream>
#include <string>

class UdpConnection;

class BinaryData {
public:
    BinaryData(const unsigned char* data, int length)
        : data_{ data }
        , length_{ length }
    {}

    const unsigned char* data() const { return data_; }
    int length() const { return length_; }

private:
    const unsigned char* data_;
    int length_;
};

std::ostream& operator<<(std::ostream& os, const BinaryData& data);

std::ostream& operator<<(std::ostream& os, const std::u16string& data);

void logNetworkMessage(UdpConnection* connection, std::string message, const unsigned char* data, int length);
