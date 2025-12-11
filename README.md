# OpenWrt 网络监控系统

<div align="center">

**轻量级 OpenWrt 网络监控解决方案**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![OpenWrt](https://img.shields.io/badge/OpenWrt-ARM-blue.svg)](https://openwrt.org/)
[![Node.js](https://img.shields.io/badge/Node.js-18+-green.svg)](https://nodejs.org/)

[English](./README_EN.md) | 简体中文

</div>

## 📖 项目简介

OpenWrt 网络监控系统是一个轻量级的网络监控解决方案，专为 ARM 架构的 OpenWrt/iStoreOS 路由器设计。系统由两部分组成：

- **路由器端**：纯 Shell 实现的监控服务，实时采集网络状态和事件
- **客户端**：Node.js Web UI，提供可视化监控面板和数据存储

## ✨ 核心特性

### 路由器端
- 🪶 **超轻量**：纯 Shell 实现，内存占用 < 10MB
- ⚡ **事件驱动**：使用 logread -f 和 dmesg -w 流式读取
- 🎯 **双模块架构**：事件监听器 + HTTP API
- 🔧 **ARM 优化**：兼容 Cortex-A53/A72/NPU
- 💾 **内存队列**：存储在 /tmp，避免闪存磨损

### 客户端
- 📊 **实时监控**：WAN 状态、CPU 温度、网络延迟
- 📈 **趋势图表**：Ping 延迟趋势可视化
- 📝 **事件记录**：网络事件自动记录和展示
- 🌓 **暗色模式**：支持明暗主题切换
- 💾 **数据持久化**：SQLite 数据库存储历史数据

## 🚀 快速开始

### 路由器端安装

1. **上传文件到路由器**
```bash
scp install.sh netmonitor* root@192.168.1.1:/tmp/
ssh root@192.168.1.1
```

2. **运行安装脚本**
```bash
cd /tmp
chmod +x install.sh
./install.sh
```

3. **启动服务**
```bash
/etc/init.d/netmonitor start
/etc/init.d/netmonitor enable
```

4. **验证安装**
```bash
curl http://localhost:8321/net/status
```

### 客户端安装

#### 方式一：Node.js 版本（推荐）

1. **安装依赖**
```bash
cd client_web_ui_NodeJS
npm install
```

2. **配置环境变量**
```bash
cp .env.example .env
# 编辑 .env 文件，设置路由器 IP 和端口
```

3. **启动服务**
```bash
npm start
```

4. **访问 Web UI**
```
http://localhost:3000
```

#### 方式二：Python 版本

1. **安装依赖**
```bash
cd client_web_ui
pip install -r requirements.txt
```

2. **配置环境变量**
```bash
cp .env.example .env
# 编辑 .env 文件
```

3. **启动服务**
```bash
python app.py
```

## 📊 监控指标

### 实时数据
- **WAN 状态**：在线/离线/连接中
- **CPU 温度**：实时温度监控
- **Ping 延迟**：多目标 RTT 测试
- **网络错误**：RX/TX 错误和丢包统计
- **光功率**：光模块 RX/TX 功率（如果支持）

### 历史统计
- **24小时可用性**：WAN 在线率统计
- **PPPoE 重连次数**：24小时内重连统计
- **WAN 断线次数**：24小时内断线统计
- **Ping 延迟趋势**：1小时/6小时/24小时趋势图

### 事件记录
- PPPoE 连接/断开事件
- WAN 上线/下线事件
- 内核网络事件
- 自定义事件

## 🔧 配置说明

### 路由器端配置

编辑 `/etc/netmonitor.conf`：

```bash
# WAN 接口配置
WAN_IFACE="wan"
PPPOE_IFACE="pppoe-wan"

# API 配置
API_PORT="8321"
ALLOWED_IPS=""  # 空表示允许所有 IP
TOKEN=""        # 可选的认证令牌

# Ping 目标
PING_TARGETS="223.5.5.5 8.8.8.8"
```

### 客户端配置

编辑 `.env` 文件：

```bash
# 路由器配置
ROUTER_IP=192.168.1.1
ROUTER_PORT=8321
ROUTER_TOKEN=

# 数据采集间隔（秒）
POLL_INTERVAL=60

# Web 服务端口
PORT=3000
```

## 📡 API 接口

### 获取网络状态
```bash
GET /net/status
```

**响应示例：**
```json
{
  "timestamp": "2025-12-11 14:30:00",
  "realtime": {
    "ping": {
      "223.5.5.5": {"rtt": 8.0, "loss": 0},
      "8.8.8.8": {"rtt": 184.5, "loss": 0}
    },
    "wan_errors": {
      "rx_errors": 0,
      "tx_errors": 0,
      "rx_dropped": 3590,
      "tx_dropped": 1249
    },
    "optical_power": {
      "rx": -8.6,
      "tx": 1.3
    },
    "cpu_temp": 59.4,
    "wan_state": "up"
  },
  "events": [
    {"time": "2025-12-10 17:00:48", "type": "pppoe_padt", "message": "收到PADT"}
  ],
  "summary": {
    "pppoe_reconnect_count_24h": 1,
    "wan_down_count_24h": 0
  }
}
```

## 🛠️ 服务管理

### 路由器端
```bash
# 启动服务
/etc/init.d/netmonitor start

# 停止服务
/etc/init.d/netmonitor stop

# 重启服务
/etc/init.d/netmonitor restart

# 查看状态
/etc/init.d/netmonitor status

# 开机自启
/etc/init.d/netmonitor enable
```

### 客户端
```bash
# Node.js 版本
npm start          # 生产环境
npm run dev        # 开发环境（自动重启）

# Python 版本
python app.py
```

## 📈 性能指标

### 路由器端
- **内存占用**：3-8 MB（事件监听器 + HTTP API）
- **CPU 占用**：< 1%（空闲时）
- **存储占用**：20-50 KB（事件队列）

### 客户端
- **内存占用**：30-50 MB（Node.js）
- **数据库大小**：随时间增长，30天自动清理
- **网络流量**：< 1 KB/分钟

## 🔍 故障排查

### 路由器端无法启动
```bash
# 检查配置文件
sh -n /etc/netmonitor.conf

# 手动运行测试
/usr/bin/netmonitor-listener &
ps | grep netmonitor
```

### API 无响应
```bash
# 检查端口监听
netstat -tlnp | grep 8321

# 本地测试
curl http://127.0.0.1:8321/net/status
```

### 客户端无法连接路由器
```bash
# 测试路由器 API
curl http://192.168.1.1:8321/net/status

# 检查防火墙规则
# 确保客户端可以访问路由器的 8321 端口
```

## 🗂️ 项目结构

```
openwrt_monitor/
├── netmonitor              # 服务管理脚本
├── netmonitor-listener     # 事件监听器
├── netmonitor-api-inetd    # HTTP API（inetd 模式）
├── netmonitor.conf         # 配置文件
├── install.sh              # 安装脚本
├── UNINSTALL-netmonitor.sh # 卸载脚本
├── client_web_ui/          # Python 客户端
│   ├── app.py
│   ├── models.py
│   └── templates/
└── client_web_ui_NodeJS/   # Node.js 客户端（推荐）
    ├── server.js
    ├── models.js
    ├── package.json
    └── public/
```

## 🤝 技术栈

### 路由器端
- Shell Script (BusyBox ash)
- inetd/xinetd
- OpenWrt/iStoreOS

### 客户端（Node.js）
- Express.js - Web 框架
- Sequelize - ORM
- SQLite - 数据库
- Chart.js - 图表
- Bootstrap 5 - UI 框架

### 客户端（Python）
- Flask - Web 框架
- SQLAlchemy - ORM
- APScheduler - 定时任务

## 📝 更新日志

### v2.0.0 (2025-12-11)
- ✨ 新增 Node.js 版本客户端
- 🐛 修复路由器 HTTP 响应不规范的问题
- 🐛 修复网络事件重复存储和显示问题
- ⚡ 优化 Ping 延迟图表默认显示
- 📝 完善中英文文档

### v1.0.0 (2025-12-08)
- 🎉 初始版本发布
- ✨ 路由器端监控服务
- ✨ Python 客户端 Web UI

## 📄 许可证

MIT License

## 🙏 致谢

本项目使用 [Claude Code](https://claude.com/claude-code) 辅助开发。
