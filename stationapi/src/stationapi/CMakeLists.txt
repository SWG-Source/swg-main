include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${PROJECT_SOURCE_DIR}/externals/easyloggingpp
    ${PROJECT_SOURCE_DIR}/externals/udplibrary
    ${Boost_INCLUDE_DIRS}
    ${SQLite3_INCLUDE_DIR})

set(SOURCES
    Node.hpp
    NodeClient.cpp
    NodeClient.hpp
    Serialization.hpp
    SQLite3.hpp
    StreamUtils.cpp
    StreamUtils.hpp
    StringUtils.cpp
    StringUtils.hpp)

add_library(stationapi ${SOURCES})

GroupSourceByFilesystem("${SOURCES}")
