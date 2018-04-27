function(GroupSourceByFilesystem SOURCES)
    foreach(FILE ${SOURCES})
        get_filename_component(PARENT_DIR "${FILE}" DIRECTORY)
        string(REPLACE "${CMAKE_CURRENT_SOURCE_DIR}" "" GROUP "${PARENT_DIR}")
        string(REPLACE "/" "\\" GROUP "${GROUP}")

        # Group into "Source Files" and "Header Files"
        if ("${FILE}" MATCHES ".*\\.cpp")
            set(GROUP "Source Files\\${GROUP}")
        elseif("${FILE}" MATCHES ".*\\.h")
            set(GROUP "Header Files\\${GROUP}")
        endif()

        source_group("${GROUP}" FILES "${FILE}")
    endforeach()
endfunction(GroupSourceByFilesystem)