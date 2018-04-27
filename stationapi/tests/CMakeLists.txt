include_directories(${PROJECT_SOURCE_DIR}/externals/catch
    ${PROJECT_SOURCE_DIR}/src)

add_executable(stationapi_tests
    main.cpp)

target_link_libraries(stationapi_tests
    stationapi)
