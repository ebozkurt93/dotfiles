BINARY_NAME := state-switcher.5m
INSTALL_DIR := ~/Documents/bitbar_plugins
SRC := main.go

.PHONY: all build install clean

# Default target
all: build install clean

build:
	@echo "Building $(BINARY_NAME)..."
	go build -o $(BINARY_NAME) $(SRC)
	@echo "Build complete."

install: build
	@echo "Installing $(BINARY_NAME) to $(INSTALL_DIR)..."
	install -m 755 $(BINARY_NAME) $(INSTALL_DIR)
	@echo "Installation complete."

clean:
	@echo "Cleaning up..."
	rm -f $(BINARY_NAME)
	@echo "Clean complete."
