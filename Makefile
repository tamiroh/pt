APP_NAME := pt
BUILD_DIR := build
APP := $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR ?= /Applications

.PHONY: all
all: app

.PHONY: app
app:
	swift build -c release --product $(APP_NAME)
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS"
	cp "$$(swift build -c release --show-bin-path)/$(APP_NAME)" "$(APP)/Contents/MacOS/$(APP_NAME)"
	cp Support/Info.plist "$(APP)/Contents/Info.plist"
	codesign --force --sign - "$(APP)"

.PHONY: install
install: app
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	ditto "$(APP)" "$(INSTALL_DIR)/$(APP_NAME).app"

.PHONY: uninstall
uninstall:
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"

.PHONY: clean
clean:
	rm -rf "$(BUILD_DIR)"
	swift package clean
