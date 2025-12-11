# OpenWrt Network Monitor

<div align="center">

**Lightweight Network Monitoring Solution for OpenWrt**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![OpenWrt](https://img.shields.io/badge/OpenWrt-ARM-blue.svg)](https://openwrt.org/)
[![Node.js](https://img.shields.io/badge/Node.js-18+-green.svg)](https://nodejs.org/)

English | [简体中文](./README.md)

</div>

## 📖 Overview

OpenWrt Network Monitor is a lightweight network monitoring solution designed for ARM-based OpenWrt/iStoreOS routers. The system consists of two components:

- **Router Side**: Pure Shell-based monitoring service for real-time network status and event collection
- **Client Side**: Node.js Web UI providing visualization dashboard and data persistence

## ✨ Key Features

### Router Side
- 🪶 **Ultra Lightweight**: Pure Shell implementation, memory usage < 10MB
- ⚡ **Event-Driven**: Stream reading using logread -f and dmesg -w
- 🎯 **Dual Module Architecture**: Event listener + HTTP API
- 🔧 **ARM Optimized**: Compatible with Cortex-A53/A72/NPU
- 💾 **Memory Queue**: Stored in /tmp to avoid flash wear

### Client Side
- 📊 **Real-time Monitoring**: WAN status, CPU temperature, network latency
- 📈 **Trend Charts**: Ping latency trend visualization
- 📝 **Event Logging**: Automatic network event recording and display
- 🌓 **Dark Mode**: Light/dark theme support
- 💾 **Data Persistence**: SQLite database for historical data storage

## 🚀 Quick Start

### Router Installation

1. **Upload files to router**
\`\`\`bash
scp install.sh netmonitor* root@192.168.1.1:/tmp/
ssh root@192.168.1.1
\`\`\`

2. **Run installation script**
\`\`\`bash
cd /tmp
chmod +x install.sh
./install.sh
\`\`\`

3. **Start service**
\`\`\`bash
/etc/init.d/netmonitor start
/etc/init.d/netmonitor enable
\`\`\`

4. **Verify installation**
\`\`\`bash
curl http://localhost:8321/net/status
\`\`\`

### Client Installation

#### Option 1: Node.js Version (Recommended)

1. **Install dependencies**
\`\`\`bash
cd client_web_ui_NodeJS
npm install
\`\`\`

2. **Configure environment**
\`\`\`bash
cp .env.example .env
# Edit .env file to set router IP and port
\`\`\`

3. **Start service**
\`\`\`bash
npm start
\`\`\`

4. **Access Web UI**
\`\`\`
http://localhost:3000
\`\`\`

## 📊 Monitoring Metrics

### Real-time Data
- **WAN Status**: Online/Offline/Connecting
- **CPU Temperature**: Real-time temperature monitoring
- **Ping Latency**: Multi-target RTT testing
- **Network Errors**: RX/TX error and packet loss statistics
- **Optical Power**: Optical module RX/TX power (if supported)

### Historical Statistics
- **24h Availability**: WAN uptime statistics
- **PPPoE Reconnects**: 24h reconnection count
- **WAN Disconnects**: 24h disconnection count
- **Ping Latency Trends**: 1h/6h/24h trend charts

## 🔧 Configuration

### Router Configuration

Edit \`/etc/netmonitor.conf\`:

\`\`\`bash
# WAN interface configuration
WAN_IFACE="wan"
PPPOE_IFACE="pppoe-wan"

# API configuration
API_PORT="8321"
ALLOWED_IPS=""  # Empty means allow all IPs
TOKEN=""        # Optional authentication token

# Ping targets
PING_TARGETS="223.5.5.5 8.8.8.8"
\`\`\`

### Client Configuration

Edit \`.env\` file:

\`\`\`bash
# Router configuration
ROUTER_IP=192.168.1.1
ROUTER_PORT=8321
ROUTER_TOKEN=

# Data collection interval (seconds)
POLL_INTERVAL=60

# Web service port
PORT=3000
\`\`\`

## 📡 API Reference

### Get Network Status
\`\`\`bash
GET /net/status
\`\`\`

**Response Example:**
\`\`\`json
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
    {"time": "2025-12-10 17:00:48", "type": "pppoe_padt", "message": "Received PADT"}
  ],
  "summary": {
    "pppoe_reconnect_count_24h": 1,
    "wan_down_count_24h": 0
  }
}
\`\`\`

## 🛠️ Service Management

### Router Side
\`\`\`bash
# Start service
/etc/init.d/netmonitor start

# Stop service
/etc/init.d/netmonitor stop

# Restart service
/etc/init.d/netmonitor restart

# Check status
/etc/init.d/netmonitor status

# Enable auto-start
/etc/init.d/netmonitor enable
\`\`\`

### Client Side
\`\`\`bash
# Node.js version
npm start          # Production
npm run dev        # Development (auto-restart)
\`\`\`

## 📈 Performance Metrics

### Router Side
- **Memory Usage**: 3-8 MB (event listener + HTTP API)
- **CPU Usage**: < 1% (idle)
- **Storage Usage**: 20-50 KB (event queue)

### Client Side
- **Memory Usage**: 30-50 MB (Node.js)
- **Database Size**: Grows over time, auto-cleanup after 30 days
- **Network Traffic**: < 1 KB/min

## 🗂️ Project Structure

\`\`\`
openwrt_monitor/
├── netmonitor              # Service management script
├── netmonitor-listener     # Event listener
├── netmonitor-api-inetd    # HTTP API (inetd mode)
├── netmonitor.conf         # Configuration file
├── install.sh              # Installation script
├── UNINSTALL-netmonitor.sh # Uninstallation script
├── client_web_ui/          # Python client
│   ├── app.py
│   ├── models.py
│   └── templates/
└── client_web_ui_NodeJS/   # Node.js client (recommended)
    ├── server.js
    ├── models.js
    ├── package.json
    └── public/
\`\`\`

## 🤝 Tech Stack

### Router Side
- Shell Script (BusyBox ash)
- inetd/xinetd
- OpenWrt/iStoreOS

### Client (Node.js)
- Express.js - Web framework
- Sequelize - ORM
- SQLite - Database
- Chart.js - Charts
- Bootstrap 5 - UI framework

## 📝 Changelog

### v2.0.0 (2025-12-11)
- ✨ Added Node.js client version
- 🐛 Fixed non-standard HTTP response handling from router
- 🐛 Fixed event duplication and display issues
- ⚡ Optimized ping chart default display
- 📝 Improved Chinese and English documentation

### v1.0.0 (2025-12-08)
- 🎉 Initial release
- ✨ Router-side monitoring service
- ✨ Python client Web UI

## 📄 License

MIT License

## 🙏 Acknowledgments

This project was developed with assistance from [Claude Code](https://claude.com/claude-code).
