# Variables

SHELL := /bin/bash
OS_NAME := $(shell uname -s | tr A-Z a-z)
DOCKER_SWIFT_VERSION := 5.5
SCHEME := APIClient
MAC_SDK := macosx12.1
MAC_DESTINATION := 'platform=macOS,arch=x86_64'
IPHONE_DESTINATION := 'platform=iOS Simulator,name=iPhone 13 Pro,OS=15.2'
WATCH_DESTINATION := 'platform=watchOS Simulator,name=Apple Watch Series 7 - 45mm,OS=8.3'
TV_DESTINATION := 'platform=tvOS Simulator,name=Apple TV 4K (2nd generation),OS=15.2'


# Lint
lint:
	$(call brew_install,swiftlint) && swiftlint --strict

# Clean
clean:
	@rm -rf .build


# Build

build-all: build-macos build-ios build-watchos build-linux

build:
	@echo "Building for current platform..."
	@swift build

build-macos:
	@echo "Building for macOS..."
	@xcodebuild \
		-scheme "$(SCHEME)" \
		-sdk $(MAC_SDK) \
		-destination $(MAC_DESTINATION) \
		clean build

build-ios:
	@echo "Building for iOS..."
	@xcodebuild \
		-scheme "$(SCHEME)" \
		-sdk iphonesimulator \
		-destination $(IPHONE_DESTINATION) \
		clean build

build-watchos:
	@echo "Building for watchOS..."
	@xcodebuild \
		-scheme "$(SCHEME)" \
		-sdk watchsimulator \
		-destination $(WATCH_DESTINATION) \
		clean build

build-tvos:
	@echo "Building for tvOS..."
	@xcodebuild \
		-scheme "$(SCHEME)" \
		-sdk appletvsimulator \
		-destination $(TV_DESTINATION) \
		clean build


# Test

test-all: test-macos test-ios test-watchos

test:
	@echo "Testing for current platform..."
	@swift test --parallel

test-macos:
	@echo "Testing for macOS..."
	@xcodebuild \
		-scheme "$(SCHEME)" \
		-sdk $(MAC_SDK) \
		-destination $(MAC_DESTINATION) \
		-parallel-testing-enabled YES \
		test

test-ios:
	@echo "Testing for iOS..."
	@xcodebuild \
		-scheme "$(SCHEME)" \
		-sdk iphonesimulator \
		-destination $(IPHONE_DESTINATION) \
		-parallel-testing-enabled YES \
		test

test-watchos:
	@echo "Testing for watchOS..."
	@xcodebuild \
		-scheme "$(SCHEME)" \
		-sdk watchsimulator \
		-destination $(WATCH_DESTINATION) \
		-parallel-testing-enabled YES \
		test

test-tvos:
	@echo "Testing for tvOS..."
	@xcodebuild \
		-scheme "$(SCHEME)" \
		-sdk appletvsimulator \
		-destination $(TV_DESTINATION) \
		-parallel-testing-enabled YES \
		test


# Test Docs

DOC_WARNINGS := $(shell xcodebuild clean docbuild \
	-scheme "$(SCHEME)" \
	-sdk $(MAC_SDK) \
	-destination $(MAC_DESTINATION) \
	-quiet \
	2>&1 \
	| grep "couldn't be resolved to known documentation" \
	| sed 's|$(PWD)|.|g' \
	| tr '\n' '\1')
test-docs:
	@test "$(DOC_WARNINGS)" = "" \
		|| (echo "xcodebuild docbuild failed:\n\n$(DOC_WARNINGS)" | tr '\1' '\n' \
		&& exit 1)


# Functions

define brew_install
	@if which $(1) >/dev/null; then \
  		echo "$(1) installed..."; \
	else \
		echo "Installing $(1)..."; \
  		brew install $(1); \
	fi
endef
