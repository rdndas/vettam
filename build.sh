#!/bin/bash
set -e

echo "Building Vettam.app..."

mkdir -p Vettam.app/Contents/MacOS Vettam.app/Contents/Resources .modcache
cp resources/*.png resources/*.icns Vettam.app/Contents/Resources/ 2>/dev/null || true

swiftc -O -module-cache-path .modcache \
  -framework SwiftUI \
  -framework AppKit \
  -framework IOKit \
  -framework CoreGraphics \
  -framework ServiceManagement \
  -framework Foundation \
  src/*.swift -o Vettam.app/Contents/MacOS/Vettam

codesign --force --deep --sign - Vettam.app

echo "Build successful: Vettam.app"
