# OpenWrt Network Monitor - Node.js Client

Node.js 版本的 OpenWrt 网络监控客户端 Web UI。

## 功能特性

- 实时监控 WAN 状态、CPU 温度、网络延迟
- Ping 延迟趋势图表
- 网络事件记录
- 24小时可用性统计
- 暗色模式支持

## 安装

```bash
npm install
```

## 配置

复制 `.env.example` 为 `.env` 并配置：

```bash
cp .env.example .env
```

编辑 `.env` 文件：

```
ROUTER_IP=192.168.1.1
ROUTER_PORT=8321
ROUTER_TOKEN=
POLL_INTERVAL=60
PORT=5000
```

## 运行

```bash
# 生产环境
npm start

# 开发环境（自动重启）
npm run dev
```

访问 http://localhost:5000

## 技术栈

- Express.js - Web 框架
- Sequelize - ORM
- SQLite - 数据库
- Chart.js - 图表
- Bootstrap 5 - UI 框架
