# OpenClaw WebSocket Proxy

[![npm version](https://badge.fury.io/js/openclaw-ws-proxy.svg)](https://badge.fury.io/js/openclaw-ws-proxy)

WebSocket 代理，用于 OpenClaw Control UI，自动注入认证 token。

## 为什么需要这个？

OpenClaw Gateway 需要认证 token 才能连接 WebSocket，但 Control UI（网页版）不方便直接管理这个 token。

这个代理作为中间层：
1. 监听本地端口（默认 18790）
2. 接收 Control UI 的 WebSocket 连接
3. 自动在 `connect` 请求中注入 gateway token
4. 透明转发所有其他消息

## 快速安装

### 方法 1: 一键安装（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/openclaw/openclaw-ws-proxy/main/install.sh | bash
```

### 方法 2: NPM 全局安装

```bash
npm install -g openclaw-ws-proxy

# 启动
openclaw-ws-proxy

# 或使用环境变量
PROXY_PORT=18790 GATEWAY_TOKEN=your-token openclaw-ws-proxy
```

### 方法 3: 手动安装

```bash
git clone https://github.com/openclaw/openclaw-ws-proxy.git
cd openclaw-ws-proxy
npm install --production

# 启动
node server.js
```

## 配置

### 环境变量

| 变量 | 说明 | 默认值 |
|-----|------|-------|
| `PROXY_PORT` | 代理监听端口 | `18790` |
| `GATEWAY_HOST` | Gateway 主机 | `localhost` |
| `GATEWAY_PORT` | Gateway 端口 | `18789` |
| `GATEWAY_TOKEN` | 认证 token | 从配置文件读取 |
| `CONFIG_PATH` | OpenClaw 配置文件路径 | `/root/.openclaw/openclaw.json` |
| `ALLOWED_ORIGINS` | 允许的来源 | `*` |

### 配置文件

安装后，配置文件位于 `/etc/openclaw-ws-proxy.env`：

```bash
# 编辑配置
sudo nano /etc/openclaw-ws-proxy.env

# 重启服务
sudo systemctl restart openclaw-ws-proxy
```

## 使用

1. 确保代理服务运行中
2. 在 Control UI 中设置 WebSocket 地址：
   - 本地: `ws://localhost:18790`
   - 局域网: `ws://192.168.x.x:18790`

## 命令

```bash
# 查看状态
sudo systemctl status openclaw-ws-proxy

# 启动
sudo systemctl start openclaw-ws-proxy

# 停止
sudo systemctl stop openclaw-ws-proxy

# 重启
sudo systemctl restart openclaw-ws-proxy

# 查看日志
sudo journalctl -u openclaw-ws-proxy -f

# 健康检查
curl http://localhost:18790/health
```

## 卸载

```bash
curl -fsSL https://raw.githubusercontent.com/openclaw/openclaw-ws-proxy/main/uninstall.sh | bash
```

## 开发

```bash
# 克隆仓库
git clone https://github.com/openclaw/openclaw-ws-proxy.git
cd openclaw-ws-proxy

# 安装依赖
npm install

# 运行
node server.js
```

## License
## 本程序由 无锡小播鼠网络科技有限公司的 李海生 vx： lihaesen发布
MIT
