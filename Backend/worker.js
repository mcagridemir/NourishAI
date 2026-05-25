/**
 * Sana AI Proxy — Cloudflare Worker
 *
 * Sits between the iOS app and Anthropic's API so the Anthropic key
 * never lives inside the app binary. The worker validates a shared
 * app secret, swaps in the real Anthropic key, and streams the
 * response back verbatim (SSE-compatible).
 *
 * Required secrets (set once via Wrangler CLI):
 *   wrangler secret put ANTHROPIC_API_KEY   # your sk-ant-api03-... key
 *   wrangler secret put APP_SECRET          # random hex, also in BackendConfig.swift
 *
 * Optional env var (set in wrangler.toml [vars] or dashboard):
 *   RATE_LIMIT_PER_MINUTE = "30"           # requests per IP per minute (default 30)
 */

// In-memory rate-limit store — resets when the worker instance recycles (~minutes).
const rateLimitMap = new Map();

export default {
  async fetch(request, env) {

    // ── CORS preflight ────────────────────────────────────────────────────────
    if (request.method === 'OPTIONS') {
      return corsResponse(null, 204);
    }

    if (request.method !== 'POST') {
      return corsResponse('Method not allowed', 405);
    }

    // ── Authenticate the app ──────────────────────────────────────────────────
    const appSecret = request.headers.get('X-App-Secret');
    if (!appSecret || appSecret !== env.APP_SECRET) {
      return corsResponse('Unauthorized', 401);
    }

    // ── Per-IP rate limiting ──────────────────────────────────────────────────
    const ip = request.headers.get('CF-Connecting-IP') ?? 'unknown';
    const limit = parseInt(env.RATE_LIMIT_PER_MINUTE ?? '30', 10);
    if (!allowRequest(ip, limit)) {
      return corsResponse('Rate limit exceeded', 429);
    }

    // ── Validate & forward body ───────────────────────────────────────────────
    let body;
    try {
      body = await request.text();
      JSON.parse(body); // reject obviously malformed payloads
    } catch {
      return corsResponse('Invalid JSON body', 400);
    }

    const anthropicVersion = request.headers.get('anthropic-version') ?? '2023-06-01';
    const upstream = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type':      'application/json',
        'x-api-key':         env.ANTHROPIC_API_KEY,
        'anthropic-version': anthropicVersion,
      },
      body,
    });

    // ── Stream the response back unchanged ───────────────────────────────────
    const contentType = upstream.headers.get('Content-Type') ?? 'application/json';
    return new Response(upstream.body, {
      status: upstream.status,
      headers: {
        'Content-Type':                contentType,
        'Access-Control-Allow-Origin': '*',
        // Forward Anthropic's retry-after header on 429s
        ...(upstream.status === 429 && upstream.headers.get('retry-after')
          ? { 'Retry-After': upstream.headers.get('retry-after') }
          : {}),
      },
    });
  },
};

// ── Helpers ───────────────────────────────────────────────────────────────────

function corsResponse(body, status) {
  return new Response(body, {
    status,
    headers: {
      'Content-Type':                'text/plain',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, X-App-Secret, anthropic-version',
    },
  });
}

function allowRequest(ip, limitPerMinute) {
  const now = Date.now();
  const windowMs = 60_000;
  const entry = rateLimitMap.get(ip) ?? { count: 0, windowStart: now };
  if (now - entry.windowStart > windowMs) {
    entry.count = 1;
    entry.windowStart = now;
  } else {
    entry.count += 1;
  }
  rateLimitMap.set(ip, entry);
  return entry.count <= limitPerMinute;
}
