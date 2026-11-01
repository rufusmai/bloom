DESTINATION ?= platform=iOS Simulator,name=iPhone 17

.PHONY: project open test-kit test clean

## Generate Bloom.xcodeproj from project.yml (requires `brew install xcodegen`)
project:
	xcodegen generate

## Generate and open the project in Xcode
open: project
	open Bloom.xcodeproj

## Run the BloomKit unit tests (works on macOS and Linux)
test-kit:
	swift test --package-path Packages/BloomKit

## Run the app unit tests in the iOS Simulator
test: project
	xcodebuild test \
		-project Bloom.xcodeproj \
		-scheme Bloom \
		-destination '$(DESTINATION)' \
		CODE_SIGNING_ALLOWED=NO

clean:
	rm -rf Bloom.xcodeproj Packages/BloomKit/.build
