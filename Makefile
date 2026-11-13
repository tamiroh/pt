PRODUCT := pt
APP_NAME := Pt
BUILD_DIR := build.noindex
APP := $(BUILD_DIR)/$(APP_NAME).app
ICON := $(BUILD_DIR)/AppIcon.icns
README_ICON := Support/AppIcon.png
DMG := $(BUILD_DIR)/$(APP_NAME).dmg
DMG_STAGE := $(BUILD_DIR)/dmg
INSTALL_DIR ?= /Applications

.PHONY: all
all: app

.PHONY: run
run:
	swift run $(PRODUCT)

.PHONY: lint
lint:
	swift package plugin --allow-writing-to-package-directory swiftlint --strict --quiet

.PHONY: app
app: $(ICON) $(README_ICON)
	swift build -c release --product $(PRODUCT)
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp "$$(swift build -c release --show-bin-path)/$(PRODUCT)" "$(APP)/Contents/MacOS/$(PRODUCT)"
	cp Support/Info.plist "$(APP)/Contents/Info.plist"
	cp "$(ICON)" "$(APP)/Contents/Resources/AppIcon.icns"
	codesign --force --sign - "$(APP)"

$(ICON): Support/IconRenderer.swift Sources/Pt/WalkerView.swift
	mkdir -p "$(BUILD_DIR)"
	swiftc -parse-as-library -O $^ -o "$(BUILD_DIR)/IconRenderer"
	"$(BUILD_DIR)/IconRenderer" "$(BUILD_DIR)/AppIcon.iconset"
	iconutil -c icns "$(BUILD_DIR)/AppIcon.iconset" -o "$@"

$(README_ICON): $(ICON)
	cp "$(BUILD_DIR)/AppIcon.iconset/icon_256x256@2x.png" "$@"

.PHONY: dmg
dmg: app
	rm -rf "$(DMG_STAGE)" "$(DMG)"
	mkdir -p "$(DMG_STAGE)"
	ditto "$(APP)" "$(DMG_STAGE)/$(APP_NAME).app"
	ln -s /Applications "$(DMG_STAGE)/Applications"
	hdiutil create -volname "$(APP_NAME)" -srcfolder "$(DMG_STAGE)" -format UDZO "$(DMG)"
	rm -rf "$(DMG_STAGE)"

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
