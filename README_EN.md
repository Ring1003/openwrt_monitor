# OpenWrt Network Monitoring Service - Complete Documentation

## Project Overview

This is a lightweight network monitoring solution designed for ARM-based OpenWrt/iStoreOS soft routers, consisting of two parts:

1. **OpenWrt-side monitoring service** - Pure Shell implementation, resident memory < 10MB
2. **Client Web UI** - Flask + SQLite + Docker, providing visual monitoring dashboard

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       System Architecture                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  OpenWrt Router (ARM)                     Monitoring Client      │
│  ┌─────────────────────────┐              ┌──────────────────┐  │
│  │  netmonitor-listener    │              │  Flask Web App   │  │
│  │  (Event Listener)       │◄────────────┤  SQLite Database │  │
│  └──────────┬──────────────┘              └────────┬─────────┘  │
│             │                                      │            │
│  ┌──────────▼──────────────┐              ┌────────▼─────────┐  │
│  │  netmonitor-api         │─────────────►│  Web Dashboard   │  │
│  │  (HTTP API Service)     │      API     │  + Charts        │  │
│  └─────────────────────────┘              └──────────────────┘  │
│          Port: 8321                          Port: 5000          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

Data Flow:
1. OpenWrt monitors network events via logread/dmesg/ubus
2. Events stored in memory queue (/tmp/net_events.json)
3. Client periodically requests API for real-time data
4. Data saved to SQLite database
5. Web UI displays monitoring data and charts
```

---

## OpenWrt Components

### 1. Event Listener (netmonitor-listener)

**File**: `netmonitor-listener` (7.4 KB)

**Features**:
- Monitor PPPoE connect/disconnect events
- Monitor WAN interface status changes
- Monitor Kernel network events
- Streaming read (logread -f, dmesg -w), no polling, CPU usage < 1%

**Event Types**:
- `pppoe_up` - PPPoE connection established
- `pppoe_down` - PPPoE connection lost
- `pppoe_lcp_term` - LCP terminated
- `pppoe_padt` - PADT received
- `pppoe_auth_fail` - Authentication failed
- `wan_up` - WAN interface UP
- `wan_down` - WAN interface DOWN
- `kernel_carrier_lost` - Carrier lost
- `kernel_link_up/down` - Link status change

**Resource Usage**:
- Memory: 3-5 MB
- CPU: < 1%
- Storage: Only /tmp (tmpfs)

### 2. HTTP API Service (netmonitor-api)

**File**: `netmonitor-api` (11 KB)

**Features**:
- Listen on port 8321
- Provide GET /net/status interface
- Collect real-time network data
- Return JSON format data

**Collected Data**:
- Ping RTT (223.5.5.5, 8.8.8.8)
- WAN interface error statistics
- Optical power (GPON)
- CPU temperature
- WAN/PPPoE status
- Event queue

**Resource Usage**:
- Memory: 2-3 MB
- Response time: < 1000ms

### 3. Init Script (netmonitor)

**File**: `netmonitor` (3.2 KB)

**Features**:
- procd service management
- Supports start/stop/restart/status
- Boot auto-start configuration
- Process monitoring and auto-restart

**Commands**:
```bash
/etc/init.d/netmonitor start    # Start service
/etc/init.d/netmonitor stop     # Stop service
/etc/init.d/netmonitor restart  # Restart service
/etc/init.d/netmonitor status   # Check status
/etc/init.d/netmonitor enable   # Enable auto-start
/etc/init.d/netmonitor disable  # Disable auto-start
```

### 4. Configuration File (netmonitor.conf)

**File**: `netmonitor.conf` (1.9 KB)

**Configuration Options**:
```bash
ENABLED=1                          # Enable/Disable
WAN_IFACE="wan"                    # WAN interface name
PPPOE_IFACE="pppoe-wan"           # PPPoE interface name
API_PORT="8321"                    # API port
ALLOWED_IPS=""                     # IP whitelist (space-separated)
TOKEN=""                          # Access token
PING_TARGETS="223.5.5.5 8.8.8.8"   # Ping targets
MAX_EVENTS=200                     # Max events in queue
```

---

## Client Web UI Components

### 1. Flask Main Application (app.py)

**File**: `app.py` (15 KB)

**Features**:
- RESTful API interfaces
- Data fetching and storage
- Scheduled task management (APScheduler)
- Database ORM operations

**API Endpoints**:
```
GET /                    - Home page
GET /health              - Health check
GET /api/status          - Real-time status
GET /api/history         - Historical data
GET /api/ping_history    - Ping history
GET /api/events          - Event list
GET /api/stats/summary   - Statistics summary
GET /api/fetch_now       - Fetch immediately
```

**Scheduled Tasks**:
- Data fetch: Every 60 seconds
- Hourly stats: Every hour
- Data cleanup: 3 AM daily

**Resource Usage**:
- Memory: 100-200 MB
- CPU: < 1%
- Storage: 10-50 MB/month

### 2. Data Models (models.py)

**File**: `models.py` (4.6 KB)

**Database Tables**:

**network_status table** - Network status
- id, timestamp, wan_state
- rx_errors, tx_errors, rx_dropped, tx_dropped
- optical_rx, optical_tx, cpu_temp
- pppoe_reconnect_count, wan_down_count

**ping_results table** - Ping results
- id, timestamp, target, rtt, loss

**network_events table** - Network events
- id, timestamp, event_time, event_type, message

**hourly_stats table** - Hourly statistics
- id, hour, avg_ping_rtt, max_ping_rtt, min_ping_rtt
- packet_loss_count, pppoe_reconnect_count, wan_down_count
- avg_cpu_temp, max_cpu_temp

### 3. Web Interface (templates/index.html)

**File**: `templates/index.html` (14.2 KB)

**Interface Modules**:
1. **Status Overview Cards**
   - WAN status (with indicator light)
   - CPU temperature
   - Average Ping latency
   - Network availability (%)

2. **Ping Latency Trend Chart**
   - Chart.js interactive chart
   - Time range switch (1h/6h/24h)
   - Multi-target comparison

3. **Optical Power Monitor**
   - RX received power (dBm)
   - TX transmitted power (dBm)

4. **Interface Error Statistics**
   - RX/TX errors count
   - RX/TX dropped count

5. **Real-time Event List**
   - Latest 20 events
   - Auto-refresh

6. **Ping Details Panel**
   - Real-time latency per target
   - Packet loss rate

**Tech Stack**:
- Bootstrap 5.3 (responsive layout)
- Chart.js 4.4.0 (charts)
- Bootstrap Icons (icons)

### 4. Docker Configuration

**Dockerfile** (533 B)
- Base image: python:3.11-slim
- System dependencies: sqlite3, curl
- Working directory: /app
- Exposed port: 5000
- Health check

**docker-compose.yml** (1.0 KB)
- Service: netmonitor-web
- Port mapping: 5000:5000
- Volume mounts: ./data, ./logs
- Environment variables
- Optional Nginx service (profile)

**nginx.conf** (2.2 KB)
- HTTP to HTTPS redirect
- SSL configuration
- Security headers
- Gzip compression
- WebSocket support

---

## Deployment Requirements

### OpenWrt Router Requirements

**Hardware**: ARM architecture (Cortex-A53/A72/NPU)
**System**: OpenWrt 21.02+ or iStoreOS
**Dependencies**: BusyBox + ash + ubus + netifd
**Tools**: grep, sed, awk, ping, ifconfig, logread, dmesg
**Port**: 8321 (configurable)

### Client Requirements

**Docker Environment** (Recommended):
- Docker 20.10+
- Docker Compose 2.0+

**Or Python Environment**:
- Python 3.11+
- SQLite 3

---

## Deployment Steps

### Step 1: Deploy on OpenWrt

**Method A - Using Install Script**:
```bash
# Upload files to router
scp netmonitor* root@192.168.1.1:/tmp/

