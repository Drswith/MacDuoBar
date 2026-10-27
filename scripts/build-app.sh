#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
sdk_version="$(xcrun --sdk macosx --show-sdk-version)"
# Swift's linker driver needs Darwin -isysroot to record the real SDK, independently of the deployment target.
swift build --sdk "$sdk_path" -Xswiftc -Xclang-linker -Xswiftc -isysroot -Xswiftc -Xclang-linker -Xswiftc "$sdk_path"
binary_dir="$(swift build --show-bin-path)"
built_sdk="$(xcrun vtool -show-build "$binary_dir/MacDuoBar" | awk '$1 == "sdk" { print $2; exit }')"
if [[ "$built_sdk" != "$sdk_version" ]]; then
    printf 'SDK mismatch: expected %s, binary records %s\n' "$sdk_version" "$built_sdk" >&2
    exit 1
fi
app_dir="$PWD/build/MacDuoBar.app"
mkdir -p "$app_dir/Contents/MacOS"
cp "$binary_dir/MacDuoBar" "$app_dir/Contents/MacOS/MacDuoBar"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
plutil -lint "$app_dir/Contents/Info.plist"
codesign --force --sign - "$app_dir"
codesign --verify --strict "$app_dir"
printf 'Built %s\n' "$app_dir"
