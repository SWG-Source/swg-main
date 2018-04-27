
find_path(SQLite3_INCLUDE_DIR sqlite3.h
    HINTS
        $ENV{SQLite3_ROOT}
    PATH_SUFFIXES include
    PATHS
        ${SQLite3_ROOT}
        ${SQLite3_INCLUDEDIR}
)

find_library(SQLite3_LIBRARY
    NAMES sqlite3
    PATH_SUFFIXES lib
    HINTS
        $ENV{SQLite3_ROOT}
        ${SQLite3_ROOT}
        ${SQLite3_LIBRARYDIR}
)

# handle the QUIETLY and REQUIRED arguments and set OPENAL_FOUND to TRUE if
# all listed variables are TRUE
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(SQLite3 DEFAULT_MSG SQLite3_LIBRARY SQLite3_INCLUDE_DIR)

mark_as_advanced(SQLite3_ROOT SQLite3_INCLUDE_DIR SQLite3_LIBRARY)
