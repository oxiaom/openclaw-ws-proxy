#!/bin/bash
#
# OpenClaw WebSocket Proxy Installer
# 
# Usage: curl -fsSL https://raw.githubusercontent.com/openclaw/openclaw-ws-proxy/main/install.sh | bash
#   or:  ./install.sh
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Config
PACKAGE_NAME="openclaw-ws-proxy"
INSTALL_DIR="/opt/openclaw-ws-proxy"
SERVICE_NAME="openclaw-ws-proxy"
CONFIG_FILE="/etc/openclaw-ws-proxy.env"

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       OpenClaw WebSocket Proxy Installer                 ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root${NC}"
  exit 1
fi

# Detect OpenClaw config
OPENCLAW_CONFIG="/root/.openclaw/openclaw.json"
if [ ! -f "$OPENCLAW_CONFIG" ]; then
  # Try to find it
  for user_home in /home/*; do
    if [ -f "$user_home/.openclaw/openclaw.json" ]; then
      OPENCLAW_CONFIG="$user_home/.openclaw/openclaw.json"
      break
    fi
  done
fi

if [ -f "$OPENCLAW_CONFIG" ]; then
  echo -e "${GREEN}Found OpenClaw config: $OPENCLAW_CONFIG${NC}"
else
  echo -e "${YELLOW}Warning: OpenClaw config not found at default location${NC}"
  echo -e "${YELLOW}You will need to set GATEWAY_TOKEN manually${NC}"
fi

# Check Node.js
if ! command -v node &> /dev/null; then
  echo -e "${RED}Node.js is not installed. Please install Node.js first.${NC}"
  exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 16 ]; then
  echo -e "${RED}Node.js version 16+ is required. Current: $(node -v)${NC}"
  exit 1
fi

echo -e "${GREEN}Node.js version: $(node -v)${NC}"

# Create installation directory
echo "Creating installation directory..."
mkdir -p "$INSTALL_DIR"

# Copy files
echo "Copying files..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp -r "$SCRIPT_DIR/server.js" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/package.json" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/bin" "$INSTALL_DIR/" 2>/dev/null || mkdir -p "$INSTALL_DIR/bin"

# Create bin entry point
cat > "$INSTALL_DIR/bin/openclaw-ws-proxy.js" << 'EOF'
#!/usr/bin/env node
const path = require('path');
try {
  require('dotenv').config({ path: '/etc/openclaw-ws-proxy.env' });
} catch (e) {}
require('../server.js');
EOF
chmod +x "$INSTALL_DIR/bin/openclaw-ws-proxy.js"

# Install dependencies
echo "Installing dependencies..."
cd "$INSTALL_DIR"
npm install --production

# Create config file if not exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Creating config file..."
  cat > "$CONFIG_FILE" << EOF
# OpenClaw WebSocket Proxy Configuration
# Edit this file to customize settings

# Proxy port (default: 18790)
PROXY_PORT=18790

# Gateway settings (default: localhost:18789)
GATEWAY_HOST=localhost
GATEWAY_PORT=18789

# Token - auto-loaded from OpenClaw config, or set manually:
# GATEWAY_TOKEN=your-token-here

# OpenClaw config path (for auto-loading token)
CONFIG_PATH=$OPENCLAW_CONFIG

# Allowed origins (comma-separated, or * for all)
ALLOWED_ORIGINS=*
EOF
  chmod 600 "$CONFIG_FILE"
fi

# Create systemd service
echo "Creating systemd service..."
NODE_BIN=$(which node)
cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=OpenClaw WebSocket Proxy
After=network.target
Wants=openclaw-gateway.service

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
EnvironmentFile=$CONFIG_FILE
ExecStart=$NODE_BIN $INSTALL_DIR/bin/openclaw-ws-proxy.js
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
systemctl daemon-reload

# Enable service
echo "Enabling service..."
systemctl enable $SERVICE_NAME

# Start service
echo "Starting service..."
systemctl start $SERVICE_NAME

# Check status
sleep 2
if systemctl is-active --quiet $SERVICE_NAME; then
  echo ""
  echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║            Installation Complete!                        ║${NC}"
  echo -e "${GREEN}╠═══════════════════════════════════════════════════════════╣${NC}"
  echo -e "${GREEN}║  Proxy URL:    ws://<your-host>:18790                   ║${NC}"
  echo -e "${GREEN}║  Status:       systemctl status $SERVICE_NAME           ${NC}"
  echo -e "${GREEN}║  Logs:         journalctl -u $SERVICE_NAME -f           ${NC}"
  echo -e "${GREEN}║  Config:       $CONFIG_FILE              ${NC}"
  echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
else
  echo -e "${RED}Service failed to start. Check logs:${NC}"
  echo "  journalctl -u $SERVICE_NAME -n 50"
fi
