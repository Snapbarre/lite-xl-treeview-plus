# Variables
CC ?= gcc
BIN ?= cplua.so
PLUGIN_DIR := $(HOME)/.config/lite-xl/plugins/treeview-plus
SCRIPT_DIR := $(CURDIR)
SRC_DIR := src/c
SRC_LUA := $(SCRIPT_DIR)/src/lua/*.lua
INIT_LUA := $(SCRIPT_DIR)/init.lua

UV_DIR := src/submod/libuv
UV_INC := -I$(UV_DIR)/include
UV_LIB := $(UV_DIR)/.libs/libuv.a

LUA_VERSION = 5.4
LUA_LIBDIR= ~/.config/lite-xl
LUA_INC += -I/usr/include/lua$(LUA_VERSION) 
LUA_INC += -I$(SCRIPT_DIR)/src/submod/lite-xl/resources/include
# Compilation directives
WARN= -O2 -Wall -fPIC -W -Waggregate-return -Wcast-align -Wmissing-prototypes -Wnested-externs -Wshadow -Wwrite-strings -pedantic
INCS= $(LUA_INC)

GTK_PACKAGES := gtk+-3.0
GTK_CFLAGS := $(shell pkg-config --cflags $(GTK_PACKAGES))
GTK_LIBS := $(shell pkg-config --libs $(GTK_PACKAGES))

CFLAGS := $(WARN) $(INCS) $(GTK_CFLAGS) $(EXTRA_CFLAGS)
LDFLAGS := $(GTK_LIBS)
CC= gcc

USE_LIBUV ?= 0

###########################

# OS dependent
LIB_OPTION= -shared #for Linux

.PHONY: all install clean

SRCS := $(SRC_DIR)/cplua.c
# $(info SRCS = $(SRCS))
OBJS := $(SRCS:.c=.o)
# $(info OBJS = $(OBJS))

src/c/%.o: src/c/%.c
	$(CC) $(CFLAGS) -c $< -o $@

###########################

USE_LIBUV ?= 0
# $(info USE_LIBUV = $(USE_LIBUV))

ifeq ($(USE_LIBUV),1)
	CFLAGS += $(UV_INC)
	LDFLAGS += $(UV_LIB) -lpthread

	UV_LIB := $(UV_DIR)/.libs/libuv.a
	# Build libuv rule
	$(UV_LIB):
		cd $(UV_DIR) && sh autogen.sh && ./configure && make

	# Add UV_LIB as dependency only if used
	BIN_DEPS := $(OBJS) $(UV_LIB)
else
	# Don't include libuv stuff
	BIN_DEPS := $(OBJS)
endif

###########################
# $(info BIN_DEPS = $(BIN_DEPS))
$(BIN): $(BIN_DEPS)
	$(CC) $(CFLAGS) $(LIB_OPTION) -o $@ $^ $(LDFLAGS)

###########################

build: $(BIN)

all: build install

bi : build install

install:
	@echo "Installing plugin to $(PLUGIN_DIR)..."
	mkdir -p $(PLUGIN_DIR)
	cp $(INIT_LUA) $(PLUGIN_DIR)/
	mkdir -p $(PLUGIN_DIR)/src/lua
	cp $(SRC_LUA) $(PLUGIN_DIR)/src/lua/
	cp $(BIN) $(PLUGIN_DIR)/
	@echo "Build finished"

clean:
	@echo "Cleaning up copied files from $(PLUGIN_DIR)..."
	rm -rf $(PLUGIN_DIR)
	@echo "Removing compiled binary and object files..."
	rm -f $(BIN) $(OBJS)
	@echo "Clean finished"
