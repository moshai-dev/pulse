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

# --- Detect OS ---
OUTPUT=$(cat /etc/*release 2>/dev/null || true)
SERVER_OS=""

if echo "$OUTPUT" | grep -qi "ubuntu"; then
    SERVER_OS="Ubuntu"
elif echo "$OUTPUT" | grep -q -E "CentOS Linux 7"; then
    SERVER_OS="CentOS7"
elif echo "$OUTPUT" | grep -q -E "CentOS Linux 8|AlmaLinux 8|AlmaLinux 9|AlmaLinux 10|CloudLinux 7|CloudLinux 8|openEuler 20.03|openEuler 22.03"; then
    SERVER_OS="RHEL"
else
    echo "❌ Unsupported Linux distribution."
    exit 1
fi

echo "Detected OS: $SERVER_OS"

# --- Install system dependencies ---
echo "Installing system dependencies..."
if [[ "$SERVER_OS" == "Ubuntu" ]]; then
    apt-get update -qq
    apt-get install -y -qq python3 python3-pip curl sqlite3 ca-certificates
else
    # CentOS / AlmaLinux / CloudLinux / openEuler
    yum install -y python3 python3-pip curl sqlite ca-certificates
fi

# --- Ensure pip exists ---
if ! command -v pip3 >/dev/null 2>&1; then
    echo "pip not found. Installing pip..."
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3
fi

# --- Install Python modules ---
echo "Installing Python modules..."
python3 -m pip install --upgrade pip --break-system-packages
python3 -m pip install psutil requests --break-system-packages > /dev/null 2>&1

# --- Setup directories ---
mkdir -p "$CONFIG_DIR" "$DATA_DIR"

# --- Download agent ---
echo "Downloading agent..."
curl -fsSL "$AGENT_URL" -o "$AGENT_PATH"
chmod +x "$AGENT_PATH"

# --- Download config ---
echo "Downloading config..."
curl -fsSL "$CONFIG_URL" -o "$CONFIG_PATH"
sed -i "s|your-server-key|$SERVER_KEY|g" "$CONFIG_PATH"

# --- Download systemd service ---
echo "Downloading systemd service..."
curl -fsSL "$SERVICE_URL" -o "$SERVICE_PATH"

# --- Enable and start service ---
echo "Reloading and enabling service..."
systemctl daemon-reload
systemctl enable --now moshai-pulse.service

echo ""
echo "✅ Installation complete!"
echo "View logs: journalctl -u moshai-pulse -f"
echo ""