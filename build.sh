#!/bin/bash
set -e

echo "Building Vettam.app..."

rm -rf Vettam.app
mkdir -p Vettam.app/Contents/MacOS Vettam.app/Contents/Resources .modcache
rm -rf Vettam.app/Contents/Resources/*
cp resources/*.png resources/*.icns Vettam.app/Contents/Resources/ 2>/dev/null || true
cp resources/Info.plist Vettam.app/Contents/Info.plist

swiftc -O -module-cache-path .modcache \
  -framework SwiftUI \
  -framework AppKit \
  -framework IOKit \
  -framework CoreGraphics \
  -framework ServiceManagement \
  -framework Foundation \
  src/*.swift -o Vettam.app/Contents/MacOS/Vettam

codesign --force --deep --sign - Vettam.app
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f Vettam.app 2>/dev/null || true

echo "Build successful: Vettam.app"
