#!/usr/bin/env python3
"""
OpenWrt NetMonitor Client - Web UI Dashboard
Dashboard for displaying network monitoring data from OpenWrt routers
"""

import os
import sys
import json
import requests
import logging
from datetime import datetime, timedelta
from dotenv import load_dotenv
from flask import Flask, render_template, jsonify, request, Response
from flask_cors import CORS
from apscheduler.schedulers.background import BackgroundScheduler

# 导入模型
from models import db, NetworkStatus, PingResult, NetworkEvent, HourlyStats, init_db

# 加载环境变量
load_dotenv()

# 创建Flask应用
app = Flask(__name__)

# 配置
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'netmonitor-secret-key')
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('SQLITE_DB', 'sqlite:///data/netmonitor.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# 初始化数据库
db_instance = init_db(app)

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('/app/logs/app.log', encoding='utf-8')
    ]
)
logger = logging.getLogger(__name__)

# CORS配置
CORS(app)

# 全局变量
router_ip = os.getenv('ROUTER_IP', '192.168.1.1')
router_port = os.getenv('ROUTER_PORT', '8321')
router_token = os.getenv('ROUTER_TOKEN', '')
poll_interval = int(os.getenv('POLL_INTERVAL', '60'))

# APScheduler
scheduler = BackgroundScheduler(timezone='UTC')


def get_router_url():
    """获取路由器API地址"""
    return f"http://{router_ip}:{router_port}/net/status"


def fetch_router_data():
    """
    从OpenWrt路由器获取监控数据
    Returns:
        dict or None: 路由器返回的JSON数据
    """
    url = get_router_url()
    headers = {}

    if router_token:
        headers['Authorization'] = f'Bearer {router_token}'

    try:
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
        data = response.json()
        logger.info(f"Successfully fetched data from router: {router_ip}")
        return data
    except requests.exceptions.RequestException as e:
        logger.error(f"Failed to fetch data from router {router_ip}: {e}")
        return None
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse JSON from router: {e}")
        return None


def save_network_status(data):
    """
    保存网络状态数据到数据库
    Args:
        data (dict): 从路由器获取的数据
    """
    if not data or 'realtime' not in data:
        logger.warning("Invalid data format, skipping save")
        return

    realtime = data['realtime']
    summary = data.get('summary', {})
    timestamp = datetime.now()

    # 保存网络状态
    status = NetworkStatus(
        timestamp=timestamp,
        wan_state=realtime.get('wan_state'),
        rx_errors=realtime['wan_errors'].get('rx_errors', 0) if 'wan_errors' in realtime else 0,
        tx_errors=realtime['wan_errors'].get('tx_errors', 0) if 'wan_errors' in realtime else 0,
        rx_dropped=realtime['wan_errors'].get('rx_dropped', 0) if 'wan_errors' in realtime else 0,
        tx_dropped=realtime['wan_errors'].get('tx_dropped', 0) if 'wan_errors' in realtime else 0,
        optical_rx=realtime['optical_power'].get('rx') if 'optical_power' in realtime and realtime['optical_power'] else None,
        optical_tx=realtime['optical_power'].get('tx') if 'optical_power' in realtime and realtime['optical_power'] else None,
        cpu_temp=realtime.get('cpu_temp'),
        pppoe_reconnect_count=summary.get('pppoe_reconnect_count_24h', 0),
        wan_down_count=summary.get('wan_down_count_24h', 0)
    )
    db.session.add(status)
    db.session.commit()
    logger.info(f"Saved network status record #{status.id}")

    # 保存Ping结果
    if 'ping' in realtime:
        for target, ping_data in realtime['ping'].items():
            ping_result = PingResult(
                timestamp=timestamp,
                target=target,
                rtt=ping_data.get('rtt'),
                loss=ping_data.get('loss', 0)
            )
            db.session.add(ping_result)
        db.session.commit()

    # 保存事件
    if 'events' in data:
        for event_data in data['events']:
            try:
                # 解析时间字符串
                event_time_str = event_data.get('time', '')
                event_time = None
                if event_time_str:
                    try:
                        event_time = datetime.strptime(event_time_str, '%Y-%m-%d %H:%M:%S')
                    except ValueError:
                        logger.warning(f"Failed to parse event time: {event_time_str}")

                event = NetworkEvent(
                    event_time=event_time if event_time else timestamp,
                    event_type=event_data.get('type', 'unknown'),
                    message=event_data.get('message', '')
                )
                db.session.add(event)
            except Exception as e:
                logger.error(f"Failed to save event: {e}")
        db.session.commit()


