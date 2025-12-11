#!/bin/sh
# OpenWrt 网络监控 - Inetd/Socat 快速安装脚本
# 用于快速安装 xinetd 或使用 socat 作为替代方案

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "${GREEN}================================${NC}"
echo "${GREEN}安装 HTTP 服务支持${NC}"
echo "${GREEN}================================${NC}"
echo ""

echo "${YELLOW}步骤 1: 更新软件包列表...${NC}"
if opkg update; then
    echo "${GREEN}✓ 软件包列表更新成功${NC}"
else
    echo "${RED}✗ 软件包列表更新失败，请检查网络连接${NC}"
    exit 1
fi

echo ""
echo "${YELLOW}步骤 2: 尝试安装 xinetd...${NC}"

# OpenWrt 使用 xinetd 而不是 inetd
echo "正在尝试安装 xinetd (OpenWrt 标准 inetd 服务)..."
if opkg install xinetd; then
    echo "${GREEN}✓ xinetd 安装成功${NC}"
    INETD_TYPE="xinetd"
else
    echo "${YELLOW}⚠ xinetd 安装失败，尝试备用方案...${NC}"
    echo ""
    echo "${YELLOW}步骤 3: 尝试安装 socat 作为替代方案...${NC}"
    echo "socat 是一个更现代的网络工具，功能更强大${NC}"

    if opkg install socat; then
        echo "${GREEN}✓ socat 安装成功${NC}"
        echo "${BLUE}ℹ 将使用 socat 替代 xinetd 提供 HTTP API 服务${NC}"
        INETD_TYPE="socat"
    else
        echo "${RED}✗ socat 安装失败${NC}"
        echo ""
        echo "${RED}所有方案都失败了，请尝试以下方法:${NC}"
        echo ""
        echo "方法 1: 检查软件源配置"
        echo "  cat /etc/opkg/distfeeds.conf"
        echo ""
        echo "方法 2: 手动下载安装包"
        echo "  访问: https://downloads.openwrt.org/snapshots/packages/aarch64_generic/packages/"
        echo "  查找: socat_*.ipk 或 xinetd_*.ipk"
        echo "  安装: opkg install /path/to/downloaded.ipk"
        echo ""
        echo "方法 3: 继续使用无 HTTP API 模式"
        echo "  运行 ./install.sh 并选择跳过 inetd 配置"
        echo "  事件监听器仍可正常工作，记录所有网络事件"
        exit 1
    fi
fi

echo ""
echo "${YELLOW}步骤 4: 启动并启用服务...${NC}"

if [ "$INETD_TYPE" = "xinetd" ]; then
    if [ -f /etc/init.d/xinetd ]; then
        /etc/init.d/xinetd enable 2>/dev/null || true
        /etc/init.d/xinetd start 2>/dev/null || true
        echo "${GREEN}✓ xinetd 服务已配置${NC}"
    else
        echo "${YELLOW}⚠ 未找到 /etc/init.d/xinetd 启动脚本${NC}"
        echo "${YELLOW}  但 xinetd 仍可工作，这是正常的${NC}"
    fi
elif [ "$INETD_TYPE" = "socat" ]; then
    echo "${GREEN}✓ socat 已准备就绪${NC}"
    echo "${BLUE}ℹ socat 不需要常驻服务，将在需要时启动${NC}"
fi

echo ""
echo "${GREEN}================================${NC}"
echo "${GREEN}安装完成！${NC}"
echo "${GREEN}================================${NC}"
echo ""
echo "安装的服务: ${BLUE}$INETD_TYPE${NC}"
echo ""

if [ "$INETD_TYPE" = "xinetd" ]; then
    echo "xinetd 配置说明:"
    echo "  - 服务将监听端口 8321"
    echo "  - 配置文件: /etc/xinetd.d/netmonitor"
    echo "  - 启动脚本: /etc/init.d/xinetd"
    echo ""
elif [ "$INETD_TYPE" = "socat" ]; then
    echo "socat 使用说明:"
    echo "  - socat 将在 HTTP API 被访问时自动启动"
    echo "  - 不需要额外的服务配置"
    echo "  - 性能优于传统的 inetd/xinetd"
    echo ""
fi

echo "接下来，请重新运行安装脚本:"
echo "  cd /tmp/openwrt_monitor"
echo "  ./install.sh"
echo ""
echo "如果安装脚本询问 inetd 类型，请选择: ${BLUE}$INETD_TYPE${NC}"
echo ""

exit 0
