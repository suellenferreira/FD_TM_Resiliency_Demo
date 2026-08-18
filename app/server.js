const http = require('http');

const port = Number(process.env.PORT || 8080);
const region = process.env.REGION || 'Unknown';
const healthy = (process.env.HEALTHY || 'true').toLowerCase() === 'true';

function sendJson(response, statusCode, payload) {
  response.writeHead(statusCode, { 'Content-Type': 'application/json; charset=utf-8' });
  response.end(`${JSON.stringify(payload)}\n`);
}

http.createServer((request, response) => {
  const payload = {
    app: 'fd-tm-resiliency-demo',
    region,
    hostname: process.env.WEBSITE_HOSTNAME || process.env.HOSTNAME || 'local',
    healthy,
    timestamp: new Date().toISOString()
  };

  if (request.url === '/health') {
    sendJson(response, healthy ? 200 : 503, { status: healthy ? 'healthy' : 'unhealthy', region });
    return;
  }

  if (request.url === '/' || request.url === '/region') {
    sendJson(response, 200, payload);
    return;
  }

  sendJson(response, 404, { error: 'Not found', path: request.url });
}).listen(port, () => {
  console.log(`Demo app listening on port ${port} in ${region}.`);
});
