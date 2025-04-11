#!/bin/sh

# Create release package for StorageTool

VERSION="2.0.0"
RELEASE_DIR="release"
PACKAGE_NAME="StorageTool_v${VERSION}"

# Create release directory
mkdir -p "$RELEASE_DIR"
rm -rf "$RELEASE_DIR/$PACKAGE_NAME"
mkdir -p "$RELEASE_DIR/$PACKAGE_NAME"

# Copy files to release directory
cp -r bin "$RELEASE_DIR/$PACKAGE_NAME/"
cp run.sh "$RELEASE_DIR/$PACKAGE_NAME/"
cp menu.json "$RELEASE_DIR/$PACKAGE_NAME/"
cp config.xml "$RELEASE_DIR/$PACKAGE_NAME/"
cp README.md "$RELEASE_DIR/$PACKAGE_NAME/"
cp -r install "$RELEASE_DIR/$PACKAGE_NAME/"
cp install.sh "$RELEASE_DIR/$PACKAGE_NAME/"

# Create zip package
cd "$RELEASE_DIR"
zip -r "${PACKAGE_NAME}.zip" "$PACKAGE_NAME"
cd ..

echo "Release package created: $RELEASE_DIR/${PACKAGE_NAME}.zip"
