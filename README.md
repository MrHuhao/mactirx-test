# Matrix 全栈本地开发环境 (Conduwuit Edition)

从源码构建和运行完整的 Matrix 通信系统，包括 Homeserver 和 6 个平台 Bridge。

## 架构

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────────────────────┐
│ Element Web  │ <-> │  Nginx (可选)     │ <-> │  Conduwuit (Rust Homeserver) │
│ :8080        │     │  :8008           │     │  :6167  (内嵌 RocksDB)       │
└─────────────┘     └──────────────────┘     └──────────┬──────────────────┘
                                                        │ Appservice API
                    ┌──────────┬──────────┬──────────┬──┴───────┬──────────┐
                    │          │          │          │          │          │
               Telegram   Discord   WhatsApp    Slack      Signal    GMsgs
               (Python)    (Go)      (Go)       (Go)       (Go)      (Go)
               :29317     :29318    :29319     :29320     :29321    :29322
```

## 快速开始

### 1. 检查环境依赖

```bash
bash scripts/check-env.sh
```

需要: Rust, Python 3.11+, Go 1.21+, Node.js 18+, yarn, libolm

macOS 一键安装依赖:
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
brew install python@3.12 go node yarn nginx libolm ffmpeg
```

### 2. 克隆源码

```bash
bash scripts/clone-sources.sh
```

克隆以下仓库到 `source/` 目录:
- conduwuit (Rust Matrix Homeserver)
- element-web (网页客户端)
- mautrix-telegram, discord, whatsapp, slack, signal, gmessages

### 3. 构建所有组件

```bash
bash scripts/build-all.sh
```

⏱ 首次构建预计需要 15-30 分钟 (Conduwuit Rust 编译较慢)

### 4. 生成 Bridge 配置

```bash
bash scripts/generate-bridge-configs.sh
```

### 5. 启动服务

```bash
bash scripts/start-all.sh
```

### 6. 查看状态

```bash
bash scripts/status.sh
```

### 7. 停止服务

```bash
bash scripts/stop-all.sh
```

## 目录结构

```
mactirx-test/
├── .env                          # 环境变量配置
├── conduwuit/
│   └── conduwuit.toml            # Conduwuit 配置模板
├── element-web/
│   └── config.json               # Element Web 客户端配置
├── bridges/
│   ├── mautrix-telegram/
│   │   ├── config.yaml           # Bridge 配置
│   │   └── registration.yaml     # Appservice 注册
│   ├── mautrix-discord/
│   ├── mautrix-whatsapp/
│   ├── mautrix-slack/
│   ├── mautrix-signal/
│   └── mautrix-gmessages/
├── nginx/
│   └── matrix.conf               # Nginx 反向代理配置
├── scripts/
│   ├── check-env.sh              # 环境检查
│   ├── clone-sources.sh          # 克隆源码
│   ├── build-all.sh              # 构建所有组件
│   ├── generate-bridge-configs.sh # 生成配置
│   ├── start-all.sh              # 启动服务
│   ├── stop-all.sh               # 停止服务
│   └── status.sh                 # 查看状态
├── source/                       # 源码目录 (git clone)
│   ├── conduwuit/
│   ├── element-web/
│   ├── mautrix-telegram/
│   ├── mautrix-discord/
│   ├── mautrix-whatsapp/
│   ├── mautrix-slack/
│   ├── mautrix-signal/
│   └── mautrix-gmessages/
├── data/                         # 运行时数据
│   ├── conduwuit/                # RocksDB 数据库
│   └── bridges/                  # Bridge SQLite 数据库
└── logs/                         # 服务日志
```

## Bridge 配置说明

### Telegram Bridge
需要从 https://my.telegram.org 获取 API 凭证:
1. 登录后进入 "API development tools"
2. 创建应用获取 `api_id` 和 `api_hash`
3. 填入 `.env` 或直接修改 `bridges/mautrix-telegram/config.yaml`

### Discord Bridge
需要从 Discord Developer Portal 创建 Bot:
1. 访问 https://discord.com/developers/applications
2. 创建应用 → Bot → 获取 Token
3. 填入 `.env`

### WhatsApp Bridge
- 无需提前配置 API Key
- 启动后通过 Matrix 聊天扫描 QR 码登录

### Signal Bridge
- 无需提前配置 API Key
- 启动后通过 Matrix 聊天进行关联

### Slack Bridge
需要创建 Slack App:
1. 访问 https://api.slack.com/apps
2. 创建应用并配置 OAuth Scopes

### Google Messages Bridge
- 无需提前配置 API Key
- 启动后通过 Matrix 聊天扫描 QR 码

## 注册用户

Conduwuit 启动后，通过 API 注册:

```bash
curl -X POST http://localhost:6167/_matrix/client/v3/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "your_password",
    "auth": {
      "type": "m.login.registration_token",
      "token": "matrix_dev_registration_token_2026"
    }
  }'
```

## 常用命令

```bash
# 查看特定服务日志
tail -f logs/conduwuit.log
tail -f logs/mautrix-discord.log

# 重启单个服务
bash scripts/stop-all.sh && bash scripts/start-all.sh

# 重新构建某个 Bridge
cd source/mautrix-discord && go build -o mautrix-discord . && cd -
```

## 技术栈

| 组件 | 语言 | 数据库 |
|---|---|---|
| Conduwuit | Rust | RocksDB (内嵌) |
| mautrix-telegram | Python | SQLite |
| mautrix-discord | Go | SQLite |
| mautrix-whatsapp | Go | SQLite |
| mautrix-slack | Go | SQLite |
| mautrix-signal | Go | SQLite |
| mautrix-gmessages | Go | SQLite |
| Element Web | TypeScript/React | - |
