const http = require('http');

const PORT = process.env.PORT || 3000;
const ENV = process.env.ENV || 'dev';
const VERSION = process.env.APP_VERSION || '1.0.0';

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    message: 'Weather App Running',
    environment: ENV,
    version: VERSION,
    timestamp: new Date().toISOString()
  }));
});

server.listen(PORT, () => {
  console.log(`Weather App v${VERSION} running on port ${PORT} in ${ENV} environment`);
});