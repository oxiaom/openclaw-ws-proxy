# OpenClaw WebSocket Proxy

WebSocket 代理，用于 OpenClaw Control UI，自动注入认证 token。

## 为什么需要这个？

OpenClaw Gateway 需要认证 token 才能连接 WebSocket，但 Control UI（网页版）不方便直接管理这个 token。

这个代理作为中间层：
1. 监听本地端口（默认 18790）
2. 接收 Control UI 的 WebSocket 连接
3. 自动在 `connect` 请求中注入 gateway token
4. 透明转发所有其他消息

---

## 安装

### 方法 1: 一键安装（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/oxiaom/openclaw-ws-proxy/main/install.sh | bash
```

安装完成后会自动：
- 创建 `/opt/openclaw-ws-proxy` 目录
- 安装依赖
- 创建 systemd 服务
- 启动服务

### 方法 2: 手动安装

```bash
# 克隆仓库
git clone https://github.com/oxiaom/openclaw-ws-proxy.git
cd openclaw-ws-proxy

# 安装依赖
npm install --production

# 启动
node server.js
```

### 方法 3: NPM 全局安装

```bash
# 从 GitHub 安装
npm install -g oxiaom/openclaw-ws-proxy

# 启动
openclaw-ws-proxy
```

---

## 配置

### 环境变量

| 变量 | 说明 | 默认值 |
|-----|------|-------|
| `PROXY_PORT` | 代理监听端口 | `18790` |
| `GATEWAY_HOST` | Gateway 主机 | `localhost` |
| `GATEWAY_PORT` | Gateway 端口 | `18789` |
| `GATEWAY_TOKEN` | 认证 token | 从配置文件自动读取 |
| `CONFIG_PATH` | OpenClaw 配置文件路径 | `/root/.openclaw/openclaw.json` |
| `ALLOWED_ORIGINS` | 允许的来源 | `*` |

### 配置文件

一键安装后，配置文件位于 `/etc/openclaw-ws-proxy.env`：

```bash
# 查看配置
cat /etc/openclaw-ws-proxy.env

# 编辑配置
sudo nano /etc/openclaw-ws-proxy.env

# 修改后重启服务
sudo systemctl restart openclaw-ws-proxy
```

配置示例：

```bash
# 代理端口
PROXY_PORT=18790

# Gateway 地址
GATEWAY_HOST=localhost
GATEWAY_PORT=18789

# Token（通常不需要手动设置，会自动从 OpenClaw 配置读取）
# GATEWAY_TOKEN=your-token-here

# OpenClaw 配置路径
CONFIG_PATH=/root/.openclaw/openclaw.json

# 允许的来源（逗号分隔，或 * 表示所有）
ALLOWED_ORIGINS=*
```

---

## 使用

### 1. 确保服务运行

```bash
# 查看状态
sudo systemctl status openclaw-ws-proxy

# 如果未运行，启动它
sudo systemctl start openclaw-ws-proxy
```

### 2. 在 Control UI 中配置

在 Control UI 的设置中，将 WebSocket 地址改为代理地址：

- **本地访问**: `ws://localhost:18790`
- **局域网访问**: `ws://192.168.x.x:18790`（替换为实际 IP）

### 3. 连接测试

代理会自动注入认证 token，无需在 Control UI 中手动配置。

---

## 命令参考

```bash
# 启动服务
sudo systemctl start openclaw-ws-proxy

# 停止服务
sudo systemctl stop openclaw-ws-proxy

# 重启服务
sudo systemctl restart openclaw-ws-proxy

# 查看状态
sudo systemctl status openclaw-ws-proxy

# 查看日志
sudo journalctl -u openclaw-ws-proxy -f

# 开机自启
sudo systemctl enable openclaw-ws-proxy

# 禁用开机自启
sudo systemctl disable openclaw-ws-proxy

# 健康检查
curl http://localhost:18790/health

# 查看状态页面
curl http://localhost:18790/
```

---

## 卸载

```bash
curl -fsSL https://raw.githubusercontent.com/oxiaom/openclaw-ws-proxy/main/uninstall.sh | bash
```

或手动卸载：

```bash
sudo systemctl stop openclaw-ws-proxy
sudo systemctl disable openclaw-ws-proxy
sudo rm /etc/systemd/system/openclaw-ws-proxy.service
sudo systemctl daemon-reload
sudo rm -rf /opt/openclaw-ws-proxy
# 可选：保留配置文件
# sudo rm /etc/openclaw-ws-proxy.env
```

---

## 工作原理

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Control    │────▶│  WS Proxy        │────▶│  OpenClaw       │
│  UI         │     │  (port 18790)    │     │  Gateway        │
│             │     │                  │     │  (port 18789)   │
│  (no token) │     │  - 拦截 connect  │     │                 │
│             │     │  - 注入 token    │     │  ✓ 有 token     │
│             │     │  - 透明转发      │     │                 │
└─────────────┘     └──────────────────┘     └─────────────────┘
```

1. Control UI 连接到代理（不需要 token）
2. 代理拦截 `connect` 请求
3. 代理自动注入 `auth.token`
4. 代理将修改后的请求转发给 Gateway
5. Gateway 验证 token 通过，建立连接
6. 后续消息透明双向转发

---

## 故障排查

### 服务无法启动

```bash
# 查看详细日志
sudo journalctl -u openclaw-ws-proxy -n 50

# 检查端口是否被占用
sudo netstat -tlnp | grep 18790
```

### 连接被拒绝

1. 确认服务正在运行：`sudo systemctl status openclaw-ws-proxy`
2. 确认端口正确：检查 `/etc/openclaw-ws-proxy.env` 中的 `PROXY_PORT`
3. 检查防火墙：确保 18790 端口可访问

### Token 加载失败

```bash
# 检查 OpenClaw 配置是否存在
cat /root/.openclaw/openclaw.json | grep token

# 或手动设置 token
sudo nano /etc/openclaw-ws-proxy.env
# 添加: GATEWAY_TOKEN=your-token-here
```

---

## 开发

```bash
# 克隆仓库
git clone https://github.com/oxiaom/openclaw-ws-proxy.git
cd openclaw-ws-proxy

# 安装依赖
npm install

# 运行（开发模式）
node server.js
```

---

## License

MIT
