#!/bin/bash
set -e

# Default to version in resources/Info.plist if not specified
VERSION="${1:-1.0.0}"
echo "=========================================="
echo " Packaging Vettam v$VERSION for Release"
echo "=========================================="

# 1. Update version in resources/Info.plist if needed
if [ -f "resources/Info.plist" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" resources/Info.plist 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" resources/Info.plist 2>/dev/null || true
fi

# 2. Build Vettam.app
./build.sh

# 3. Setup output directory
OUTPUT_DIR="dist"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/pkg_root/Applications"

# 4. Build native macOS PKG installer (Installs to /Applications)
echo "Building macOS Installer Package (.pkg)..."
cp -R "Vettam.app" "$OUTPUT_DIR/pkg_root/Applications/"
pkgbuild --root "$OUTPUT_DIR/pkg_root" \
  --identifier "com.vettam.app" \
  --version "$VERSION" \
  --install-location "/" \
  "$OUTPUT_DIR/Vettam-${VERSION}-installer.pkg"
rm -rf "$OUTPUT_DIR/pkg_root"

# 5. Build ZIP archive (preserves codesign and Mac attributes)
echo "Building portable ZIP archive (.zip)..."
ditto -c -k --sequesterRsrc --keepParent "Vettam.app" "$OUTPUT_DIR/Vettam-${VERSION}.zip"

# 6. Build DMG image (Drag-to-Applications) if supported in environment
echo "Building Disk Image (.dmg)..."
DMG_STAGING="dist/dmg_staging"
mkdir -p "$DMG_STAGING"
cp -R "Vettam.app" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications" 2>/dev/null || true
hdiutil create -volname "Vettam" \
  -srcfolder "$DMG_STAGING" \
  -ov -format UDZO \
  "$OUTPUT_DIR/Vettam-${VERSION}.dmg" 2>/dev/null || \
  echo "Note: DMG generation requires unsandboxed terminal. Run 'hdiutil' directly if DMG is preferred."
rm -rf "$DMG_STAGING"

echo ""
echo "=========================================="
echo " Build Complete! Artifacts in $OUTPUT_DIR/:"
echo "=========================================="
ls -lh "$OUTPUT_DIR"

echo ""
echo "Next steps to release on GitHub:"
echo " 1. git tag -a v$VERSION -m \"Release v$VERSION\""
echo " 2. git push origin main --tags"
echo " 3. gh release create v$VERSION dist/* --title \"Vettam v$VERSION\" --generate-notes"