# Login to router
ssh root@192.168.1.1

# Run install script
cd /tmp
sh install.sh

# Configure
vi /etc/netmonitor.conf

# Start service
/etc/init.d/netmonitor enable
/etc/init.d/netmonitor start

# Verify
/etc/init.d/netmonitor status
ps | grep netmonitor
tail -f /tmp/net_events.json
```

**Method B - Manual Installation**:
```bash
cd /tmp
cp netmonitor-listener /usr/bin/
cp netmonitor-api /usr/bin/
cp netmonitor /etc/init.d/
cp netmonitor.conf /etc/

chmod +x /usr/bin/netmonitor-listener /usr/bin/netmonitor-api
chmod +x /etc/init.d/netmonitor

echo '[]' > /tmp/net_events.json
chmod 644 /tmp/net_events.json

/etc/init.d/netmonitor enable
/etc/init.d/netmonitor start
```

### Step 2: Deploy Client

**Method A - Docker Deployment (Recommended)**:
```bash
cd client_web_ui

# Configure environment
cp .env.example .env
vi .env  # Edit ROUTER_IP, ROUTER_PORT, ROUTER_TOKEN

# One-click deployment
./deploy.sh

# Or manual
mkdir -p data logs
docker-compose build
docker-compose up -d

# Verify
docker-compose ps
curl http://localhost:5000/health
```

**Method B - Direct Python Execution**:
```bash
cd client_web_ui