def generate_hourly_stats():
    """
    生成每小时统计数据（优化查询性能）
    定时任务，每小时执行一次
    """
    try:
        now = datetime.utcnow()
        hour_start = now.replace(minute=0, second=0, microsecond=0)
        hour_end = hour_start + timedelta(hours=1)

        # 检查是否已经统计过这一小时
        existing = HourlyStats.query.filter_by(hour=hour_start).first()
        if existing:
            logger.info(f"Hourly stats for {hour_start} already exists")
            return

        # 查询该小时的数据
        ping_data = PingResult.query.filter(
            PingResult.timestamp >= hour_start,
            PingResult.timestamp < hour_end
        ).all()

        status_data = NetworkStatus.query.filter(
            NetworkStatus.timestamp >= hour_start,
            NetworkStatus.timestamp < hour_end
        ).all()

        if not ping_data and not status_data:
            logger.info(f"No data found for {hour_start}, skipping stats generation")
            return

        # 计算统计数据
        rtt_values = [p.rtt for p in ping_data if p.rtt is not None]

        stats = HourlyStats(
            hour=hour_start,
            avg_ping_rtt=sum(rtt_values) / len(rtt_values) if rtt_values else None,
            max_ping_rtt=max(rtt_values) if rtt_values else None,
            min_ping_rtt=min(rtt_values) if rtt_values else None,
            packet_loss_count=len([p for p in ping_data if p.loss > 0]),
            pppoe_reconnect_count=sum(s.pppoe_reconnect_count for s in status_data) // len(status_data) if status_data else 0,
            wan_down_count=sum(s.wan_down_count for s in status_data) // len(status_data) if status_data else 0,
        )

        # CPU温度统计
        temps = [s.cpu_temp for s in status_data if s.cpu_temp is not None]
        if temps:
            stats.avg_cpu_temp = sum(temps) / len(temps)
            stats.max_cpu_temp = max(temps)

        db.session.add(stats)
        db.session.commit()

        logger.info(f"Generated hourly stats for {hour_start}")

    except Exception as e:
        logger.error(f"Failed to generate hourly stats: {e}")


def scheduled_fetch():
    """定时任务：定期从路由器抓取数据"""
    logger.info("Executing scheduled data fetch...")
    data = fetch_router_data()
    if data:
        save_network_status(data)


def cleanup_old_data():
    """清理30天前的旧数据"""
    try:
        cutoff = datetime.utcnow() - timedelta(days=30)

        # 删除Ping结果
        deleted_ping = PingResult.query.filter(PingResult.timestamp < cutoff).delete()

        # 删除网络状态（保留事件）
        deleted_status = NetworkStatus.query.filter(NetworkStatus.timestamp < cutoff).delete()

        db.session.commit()
        logger.info(f"Cleaned up {deleted_ping} ping records and {deleted_status} status records")

    except Exception as e:
        logger.error(f"Failed to cleanup old data: {e}")


@app.route('/')
def index():
    """主页"""
    return render_template('index.html',
                           router_ip=router_ip,
                           router_port=router_port,
                           last_update=datetime.now().strftime('%Y-%m-%d %H:%M:%S'))


@app.route('/health')
def health():
    """健康检查"""
    try:
        # 检查数据库连接
        db.session.execute('SELECT 1')
        return jsonify({'status': 'healthy', 'timestamp': datetime.utcnow().isoformat()})
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return jsonify({'status': 'unhealthy', 'error': str(e)}), 503


@app.route('/api/status')
def api_status():
    """获取最新状态"""
    data = fetch_router_data()
    if data:
        return jsonify(data)
    else:
        return jsonify({'error': 'Failed to fetch from router'}), 503


