#!/bin/sh
# OpenWrt NetMonitor - 一键卸载脚本
# 版本: v1.0.1

set -e

echo "================================"
echo "OpenWrt 网络监控服务 - 卸载"
echo "================================"
echo ""

# 停止服务
echo -n "正在停止服务... "
/etc/init.d/netmonitor stop 2>/dev/null || true
echo "✓"

# 禁用开机自启
echo -n "正在禁用开机自启... "
/etc/init.d/netmonitor disable 2>/dev/null || true
echo "✓"

# 从 xinetd 配置中移除
echo -n "正在清理 xinetd/socat 配置... "
rm -f /etc/xinetd.d/netmonitor 2>/dev/null || true
[ -f /etc/init.d/xinetd ] && /etc/init.d/xinetd restart 2>/dev/null || true
echo "✓"

# 删除可执行文件
echo -n "正在删除脚本文件... "
rm -f /usr/bin/netmonitor-listener
rm -f /usr/bin/netmonitor-api-inetd
echo "✓"

# 删除启动脚本
echo -n "正在删除启动脚本... "
rm -f /etc/init.d/netmonitor
echo "✓"

# 删除配置文件
echo -n "正在删除配置文件... "
rm -f /etc/netmonitor.conf
echo "✓"

# 清理临时文件
echo -n "正在清理临时文件... "
rm -f /tmp/net_events.json
rm -f /tmp/netmonitor*.tmp*
echo "✓"

# 清理PID文件
echo -n "正在清理PID文件... "
rm -f /var/run/netmonitor-*.pid
echo "✓"

echo ""
echo "================================"
echo "卸载完成！"
echo "================================"
echo ""
echo "已清理内容:"
echo "  - 所有可执行脚本"
echo "  - 启动脚本"
echo "  - 配置文件"
echo "  - 临时数据文件"
echo "  - inetd 配置"
echo ""
echo "如需重新安装，请运行:"
echo "  cd /tmp/openwrt_monitor"
echo "  sh install.sh"
echo ""

exit 0
