require('dotenv').config();
const express = require('express');
const cors = require('cors');
const net = require('net');
const cron = require('node-cron');
const { Op } = require('sequelize');
const { NetworkStatus, PingResult, NetworkEvent, initDB } = require('./models');

const app = express();
const PORT = process.env.PORT || 5000;
const ROUTER_IP = process.env.ROUTER_IP || '192.168.1.1';
const ROUTER_PORT = process.env.ROUTER_PORT || '8321';
const ROUTER_TOKEN = process.env.ROUTER_TOKEN || '';
const POLL_INTERVAL = parseInt(process.env.POLL_INTERVAL || '60');

app.use(cors());
app.use(express.json());
app.use(express.static('public'));

async function fetchRouterData() {
  return new Promise((resolve) => {
    const client = net.createConnection({ host: ROUTER_IP, port: ROUTER_PORT }, () => {
      const authHeader = ROUTER_TOKEN && ROUTER_TOKEN.trim() ? `Authorization: Bearer ${ROUTER_TOKEN}\r\n` : '';
      client.write(`GET /net/status HTTP/1.1\r\nHost: ${ROUTER_IP}\r\n${authHeader}Connection: close\r\n\r\n`);
    });

    let rawData = '';
    client.on('data', (chunk) => { rawData += chunk.toString(); });
    client.on('end', () => {
      try {
        const jsonStart = rawData.indexOf('{');
        if (jsonStart === -1) throw new Error('No JSON found');
        const data = JSON.parse(rawData.substring(jsonStart));
        resolve(data);
      } catch (error) {
        console.error('Failed to parse router data:', error.message);
        resolve(null);
      }
    });
    client.on('error', (error) => {
      console.error('Failed to fetch router data:', error.message);
      resolve(null);
    });
  });
}

async function saveNetworkStatus(data) {
  if (!data?.realtime) return;

  const { realtime, summary = {}, events = [] } = data;
  const timestamp = new Date();

  await NetworkStatus.create({
    timestamp,
    wan_state: realtime.wan_state,
    rx_errors: realtime.wan_errors?.rx_errors || 0,
    tx_errors: realtime.wan_errors?.tx_errors || 0,
    rx_dropped: realtime.wan_errors?.rx_dropped || 0,
    tx_dropped: realtime.wan_errors?.tx_dropped || 0,
    optical_rx: realtime.optical_power?.rx,
    optical_tx: realtime.optical_power?.tx,
    cpu_temp: realtime.cpu_temp,
    pppoe_reconnect_count: summary.pppoe_reconnect_count_24h || 0,
    wan_down_count: summary.wan_down_count_24h || 0
  });

  if (realtime.ping) {
    for (const [target, ping] of Object.entries(realtime.ping)) {
      await PingResult.create({ timestamp, target, rtt: ping.rtt, loss: ping.loss || 0 });
    }
  }

  for (const event of events) {
    const eventTime = event.time ? new Date(event.time) : timestamp;
    const existing = await NetworkEvent.findOne({
      where: { event_time: eventTime, event_type: event.type || 'unknown' }
    });
    if (existing) continue;

    await NetworkEvent.create({
      event_time: eventTime,
      event_type: event.type || 'unknown',
      message: event.message || ''
    });
  }
}

async function scheduledFetch() {
  const data = await fetchRouterData();
  if (data) await saveNetworkStatus(data);
}

app.get('/', (req, res) => {
  res.sendFile(__dirname + '/public/index.html');
});

app.get('/health', async (req, res) => {
  try {
    await NetworkStatus.findOne();
    res.json({ status: 'healthy', timestamp: new Date().toISOString() });
  } catch (error) {
    res.status(503).json({ status: 'unhealthy', error: error.message });
  }
});

app.get('/api/status', async (req, res) => {
  const data = await fetchRouterData();
  data ? res.json(data) : res.status(503).json({ error: 'Failed to fetch from router' });
});

app.get('/api/ping_history', async (req, res) => {
  const hours = parseInt(req.query.hours || '24');
  const cutoff = new Date(Date.now() - hours * 3600000);
  const records = await PingResult.findAll({
    where: { timestamp: { [Op.gte]: cutoff } },
    order: [['timestamp', 'DESC']],
    limit: 500
  });
  res.json({ status: 'success', records });
});

app.get('/api/events', async (req, res) => {
  const limit = parseInt(req.query.limit || '50');
  const records = await NetworkEvent.findAll({
    order: [['event_time', 'DESC']],
    limit,
    raw: true
  });
  const formatted = records.map(r => ({ ...r, type: r.event_type }));
  res.json({ status: 'success', records: formatted });
});

app.get('/api/stats/summary', async (req, res) => {
  const hours = parseInt(req.query.hours || '24');
  const cutoff = new Date(Date.now() - hours * 3600000);

  const [totalPing, lossPing, wanUpCount, totalCount, pppoeEvents, wanEvents] = await Promise.all([
    PingResult.count({ where: { timestamp: { [Op.gte]: cutoff } } }),
    PingResult.count({ where: { timestamp: { [Op.gte]: cutoff }, loss: { [Op.gt]: 0 } } }),
    NetworkStatus.count({ where: { timestamp: { [Op.gte]: cutoff }, wan_state: 'up' } }),
    NetworkStatus.count({ where: { timestamp: { [Op.gte]: cutoff } } }),
    NetworkEvent.count({ where: { event_time: { [Op.gte]: cutoff }, event_type: { [Op.like]: 'pppoe%' } } }),
    NetworkEvent.count({ where: { event_time: { [Op.gte]: cutoff }, event_type: { [Op.like]: '%wan%' } } })
  ]);

  const avgTemp = await NetworkStatus.findOne({
    attributes: [[require('sequelize').fn('AVG', require('sequelize').col('cpu_temp')), 'avg']],
    where: { timestamp: { [Op.gte]: cutoff }, cpu_temp: { [Op.ne]: null } },
    raw: true
  });

  res.json({
    status: 'success',
    summary: {
      wan_availability: totalCount > 0 ? (wanUpCount / totalCount * 100) : 0,
      packet_loss_rate: totalPing > 0 ? (lossPing / totalPing * 100) : 0,
      avg_cpu_temp: avgTemp?.avg ? Math.round(avgTemp.avg * 10) / 10 : null,
      pppoe_events: pppoeEvents,
      wan_events: wanEvents
    }
  });
});

app.get('/api/fetch_now', async (req, res) => {
  const data = await fetchRouterData();
  if (data) {
    await saveNetworkStatus(data);
    res.json({ status: 'success', message: 'Data fetched and saved' });
  } else {
    res.status(503).json({ status: 'error', message: 'Failed to fetch from router' });
  }
});

initDB().then(() => {
  cron.schedule(`*/${POLL_INTERVAL} * * * * *`, scheduledFetch);
  scheduledFetch();
  app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
});
