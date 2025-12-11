# OpenWrt NetMonitor Web UI

基于 Flask 的 Web 监控面板，用于展示 OpenWrt 软路由的网络监控数据。

## 功能特性

- 📊 实时网络状态监控
- 📈 历史数据图表展示
- 💾 SQLite 数据库存储
- 🐳 Docker 容器化部署
- 📱 响应式设计，支持移动端
- 🔔 事件日志记录
- 📊 自动生成每小时统计数据

## 系统架构

```
+-------------------+       +-------------------+       +-------------------+
| OpenWrt Router    |       | NetMonitor Web UI |       | Web Browser       |
| (netmonitor-api)  | <---> | (Flask + SQLite)  | <---> | (Dashboard)       |
| Port: 8321        |  API  | Port: 5000        |  HTTP |                   |
+-------------------+       +-------------------+       +-------------------+
```

## 快速部署

### 前提条件

- Docker 和 Docker Compose
- 运行中的 OpenWrt netmonitor-api 服务
- Python 3.11+ (用于开发)

### 方式1：Docker 部署（推荐）

1. 克隆仓库并进入目录：
```bash
cd client_web_ui
```

2. 配置环境变量：
```bash
cp .env.example .env
# 编辑 .env 文件，配置路由器IP和Token
```

3. 启动服务：
```bash
docker-compose up -d
```

4. 访问 Web UI：
打开浏览器访问: http://localhost:5000

### 方式2：Docker 手动构建

```bash
# 构建镜像
docker build -t netmonitor-web .

# 运行容器
docker run -d \
  --name netmonitor-web \
  -p 5000:5000 \
  -e ROUTER_IP=192.168.1.1 \
  -e ROUTER_PORT=8321 \
  -e ROUTER_TOKEN=your_token \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/logs:/app/logs \
  netmonitor-web
```

### 方式3：Python 直接运行

1. 安装依赖：
```bash
pip install -r requirements.txt
```

2. 配置环境变量：
```bash
export ROUTER_IP=192.168.1.1
export ROUTER_PORT=8321
export ROUTER_TOKEN=your_token
export SQLITE_DB=./data/netmonitor.db
```

3. 运行应用：
```bash
python app.py
```

## 配置文件

### 环境变量 (.env)

```bash
# OpenWrt Router Configuration
ROUTER_IP=192.168.1.1          # 路由器IP地址
ROUTER_PORT=8321              # netmonitor-api端口
ROUTER_TOKEN=                 # API访问令牌（可选）

# Data Collection
POLL_INTERVAL=60              # 数据抓取间隔（秒）

# Database
SQLITE_DB=./data/netmonitor.db  # SQLite数据库路径

# Flask Configuration
FLASK_HOST=0.0.0.0            # Flask监听地址
FLASK_PORT=5000               # Flask端口
FLASK_DEBUG=false             # 调试模式
```

### Docker Compose 配置

```yaml
version: '3.8'
services:
  netmonitor-web:
    image: netmonitor-web
    container_name: netmonitor-web
    restart: unless-stopped
    ports:
      - "5000:5000"           # 映射到主机端口
    environment:
      - ROUTER_IP=192.168.1.1
      - ROUTER_PORT=8321
      - ROUTER_TOKEN=${ROUTER_TOKEN}
      - POLL_INTERVAL=60
    volumes:
      - ./data:/app/data       # 数据持久化
      - ./logs:/app/logs       # 日志持久化
```

## API 接口

### REST API

#### 获取实时状态
```http
GET /api/status
```

返回：
```json
{
  "timestamp": "2025-01-01 10:00:00",
  "realtime": { ... },
  "events": [ ... ],
  "summary": { ... }
}
```

#### 获取历史数据
```http
GET /api/history?hours=24&limit=100
```

#### 获取Ping历史
```http
GET /api/ping_history?hours=6&target=8.8.8.8
```

#### 获取事件列表
```http
GET /api/events?limit=50&type=pppoe_up
```

#### 获取统计摘要
```http
GET /api/stats/summary?hours=24
```

