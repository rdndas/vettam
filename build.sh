#!/bin/bash
set -e

echo "Building Vettam.app (macOS 26+ Universal Binary)..."

rm -rf Vettam.app
mkdir -p Vettam.app/Contents/MacOS Vettam.app/Contents/Resources .modcache
rm -rf Vettam.app/Contents/Resources/*
cp resources/*.png resources/*.icns Vettam.app/Contents/Resources/ 2>/dev/null || true
cp resources/Info.plist Vettam.app/Contents/Info.plist

TARGET_ARM="arm64-apple-macos26.0"
TARGET_X86="x86_64-apple-macos26.0"
FRAMEWORKS="-framework SwiftUI -framework AppKit -framework IOKit -framework CoreGraphics -framework ServiceManagement -framework Foundation"

# Compile arm64 slice
swiftc -O -module-cache-path .modcache \
  -target "$TARGET_ARM" \
  $FRAMEWORKS \
  src/*.swift -o .modcache/Vettam_arm64

# Compile x86_64 slice
swiftc -O -module-cache-path .modcache \
  -target "$TARGET_X86" \
  $FRAMEWORKS \
  src/*.swift -o .modcache/Vettam_x86_64

# Create universal binary
lipo -create -output Vettam.app/Contents/MacOS/Vettam .modcache/Vettam_arm64 .modcache/Vettam_x86_64

codesign --force --deep --sign - Vettam.app
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f Vettam.app 2>/dev/null || true

echo "Build successful: Vettam.app (Universal: arm64 + x86_64, macOS 26+)"
