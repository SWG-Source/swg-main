
#pragma once

#include <string>

std::string FromWideString(const std::u16string& str);

std::u16string ToWideString(const std::string& str);
