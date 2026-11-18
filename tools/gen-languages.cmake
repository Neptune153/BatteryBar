# Joins every lang/*.txt into the single file that res\app.rc embeds as the LANGS resource.
# Each file is introduced by "@file <name>", which is what src/text/i18n.cpp expects.
# Invoked from CMakeLists.txt: cmake -DLANG_DIR=<dir> -DOUT=<file> -P tools/gen-languages.cmake

if (NOT LANG_DIR OR NOT OUT)
    message(FATAL_ERROR "gen-languages.cmake needs -DLANG_DIR=<dir> and -DOUT=<file>")
endif ()

file(GLOB lang_files "${LANG_DIR}/*.txt")
list(SORT lang_files)

set(joined "")
foreach (file IN LISTS lang_files)
    get_filename_component(name "${file}" NAME_WE)
    file(READ "${file}" body)
    string(APPEND joined "@file ${name}\r\n${body}\r\n")
endforeach ()

file(WRITE "${OUT}" "${joined}")
message(STATUS "Wrote ${OUT} from ${LANG_DIR}")