# Install dependencies
pip install -r requirements.txt

# Set environment variables
export ROUTER_IP=192.168.1.1
export ROUTER_PORT=8321
export ROUTER_TOKEN=your_token
export SQLITE_DB=./data/netmonitor.db

# Run
python app.py
```

### Step 3: Verify Complete System

**OpenWrt Side**:
```bash
# Check processes
ps | grep netmonitor | grep -v grep
# Should show 2 processes: netmonitor-listener, netmonitor-api

# Check port
netstat -tlnp | grep 8321
# Should show listening on 8321

# Test API
curl http://localhost:8321/net/status
# Should return JSON data
```

**Client Side**:
```bash
# Check container
docker-compose ps
# Status should be Up

# Test API
curl http://localhost:5000/api/status
# Should return router data

# Access Web UI
open http://localhost:5000
```

---

## Configuration Guide

### OpenWrt Configuration (/etc/netmonitor.conf)

```bash
# Enable/Disable
ENABLED=1

# Interface Configuration
WAN_IFACE="wan"                    # WAN interface, check with ifconfig
PPPOE_IFACE="pppoe-wan"           # PPPoE interface, leave empty if using DHCP

# API Configuration
API_PORT="8321"                    # API port, avoid conflicts

# Security Settings
ALLOWED_IPS="192.168.1.100"       # Allowed IPs, space-separated
TOKEN="your-secret-token"          # Access token, recommended to set

# Ping Targets
PING_TARGETS="223.5.5.5 8.8.8.8"   # Domestic + International DNS

# Event Queue
MAX_EVENTS=200                     # Maximum events in queue
```

**Get WAN Interface Name**:
```bash
ip link show | grep "UP" | awk '{print $2}' | sed 's/:$//'
# or
ifconfig | grep "Link encap" | awk '{print $1}'
```

**Get PPPoE Interface**:
```bash
ifconfig | grep "pppoe" | awk '{print $1}'
```

### Client Configuration (.env)

```bash
# Router Configuration
ROUTER_IP=192.168.1.1              # OpenWrt router IP
ROUTER_PORT=8321                  # API port
ROUTER_TOKEN=your-secret-token   # Must match router config

# Data Collection
POLL_INTERVAL=60                   # Seconds, recommend ≥30

# Flask Configuration
FLASK_HOST=0.0.0.0                # Listen address
FLASK_PORT=5000                   # Web port
FLASK_DEBUG=false                 # Set false for production