#### 立即抓取数据
```http
GET /api/fetch_now
```

## 数据结构

### SQLite 数据库

#### network_status 表
存储网络状态数据

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键 |
| timestamp | DATETIME | 时间戳 |
| wan_state | VARCHAR | WAN状态 |
| rx_errors | INTEGER | 接收错误数 |
| tx_errors | INTEGER | 发送错误数 |
| rx_dropped | INTEGER | 接收丢包数 |
| tx_dropped | INTEGER | 发送丢包数 |
| optical_rx | FLOAT | 接收光功率 |
| optical_tx | FLOAT | 发送光功率 |
| cpu_temp | FLOAT | CPU温度 |
| pppoe_reconnect_count | INTEGER | PPPoE重连次数 |
| wan_down_count | INTEGER | WAN断线次数 |

#### ping_results 表
存储Ping测试结果

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键 |
| timestamp | DATETIME | 时间戳 |
| target | VARCHAR | Ping目标 |
| rtt | FLOAT | 往返时间(ms) |
| loss | INTEGER | 丢包率(%) |

#### network_events 表
存储网络事件

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键 |
| timestamp | DATETIME | 记录时间 |
| event_time | DATETIME | 事件时间 |
| event_type | VARCHAR | 事件类型 |
| message | TEXT | 事件消息 |

## Web 界面

### 主页面

主页面展示以下内容：

1. **状态概览**
   - WAN状态（UP/DOWN/Connecting）
   - CPU温度
   - 平均Ping延迟
   - 网络可用性

2. **Ping延迟趋势图**
   - 时间范围：1小时 / 6小时 / 24小时
   - 多目标对比
   - 交互式图表

3. **光功率**
   - 接收功率 (RX)
   - 发送功率 (TX)

4. **接口错误统计**
   - RX错误 / TX错误
   - RX丢弃 / TX丢弃

5. **实时事件**
   - 最近20条网络事件
   - 事件类型：PPPoE、WAN、Kernel
   - 自动刷新

6. **Ping详情**
   - 各目标延迟和丢包率
   - 实时更新

### 响应式设计

- 支持桌面端和移动端
- 自适应布局
- 触摸友好的界面

## 定时任务

应用使用 APScheduler 管理定时任务：

1. **数据抓取**
   - 间隔：60秒（可配置）
   - 功能：从路由器抓取数据并保存到数据库

2. **每小时统计**
   - 时间：每小时整点
   - 功能：生成该小时的统计数据

3. **数据清理**
   - 时间：每天凌晨3点
   - 功能：删除30天前的旧数据

## 性能优化

1. **数据分页**：历史数据分页加载
2. **索引优化**：关键字段添加数据库索引
3. **缓存机制**：每小时统计数据预计算
4. **数据保留**：自动清理旧数据

## 日志管理

日志文件位置：`/app/logs/`

- `app.log`: 应用日志
- 日志轮转：保留最近10MB，最多3个文件

## 故障排查

### 检查容器状态

```bash
docker-compose ps
docker logs netmonitor-web
```

### 手动抓取数据

```bash
curl http://localhost:5000/api/fetch_now
```

### 查看数据库

```bash
# 进入容器
docker exec -it netmonitor-web sh

# 查询数据
sqlite3 /app/data/netmonitor.db
sqlite> SELECT * FROM network_status ORDER BY timestamp DESC LIMIT 10;
```

### 检查API连接

```bash
# 在容器内测试
curl http://192.168.1.1:8321/net/status
```

## 扩展功能

### 添加Nginx反向代理

使用 Docker Compose profiles 启动Nginx：

```bash
docker-compose --profile with-nginx up -d
```

配置SSL证书：
```bash
# 将SSL证书放入ssl目录
ssl/
  ├── cert.pem
  └── key.pem
```

### 集成Prometheus

可以添加 `/metrics` 接口导出Prometheus格式数据。

### 邮件告警

配置邮件通知，当WAN断开或延迟过高时发送告警。

## 许可证

MIT License
