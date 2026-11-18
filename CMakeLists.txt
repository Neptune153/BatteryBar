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
else ()
    target_compile_options(BatteryBar PRIVATE -Os -Wall -Wno-missing-field-initializers -ffunction-sections -fdata-sections)
    target_link_options(BatteryBar PRIVATE -static -municode -Wl,--gc-sections)
endif ()

target_link_libraries(BatteryBar PRIVATE
    user32 gdi32 advapi32 ole32 oleaut32 comctl32
    hid setupapi cfgmgr32 runtimeobject ws2_32
    shell32 comdlg32 uuid windowsapp)
