IGNORE   := $(shell crystal run find_clang.cr > Makefile.variables)
include Makefile.variables

LLVM_LIBS := $(shell $(LLVM_CONFIG) --system-libs --libs core)
LLVM_INCLUDE_DIR := $(shell $(LLVM_CONFIG) --includedir)
LLVM_LDFLAGS  := $(shell $(LLVM_CONFIG) --ldflags)
# NOTE: No -ltinfo on OSX
CLANG_LIBS := -Wl,--start-group -lclang -lclangParse -lclangASTMatchers -lclangSema -lclangAnalysis -lclangAST -lclangEdit -lclangLex -lclangFrontend -lclangTooling -lclangDriver -lclangBasic -lclangSerialization -Wl,--end-group
LIBS     := $(LLVM_LIBS) $(CLANG_LIBS) -ldl -pthread -lz -lcurses -ltinfo -lpcre
DEFINES  := -D__STDC_LIMIT_MACROS -D__STDC_CONSTANT_MACROS
CXXFLAGS := -std=c++11 $(DEFINES) -Iinclude -I$(LLVM_INCLUDE_DIR)

HEADERS  := $(wildcard include/*.hpp)
SOURCES  := $(wildcard src/*.cpp)
OBJECTS  := $(patsubst src/%.cpp,build/%.o,$(SOURCES))
BINARY   := bindgen

RM       ?= rm
CXX      := $(CLANG_BINARY)

all: $(BINARY)

clean:
	$(RM) -f bindgen $(OBJECTS)

build/%.o: src/%.cpp $(HEADERS)
	$(CXX) -c -o $@ $< $(CXXFLAGS)

$(BINARY): $(OBJECTS)
	$(CXX) -o $(BINARY) $(OBJECTS) $(LIBS) $(LLVM_LDFLAGS)

.PHONY: clean
