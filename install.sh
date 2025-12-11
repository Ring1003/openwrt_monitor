#!/bin/sh
# OpenWrt 网络监控 - 优化版安装脚本 (ARM专用)
# 版本: v1.1.0
# 特性: 支持 xinetd/socat/无HTTP模式

set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Inetd 类型: xinetd, socat, none
INETD_TYPE=""

echo "${GREEN}================================${NC}"
echo "${GREEN}OpenWrt 网络监控 - ARM优化版安装${NC}"
echo "${GREEN}================================${NC}"
echo ""

# 检测或选择 inetd 类型
select_inetd_type() {
    echo "${YELLOW}请选择或确认 HTTP 服务模式:${NC}"
    echo ""

    # 检查 xinetd
    if command -v xinetd >/dev/null 2>&1 || [ -f /etc/init.d/xinetd ]; then
        echo "✓ 检测到 xinetd 已安装"
        INETD_TYPE="xinetd"
    # 检查 socat
    elif command -v socat >/dev/null 2>&1; then
        echo "✓ 检测到 socat 已安装"
        INETD_TYPE="socat"
    else
        echo "${YELLOW}未检测到 xinetd 或 socat${NC}"
        echo ""
        echo "请选择安装方式："
        echo "1) 使用 xinetd (OpenWrt 标准, 推荐)"
        echo "2) 使用 socat (现代工具, 功能强大)"
        echo "3) 跳过 HTTP API 配置 (仅事件监听)"
        echo ""
        read -p "请选择 [1-3]: " choice

        case $choice in
            1)
                INETD_TYPE="xinetd"
                ;;
            2)
                INETD_TYPE="socat"
                ;;
            3)
                INETD_TYPE="none"
                ;;
            *)
                echo "${RED}无效选项${NC}"
                exit 1
                ;;
        esac
    fi

    echo "${BLUE}ℹ 选择的模式: $INETD_TYPE${NC}"
    echo ""
}

# 检查必需命令（不强制inetd）
check_requirements() {
    for cmd in awk sed grep ping ifconfig ubus; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "${RED}错误: 缺少必需命令: $cmd${NC}"
            exit 1
        fi
    done
}

# 检查inetd服务
check_inetd() {
    if command -v inetd >/dev/null 2>&1; then
        echo "inetd"
    elif command -v xinetd >/dev/null 2>&1; then
        echo "xinetd"
    elif [ -f /etc/init.d/inetd ]; then
        echo "inetd"
    elif [ -f /etc/init.d/xinetd ]; then
        echo "xinetd"
    else
        echo "none"
    fi
}

# 安装inetd
install_inetd() {
    echo "${YELLOW}检测到未安装 inetd 服务${NC}"
    echo ""
    echo "请选择安装方式："
    echo "1) 自动安装 inetd (推荐)"
    echo "2) 手动安装后重新运行脚本"
    echo "3) 跳过inetd配置 (仅安装事件监听器)"
    echo ""
    read -p "请选择 [1-3]: " choice

    case $choice in
        1)
            echo "${YELLOW}正在安装 inetd...${NC}"
            if opkg update >/dev/null 2>&1; then
                if opkg install inetd >/dev/null 2>&1; then
                    echo "${GREEN}✓ inetd 安装成功${NC}"
                    return 0
                elif opkg install xinetd >/dev/null 2>&1; then
                    echo "${GREEN}✓ xinetd 安装成功${NC}"
                    return 0
                elif opkg install busybox-inetd >/dev/null 2>&1; then
                    echo "${GREEN}✓ busybox-inetd 安装成功${NC}"
                    return 0
                else
                    echo "${RED}✗ 安装失败，请手动安装${NC}"
                    return 1
                fi
            else
                echo "${RED}✗ opkg 更新失败，请检查网络${NC}"
                return 1
            fi
            ;;
        2)
            echo "请运行: opkg update && opkg install inetd"
            exit 1
            ;;
        3)
            echo "${YELLOW}跳过inetd配置，仅安装事件监听器${NC}"
            return 1
            ;;
        *)
            echo "${RED}无效选项${NC}"
            exit 1
            ;;
    esac
}

# 初始化队列
init_queue() {
    if [ ! -f "/tmp/net_events.json" ]; then
        echo '[
]' > "/tmp/net_events.json"
        chmod 644 "/tmp/net_events.json"
        echo "✓ 初始化事件队列"
    fi
}

# 安装 xinetd
install_xinetd() {
    echo "${YELLOW}正在安装 xinetd...${NC}"
    if opkg install xinetd 2>/dev/null; then
        echo "${GREEN}✓ xinetd 安装成功${NC}"
        return 0
    else
        echo "${RED}✗ xinetd 安装失败${NC}"
        return 1
    fi
}

# 安装 socat
install_socat() {
    echo "${YELLOW}正在安装 socat...${NC}"
    if opkg install socat 2>/dev/null; then
        echo "${GREEN}✓ socat 安装成功${NC}"
        return 0
    else
        echo "${RED}✗ socat 安装失败${NC}"
        return 1
    fi
}

# 配置 xinetd
setup_xinetd() {
    echo "${YELLOW}配置 xinetd 服务...${NC}"

    # 创建 xinetd 配置目录
    mkdir -p /etc/xinetd.d

    # 创建 netmonitor 服务配置
    cat > /etc/xinetd.d/netmonitor << 'EOF'
# NetMonitor HTTP API Service
service netmonitor
{
    type            = UNLISTED
    socket_type     = stream
    protocol        = tcp
    wait            = no
    user            = root
    server          = /usr/bin/netmonitor-api-inetd
    server_args     =
    port            = 8321
    disable         = no
    per_source      = 10
    instances       = 50
}
EOF

    # 确保 xinetd 启动
    if [ -f /etc/init.d/xinetd ]; then
        /etc/init.d/xinetd enable 2>/dev/null || true
        /etc/init.d/xinetd restart 2>/dev/null || true
        echo "${GREEN}✓ xinetd 配置完成并重启${NC}"
    else
        echo "${YELLOW}⚠ 未找到 xinetd 启动脚本，但配置已创建${NC}"
    fi

    return 0
}

