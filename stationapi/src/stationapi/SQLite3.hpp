
#pragma once

#include <string>
#include <sqlite3.h>

struct SQLite3Exception {
    int code;
    std::string message;

    SQLite3Exception(const int result, char const * text)
        : code{result}
        , message{text} {}
};