# Database Path
SQLITE_DB=./data/netmonitor.db
```

---

## API Documentation

### OpenWrt API (Port 8321)

**GET /net/status**

**Request Example**:
```bash
curl http://192.168.1.1:8321/net/status
# Or with Token
curl -H "Authorization: Bearer TOKEN" http://192.168.1.1:8321/net/status
```

**Response Example**:
```json
{
  "timestamp": "2025-02-12 10:34:00",
  "realtime": {
    "ping": {
      "223.5.5.5": {"rtt": 6.2, "loss": 0},
      "8.8.8.8": {"rtt": 21.4, "loss": 0}
    },
    "wan_errors": {
      "rx_errors": 0,
      "tx_errors": 1,
      "rx_dropped": 0,
      "tx_dropped": 0
    },
    "optical_power": {
      "rx": -8.6,
      "tx": 1.3
    },
    "cpu_temp": 52.8,
    "wan_state": "up"
  },
  "events": [
    {"time": "2025-02-12 10:30:00", "type": "pppoe_up", "message": "PPP connection established"},
    {"time": "2025-02-12 10:25:12", "type": "wan_down", "message": "WAN interface DOWN"}
  ],
  "summary": {
    "pppoe_reconnect_count_24h": 3,
    "wan_down_count_24h": 1
  }
}
```

### Client API (Port 5000)

**GET /api/status**

Fetch real-time data from router

**GET /api/history?hours=24&limit=100**

Get historical data

**GET /api/ping_history?hours=6&target=8.8.8.8**

Get Ping history data

**GET /api/events?limit=50&type=pppoe_up**

Get event list

**GET /api/stats/summary?hours=24**

Get statistics summary

**GET /api/fetch_now**

Fetch data immediately from router

**GET /health**

Health check

---

## Web Interface Usage

### Access Methods

```bash
# Local access
open http://localhost:5000

# Remote access (configure firewall)
http://your-server-ip:5000
```

### Interface Features

**1. Status Overview Cards**
- WAN Status: Color indicator light
- CPU Temperature: Celsius (°C)
- Average Latency: Milliseconds (ms)
- Availability: Percentage (%)

**2. Ping Latency Trend Chart**
- Mouse hover for detailed data
- Click legend to show/hide
- Button to switch time range (1h/6h/24h)

**3. Optical Power Monitor**
- Received Power (RX): -8 ~ -28 dBm (normal range)
- Transmitted Power (TX): 1 ~ 5 dBm (normal range)

**4. Interface Error Statistics**
- RX errors/TX errors: Hardware error count
- RX dropped/TX dropped: Buffer overflow count

**5. Real-time Event List**
- Auto refresh every minute
- Shows latest 20 events
- Color-coded event types

**6. Ping Details Panel**
- Real-time latency per target
- Packet loss rate

---

## Troubleshooting

### OpenWrt Side Issues

**Issue 1: Service Won't Start**
```bash
# Check script permissions
ls -l /usr/bin/netmonitor-* /etc/init.d/netmonitor
# Should have x permission

# Check config file syntax
sh -n /etc/netmonitor.conf

# Manual test run
/usr/bin/netmonitor-listener &
/usr/bin/netmonitor-api &
ps | grep netmonitor

# Check system logs
logread | grep netmonitor
```

**Issue 2: API Not Responding**
```bash
# Check port listening
netstat -tlnp | grep 8321
# Should show listening status

# Test from localhost
curl http://127.0.0.1:8321/net/status

# Check if process is running
ps | grep netmonitor-api

# Check firewall
iptables -L INPUT -n | grep 8321
```

**Issue 3: Events Not Recording**
```bash
# Check logread permission
logread | tail -5

# Check queue file
cat /tmp/net_events.json
# Should be JSON format

# Reset queue
echo '[]' > /tmp/net_events.json
chmod 644 /tmp/net_events.json

# Manual trigger test event
logger -t pppd "test event"
tail -f /tmp/net_events.json
```

**Issue 4: High Resource Usage**
```bash
# Check memory usage
ps | grep netmonitor | awk '{print $4}' | awk '{sum+=$1} END {print "Total: " sum " KB"}'
# Should be <10MB

# Check queue size
wc -l /tmp/net_events.json
# Should be <=200

# Reduce queue size
sed -i 's/MAX_EVENTS=200/MAX_EVENTS=100/' /etc/netmonitor.conf
/etc/init.d/netmonitor restart
```

### Client Issues

**Issue 1: Container Won't Start**
```bash
# Check Docker environment
docker --version
docker-compose --version

