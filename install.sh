#!/bin/bash
set -euo pipefail
clear

REPO="RicheeseCodes/SolaraM"
TAG="Releases"

echo "🚀 Solara Installer"
echo "===================="

OS_VERSION=$(sw_vers -productVersion | cut -d. -f1,2)
ARCH=$(uname -m)

# Catalina detection (10.15)
if [[ "$OS_VERSION" == "10.15" ]]; then
  ASSET_NAME="Solara-catliona.zip"
  echo "Detected: macOS Catalina ($OS_VERSION)"
else
  case "$ARCH" in
    arm64|aarch64)
      ASSET_NAME="Solara-arm64.zip"
      echo "Detected: Apple Silicon ($ARCH)"
      ;;
    x86_64|amd64)
      ASSET_NAME="Solara-x86_64.zip"
      echo "Detected: Intel ($ARCH)"
      ;;
    *)
      echo "❌ Unsupported architecture: $ARCH"
      exit 1
      ;;
  esac
fi

DOWNLOAD_URL="https://github.com/$REPO/releases/download/$TAG/$ASSET_NAME"

TMP_ZIP="/tmp/$ASSET_NAME"
TMP_DIR=$(mktemp -d)

echo "🔗 Downloading: $DOWNLOAD_URL"
curl -fL "$DOWNLOAD_URL" -o "$TMP_ZIP" || {
  echo "❌ Download failed."
  exit 1
}

echo "📦 Extracting ZIP..."
unzip -q "$TMP_ZIP" -d "$TMP_DIR"

APP_SRC=$(find "$TMP_DIR" -maxdepth 2 -name "Solara.app" -type d | head -n 1)

if [ -z "$APP_SRC" ]; then
  echo "❌ Solara.app not found in ZIP"
  exit 1
fi

if [ -d "/Applications/Solara.app" ]; then
  echo "♻️ Removing existing installation..."
  rm -rf /Applications/Solara.app
fi

echo "💾 Installing..."
if [ -w /Applications ]; then
  cp -R "$APP_SRC" /Applications/
else
  sudo cp -R "$APP_SRC" /Applications/
fi

echo "🛡️ Removing quarantine flags..."
xattr -rd com.apple.quarantine /Applications/Solara.app 2>/dev/null || true

echo "🧹 Cleaning up..."
rm -rf "$TMP_DIR" "$TMP_ZIP"

echo ""
echo "✅ Solara installed successfully!"
open -a /Applications/Solara.app