@app.route('/api/history')
def api_history():
    """获取历史数据"""
    try:
        offset = request.args.get('offset', 0, type=int)
        limit = request.args.get('limit', 100, type=int)
        hours = request.args.get('hours', 24, type=int)

        cutoff = datetime.utcnow() - timedelta(hours=hours)

        # 获取网络状态
        status_query = NetworkStatus.query.filter(
            NetworkStatus.timestamp >= cutoff
        ).order_by(NetworkStatus.timestamp.desc())

        total = status_query.count()
        records = status_query.offset(offset).limit(limit).all()

        # 获取Ping数据
        ping_query = PingResult.query.filter(
            PingResult.timestamp >= cutoff
        ).order_by(PingResult.timestamp.desc())
        ping_records = ping_query.limit(500).all()

        # 获取事件
        events_query = NetworkEvent.query.filter(
            NetworkEvent.event_time >= cutoff
        ).order_by(NetworkEvent.event_time.desc())
        events = events_query.limit(100).all()

        return jsonify({
            'status': 'success',
            'total': total,
            'records': [r.to_dict() for r in records],
            'ping': [p.to_dict() for p in ping_records],
            'events': [e.to_dict() for e in events],
            'router': {'ip': router_ip, 'port': router_port}
        })

    except Exception as e:
        logger.error(f"Failed to get history: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/ping_history')
def api_ping_history():
    """获取Ping历史数据"""
    try:
        hours = request.args.get('hours', 24, type=int)
        target = request.args.get('target', '')

        cutoff = datetime.utcnow() - timedelta(hours=hours)

        query = PingResult.query.filter(
            PingResult.timestamp >= cutoff
        )

        if target:
            query = query.filter(PingResult.target == target)

        records = query.order_by(PingResult.timestamp.desc()).limit(500).all()

        return jsonify({
            'status': 'success',
            'records': [r.to_dict() for r in records]
        })

    except Exception as e:
        logger.error(f"Failed to get ping history: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/events')
def api_events():
    """获取事件列表"""
    try:
        limit = request.args.get('limit', 50, type=int)
        event_type = request.args.get('type', '')

        query = NetworkEvent.query

        if event_type:
            query = query.filter(NetworkEvent.event_type == event_type)

        records = query.order_by(NetworkEvent.event_time.desc()).limit(limit).all()

        return jsonify({
            'status': 'success',
            'records': [r.to_dict() for r in records]
        })

    except Exception as e:
        logger.error(f"Failed to get events: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/stats/summary')
def api_stats_summary():
    """获取统计摘要"""
    try:
        hours = request.args.get('hours', 24, type=int)
        cutoff = datetime.utcnow() - timedelta(hours=hours)

        # 最近24小时统计
        total_ping = PingResult.query.filter(PingResult.timestamp >= cutoff).count()
        loss_ping = PingResult.query.filter(
            PingResult.timestamp >= cutoff,
            PingResult.loss > 0
        ).count()

        # WAN状态
        wan_up_count = NetworkStatus.query.filter(
            NetworkStatus.timestamp >= cutoff,
            NetworkStatus.wan_state == 'up'
        ).count()
        total_count = NetworkStatus.query.filter(
            NetworkStatus.timestamp >= cutoff
        ).count()

        # 平均CPU温度
        avg_temp = db.session.query(db.func.avg(NetworkStatus.cpu_temp)).filter(
            NetworkStatus.timestamp >= cutoff,
            NetworkStatus.cpu_temp.isnot(None)
        ).scalar()

        # 事件统计
        pppoe_events = NetworkEvent.query.filter(
            NetworkEvent.event_time >= cutoff,
            NetworkEvent.event_type.like('pppoe%')
        ).count()

        wan_events = NetworkEvent.query.filter(
            NetworkEvent.event_time >= cutoff,
            NetworkEvent.event_type.like('%wan%')
        ).count()

        return jsonify({
            'status': 'success',
            'summary': {
                'total_records': total_count,
                'wan_availability': (wan_up_count / total_count * 100) if total_count > 0 else 0,
                'packet_loss_rate': (loss_ping / total_ping * 100) if total_ping > 0 else 0,
                'avg_cpu_temp': round(avg_temp, 1) if avg_temp else None,
                'pppoe_events': pppoe_events,
                'wan_events': wan_events,
                'monitoring_hours': hours
            }
        })

    except Exception as e:
        logger.error(f"Failed to get summary stats: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/fetch_now')
def api_fetch_now():
    """立即抓取数据"""
    try:
        data = fetch_router_data()
        if data:
            save_network_status(data)
            return jsonify({'status': 'success', 'message': 'Data fetched and saved'})
        else:
            return jsonify({'status': 'error', 'message': 'Failed to fetch from router'}), 503
    except Exception as e:
        logger.error(f"Failed to fetch now: {e}")
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    # 创建日志目录
    os.makedirs('/app/logs', exist_ok=True)

    # 创建logs目录
    os.makedirs('/app/logs', exist_ok=True)

    # 设置定时任务
    scheduler.add_job(scheduled_fetch, 'interval', seconds=poll_interval,
                      id='fetch_data', replace_existing=True)
    scheduler.add_job(generate_hourly_stats, 'cron', hour='*',
                      id='hourly_stats', replace_existing=True)
    scheduler.add_job(cleanup_old_data, 'cron', hour='3',
                      id='cleanup', replace_existing=True)

    scheduler.start()

    logger.info(f"Starting NetMonitor Client...")
    logger.info(f"Router: {router_ip}:{router_port}")
    logger.info(f"Poll interval: {poll_interval}s")
    logger.info(f"Database: {app.config['SQLALCHEMY_DATABASE_URI']}")

    # 启动时立即抓取一次
    scheduled_fetch()

    # 启动Flask
    host = os.getenv('FLASK_HOST', '0.0.0.0')
    port = int(os.getenv('FLASK_PORT', '5000'))
    debug = os.getenv('FLASK_DEBUG', 'false').lower() == 'true'

    app.run(host=host, port=port, debug=debug)