# View error logs
docker-compose logs netmonitor-web

# Check if port is in use
netstat -tlnp | grep 5000

# Check config file
sh -n docker-compose.yml
```

**Issue 2: Can't Connect to Router**
```bash
# Test inside container
 docker exec -it netmonitor-web bash
curl http://192.168.1.1:8321/net/status
# Should return JSON data

# Check network connectivity
ping 192.168.1.1

# Check environment variables
docker exec -it netmonitor-web env | grep ROUTER
```

**Issue 3: Database Error**
```bash
# Enter container
docker exec -it netmonitor-web bash

# Check database file
ls -lh /app/data/netmonitor.db

# Connect to database
sqlite3 /app/data/netmonitor.db
sqlite> .tables
sqlite> SELECT COUNT(*) FROM network_status;

# Reset database (will lose data)
rm /app/data/netmonitor.db
# Restart container to auto-create
```

**Issue 4: Web Interface Not Accessible**
```bash
# Check container ports
docker-compose ps
# Should show 5000->5000

# Check container logs
docker-compose logs -f netmonitor-web

# Test API
curl http://localhost:5000/health
# Should return {"status":"healthy"}

# Test from inside container
docker exec -it netmonitor-web curl http://localhost:5000/
```

---

## Performance Optimization

### OpenWrt Side

1. **Reduce Log Level**
```bash
# In /etc/netmonitor.conf
LOG_LEVEL=1  # Only log errors
```

2. **Adjust Poll Interval**
```bash
# In netmonitor-listener
# Modify sleep time
poll_wan_status() {
    while true; do
 sleep 60  # Change from 30 to 60 seconds
        ...
    done
}
```

3. **Disable Unnecessary Monitoring**
```bash
# Comment out unneeded monitoring functions
# monitor_pppoe &    # If not using PPPoE
# dmesg_monitor &    # If not tracking Kernel events
```

### Client

1. **Adjust Fetch Interval**
```bash
# In .env
POLL_INTERVAL=120  # Change from 60 to 120 seconds
```

2. **Increase Data Cleanup Frequency**
```bash
# In app.py
def cleanup_old_data():
    # Change from 30 to 7 days
    cutoff = datetime.utcnow() - timedelta(days=7)
```

3. **Use Nginx Cache**
```bash
# In nginx.conf
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=api:10m;
location /api/ {
    proxy_cache api;
    proxy_cache_valid 200 30s;
    proxy_pass http://netmonitor;
}
```

---

## Backup and Recovery

### OpenWrt Side Backup

```bash
# Backup configuration file
cp /etc/netmonitor.conf /backup/

# Backup scripts
cp /usr/bin/netmonitor-listener /backup/
cp /usr/bin/netmonitor-api /backup/
cp /etc/init.d/netmonitor /backup/

# Backup event queue (optional)
cp /tmp/net_events.json /backup/
```

### Recovery

```bash
cp /backup/netmonitor-listener /usr/bin/
cp /backup/netmonitor-api /usr/bin/
cp /backup/netmonitor /etc/init.d/
cp /backup/netmonitor.conf /etc/

chmod +x /usr/bin/netmonitor-* /etc/init.d/netmonitor
/etc/init.d/netmonitor start
```

### Client Backup

```bash
# Backup database
docker exec netmonitor-web sqlite3 /app/data/netmonitor.db ".backup /app/data/backup.db"
cp data/backup.db /backup/

# Backup config
cp .env docker-compose.yml /backup/
```

### Recovery

```bash
cp /backup/netmonitor.db data/
cp /backup/.env .
docker-compose up -d
```

---

## Uninstallation

### Uninstall OpenWrt Side

```bash
# Stop service
/etc/init.d/netmonitor stop
/etc/init.d/netmonitor disable

# Delete files
rm -f /usr/bin/netmonitor-listener
rm -f /usr/bin/netmonitor-api
rm -f /etc/init.d/netmonitor
rm -f /etc/netmonitor.conf
rm -f /tmp/net_events.json

