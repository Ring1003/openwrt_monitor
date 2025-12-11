# OpenWrt ARM 网络监控服务

## 功能特性

- 轻量级：纯 Shell 实现，内存占用 < 10MB
- 事件驱动：使用 logread -f 和 dmesg -w 流式读取
- 双模块：事件监听器 + HTTP API
- ARM 优化：兼容 Cortex-A53/A72/NPU
- 内存队列：存储在 /tmp，避免闪存磨损

## 系统要求

- ARM 架构 OpenWrt/iStoreOS
- BusyBox + ash 环境
- 基础工具：grep, sed, awk, ping, ifconfig, ubus

## 快速安装

1. 上传文件到路由器
   ```bash
   scp netmonitor* root@192.168.1.1:/tmp/
   ssh root@192.168.1.1
   ```

2. 安装
   ```bash
   cd /tmp
   cp netmonitor-listener /usr/bin/
   cp netmonitor-api /usr/bin/
   cp netmonitor /etc/init.d/
   cp netmonitor.conf /etc/
   ```

3. 设置权限
   ```bash
   chmod +x /usr/bin/netmonitor-listener /usr/bin/netmonitor-api
   chmod +x /etc/init.d/netmonitor
   echo '[]' > /tmp/net_events.json
   ```

4. 启动服务
   ```bash
   /etc/init.d/netmonitor enable
   /etc/init.d/netmonitor start
   ```

## API使用

```bash
# 查询网络状态
curl http://localhost:8321/net/status

# 带Token认证（如果配置）
curl -H "Authorization: Bearer YOUR_TOKEN" \
     http://localhost:8321/net/status
```

## 响应示例

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
    {"time": "...", "type": "pppoe_reconnect"},
    {"time": "...", "type": "wan_down"}
  ],
  "summary": {
    "pppoe_reconnect_count_24h": 3,
    "wan_down_count_24h": 1
  }
}
```

## 配置参数

编辑 `/etc/netmonitor.conf`：

- `WAN_IFACE`: WAN接口名称（默认：wan）
- `PPPOE_IFACE`: PPPoE接口（默认：pppoe-wan）
- `API_PORT`: API端口（默认：8321）
- `ALLOWED_IPS`: IP白名单（空格分隔）
- `TOKEN`: 认证令牌
- `PING_TARGETS`: Ping目标（默认：223.5.5.5 8.8.8.8）

## 服务管理

```bash
# 启动
/etc/init.d/netmonitor start

# 停止
/etc/init.d/netmonitor stop

# 重启
/etc/init.d/netmonitor restart

# 查看状态
/etc/init.d/netmonitor status

# 开机自启
/etc/init.d/netmonitor enable

# 禁用自启
/etc/init.d/netmonitor disable
```

## 日志查看

```bash
# 查看实时事件
tail -f /tmp/net_events.json

# 查看系统日志
logread | grep -E "pppd|pppoe|wan" | tail -20

# 查看kernel事件
dmesg | grep -i "link\|carrier" | tail -10
```

## 性能监控

```bash
# 查看内存占用
ps | grep netmonitor | awk '{sum+=$4} END {print "Memory: " sum " KB"}'

# 查看进程
ps | grep netmonitor

# 查看端口监听
netstat -tlnp | grep 8321
```

典型资源占用：
- 事件监听器：3-5 MB
- HTTP API：2-3 MB
- 队列文件：20-50 KB

## 故障排查

### 服务无法启动

```bash
# 检查配置文件
sh -n /etc/netmonitor.conf

# 手动运行测试
/usr/bin/netmonitor-listener &
ps | grep netmonitor-listener
```

### API无响应

```bash
# 检查端口
netstat -tlnp | grep 8321

# 从本机测试
curl http://127.0.0.1:8321/net/status
```

### 事件不记录

```bash
# 检查logread权限
logread | tail -5

# 重置队列
echo '[]' > /tmp/net_events.json
chmod 644 /tmp/net_events.json
```

## 卸载

```bash
# 停止并禁用
/etc/init.d/netmonitor stop
/etc/init.d/netmonitor disable

# 删除文件
rm -f /usr/bin/netmonitor-listener
rm -f /usr/bin/netmonitor-api
rm -f /etc/init.d/netmonitor
rm -f /etc/netmonitor.conf
rm -f /tmp/net_events.json
```

## 许可证

MIT License
