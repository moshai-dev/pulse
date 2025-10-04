#!/bin/bash
set -e

# URLs
AGENT_URL="https://raw.githubusercontent.com/moshai-dev/pulse/main/agent/pulse.py"
CONFIG_URL="https://raw.githubusercontent.com/moshai-dev/pulse/main/config/config.sample.ini"
SERVICE_URL="https://raw.githubusercontent.com/moshai-dev/pulse/main/scripts/systemd.service"

# Paths
AGENT_PATH="/usr/local/bin/moshai-pulse.py"
CONFIG_DIR="/etc/moshai-pulse"
CONFIG_PATH="$CONFIG_DIR/config"
DATA_DIR="/var/lib/moshai-pulse"
SERVICE_PATH="/etc/systemd/system/moshai-pulse.service"

# --- Parse Args ---
if [[ "$1" == "--key" && -n "$2" ]]; then
  SERVER_KEY="$2"
else
  echo "Usage: bash <(curl -fsSL https://raw.githubusercontent.com/moshai-dev/pulse/main/scripts/install.sh) --key YOUR_SERVER_KEY"
  exit 1
fi

echo ""
echo "=== Installing Moshai Pulse Agent ==="
echo ""

# --- Detect package manager and install system dependencies ---
if command -v apt-get >/dev/null 2>&1; then
    PKG_INSTALL="apt-get install -y -qq"
    UPDATE_CMD="apt-get update -qq"
    $UPDATE_CMD
    $PKG_INSTALL python3 python3-pip curl sqlite -y
elif command -v yum >/dev/null 2>&1; then
    PKG_INSTALL="yum install -y -q"
    UPDATE_CMD="yum makecache -q"
    $UPDATE_CMD
    # Enable EPEL for pip on older RHEL/CentOS
    yum install -y epel-release
    $PKG_INSTALL python3 python3-pip curl sqlite
elif command -v dnf >/dev/null 2>&1; then
    PKG_INSTALL="dnf install -y -q"
    UPDATE_CMD="dnf makecache -q"
    $UPDATE_CMD
    $PKG_INSTALL python3 python3-pip curl sqlite
else
    echo "❌ Unsupported Linux distribution."
    exit 1
fi

# --- Ensure pip exists ---
if ! command -v pip3 >/dev/null 2>&1; then
    echo "pip not found. Installing pip..."
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3
fi

# --- Install Python modules ---
echo "Installing Python modules..."
python3 -m pip install --upgrade pip
python3 -m pip install psutil requests > /dev/null 2>&1

# --- Setup directories ---
mkdir -p "$CONFIG_DIR" "$DATA_DIR"

echo "Downloading agent..."
curl -fsSL "$AGENT_URL" -o "$AGENT_PATH"
chmod +x "$AGENT_PATH"

echo "Downloading config..."
curl -fsSL "$CONFIG_URL" -o "$CONFIG_PATH"
sed -i "s|your-server-key|$SERVER_KEY|g" "$CONFIG_PATH"

echo "Downloading systemd service..."
curl -fsSL "$SERVICE_URL" -o "$SERVICE_PATH"

echo "Reloading and enabling service..."
systemctl daemon-reload
systemctl enable --now moshai-pulse.service

echo ""
echo "✅ Installation complete!"
echo "View logs: journalctl -u moshai-pulse -f"
echo ""