# Clean logs
logread | grep netmonitor > /dev/null
```

### Uninstall Client

```bash
# Stop container
docker-compose down

# Delete image
docker rmi netmonitor-web

# Delete data (if no backup needed)
rm -rf data logs

# Delete code
rm -rf client_web_ui
```

---

## Monitoring Metrics Reference

### Normal Ranges

| Metric | Normal Range | Description |
|--------|--------------|-------------|
| CPU Temp | 30-70°C | Typical for ARM routers |
| Ping Latency (Domestic) | 5-50ms | To 223.5.5.5 |
| Ping Latency (International) | 50-300ms | To 8.8.8.8 |
| Packet Loss | 0-1% | Should be <1% |
| Optical Power RX | -8 ~ -28 dBm | GPON standard |
| Optical Power TX | 1 ~ 5 dBm | GPON standard |
| RX/TX Errors | 0 | Should be 0 |

### Warning Thresholds

| Metric | Warning | Critical |
|--------|---------|----------|
| CPU Temp | > 75°C | > 85°C |
| Latency | > 100ms | > 500ms |
| Packet Loss | > 1% | > 5% |
| Optical Power RX | -28 ~ -30 dBm | < -30 dBm |
| RX Errors | > 0 | > 10 |

---

## Development Notes

### Code Structure

```
/Volumes/Mr.Meng/Meng-Code/openwrt_monitor/
├── OpenWrt Side
│   ├── netmonitor-listener    # Event listener
│   ├── netmonitor-api         # HTTP API
│   ├── netmonitor             # Init script
│   ├── netmonitor.conf        # Config file
│   ├── install.sh             # Install script
│   ├── README.md              # Detailed documentation
│   └── QUICKSTART.md          # Quick start
│
└── Client Web UI
    ├── app.py                 # Flask application
    ├── models.py              # Data models
    ├── requirements.txt       # Python dependencies
    ├── Dockerfile             # Docker config
    ├── docker-compose.yml     # Docker Compose
    ├── nginx.conf             # Nginx config
    ├── deploy.sh              # Deploy script
    ├── .env                   # Environment variables
    ├── .env.example           # Env template
    ├── README.md              # Detailed documentation
    ├── 文件清单.txt           # File list (ln)
    └── templates/
        └── index.html         # Web interface
```

### Modification Suggestions

**OpenWrt Side**:
- All scripts are pure Shell, can be modified directly
- Ensure JSON format remains correct
- Test with `sh -n script.sh` for syntax check

**Client**:
- Uses Flask framework, follows MVC pattern
- Database model changes require migration
- Frontend uses Bootstrap and Chart.js

---

## Frequently Asked Questions

### Q1: Which OpenWrt versions are supported?
A: OpenWrt 21.02+, iStoreOS, requires ash/bash environment

### Q2: Does it support other architectures?
A: Primarily optimized for ARM, can run on MIPS/x86 (adjust temperature reading)

### Q3: How long is data stored?
A: OpenWrt: 200 events cycle; Client: 30 days auto-cleanup

### Q4: Can it monitor multiple routers?
A: Yes, deploy multiple client instances with different ROUTER_IP

### Q5: Does it support public internet access?
A: Yes, but recommend VPN or SSH tunnel, configure ALLOWED_IPS and TOKEN

### Q6: Can database be changed to MySQL/PostgreSQL?
A: Yes, modify SQLALCHEMY_DATABASE_URI in app.py

### Q7: How to upgrade?
A: OpenWrt: Replace script files; Client: Rebuild Docker image

---

## License

MIT License - Free to use, commercial use allowed

---

## Contact

- Bug Reports: GitHub Issues
- Feature Requests: GitHub Discussions
- Code Contributions: GitHub Pull Requests

---

## Version History

### v1.0.0 (2025-12-08)
- Initial version
- OpenWrt side pure Shell implementation
- Client Flask + SQLite
- Docker containerization
- Responsive Web UI
- Complete API interfaces

---

**Document Generated**: 2025-12-08
**Document Version**: v1.0.0
