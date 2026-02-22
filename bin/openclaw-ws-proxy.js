#!/usr/bin/env node
/**
 * openclaw-ws-proxy CLI entry point
 */

const path = require('path');

// Load environment from .env if exists
try {
  require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
} catch (e) {
  // dotenv not installed, ignore
}

// Start the server
require('../server.js');
