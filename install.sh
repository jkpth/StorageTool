#!/bin/sh

set -e

# Check if running on a Kindle
if ! { [ -f "/etc/prettyversion.txt" ] || [ -d "/mnt/us" ] || pgrep "lipc-daemon" >/dev/null; }; then
    echo "Error: This script must run on a Kindle device." >&2
    exit 1
fi

# Variables
REPO_URL="https://github.com/jkpth/StorageTool/archive/refs/heads/main.zip"
ZIP_FILE="/mnt/us/storagetool.zip"
EXTRACTED_DIR="/mnt/us/StorageTool-main/storagetool"  # Points to storagetool directory
INSTALL_DIR="/mnt/us/extensions/storagetool"
CONFIG_FILE="$INSTALL_DIR/bin/.storagetool_config"
TEMP_CONFIG="/mnt/us/storagetool_config_backup"
VERSION="2.0.0"

# Backup existing config
if [ -f "$CONFIG_FILE" ]; then
    echo "Backing up existing config..."
    cp -f "$CONFIG_FILE" "$TEMP_CONFIG"
fi

# Download repository
echo "Downloading StorageTool..."
curl -s -L -o "$ZIP_FILE" "$REPO_URL"

# Extract files
echo "Extracting files..."
unzip -o "$ZIP_FILE" -d "/mnt/us"
rm -f "$ZIP_FILE"

# Remove old installation
if [ -d "$INSTALL_DIR" ]; then
    echo "Removing old installation..."
    rm -rf "$INSTALL_DIR"
fi

# Install
echo "Installing StorageTool..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/bin"
mv -f "$EXTRACTED_DIR/run.sh" "$INSTALL_DIR/"
mv -f "$EXTRACTED_DIR/menu.json" "$INSTALL_DIR/"
mv -f "$EXTRACTED_DIR/config.xml" "$INSTALL_DIR/"
mv -f "$EXTRACTED_DIR/bin/storagetool.sh" "$INSTALL_DIR/bin/"

# Set permissions
chmod +x "$INSTALL_DIR/run.sh"
chmod +x "$INSTALL_DIR/bin/storagetool.sh"

# Restore config
if [ -f "$TEMP_CONFIG" ]; then
    echo "Restoring configuration..."
    mv -f "$TEMP_CONFIG" "$CONFIG_FILE"
fi

# Cleanup
rm -rf "/mnt/us/StorageTool-main"

echo "StorageTool v$VERSION installation completed successfully."
echo "You can now access StorageTool from the KUAL menu."