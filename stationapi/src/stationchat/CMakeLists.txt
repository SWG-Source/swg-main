include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${PROJECT_SOURCE_DIR}/src/stationapi
    ${PROJECT_SOURCE_DIR}/externals/easyloggingpp
    ${PROJECT_SOURCE_DIR}/externals/udplibrary
    ${Boost_INCLUDE_DIRS}
    ${SQLite3_INCLUDE_DIR})

set(SOURCES
    protocol/AddBan.hpp
    protocol/AddFriend.hpp
    protocol/AddIgnore.hpp
    protocol/AddInvite.hpp
    protocol/AddModerator.hpp
    protocol/CreateRoom.hpp
    protocol/DestroyAvatar.hpp
    protocol/DestroyRoom.hpp
    protocol/EnterRoom.hpp
    protocol/FailoverReLoginAvatar.hpp
    protocol/FriendStatus.hpp
    protocol/GetAnyAvatar.hpp
    protocol/GetPersistentHeaders.hpp
    protocol/GetPersistentMessage.hpp
    protocol/GetRoom.hpp
    protocol/GetRoomSummaries.hpp
    protocol/IgnoreStatus.hpp
    protocol/KickAvatar.hpp
    protocol/LeaveRoom.hpp
    protocol/LoginAvatar.hpp
    protocol/LogoutAvatar.hpp
    protocol/Protocol.cpp
    protocol/RegistrarGetChatServer.hpp
    protocol/RemoveBan.hpp
    protocol/RemoveFriend.hpp
    protocol/RemoveIgnore.hpp
    protocol/RemoveInvite.hpp
    protocol/RemoveModerator.hpp
    protocol/SendInstantMessage.hpp
    protocol/SendPersistentMessage.hpp
    protocol/SendRoomMessage.hpp
    protocol/SetApiVersion.hpp
    protocol/SetAvatarAttributes.hpp
    protocol/UpdatePersistentMessage.hpp

    ChatAvatar.cpp
    ChatAvatar.hpp
    ChatAvatarService.cpp
    ChatAvatarService.hpp
    ChatEnums.cpp
    ChatEnums.hpp
    ChatRoom.cpp
    ChatRoom.hpp
    ChatRoomService.cpp
    ChatRoomService.hpp
    GatewayClient.cpp
    GatewayClient.hpp
    GatewayNode.cpp
    GatewayNode.hpp
    main.cpp
    Message.hpp
    PersistentMessage.hpp
    PersistentMessageService.cpp
    PersistentMessageService.hpp
    RegistrarClient.cpp
    RegistrarClient.hpp
    RegistrarNode.cpp
    RegistrarNode.hpp
    StationChatApp.cpp
    StationChatApp.hpp
    StationChatConfig.hpp)

add_executable(stationchat ${SOURCES})

GroupSourceByFilesystem("${SOURCES}")

target_link_libraries(stationchat
    stationapi
    udplibrary
    ${Boost_LIBRARIES}
    ${SQLite3_LIBRARY})

if(WIN32)
    target_link_libraries(stationchat ws2_32)
endif()
