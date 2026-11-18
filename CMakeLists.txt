cmake_minimum_required(VERSION 3.20)

project(BatteryBar VERSION 1.0.0 LANGUAGES CXX RC)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Every source file is picked up automatically, so a new driver needs no build change.
file(GLOB_RECURSE SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/*.cpp")

# The translations live in lang/*.txt and are compiled into the executable as one RCDATA blob
# (res/app.rc -> LANGS), so they are joined into a single file before rc.exe runs.
file(GLOB LANG_FILES "${CMAKE_CURRENT_SOURCE_DIR}/lang/*.txt")
set(LANGS "${CMAKE_CURRENT_BINARY_DIR}/languages.txt")
add_custom_command(
    OUTPUT "${LANGS}"
    COMMAND ${CMAKE_COMMAND}
            -DLANG_DIR=${CMAKE_CURRENT_SOURCE_DIR}/lang
            -DOUT=${LANGS}
            -P ${CMAKE_CURRENT_SOURCE_DIR}/tools/gen-languages.cmake
    DEPENDS ${LANG_FILES} "${CMAKE_CURRENT_SOURCE_DIR}/tools/gen-languages.cmake"
    COMMENT "Joining lang/*.txt into languages.txt")

add_executable(BatteryBar WIN32 ${SOURCES} res/app.rc "${LANGS}")
set_source_files_properties(res/app.rc PROPERTIES OBJECT_DEPENDS "${LANGS}")

# rc.exe needs to find languages.txt (generated in the build tree) next to the normal res\ headers.
if (MSVC)
    set(CMAKE_RC_FLAGS "${CMAKE_RC_FLAGS} /I \"${CMAKE_CURRENT_SOURCE_DIR}/res\" /I \"${CMAKE_CURRENT_BINARY_DIR}\"")
else ()
    set(CMAKE_RC_FLAGS "${CMAKE_RC_FLAGS} -I \"${CMAKE_CURRENT_SOURCE_DIR}/res\" -I \"${CMAKE_CURRENT_BINARY_DIR}\"")
endif ()

target_include_directories(BatteryBar PRIVATE src)
target_compile_definitions(BatteryBar PRIVATE UNICODE _UNICODE _WIN32_WINNT=0x0A00 WINVER=0x0A00)

if (MSVC)
    target_compile_definitions(BatteryBar PRIVATE NOMINMAX _CRT_SECURE_NO_WARNINGS)
    target_compile_options(BatteryBar PRIVATE /W3 /O1 /MT)
    # res/app.rc already embeds res/app.manifest as RT_MANIFEST 1. The MSVC linker would generate
    # and embed a second manifest with the same id, which fails as CVTRES CVT1100 (duplicate
    # resource), so the generated one is turned off and the manifest in the resource is the only one.
    target_link_options(BatteryBar PRIVATE /MANIFEST:NO)
else ()
    target_compile_options(BatteryBar PRIVATE -Os -Wall -Wno-missing-field-initializers -ffunction-sections -fdata-sections)
    target_link_options(BatteryBar PRIVATE -static -municode -Wl,--gc-sections)
endif ()

target_link_libraries(BatteryBar PRIVATE
    user32 gdi32 advapi32 ole32 oleaut32 comctl32
    hid setupapi cfgmgr32 runtimeobject ws2_32
    shell32 comdlg32 uuid windowsapp)

# Unit tests. tests/tests.txt is the single source of the list: one "name|extra sources"
# entry per line, empty extra means the test only needs its own .cpp. Run them with
# `ctest --test-dir build/ninja` (or `--test-dir build/vs2022 -C Release`).
option(BATTERYBAR_BUILD_TESTS "Build and register the unit tests" ON)
if (BATTERYBAR_BUILD_TESTS)
    enable_testing()
    file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/tests/tests.txt" TEST_ENTRIES)
    foreach (entry IN LISTS TEST_ENTRIES)
        if (entry MATCHES "^\\s*#" OR entry STREQUAL "")
            continue()
        endif ()
        string(REPLACE "|" ";" parts "${entry}")
        list(GET parts 0 test_name)
        list(GET parts 1 test_extra)
        separate_arguments(test_extra_list UNIX_COMMAND "${test_extra}")
        string(STRIP "${test_name}" test_name)
        add_executable(${test_name} "${CMAKE_CURRENT_SOURCE_DIR}/tests/${test_name}.cpp" ${test_extra_list})
        target_include_directories(${test_name} PRIVATE src)
        target_compile_definitions(${test_name} PRIVATE UNICODE _UNICODE _WIN32_WINNT=0x0A00 WINVER=0x0A00)
        if (MSVC)
            target_compile_definitions(${test_name} PRIVATE NOMINMAX _CRT_SECURE_NO_WARNINGS)
            target_compile_options(${test_name} PRIVATE /W3 /O1 /MT)
        else ()
            target_compile_options(${test_name} PRIVATE -Os -Wall -Wno-missing-field-initializers)
        endif ()
        add_test(NAME ${test_name} COMMAND ${test_name} WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
    endforeach ()
endif ()
