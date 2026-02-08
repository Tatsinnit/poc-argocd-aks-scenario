const express = require('express');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 3000;
const VERSION = process.env.APP_VERSION || 'v1.0.0';
const ENVIRONMENT = process.env.ENVIRONMENT || 'development';

// Track server start time for uptime calculation
const startTime = Date.now();

// Middleware for JSON parsing
app.use(express.json());

// Middleware for logging requests
app.use((req, res, next) => {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${req.method} ${req.path} - ${req.ip}`);
  next();
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Hello from AKS with ArgoCD! 🚀',
    timestamp: new Date().toISOString(),
    hostname: os.hostname(),
    environment: ENVIRONMENT,
    version: VERSION
  });
});

// Health check endpoint
app.get('/health', (req, res) => {
  const uptime = Math.floor((Date.now() - startTime) / 1000);
  
  res.json({
    status: 'healthy',
    uptime: uptime,
    timestamp: new Date().toISOString(),
    checks: {
      server: 'ok',
      memory: process.memoryUsage().heapUsed < 100 * 1024 * 1024 ? 'ok' : 'warning'
    }
  });
});

// Version endpoint
app.get('/version', (req, res) => {
  res.json({
    version: VERSION,
    environment: ENVIRONMENT,
    node_version: process.version,
    platform: process.platform,
    hostname: os.hostname()
  });
});

// Info endpoint - returns system information
app.get('/info', (req, res) => {
  res.json({
    application: {
      name: 'sample-app',
      version: VERSION,
      environment: ENVIRONMENT
    },
    system: {
      hostname: os.hostname(),
      platform: os.platform(),
      architecture: os.arch(),
      cpus: os.cpus().length,
      totalMemory: `${Math.round(os.totalmem() / 1024 / 1024)} MB`,
      freeMemory: `${Math.round(os.freemem() / 1024 / 1024)} MB`
    },
    process: {
      nodeVersion: process.version,
      pid: process.pid,
      uptime: `${Math.floor(process.uptime())} seconds`,
      memoryUsage: {
        heapUsed: `${Math.round(process.memoryUsage().heapUsed / 1024 / 1024)} MB`,
        heapTotal: `${Math.round(process.memoryUsage().heapTotal / 1024 / 1024)} MB`
      }
    }
  });
});

// Readiness probe endpoint
app.get('/ready', (req, res) => {
  // In a real application, check database connections, etc.
  const ready = true;
  
  if (ready) {
    res.status(200).json({ status: 'ready' });
  } else {
    res.status(503).json({ status: 'not ready' });
  }
});

// Liveness probe endpoint
app.get('/live', (req, res) => {
  res.status(200).json({ status: 'alive' });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    path: req.path,
    message: 'The requested endpoint does not exist'
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({
    error: 'Internal Server Error',
    message: process.env.NODE_ENV === 'production' ? 'An error occurred' : err.message
  });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log('========================================');
  console.log(`🚀 Server started successfully!`);
  console.log(`📝 Version: ${VERSION}`);
  console.log(`🌍 Environment: ${ENVIRONMENT}`);
  console.log(`🔗 Listening on: http://0.0.0.0:${PORT}`);
  console.log(`💻 Hostname: ${os.hostname()}`);
  console.log('========================================');
  console.log('Available endpoints:');
  console.log(`  GET  /           - Welcome message`);
  console.log(`  GET  /health     - Health check`);
  console.log(`  GET  /version    - Version info`);
  console.log(`  GET  /info       - Detailed info`);
  console.log(`  GET  /ready      - Readiness probe`);
  console.log(`  GET  /live       - Liveness probe`);
  console.log('========================================');
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT signal received: closing HTTP server');
  process.exit(0);
});
