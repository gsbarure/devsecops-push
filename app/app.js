'use strict';

const express = require('express');
const app     = express();
const PORT    = process.env.PORT || 3000;
const VERSION = process.env.APP_VERSION || '1.0.0';

app.use(express.json());

// Main route
app.get('/', (req, res) => {
  res.json({ message: 'DevSecOps App', version: VERSION, status: 'running' });
});

// Health endpoint — liveness probe
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Readiness endpoint — readiness probe
app.get('/ready', (req, res) => {
  res.status(200).json({ status: 'ready', timestamp: new Date().toISOString() });
});

// Info endpoint
app.get('/info', (req, res) => {
  res.json({
    app:     'devsecops-app',
    version: VERSION,
    node:    process.version,
    uptime:  process.uptime()
  });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

module.exports = app;
