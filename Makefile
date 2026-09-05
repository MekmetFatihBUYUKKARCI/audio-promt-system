APP_NAME := AudioPromt
SIGN_IDENTITY := Audio Promt Local Signing
BUILD_DIR := .build/release
APP_DIR := .build/$(APP_NAME).app

.PHONY: build bundle sign run clean

build:
	swift build -c release

bundle: build
	rm -rf "$(APP_DIR)"
	mkdir -p "$(APP_DIR)/Contents/MacOS"
	mkdir -p "$(APP_DIR)/Contents/Resources"
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(APP_DIR)/Contents/MacOS/$(APP_NAME)"
	cp Resources/Info.plist "$(APP_DIR)/Contents/Info.plist"
	@if [ -f Resources/vocabulary.json ]; then \
		cp Resources/vocabulary.json "$(APP_DIR)/Contents/Resources/"; \
	fi

sign: bundle
	codesign --force --deep --sign "$(SIGN_IDENTITY)" "$(APP_DIR)"
	codesign -dv "$(APP_DIR)"

run: sign
	"$(APP_DIR)/Contents/MacOS/$(APP_NAME)"

clean:
	rm -rf .build
