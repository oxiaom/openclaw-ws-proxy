/**
 * OpenClaw WebSocket Proxy
 * 
 * Intercepts the 'connect' request from Control UI and injects the gateway token.
 * All other messages are transparently forwarded.
 * 
 * Usage:
 *   1. npm install
 *   2. node server.js
 *   3. Connect Control UI to ws://localhost:18790
 */

const WebSocket = require('ws');
const http = require('http');
const fs = require('fs');
const crypto = require('crypto');

// Config
const CONFIG = {
  proxyPort: process.env.PROXY_PORT || 18790,
  gatewayHost: process.env.GATEWAY_HOST || 'localhost',
  gatewayPort: process.env.GATEWAY_PORT || 18789,
  gatewayToken: process.env.GATEWAY_TOKEN || '',
  configPath: process.env.CONFIG_PATH || '/root/.openclaw/openclaw.json',
  allowedOrigins: process.env.ALLOWED_ORIGINS || '*',
};

// Load token from config
function loadTokenFromConfig() {
  if (CONFIG.gatewayToken) return CONFIG.gatewayToken;
  
  try {
    const config = JSON.parse(fs.readFileSync(CONFIG.configPath, 'utf8'));
    CONFIG.gatewayToken = config.gateway?.auth?.token || '';
    if (CONFIG.gatewayToken) {
      console.log(`[config] Loaded token from ${CONFIG.configPath}`);
    }
  } catch (err) {
    console.warn(`[config] Failed to load token:`, err.message);
  }
  
  return CONFIG.gatewayToken;
}

// HTTP server
const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ 
      status: 'ok', 
      gateway: `ws://${CONFIG.gatewayHost}:${CONFIG.gatewayPort}`,
      hasToken: !!CONFIG.gatewayToken 
    }));
    return;
  }
  
  if (req.url === '/' || req.url === '/status') {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(`
      <html>
        <head><title>OpenClaw WS Proxy</title></head>
        <body>
          <h1>OpenClaw WebSocket Proxy</h1>
          <p>Status: Running</p>
          <p>Gateway: ws://${CONFIG.gatewayHost}:${CONFIG.gatewayPort}</p>
          <p>Token: ${CONFIG.gatewayToken ? 'Loaded ✓' : 'Missing ✗'}</p>
          <h2>Connect</h2>
          <p>Use: <code>ws://<this-host>:${CONFIG.proxyPort}</code></p>
        </body>
      </html>
    `);
    return;
  }
  
  res.writeHead(404);
  res.end('Not found');
});

const wss = new WebSocket.Server({ noServer: true });

// Handle upgrade
server.on('upgrade', (request, socket, head) => {
  const origin = request.headers.origin || '';
  
  if (CONFIG.allowedOrigins !== '*') {
    const allowed = CONFIG.allowedOrigins.split(',').map(o => o.trim());
    if (!allowed.includes(origin) && !allowed.includes('*')) {
      console.log(`[reject] Origin not allowed: ${origin}`);
      socket.write('HTTP/1.1 403 Forbidden\r\n\r\n');
      socket.destroy();
      return;
    }
  }
  
  wss.handleUpgrade(request, socket, head, (ws) => {
    wss.emit('connection', ws, request);
  });
});

// Generate a nonce for this connection (gateway expects this in URL)
function generateNonce() {
  return crypto.randomBytes(16).toString('hex');
}

