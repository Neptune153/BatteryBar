
# BatteryBar - MinGW-w64 Makefile
#
# Requirements:
#   MinGW-w64 (MSYS2 MINGW64 / UCRT64)
#   GNU Make
#   windres
#
# Usage:
#   make -j8       Build BatteryBar.exe
#   make test      Build and run tests
#   make clean     Remove build directory

# The recipes below are POSIX shell commands (mkdir -p, rm -rf, printf, while read). GNU make for
# Windows runs recipes with cmd.exe unless a POSIX shell is configured; fail here with a readable
# message instead of a confusing error at the first recipe.
ifeq ($(OS),Windows_NT)
  ifeq ($(findstring sh,$(notdir $(SHELL))),)
    $(error Recipes need a POSIX shell (sh or bash), but SHELL is "$(if $(SHELL),$(SHELL),unset)". Start make from the MSYS2 MINGW64 terminal, or pass SHELL=<msys2>/usr/bin/sh.exe)
  endif
endif

.DEFAULT_GOAL := all

CXX     ?= g++
WINDRES ?= windres

BUILD_DIR := build
TARGET    := $(BUILD_DIR)/BatteryBar.exe

RESOURCE  := $(BUILD_DIR)/app_res.o
LANG_FILE := $(BUILD_DIR)/languages.txt

ICON      := resources/app.ico
MANIFEST  := resources/app.manifest
RC_FILE   := resources/app.rc

CPPFLAGS += -D_WIN32_WINNT=0x0A00
CPPFLAGS += -DWINVER=0x0A00

CXXFLAGS ?= -std=c++17 -Os -Wall \
            -Wno-missing-field-initializers \
            -ffunction-sections -fdata-sections

DEPFLAGS := -MMD -MP

LDFLAGS ?= -municode -mwindows -static -s \
           -Wl,--gc-sections

LDLIBS ?= -lhid -lsetupapi -lcfgmgr32 \
          -lole32 -loleaut32 -lcomctl32 \
          -lgdi32 -lruntimeobject -lws2_32 \
          -luser32 -lshell32 -lcomdlg32 -luuid

# Recursively collect all .cpp files under src/.
rwildcard = $(wildcard $1$2) $(foreach d,$(wildcard $1*/),$(call rwildcard,$d,$2))

SRC := $(call rwildcard,src/,*.cpp)
OBJ := $(patsubst src/%.cpp,$(BUILD_DIR)/%.o,$(SRC))
DEP := $(OBJ:.o=.d)

LANG_SRC := $(wildcard lang/*.txt)

.PHONY: all
all: $(TARGET)

$(TARGET): $(OBJ) $(RESOURCE)
	@mkdir -p $(dir $@)
	$(CXX) $(LDFLAGS) $^ -o $@ $(LDLIBS)
	@printf '\n'
	@echo "Build successful: $@"

$(BUILD_DIR)/%.o: src/%.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(DEPFLAGS) \
		-MF $(@:.o=.d) -MT $@ \
		-c $< -o $@

$(LANG_FILE): $(LANG_SRC)
	@mkdir -p $(dir $@)
	@echo Generating language resources...
	@printf '' > $@
	@for f in $^; do \
		printf '@file %s\n' "$$(basename "$$f" .txt)" >> $@; \
		cat "$$f" >> $@; \
		printf '\n' >> $@; \
	done

$(RESOURCE): $(RC_FILE) $(MANIFEST) $(ICON) $(LANG_FILE)
	@mkdir -p $(dir $@)
	@echo Compiling Windows resources...
	$(WINDRES) -i $(RC_FILE) -o $@ \
		--include-dir=resources \
		--include-dir=$(BUILD_DIR)

.PHONY: test
test:
	@mkdir -p $(BUILD_DIR)/tests
	@if [ ! -f tests/tests.txt ]; then \
		echo "Error: tests/tests.txt not found"; \
		exit 1; \
	fi
	@echo Running unit tests...
	@while IFS='|' read -r name extra || [ -n "$$name" ]; do \
		case "$$name" in \
			''|\#*) continue ;; \
		esac; \
		echo; \
		echo "Building test: $$name"; \
		$(CXX) $(CPPFLAGS) $(CXXFLAGS) -Isrc \
			"tests/$$name.cpp" $$extra \
			-o "$(BUILD_DIR)/tests/$$name.exe" || exit 1; \
		echo "Running test: $$name"; \
		"./$(BUILD_DIR)/tests/$$name.exe" || exit 1; \
	done < tests/tests.txt
	@echo
	@echo All tests passed.

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)
	@echo Build directory cleaned.

-include $(DEP)
