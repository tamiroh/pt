PRODUCT := pt
APP_NAME := Pt
BUILD_DIR := build
APP := $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR ?= /Applications

.PHONY: all
all: app

.PHONY: app
app:
	swift build -c release --product $(PRODUCT)
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS"
	cp "$$(swift build -c release --show-bin-path)/$(PRODUCT)" "$(APP)/Contents/MacOS/$(PRODUCT)"
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
