BINARY_NAME := state-switcher
INSTALL_DIR := ~/bin
SRC := main.go
UNAME_S := $(shell uname -s)

.PHONY: all build install clean

# Default target
all: build install clean

build:
	@echo "Building $(BINARY_NAME)..."
	go build -o $(BINARY_NAME) $(SRC)
	@echo "Build complete."

install: build
	@echo "Installing $(BINARY_NAME) to $(INSTALL_DIR)..."
	mkdir -p $(INSTALL_DIR)
	install -m 755 $(BINARY_NAME) $(INSTALL_DIR)
ifeq ($(UNAME_S),Darwin)
	@echo "Linking BitBar plugin..."
	mkdir -p ~/Documents/bitbar_plugins
	ln -sf $(INSTALL_DIR)/$(BINARY_NAME) ~/Documents/bitbar_plugins/$(BINARY_NAME).5m
endif
	@echo "Installation complete."

clean:
	@echo "Cleaning up..."
	rm -f $(BINARY_NAME)
	@echo "Clean complete."
