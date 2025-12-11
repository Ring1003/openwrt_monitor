const { Sequelize, DataTypes } = require('sequelize');

const sequelize = new Sequelize({
  dialect: 'sqlite',
  storage: './data/netmonitor.db',
  logging: false
});

const NetworkStatus = sequelize.define('NetworkStatus', {
  timestamp: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  wan_state: DataTypes.STRING,
  rx_errors: { type: DataTypes.INTEGER, defaultValue: 0 },
  tx_errors: { type: DataTypes.INTEGER, defaultValue: 0 },
  rx_dropped: { type: DataTypes.INTEGER, defaultValue: 0 },
  tx_dropped: { type: DataTypes.INTEGER, defaultValue: 0 },
  optical_rx: DataTypes.FLOAT,
  optical_tx: DataTypes.FLOAT,
  cpu_temp: DataTypes.FLOAT,
  pppoe_reconnect_count: { type: DataTypes.INTEGER, defaultValue: 0 },
  wan_down_count: { type: DataTypes.INTEGER, defaultValue: 0 }
}, { tableName: 'network_status', timestamps: false });

const PingResult = sequelize.define('PingResult', {
  timestamp: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  target: DataTypes.STRING,
  rtt: DataTypes.FLOAT,
  loss: { type: DataTypes.INTEGER, defaultValue: 0 }
}, { tableName: 'ping_results', timestamps: false });

const NetworkEvent = sequelize.define('NetworkEvent', {
  timestamp: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  event_time: DataTypes.DATE,
  event_type: DataTypes.STRING,
  message: DataTypes.TEXT
}, { tableName: 'network_events', timestamps: false });

async function initDB() {
  await sequelize.sync();
}

module.exports = { sequelize, NetworkStatus, PingResult, NetworkEvent, initDB };