# 配置 socat (直接在 netmonitor 服务中集成)
setup_socat() {
    echo "${YELLOW}配置 socat HTTP 服务...${NC}"
    echo "${GREEN}✓ socat 将在 netmonitor 服务启动时自动配置${NC}"
    echo "${BLUE}ℹ 监听地址: 0.0.0.0:$API_PORT (所有网络接口)${NC}"
    return 0
}

# 配置inetd/socat
setup_inetd() {
    case $INETD_TYPE in
        xinetd)
            if ! command -v xinetd >/dev/null 2>&1 && ! [ -f /etc/init.d/xinetd ]; then
                install_xinetd || return 1
            fi
            setup_xinetd || return 1
            ;;
        socat)
            if ! command -v socat >/dev/null 2>&1; then
                install_socat || return 1
            fi
            setup_socat || return 1
            ;;
        none)
            return 1
            ;;
    esac

    return 0
}

# 主安装流程
main() {
    check_requirements

    # 选择或确认 inetd 类型
    select_inetd_type

    # 确认后继续
    read -p "按回车键继续安装..."
    echo ""

    echo "${YELLOW}[1/6]${NC} 复制事件监听器..."
    cp "netmonitor-listener" "/usr/bin/netmonitor-listener"
    chmod +x "/usr/bin/netmonitor-listener"
    echo "✓ 完成\n"

    echo "${YELLOW}[2/6]${NC} 复制Inetd API脚本..."
    cp "netmonitor-api-inetd" "/usr/bin/netmonitor-api-inetd"
    chmod +x "/usr/bin/netmonitor-api-inetd"
    echo "✓ 完成\n"

    echo "${YELLOW}[3/6]${NC} 复制启动脚本..."
    cp "netmonitor" "/etc/init.d/netmonitor"
    chmod +x "/etc/init.d/netmonitor"
    echo "✓ 完成\n"

    echo "${YELLOW}[4/6]${NC} 复制配置文件..."
    cp "netmonitor.conf" "/etc/netmonitor.conf"
    chmod 644 "/etc/netmonitor.conf"
    echo "✓ 完成\n"

    echo "${YELLOW}[5/6]${NC} 初始化事件队列..."
    init_queue
    echo "✓ 完成\n"

    echo "${YELLOW}[6/6]${NC} 配置 HTTP API 服务 ($INETD_TYPE)..."
    if setup_inetd; then
        echo "✓ 完成\n"
    else
        echo "${YELLOW}⚠ 跳过 HTTP API 配置${NC}\n"
    fi

    echo "${GREEN}================================${NC}"
    echo "${GREEN}安装完成！${NC}"
    echo "${GREEN}================================${NC}"
    echo ""

    echo "${GREEN}==============================${NC}"
    echo "${GREEN}核心服务启动命令${NC}"
    echo "${GREEN}==============================${NC}"
    echo ""
    echo "启动事件监听器:"
    echo "  /etc/init.d/netmonitor enable"
    echo "  /etc/init.d/netmonitor start"
    echo ""

    if [ "$INETD_TYPE" = "xinetd" ]; then
        echo "${GREEN}==============================${NC}"
        echo "${GREEN}HTTP API 信息 (xinetd)${NC}"
        echo "${GREEN}==============================${NC}"
        echo ""
        echo "✓ 使用 xinetd 托管 HTTP API"
        echo "✓ 服务端口: 8321"
        echo "✓ 配置目录: /etc/xinetd.d/"
        echo ""
        echo "测试 API:"
        echo "  curl http://localhost:8321/net/status"
        echo ""
        echo "xinetd 服务管理:"
        echo "  /etc/init.d/xinetd status"
        echo "  /etc/init.d/xinetd restart"
        echo ""
    elif [ "$INETD_TYPE" = "socat" ]; then
        echo "${GREEN}==============================${NC}"
        echo "${GREEN}HTTP API 信息 (socat)${NC}"
        echo "${GREEN}==============================${NC}"
        echo ""
        echo "✓ 使用 socat 提供 HTTP API"
        echo "✓ 服务端口: 8321"
        echo "✓ 监听地址: 0.0.0.0 (所有网络接口)"
        echo "✓ 集成模式: socat 集成在 netmonitor 服务中"
        echo ""
        echo "测试 API:"
        echo "  curl http://localhost:8321/net/status"
        echo "  curl http://<你的IP>:8321/net/status"
        echo ""
        echo "服务管理 (统一由 netmonitor 管理):"
        echo "  /etc/init.d/netmonitor enable"
        echo "  /etc/init.d/netmonitor start"
        echo "  /etc/init.d/netmonitor stop"
        echo "  /etc/init.d/netmonitor status"
        echo ""
    else
        echo "${YELLOW}注意：HTTP API 未配置${NC}"
        echo "${YELLOW}原因：跳过了 HTTP API 配置${NC}"
        echo ""
        echo "如需 HTTP API，请重新运行:"
        echo "  ./install-inetd.sh    # 先安装 xinetd 或 socat"
        echo "  ./install.sh          # 然后重新安装"
        echo ""
    fi

    echo "卸载命令:"
    echo "  sh UNINSTALL-netmonitor.sh"
    echo ""
}

main "$@"
