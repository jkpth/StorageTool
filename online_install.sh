#!/bin/sh

set -e

# Check if running on a Kindle
if ! { [ -f "/etc/prettyversion.txt" ] || [ -d "/mnt/us" ] || pgrep "lipc-daemon" >/dev/null; }; then
    echo "Error: This script must run on a Kindle device." >&2
    exit 1
fi

# Variables
REPO_URL="https://github.com/jptho/StorageTool/archive/refs/heads/main.zip"
ZIP_FILE="/mnt/us/storagetool.zip"
EXTRACTED_DIR="/mnt/us/StorageTool-main"
INSTALL_DIR="/mnt/us/extensions/storagetool"
CONFIG_FILE="$INSTALL_DIR/bin/.storagetool_config"
TEMP_CONFIG="/mnt/us/storagetool_config_backup"
VERSION="2.0.0"

# Banner
echo ""
echo "=================================================="
echo "          StorageTool Installer v$VERSION         "
echo "=================================================="
echo "A book storage management tool for Kindle devices."
echo "=================================================="
echo ""

# Backup existing config
if [ -f "$CONFIG_FILE" ]; then
    echo "Backing up existing config..."
    cp -f "$CONFIG_FILE" "$TEMP_CONFIG"
fi

# Download repository
echo "Downloading StorageTool..."
curl -s -L -o "$ZIP_FILE" "$REPO_URL"
echo "Download complete."

# Extract files
echo "Extracting files..."
unzip -o -q "$ZIP_FILE" -d "/mnt/us"
echo "Extraction complete."
rm -f "$ZIP_FILE"

# Remove old installation
echo "Removing old installation..."
rm -rf "$INSTALL_DIR"

# Install
echo "Installing StorageTool..."
mkdir -p "$INSTALL_DIR"
cp -rf "$EXTRACTED_DIR/storagetool"/* "$INSTALL_DIR/"
echo "Installation successful."

# Set permissions
echo "Setting permissions..."
chmod +x "$INSTALL_DIR/run.sh"
chmod +x "$INSTALL_DIR/bin/storagetool.sh"

# Restore config
if [ -f "$TEMP_CONFIG" ]; then
    echo "Restoring configuration..."
    mkdir -p "$(dirname "$CONFIG_FILE")"
    mv -f "$TEMP_CONFIG" "$CONFIG_FILE"
fi

# Cleanup
echo "Cleaning up..."
rm -rf "$EXTRACTED_DIR"

echo ""
echo "=================================================="
echo "      StorageTool v$VERSION installed successfully!     "
echo "=================================================="
echo "You can now access StorageTool from the KUAL menu."
echo "=================================================="
