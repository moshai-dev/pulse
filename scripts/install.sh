#!/bin/bash
set -e

AGENT_URL="https://raw.githubusercontent.com/moshai-dev/pulse/main/agent/pulse.py"
CONFIG_URL="https://raw.githubusercontent.com/moshai-dev/pulse/main/config/config.sample.ini"
SERVICE_URL="https://raw.githubusercontent.com/moshai-dev/pulse/main/scripts/systemd.service"

AGENT_PATH="/usr/local/bin/moshai-pulse.py"
CONFIG_DIR="/etc/moshai-pulse"
CONFIG_PATH="$CONFIG_DIR/config"
SERVICE_PATH="/etc/systemd/system/moshai-pulse.service"
DATA_DIR="/var/lib/moshai-pulse"

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

# --- Detect package manager ---
if command -v apt-get >/dev/null 2>&1; then
  PKG_INSTALL="apt-get install -y -qq"
  UPDATE_CMD="apt-get update -qq"
elif command -v yum >/dev/null 2>&1; then
  PKG_INSTALL="yum install -y -q"
  UPDATE_CMD="yum makecache -q"
elif command -v dnf >/dev/null 2>&1; then
  PKG_INSTALL="dnf install -y -q"
  UPDATE_CMD="dnf makecache -q"
else
  echo "❌ Unsupported Linux distribution."
  exit 1
fi

echo "Installing dependencies..."
$UPDATE_CMD
$PKG_INSTALL python3 python3-pip python3-psutil python3-requests sqlite curl > /dev/null 2>&1 || true

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
echo "Logs: journalctl -u moshai-pulse -f"
echo ""
