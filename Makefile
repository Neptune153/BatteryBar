# Builds BatteryBar.exe with MinGW-w64 (MSYS2 MINGW64/UCRT64 shell, or any mingw g++ on PATH).
CXX      ?= g++
WINDRES  ?= windres
CXXFLAGS ?= -std=c++17 -Os -Wall -Wno-missing-field-initializers -ffunction-sections -fdata-sections \
            -D_WIN32_WINNT=0x0A00 -DWINVER=0x0A00
LDFLAGS  ?= -municode -mwindows -static -s -Wl,--gc-sections
LIBS     := -lhid -lsetupapi -lcfgmgr32 -lole32 -loleaut32 -lcomctl32 -lgdi32 -lruntimeobject -lws2_32 \
            -luser32 -lshell32 -lcomdlg32 -luuid

# The sources live in subdirectories of src\, so they are collected recursively.
SRC := $(wildcard src/*.cpp src/*/*.cpp src/*/*/*.cpp src/*/*/*/*.cpp)
HDR := $(wildcard src/*.h src/*/*.h src/*/*/*.h src/*/*/*/*.h)
OBJ := $(patsubst src/%.cpp,build/%.o,$(SRC)) build/app_res.o

build/BatteryBar.exe: $(OBJ)
	$(CXX) $(LDFLAGS) $^ -o $@ $(LIBS)

build/%.o: src/%.cpp $(HDR)
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -municode -c $< -o $@

# Every lang/*.txt is a built-in UI language: joined into one resource, each after an "@file <name>" line.
build/languages.txt: $(wildcard lang/*.txt)
	@mkdir -p build
	@printf '' > $@; for f in $^; do printf '@file %s\n' "$$(basename $$f .txt)" >> $@; cat "$$f" >> $@; printf '\n' >> $@; done

build/app_res.o: res/app.rc res/app.manifest res/app.ico build/languages.txt
	@mkdir -p build
	$(WINDRES) -i $< -o $@ --include-dir res --include-dir build

clean:
	rm -rf build

# Unit tests: tests/tests.txt holds one "name|extra sources" line per test.
test:
	@mkdir -p build/tests
	@while IFS='|' read -r name extra; do \
	  case "$$name" in ''|\#*) continue;; esac; \
	  echo "  building $$name"; \
	  $(CXX) $(CXXFLAGS) -Isrc "tests/$$name.cpp" $$extra -o "build/tests/$$name.exe" || exit 1; \
	  "./build/tests/$$name.exe" || exit 1; \
	  done < tests/tests.txt

.PHONY: clean test