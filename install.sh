#!/usr/bin/env bash
set -e

REPO="hubfly-space/hubcell-docs"
BIN_NAME="hubcell"
INSTALL_DIR="/usr/local/bin"

echo "Installing Hubcell..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root (e.g., sudo bash install.sh)"
  exit 1
fi

# Check architecture
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "aarch64" ] && [ "$ARCH" != "arm64" ]; then
    echo "Warning: Hubcell is primarily built for x86_64/arm64 Linux. You are running $ARCH."
fi

# Fetch the latest release tag
echo "Fetching latest release from $REPO..."
LATEST_TAG=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$LATEST_TAG" ]; then
    echo "Error: Could not find any releases for $REPO."
    echo "If you are developing locally, build manually: go build -o hubcell ./cmd/hubcell/main.go"
    exit 1
fi

echo "Found latest version: $LATEST_TAG"

# Download binary
DOWNLOAD_URL="https://github.com/$REPO/releases/download/$LATEST_TAG/$BIN_NAME"
TMP_FILE=$(mktemp)

echo "Downloading $BIN_NAME from $DOWNLOAD_URL..."
curl -sL -o "$TMP_FILE" "$DOWNLOAD_URL"

# Install binary
echo "Installing to $INSTALL_DIR/$BIN_NAME..."
chmod +x "$TMP_FILE"
mv "$TMP_FILE" "$INSTALL_DIR/$BIN_NAME"

echo "Installation successful!"
echo "You can now run '$BIN_NAME serve --web' to start the node."
$BIN_NAME version || echo "Version check failed, but binary is installed."
