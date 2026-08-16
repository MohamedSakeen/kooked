import { describe, it, before, after } from 'node:test';
import assert from 'node:assert';
import express from 'express';

let server;
let BASE_URL;

function createTestApp() {
  const app = express();
  app.use(express.json());

  app.get('/health', (req, res) => {
    res.json({
      status: 'ok',
      service: 'KooKed API',
      timestamp: new Date().toISOString(),
    });
  });

  app.post('/api/gemini/chat', (req, res) => {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Missing or invalid authorization header' });
    }
    res.json({ reply: 'test' });
  });

  app.post('/api/gemini/vision', (req, res) => {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Missing or invalid authorization header' });
    }
    if (!req.body.image) {
      return res.status(400).json({ error: 'Image data required' });
    }
    res.json({ items: [] });
  });

  app.post('/api/gemini/ocr', (req, res) => {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Missing or invalid authorization header' });
    }
    res.json({ items: [] });
  });

  app.post('/api/gemini/recipe', (req, res) => {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Missing or invalid authorization header' });
    }
    res.json({ recipe: {} });
  });

  app.post('/api/gemini/estimate', (req, res) => {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Missing or invalid authorization header' });
    }
    res.json({ estimates: [] });
  });

  return app;
}

before(async () => {
  const app = createTestApp();
  await new Promise((resolve) => {
    server = app.listen(0, () => {
      const port = server.address().port;
      BASE_URL = `http://localhost:${port}`;
      resolve();
    });
  });
});

after(() => {
  server?.close();
});

async function request(method, path, { body, headers } = {}) {
  const url = `${BASE_URL}${path}`;
  const opts = {
    method,
    headers: { 'Content-Type': 'application/json', ...headers },
  };
  if (body) opts.body = JSON.stringify(body);
  const res = await fetch(url, opts);
  const json = await res.json().catch(() => null);
  return { status: res.status, json };
}

describe('Health endpoint', () => {
  it('GET /health returns 200 with status ok', async () => {
    const { status, json } = await request('GET', '/health');
    assert.strictEqual(status, 200);
    assert.strictEqual(json.status, 'ok');
    assert.strictEqual(json.service, 'KooKed API');
    assert.ok(json.timestamp);
  });
});

describe('Gemini endpoints — auth required', () => {
  it('POST /api/gemini/chat returns 401 without token', async () => {
    const { status, json } = await request('POST', '/api/gemini/chat');
    assert.strictEqual(status, 401);
    assert.ok(json.error);
  });

  it('POST /api/gemini/vision returns 401 without token', async () => {
    const { status, json } = await request('POST', '/api/gemini/vision');
    assert.strictEqual(status, 401);
    assert.ok(json.error);
  });

  it('POST /api/gemini/ocr returns 401 without token', async () => {
    const { status, json } = await request('POST', '/api/gemini/ocr');
    assert.strictEqual(status, 401);
    assert.ok(json.error);
  });

  it('POST /api/gemini/recipe returns 401 without token', async () => {
    const { status, json } = await request('POST', '/api/gemini/recipe');
    assert.strictEqual(status, 401);
    assert.ok(json.error);
  });

  it('POST /api/gemini/estimate returns 401 without token', async () => {
    const { status, json } = await request('POST', '/api/gemini/estimate');
    assert.strictEqual(status, 401);
    assert.ok(json.error);
  });

  it('POST /api/gemini/chat accepts valid bearer token', async () => {
    const { status, json } = await request('POST', '/api/gemini/chat', {
      headers: { Authorization: 'Bearer fake-token-for-test' },
      body: { message: 'Hello' },
    });
    assert.strictEqual(status, 200);
    assert.ok(json.reply);
  });

  it('POST /api/gemini/vision rejects missing image', async () => {
    const { status, json } = await request('POST', '/api/gemini/vision', {
      headers: { Authorization: 'Bearer fake-token-for-test' },
      body: {},
    });
    assert.strictEqual(status, 400);
    assert.ok(json.error.includes('Image'));
  });
});
