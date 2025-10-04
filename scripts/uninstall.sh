#!/bin/bash
set -e

echo "Stopping Moshai Pulse service..."
if systemctl is-active --quiet moshai-pulse.service; then
    systemctl stop moshai-pulse.service
fi

echo "Disabling service..."
systemctl disable moshai-pulse.service || true

echo "Removing systemd service file..."
rm -f /etc/systemd/system/moshai-pulse.service
systemctl daemon-reload

echo "Removing agent executable..."
rm -f /usr/local/bin/moshai-pulse.py

echo "Removing configuration and data..."
rm -rf /etc/moshai-pulse
rm -rf /var/lib/moshai-pulse

echo "✅ Moshai Pulse Agent uninstalled successfully!"
