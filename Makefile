# Builds BatteryBar.exe with MinGW-w64 (MSYS2 MINGW64/UCRT64 shell, or any mingw g++ on PATH).
CXX      ?= g++
WINDRES  ?= windres
CXXFLAGS ?= -std=c++17 -Os -Wall -Wno-missing-field-initializers -ffunction-sections -fdata-sections \
            -D_WIN32_WINNT=0x0A00 -DWINVER=0x0A00
LDFLAGS  ?= -municode -mwindows -static -s -Wl,--gc-sections
LIBS     := -lhid -lsetupapi -lcfgmgr32 -lole32 -loleaut32 -lcomctl32 -lgdi32 -lruntimeobject -lws2_32

# Every .cpp under src\ is compiled, so a new driver needs no change here.
SRC := $(shell find src -name '*.cpp')
HDR := $(shell find src -name '*.h')
OBJ := $(patsubst src/%.cpp,build/%.o,$(SRC)) build/app_res.o

BatteryBar.exe: $(OBJ)
	$(CXX) $(LDFLAGS) $^ -o $@ $(LIBS)

build/%.o: src/%.cpp $(HDR)
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -municode -c $< -o $@

# Every lang/*.txt is a built-in UI language: joined into one resource, each after an "@file <name>" line.
build/languages.txt: $(wildcard lang/*.txt)
	@mkdir -p build
	@printf '' > $@; for f in $^; do printf '@file %s\n' "$$(basename $$f .txt)" >> $@; cat "$$f" >> $@; printf '\n' >> $@; done

build/app_res.o: res/app.rc res/app.manifest res/app.ico res/app_light.ico build/languages.txt
	@mkdir -p build
	$(WINDRES) -i $< -o $@ --include-dir res --include-dir build

clean:
	rm -rf build BatteryBar.exe

# Each test is "<name>|<extra sources>"; an empty extra list means a header-only protocol test.
TESTS := \
    astro_driver_test|src/core/drivers/astro.cpp \
    steelseries_mouse_test|src/core/drivers/steelseries.cpp \
    rapoo_driver_test|src/core/drivers/rapoo.cpp \
    rapoo_protocol_test| \
    ninjutso_driver_test|src/core/drivers/ninjutso.cpp \
    ninjutso_cable_test|src/core/drivers/ninjutso.cpp \
    cherry_driver_test|src/core/drivers/cherry.cpp \
    machenike_driver_test|src/core/drivers/machenike.cpp \
    niceboy_driver_test|src/core/drivers/niceboy.cpp \
    alienware_driver_test|src/core/drivers/alienware.cpp \
    arbiter_driver_test|src/core/drivers/arbiter.cpp src/core/drivers/lamzu.cpp \
    dareu_driver_test|src/core/drivers/dareu.cpp \
    semico_driver_test|src/core/drivers/semico.cpp \
    steelseries_driver_test|src/core/drivers/steelseries.cpp \
    mchose_modern_driver_test|src/core/drivers/mchose_modern.cpp \
    vaxee_driver_test|src/core/drivers/vaxee.cpp \
    finalmouse_driver_test|src/core/drivers/finalmouse.cpp \
    keychron_driver_test|src/core/drivers/keychron.cpp \
    hyperx_haste_driver_test|src/core/drivers/hyperx.cpp \
    galaxy_buds_protocol_test| \
    logitech_g435_0adf_test| \
    xenta_protocol_test|src/core/drivers/protocol/xenta_protocol.cpp \
    labels_test|src/text/labels.cpp \
    brands_test|src/text/brands.cpp

test:
	@mkdir -p build/tests
	@for entry in $(TESTS); do \
	    name=$${entry%%|*}; extra=$${entry#*|}; \
	    echo "== $$name"; \
	    $(CXX) $(CXXFLAGS) tests/$$name.cpp $$extra -o build/tests/$$name.exe || exit 1; \
	    ./build/tests/$$name.exe || exit 1; \
	done
	@echo "all tests passed"

.PHONY: clean test
