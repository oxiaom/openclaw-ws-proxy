#!/bin/bash
# Start OpenClaw WebSocket Proxy

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
  echo "Installing dependencies..."
  npm install
fi

# Start with environment variables (optional)
# PROXY_PORT=18790 GATEWAY_HOST=localhost GATEWAY_PORT=18789 node server.js

node server.js