// Handle connection
wss.on('connection', (clientWs, request) => {
  const clientIp = request.socket.remoteAddress;
  const connId = `${clientIp}:${Date.now()}`;
  console.log(`[connect] ${connId}`);
  
  if (!CONFIG.gatewayToken) {
    loadTokenFromConfig();
  }
  
  if (!CONFIG.gatewayToken) {
    console.error(`[error] No token!`);
    clientWs.close(1008, 'Proxy misconfigured: no gateway token');
    return;
  }
  
  // Generate nonce and connect to gateway with token in URL
  const nonce = generateNonce();
  const gatewayUrl = `ws://${CONFIG.gatewayHost}:${CONFIG.gatewayPort}/ws?token=${CONFIG.gatewayToken}&nonce=${nonce}`;
  
  const gatewayWs = new WebSocket(gatewayUrl, {
    headers: {
      'origin': `http://${CONFIG.gatewayHost}:${CONFIG.gatewayPort}`
    }
  });
  
  let clientClosed = false;
  let gatewayClosed = false;
  let handshakeDone = false;  // Track if we've seen the connect request
  
  gatewayWs.on('open', () => {
    console.log(`[gateway] Connected for ${connId}`);
    // Don't send anything - wait for client to send connect request
  });
  
  // Messages from client -> inject token into connect -> forward to gateway
  clientWs.on('message', (data) => {
    if (gatewayClosed) return;
    
    try {
      const msg = JSON.parse(data.toString());
      
      // Intercept the 'connect' request and inject auth.token
      if (!handshakeDone && msg.type === 'req' && msg.method === 'connect') {
        handshakeDone = true;
        
        // Inject auth.token if not present
        if (!msg.params) msg.params = {};
        if (!msg.params.auth) msg.params.auth = {};
        if (!msg.params.auth.token) {
          msg.params.auth.token = CONFIG.gatewayToken;
        }
        
        console.log(`[inject] Added auth.token to connect request for ${connId}`);
        
        if (gatewayWs.readyState === WebSocket.OPEN) {
          gatewayWs.send(JSON.stringify(msg));
        }
        return;
      }
      
      // Forward all other messages as-is
      if (gatewayWs.readyState === WebSocket.OPEN) {
        gatewayWs.send(data);
      }
    } catch (e) {
      // Not JSON or parse error - forward as-is
      if (gatewayWs.readyState === WebSocket.OPEN) {
        gatewayWs.send(data);
      }
    }
  });
  
  // Messages from gateway -> forward to client
  gatewayWs.on('message', (data) => {
    if (!clientClosed && clientWs.readyState === WebSocket.OPEN) {
      clientWs.send(data);
    }
  });
  
  clientWs.on('close', (code, reason) => {
    clientClosed = true;
    console.log(`[disconnect] ${connId}: ${code}`);
    if (!gatewayClosed && gatewayWs.readyState === WebSocket.OPEN) {
      gatewayWs.close(code, reason);
    }
  });
  
  gatewayWs.on('close', (code, reason) => {
    gatewayClosed = true;
    console.log(`[gateway] Disconnected for ${connId}: ${code} ${reason || ''}`);
    if (!clientClosed && clientWs.readyState === WebSocket.OPEN) {
      clientWs.close(code, reason);
    }
  });
  
  gatewayWs.on('error', (err) => {
    console.error(`[gateway] Error for ${connId}:`, err.message);
    if (!clientClosed && clientWs.readyState === WebSocket.OPEN) {
      clientWs.close(1011, 'Gateway error');
    }
  });
  
  clientWs.on('error', (err) => {
    console.error(`[client] Error for ${connId}:`, err.message);
  });
});

// Load token on startup
loadTokenFromConfig();

server.listen(CONFIG.proxyPort, () => {
  console.log(`
╔═══════════════════════════════════════════════════════════╗
║           OpenClaw WebSocket Proxy v2                    ║
╠═══════════════════════════════════════════════════════════╣
║  Proxy:     ws://localhost:${CONFIG.proxyPort}                    ║
║  Gateway:   ws://${CONFIG.gatewayHost}:${CONFIG.gatewayPort}                ║
║  Token:     ${CONFIG.gatewayToken ? 'Loaded ✓' : 'Missing ✗'}                            ║
╚═══════════════════════════════════════════════════════════╝
  `);
});

process.on('SIGINT', () => {
  console.log('\n[shutdown]');
  wss.clients.forEach((ws) => ws.close(1001, 'Server shutting down'));
  server.close(() => process.exit(0));
});
