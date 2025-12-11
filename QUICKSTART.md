# OpenWrt 网络监控 - iStoreOS 快速开始指南

## 🔴 问题：inetd 包不存在

在 iStoreOS/OpenWrt 上，`inetd` 包实际上不存在。OpenWrt 使用的是 `xinetd` 或 `busybox` 内置的 inetd。

## ✅ 解决方案

### 方法 1：自动安装 xinetd 或 socat（推荐）

```bash
cd /tmp/openwrt_monitor
./install-inetd.sh
```

这个脚本会：
1. 更新 opkg 包列表
2. 尝试安装 `xinetd`（OpenWrt 标准）
3. 如果 xinetd 失败，自动尝试安装 `socat`（现代替代方案）
4. 自动配置并启动服务

### 方法 2：跳过 HTTP API，仅使用事件监听

```bash
cd /tmp/openwrt_monitor
./install.sh
# 当提示选择时，选择 "3) 跳过 HTTP API 配置"
```

这样安装后：
- ✓ 事件监听器正常工作（记录所有 PPPoE/WAN 事件）
- ✗ 无法通过 HTTP API 查询实时状态
- 事件数据保存在 `/tmp/net_events.json`

### 方法 3：先安装 xinetd/socat，再安装监控

```bash
# 手动安装 xinetd
opkg update
opkg install xinetd

# 或者安装 socat
opkg install socat

# 然后安装监控
cd /tmp/openwrt_monitor
./install.sh
```

## 📊 三种模式对比

| 模式 | 安装命令 | 内存占用 | 特点 |
|------|---------|---------|------|
| **xinetd** | `opkg install xinetd` | ~200KB | OpenWrt 标准，稳定可靠 |
| **socat** | `opkg install socat` | ~150KB | 现代工具，功能强大，推荐 |
| **无HTTP** | 跳过安装 | 0KB | 仅事件监听，无法实时查询 |

## 🚀 推荐的完整步骤

```bash
# 1. 进入目录
cd /tmp/openwrt_monitor

# 2. 安装 HTTP 服务支持（使用 socat）
./install-inetd.sh

# 3. 这将自动尝试：
#    - 先安装 xinetd
#    - 如果失败，自动切换到 socat
#    - 配置服务

# 4. 安装网络监控
./install.sh
#    - 选择检测到的服务模式（xinetd 或 socat）
#    - 按回车继续

# 5. 启动服务
/etc/init.d/netmonitor enable
/etc/init.d/netmonitor start

# 6. 测试
curl http://localhost:8321/net/status
```

## 📝 在你的 iStoreOS 上现在运行：

```bash
cd /tmp/openwrt_monitor
./install-inetd.sh
```

如果 `install-inetd.sh` 成功安装了 xinetd 或 socat，然后运行：

```bash
./install.sh
```

按照提示选择即可！
