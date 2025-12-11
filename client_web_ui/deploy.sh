#!/bin/bash
# OpenWrt NetMonitor Web UI - 部署脚本

set -e

echo "================================"
echo "OpenWrt NetMonitor Web UI 部署"
echo "================================"
echo ""

# 检查Docker环境
check_docker() {
    echo -n "检查Docker环境... "
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker未安装"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        echo "❌ Docker Compose未安装"
        exit 1
    fi
    echo "✅ 正常"
}

# 检查配置文件
check_config() {
    echo -n "检查配置文件... "
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            cp .env.example .env
            echo "⚠️  已创建.env文件，请修改配置"
        else
            echo "❌ 缺少配置文件"
            exit 1
        fi
    fi
    echo "✅ 正常"
}

# 创建必要目录
setup_dirs() {
    echo -n "创建数据目录... "
    mkdir -p data logs
    echo "✅ 完成"
}

# 修改.env配置
config_env() {
    echo ""
    echo "配置路由器信息："
    read -p "路由器IP地址 (默认: 192.168.1.1): " router_ip
    router_ip=${router_ip:-192.168.1.1}

    read -p "API端口 (默认: 8321): " router_port
    router_port=${router_port:-8321}

    read -p "访问令牌 (可选): " router_token

    # 更新.env文件
    sed -i "s/^ROUTER_IP=.*/ROUTER_IP=$router_ip/" .env
    sed -i "s/^ROUTER_PORT=.*/ROUTER_PORT=$router_port/" .env

    if [ -n "$router_token" ]; then
        sed -i "s/^ROUTER_TOKEN=.*/ROUTER_TOKEN=$router_token/" .env
    fi

    echo "✅ 配置已更新"
}

# 构建镜像
build_image() {
    echo ""
    echo "构建Docker镜像..."
    docker-compose build
    echo "✅ 构建完成"
}

# 启动服务
start_service() {
    echo ""
    echo "启动服务..."
    docker-compose up -d
    echo "✅ 服务已启动"
}

# 检查服务状态
check_status() {
    echo ""
    echo "检查服务状态..."
    sleep 5
    docker-compose ps

    # 检查健康状态
    if curl -s http://localhost:5000/health > /dev/null; then
        echo "✅ 服务健康"
    else
        echo "❌ 服务异常，请检查日志"
        docker-compose logs
    fi
}

# 显示访问信息
show_info() {
    echo ""
    echo "================================"
    echo "部署完成！"
    echo "================================"
    echo ""
    echo "访问地址："
    echo "  Web UI: http://localhost:5000"
    echo "  Health: http://localhost:5000/health"
    echo ""
    echo "管理命令："
    echo "  查看日志: docker-compose logs -f"
    echo "  停止服务: docker-compose down"
    echo "  重启服务: docker-compose restart"
    echo ""
    echo "数据存储："
    echo "  数据库: ./data/netmonitor.db"
    echo "  日志: ./logs/"
    echo ""
}

# 主流程
main() {
    check_docker
    check_config

    echo ""
    read -p "是否要修改路由器配置? (y/n): " config_choice
    if [ "$config_choice" = "y" ]; then
        config_env
    fi

    setup_dirs
    build_image
    start_service
    check_status
    show_info
}

# 执行
case "$1" in
    "config")
        config_env
        ;;
    "build")
        build_image
        ;;
    "start")
        start_service
        ;;
    "stop")
        docker-compose down
        ;;
    "logs")
        docker-compose logs -f
        ;;
    "restart")
        docker-compose restart
        ;;
    *)
        main
        ;;
esac
