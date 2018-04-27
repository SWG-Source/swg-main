
#include "StreamUtils.hpp"

std::string FromWideString(const std::u16string& str) {
    return std::string{std::begin(str), std::end(str)};
}

std::u16string ToWideString(const std::string& str) {
    return std::u16string{std::begin(str), std::end(str)};
}
