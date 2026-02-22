#!/bin/bash
#
# OpenClaw WebSocket Proxy Uninstaller
#

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SERVICE_NAME="openclaw-ws-proxy"
INSTALL_DIR="/opt/openclaw-ws-proxy"
CONFIG_FILE="/etc/openclaw-ws-proxy.env"

echo -e "${YELLOW}Uninstalling OpenClaw WebSocket Proxy...${NC}"

# Stop service
if systemctl is-active --quiet $SERVICE_NAME 2>/dev/null; then
  echo "Stopping service..."
  systemctl stop $SERVICE_NAME
fi

# Disable service
if systemctl is-enabled --quiet $SERVICE_NAME 2>/dev/null; then
  echo "Disabling service..."
  systemctl disable $SERVICE_NAME
fi

# Remove service file
if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
  echo "Removing service file..."
  rm "/etc/systemd/system/$SERVICE_NAME.service"
  systemctl daemon-reload
fi

# Ask about config
if [ -f "$CONFIG_FILE" ]; then
  echo -e "${YELLOW}Keep config file? [Y/n]${NC}"
  read -r keep_config
  if [ "$keep_config" = "n" ] || [ "$keep_config" = "N" ]; then
    rm "$CONFIG_FILE"
    echo "Removed config file"
  fi
fi

# Remove installation directory
if [ -d "$INSTALL_DIR" ]; then
  echo "Removing installation directory..."
  rm -rf "$INSTALL_DIR"
fi

echo -e "${GREEN}Uninstallation complete.${NC}"
