#!/usr/bin/env bash
set -e

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
NC="\033[0m"

OWNER="mesiel-org"
REPO="mdu"

echo -e "${BLUE}Detecting OS and architecture...${NC}"

OS="$(uname | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$ARCH" in
    x86_64) ARCH="x86_64" ;;
    aarch64|arm64) ARCH="aarch64" ;;
    *) echo -e "${RED}[!] Unsupported architecture: $ARCH${NC}"; exit 1 ;;
esac

case "$OS" in
    darwin) OS="macos" ;;
    mingw*|cygwin*|msys*) OS="windows" ;;
    freebsd) OS="freebsd" ;;
    linux)
        if ldd --version 2>&1 | grep -q musl; then
            OS="linux-musl"
        else
            OS="linux-gnu"
        fi
        ;;
    *) echo -e "${RED}[!] Unsupported OS: $OS${NC}"; exit 1 ;;
esac

echo -e "${GREEN}Detected OS: $OS, ARCH: $ARCH${NC}"

echo -e "${BLUE}Fetching latest release tag from GitHub...${NC}"
TAG=$(curl -s "https://api.github.com/repos/$OWNER/$REPO/releases/latest" | \
      grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

FILE_NAME="${REPO}-${ARCH}-${OS}.tar.gz"
DOWNLOAD_URL="https://github.com/$OWNER/$REPO/releases/download/$TAG/$FILE_NAME"

echo -e "${BLUE}Downloading $FILE_NAME...${NC}"
TMP_DIR=$(mktemp -d)
curl -sL "$DOWNLOAD_URL" -o "$TMP_DIR/$FILE_NAME"

echo -e "${BLUE}Extracting...${NC}"
tar -xzf "$TMP_DIR/$FILE_NAME" -C "$TMP_DIR"

BIN_NAME="mdu"
if [ "$OS" = "windows" ]; then
    BIN_NAME="mdu.exe"
fi

BIN=$(find "$TMP_DIR" -name "$BIN_NAME" -type f | head -1)

if [ ! -f "$BIN" ]; then
    echo -e "${RED}[!] Could not find $BIN_NAME in extracted archive${NC}"
    echo -e "${YELLOW}Contents of extracted archive:${NC}"
    find "$TMP_DIR" -type f
    exit 1
fi

echo -e "${BLUE}Installing $BIN to /usr/local/bin...${NC}"
sudo cp "$BIN" /usr/local/bin/mdu
sudo chmod +x /usr/local/bin/mdu

echo -e "${GREEN}mdu installed successfully!${NC}"
echo -e "${BLUE}Installed version: ${TAG}${NC}"

rm -rf "$TMP_DIR"
