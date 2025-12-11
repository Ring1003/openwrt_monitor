#!/usr/bin/env python3
"""
Database models for NetMonitor client
"""

from datetime import datetime
from flask_sqlalchemy import SQLAlchemy
from flask import Flask

db = SQLAlchemy()


class NetworkStatus(db.Model):
    """网络状态数据"""
    __tablename__ = 'network_status'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    timestamp = db.Column(db.DateTime, nullable=False, default=datetime.utcnow, index=True)

    # WAN状态
    wan_state = db.Column(db.String(20))
    rx_errors = db.Column(db.Integer, default=0)
    tx_errors = db.Column(db.Integer, default=0)
    rx_dropped = db.Column(db.Integer, default=0)
    tx_dropped = db.Column(db.Integer, default=0)

    # 光功率
    optical_rx = db.Column(db.Float, nullable=True)
    optical_tx = db.Column(db.Float, nullable=True)

    # CPU温度
    cpu_temp = db.Column(db.Float, nullable=True)

    # PPPoE重连次数
    pppoe_reconnect_count = db.Column(db.Integer, default=0)
    wan_down_count = db.Column(db.Integer, default=0)

    def to_dict(self):
        return {
            'id': self.id,
            'timestamp': self.timestamp.isoformat(),
            'wan_state': self.wan_state,
            'wan_errors': {
                'rx_errors': self.rx_errors,
                'tx_errors': self.tx_errors,
                'rx_dropped': self.rx_dropped,
                'tx_dropped': self.tx_dropped
            },
            'optical_power': {
                'rx': self.optical_rx,
                'tx': self.optical_tx
            },
            'cpu_temp': self.cpu_temp,
            'summary': {
                'pppoe_reconnect_count_24h': self.pppoe_reconnect_count,
                'wan_down_count_24h': self.wan_down_count
            }
        }

    def __repr__(self):
        return f"<NetworkStatus {self.timestamp}>"


class PingResult(db.Model):
    """Ping测试结果"""
    __tablename__ = 'ping_results'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    timestamp = db.Column(db.DateTime, nullable=False, default=datetime.utcnow, index=True)
    target = db.Column(db.String(100), nullable=False, index=True)
    rtt = db.Column(db.Float, nullable=True)
    loss = db.Column(db.Integer, default=0)

    def to_dict(self):
        return {
            'id': self.id,
            'timestamp': self.timestamp.isoformat(),
            'target': self.target,
            'rtt': self.rtt,
            'loss': self.loss
        }

    def __repr__(self):
        return f"<PingResult {self.target} {self.rtt}ms>"


class NetworkEvent(db.Model):
    """网络事件"""
    __tablename__ = 'network_events'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    timestamp = db.Column(db.DateTime, nullable=False, default=datetime.utcnow, index=True)
    event_time = db.Column(db.DateTime, nullable=False)
    event_type = db.Column(db.String(100), nullable=False, index=True)
    message = db.Column(db.Text)

    def to_dict(self):
        return {
            'id': self.id,
            'timestamp': self.timestamp.isoformat(),
            'event_time': self.event_time.isoformat() if self.event_time else None,
            'type': self.event_type,
            'message': self.message
        }

    def __repr__(self):
        return f"<NetworkEvent {self.event_type}>"


class HourlyStats(db.Model):
    """每小时统计数据（用于性能优化）"""
    __tablename__ = 'hourly_stats'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    hour = db.Column(db.DateTime, nullable=False, index=True, unique=True)  # 整点时间

    # 统计数据
    avg_ping_rtt = db.Column(db.Float, nullable=True)
    max_ping_rtt = db.Column(db.Float, nullable=True)
    min_ping_rtt = db.Column(db.Float, nullable=True)
    packet_loss_count = db.Column(db.Integer, default=0)

    pppoe_reconnect_count = db.Column(db.Integer, default=0)
    wan_down_count = db.Column(db.Integer, default=0)

    avg_cpu_temp = db.Column(db.Float, nullable=True)
    max_cpu_temp = db.Column(db.Float, nullable=True)

    def to_dict(self):
        return {
            'hour': self.hour.isoformat(),
            'avg_ping_rtt': self.avg_ping_rtt,
            'max_ping_rtt': self.max_ping_rtt,
            'min_ping_rtt': self.min_ping_rtt,
            'packet_loss_count': self.packet_loss_count,
            'pppoe_reconnect_count': self.pppoe_reconnect_count,
            'wan_down_count': self.wan_down_count,
            'avg_cpu_temp': self.avg_cpu_temp,
            'max_cpu_temp': self.max_cpu_temp
        }


def init_db(app: Flask):
    """初始化数据库"""
    db.init_app(app)
    with app.app_context():
        db.create_all()
        return db
