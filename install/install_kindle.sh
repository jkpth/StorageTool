#!/bin/sh

set -e

# Check if running on a Kindle
if ! { [ -f "/etc/prettyversion.txt" ] || [ -d "/mnt/us" ] || pgrep "lipc-daemon" >/dev/null; }; then
    echo "Error: This script must run on a Kindle device." >&2
    exit 1
fi

# Variables
INSTALL_DIR="/mnt/us/extensions/storagetool"
CONFIG_FILE="$INSTALL_DIR/bin/.storagetool_config"
TEMP_CONFIG="/mnt/us/storagetool_config_backup"
SOURCE_DIR="/mnt/us/storagetool"
VERSION="2.0.0"

# Ensure source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory $SOURCE_DIR does not exist." >&2
    echo "Please extract the StorageTool files to /mnt/us/storagetool first." >&2
    exit 1
fi

# Backup existing config
if [ -f "$CONFIG_FILE" ]; then
    echo "Backing up existing config..."
    cp -f "$CONFIG_FILE" "$TEMP_CONFIG"
fi

# Remove old installation
if [ -d "$INSTALL_DIR" ]; then
    echo "Removing old installation..."
    rm -rf "$INSTALL_DIR"
fi

# Install
echo "Installing StorageTool..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/bin"

# Copy files from source directory
cp -f "$SOURCE_DIR/run.sh" "$INSTALL_DIR/"
cp -f "$SOURCE_DIR/menu.json" "$INSTALL_DIR/"
cp -f "$SOURCE_DIR/config.xml" "$INSTALL_DIR/"
cp -f "$SOURCE_DIR/bin/storagetool.sh" "$INSTALL_DIR/bin/"

# Set permissions
chmod +x "$INSTALL_DIR/run.sh"
chmod +x "$INSTALL_DIR/bin/storagetool.sh"

# Restore config
if [ -f "$TEMP_CONFIG" ]; then
    echo "Restoring configuration..."
    mkdir -p "$(dirname "$CONFIG_FILE")"
    mv -f "$TEMP_CONFIG" "$CONFIG_FILE"
fi

echo "StorageTool v$VERSION installation completed successfully."
echo "You can now access StorageTool from the KUAL menu."
