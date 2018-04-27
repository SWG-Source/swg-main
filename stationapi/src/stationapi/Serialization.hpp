
#pragma once

#include <string>
#include <type_traits>

// integral types

template <typename StreamT, typename T,
    typename std::enable_if_t<std::is_integral<T>::value, int> = 0>
void read(StreamT& istream, T& value) {
    istream.read(reinterpret_cast<char*>(&value), sizeof(T));
}

template <typename StreamT, typename T,
    typename std::enable_if_t<std::is_integral<T>::value, int> = 0>
void write(StreamT& ostream, const T& value) {
    ostream.write(reinterpret_cast<const char*>(&value), sizeof(T));
}

// enumeration types with integral underlying types

template <typename StreamT, typename T,
    typename std::enable_if_t<std::is_enum<T>::value, int> = 0>
    void read(StreamT& istream, T& value) {
    istream.read(reinterpret_cast<char*>(&value), sizeof(T));
}

template <typename StreamT, typename T,
    typename std::enable_if_t<std::is_enum<T>::value, int> = 0>
    void write(StreamT& ostream, const T& value) {
    ostream.write(reinterpret_cast<const char*>(&value), sizeof(T));
}

// boolean types

template <typename StreamT>
void read(StreamT& istream, bool& value) {
    uint8_t boolAsInt;
    read(istream, boolAsInt);
    value = (boolAsInt != 0);
}

template <typename StreamT>
void write(StreamT& ostream, const bool& value) {
    uint8_t boolAsInt = value ? 1 : 0;
    write(ostream, boolAsInt);
}

// std::string types

template <typename StreamT>
void read(StreamT& istream, std::string& value) {
    uint16_t length;
    read(istream, length);

    value.resize(length);

    istream.read(&value[0], length);
}

template <typename StreamT>
void write(StreamT& ostream, const std::string& value) {
    uint16_t length = static_cast<uint16_t>(value.length());
    write(ostream, length);

    ostream.write(&value[0], length);
}

// std::u16string types

template <typename StreamT>
void read(StreamT& istream, std::u16string& value) {
    uint32_t length;
    read(istream, length);

    value.resize(length);
    uint16_t tmp;
    for (uint32_t i = 0; i < length; ++i) {
        istream.read(reinterpret_cast<char*>(&tmp), sizeof(uint16_t));
        value[i] = tmp;
    }
}

template <typename StreamT>
void write(StreamT& ostream, const std::u16string& value) {
    uint32_t length = static_cast<uint32_t>(value.length());
    write(ostream, length);

    uint16_t tmp;
    for (uint32_t i = 0; i < length; ++i) {
        tmp = static_cast<uint16_t>(value[i]);
        ostream.write(reinterpret_cast<const char*>(&tmp), sizeof(uint16_t));
    }
}

// Specialized Read Types

template <typename T, typename StreamT>
T read(StreamT& istream) {
    T tmp;
    read(istream, tmp);
    return tmp;
}

template <typename T, typename StreamT>
T readAt(StreamT& istream, size_t offset) {
    istream.seekg(offset);
    return read<T>(istream);
}

// Similar to readAt, but preserves the read position of the stream
template <typename T, typename StreamT>
T peekAt(StreamT& istream, size_t offset) {
    auto pos = istream.tellg();
    T val = readAt<T>(istream, offset);
    istream.seekg(pos);
    return val;
}
