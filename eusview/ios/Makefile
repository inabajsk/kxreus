# EusView (iPhone アプリ)
#   make project DEVELOPMENT_TEAM=<チーム ID>   Xcode プロジェクトを XcodeGen で作る
#   make device  DEVELOPMENT_TEAM=<チーム ID> DEVICE=<devicectl の ID>   ビルドして iPhone に入れる
XCODEGEN ?= xcodegen
DEST ?= generic/platform=iOS
project:
	DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM) $(XCODEGEN) generate --spec project.yml
build:
	xcodebuild -project EusView.xcodeproj -scheme EusView -configuration Release -destination '$(DEST)' -derivedDataPath build -allowProvisioningUpdates build
device: build
	xcrun devicectl device install app --device $(DEVICE) build/Build/Products/Release-iphoneos/EusView.app
# Mac 版 (Mac Catalyst): build/Build/Products/Release-maccatalyst/EusView.app
mac:
	xcodebuild -project EusView.xcodeproj -scheme EusView -configuration Release -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath build -allowProvisioningUpdates build
.PHONY: project build device mac
