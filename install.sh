#!/bin/sh

set -e

# Check if running on a Kindle
if ! { [ -f "/etc/prettyversion.txt" ] || [ -d "/mnt/us" ] || pgrep "lipc-daemon" >/dev/null; }; then
    echo "Error: This script must run on a Kindle device." >&2
    exit 1
fi

# Variables
API_URL="https://api.github.com/repos/jkpth/StorageTool/commits"
REPO_URL="https://github.com/jkpth/StorageTool/archive/refs/heads/main.zip"
ZIP_FILE="/mnt/us/storagetool.zip"
EXTRACTED_DIR="/mnt/us/StorageTool-main/storagetool"  # Points to storagetool directory
INSTALL_DIR="/mnt/us/extensions/storagetool"
CONFIG_FILE="$INSTALL_DIR/bin/.storagetool_config"
VERSION_FILE="$INSTALL_DIR/bin/.version"
TEMP_CONFIG="/mnt/us/storagetool_config_backup"
VERSION="2.0.1"  # Default version in case we can't get it from GitHub

# Get version from GitHub
get_version() {
    api_response=$(curl -s -H "Accept: application/vnd.github.v3+json" "$API_URL") || {
        echo "Warning: Failed to fetch version from GitHub API" >&2
        echo "$VERSION"
        return
    }

    latest_sha=$(echo "$api_response" | grep -m1 '"sha":' | cut -d'"' -f4 | cut -c1-7)
    
    if [ -n "$latest_sha" ]; then
        echo "${latest_sha}"
    else
        echo "$VERSION"
    fi
}

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

# Create version file
echo "Creating version file..."
VERSION_SHA=$(get_version)
mkdir -p "$INSTALL_DIR/bin"
echo "$VERSION_SHA" > "$VERSION_FILE"

# Restore config
if [ -f "$TEMP_CONFIG" ]; then
    echo "Restoring configuration..."
    mv -f "$TEMP_CONFIG" "$CONFIG_FILE"
fi

# Cleanup
rm -rf "/mnt/us/StorageTool-main"

echo "StorageTool v$VERSION_SHA installation completed successfully."
echo "You can now access StorageTool from the KUAL menu."