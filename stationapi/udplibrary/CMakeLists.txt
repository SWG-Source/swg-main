cmake_minimum_required(VERSION 2.8)

project(udplibrary)

if(WIN32)
	add_definitions(/D_CRT_SECURE_NO_WARNINGS)
endif()

include_directories(${CMAKE_CURRENT_SOURCE_DIR})

add_definitions(-DREENTRANT)

add_library(udplibrary
	hashtable.hpp
	PointerDeque.hpp
	priority.hpp
	UdpHandler.hpp
	UdpHandler.h
	UdpLibrary.cpp
	UdpLibrary.hpp
	UdpLibrary.h
)

