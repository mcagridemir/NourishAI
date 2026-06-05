/**
 * Sana AI Proxy — Cloudflare Worker
 *
 * Routes:
 *   POST /                    → Anthropic proxy (authenticated, rate-limited, quota-enforced)
 *   POST /webhook/appstore    → App Store Server Notifications receiver
 *   OPTIONS *                 → CORS preflight
 *
 * Required secrets (set once via Wrangler CLI):
 *   wrangler secret put ANTHROPIC_API_KEY   # sk-ant-api03-...
 *   wrangler secret put APP_SECRET          # hex token, mirrors BackendConfig.appSecret
 *
 * Required KV namespace (create once, paste IDs into wrangler.toml):
 *   wrangler kv namespace create "RATE_KV"
 *   wrangler kv namespace create "RATE_KV" --preview
 *
 * Optional env vars (wrangler.toml [vars]):
 *   RATE_LIMIT_PER_MINUTE = "30"    # per-IP soft cap (default 30)
 *   DAILY_AI_QUOTA        = "100"   # per user-ID per UTC day (default 100)
 *
 * App Store notifications webhook:
 *   Set the URL in App Store Connect → App Information → App Store Server Notifications
 *   → Production URL: https://sana-ai-proxy.cagriidemirr.workers.dev/webhook/appstore
 */

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // ── CORS preflight ───────────────────────────────────────────────────────
    if (request.method === 'OPTIONS') {
      return corsResponse(null, 204);
    }

    // ── Route dispatch ───────────────────────────────────────────────────────
    if (url.pathname === '/webhook/appstore') {
      return handleAppStoreWebhook(request, env);
    }

    return handleProxy(request, env);
  },
};

// ── Anthropic proxy ──────────────────────────────────────────────────────────

async function handleProxy(request, env) {
  if (request.method !== 'POST') {
    return corsResponse('Method not allowed', 405);
  }

  // Authenticate app
  const appSecret = request.headers.get('X-App-Secret');
  if (!appSecret || appSecret !== env.APP_SECRET) {
    return corsResponse('Unauthorized', 401);
  }

  // Per-IP rate limiting (KV-backed, survives instance recycling)
  const ip = request.headers.get('CF-Connecting-IP') ?? 'unknown';
  const ipLimit = parseInt(env.RATE_LIMIT_PER_MINUTE ?? '30', 10);
  if (!(await allowByIP(ip, ipLimit, env))) {
    return corsResponse('Rate limit exceeded', 429);
  }

  // Per-user daily quota (KV-backed, keyed by app-supplied user ID)
  const userID = request.headers.get('X-User-ID');
  if (userID) {
    const dailyQuota = parseInt(env.DAILY_AI_QUOTA ?? '100', 10);
    if (!(await allowByUser(userID, dailyQuota, env))) {
      return corsResponse('Daily quota exceeded', 429);
    }
  }

  // Validate & forward body
  let body;
  try {
    body = await request.text();
    JSON.parse(body); // reject obviously malformed payloads early
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

  // Stream response back unchanged
  const contentType = upstream.headers.get('Content-Type') ?? 'application/json';
  return new Response(upstream.body, {
    status: upstream.status,
    headers: {
      'Content-Type':                contentType,
      'Access-Control-Allow-Origin': '*',
      // Forward Anthropic's retry-after on their own 429s
      ...(upstream.status === 429 && upstream.headers.get('retry-after')
        ? { 'Retry-After': upstream.headers.get('retry-after') }
        : {}),
    },
  });
}

// ── App Store Server Notifications ───────────────────────────────────────────
//
// Apple sends a signed JWS (JSON Web Signature) in compact form:
//   { "signedPayload": "<header>.<payload>.<signature>" }
//
// We decode the payload segment (Base64URL → JSON) to extract the notification
// type and signed transaction info, then store the subscription status in KV.
// Full certificate-chain verification is omitted for v1 — Apple retries on
// non-200 responses, so failures are safe.

async function handleAppStoreWebhook(request, env) {
  if (request.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  let notifPayload;
  try {
    const body = await request.json();
    notifPayload = decodeJWS(body?.signedPayload ?? '');
  } catch {
    return new Response('Bad Request', { status: 400 });
  }

  const { notificationType, subtype, data } = notifPayload ?? {};

  // Decode the per-transaction JWS to get the original transaction ID
  try {
    if (data?.signedTransactionInfo) {
      const tx = decodeJWS(data.signedTransactionInfo);
      const tid = tx?.originalTransactionId;
      const expiresDate = tx?.expiresDate; // ms since epoch (may be undefined for consumables)

      const statusMap = {
        SUBSCRIBED:                 'active',
        DID_RENEW:                  'active',
        DID_CHANGE_RENEWAL_STATUS:  subtype === 'AUTO_RENEW_DISABLED' ? 'cancelled' : 'active',
        DID_FAIL_TO_RENEW:          subtype === 'GRACE_PERIOD'        ? 'grace'     : 'billing_retry',
        EXPIRED:                    'expired',
        GRACE_PERIOD_EXPIRED:       'expired',
        REFUND:                     'refunded',
        REVOKE:                     'revoked',
      };
      const status = statusMap[notificationType] ?? 'unknown';

      if (env.RATE_KV && tid) {
        const record = JSON.stringify({
          status,
          expiresDate,
          notificationType,
          subtype: subtype ?? null,
          updatedAt: Date.now(),
        });
        // 90-day TTL — covers even the longest billing grace + retry period
        await env.RATE_KV.put(`sub:${tid}`, record, { expirationTtl: 90 * 86_400 });
      }
    }
  } catch {
    // Non-fatal: return 200 so Apple doesn't retry a malformed notification
  }

  return new Response('OK', { status: 200 });
}

// ── Rate-limiting helpers (KV-backed) ────────────────────────────────────────
//
// KV is eventually consistent and does not support atomic increments, so the
// read-increment-write pattern below has a soft race window. For a rate limiter
// on a nutrition app this is acceptable — the limit is a protection measure,
// not a hard billing cap.

async function allowByIP(ip, limitPerMinute, env) {
  if (!env.RATE_KV) return true; // KV not yet provisioned — fail open
  const window = Math.floor(Date.now() / 60_000); // 1-minute bucket
  const key = `rl:ip:${ip}:${window}`;
  try {
    const current = parseInt((await env.RATE_KV.get(key)) ?? '0', 10);
    if (current >= limitPerMinute) return false;
    await env.RATE_KV.put(key, String(current + 1), { expirationTtl: 120 }); // 2-min TTL
    return true;
  } catch {
    return true; // KV error → fail open
  }
}

async function allowByUser(userID, dailyQuota, env) {
  if (!env.RATE_KV) return true;
  const dayKey = new Date().toISOString().slice(0, 10); // YYYY-MM-DD UTC
  const key = `rl:user:${userID}:${dayKey}`;
  try {
    const current = parseInt((await env.RATE_KV.get(key)) ?? '0', 10);
    if (current >= dailyQuota) return false;
    await env.RATE_KV.put(key, String(current + 1), { expirationTtl: 172_800 }); // 48h
    return true;
  } catch {
    return true;
  }
}

// ── JWS decoder ──────────────────────────────────────────────────────────────

function decodeJWS(token) {
  const parts = token.split('.');
  if (parts.length !== 3) throw new Error('Invalid JWS: expected 3 segments');
  // Base64URL → Base64 → JSON
  const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
  const padded = base64 + '='.repeat((4 - (base64.length % 4)) % 4);
  return JSON.parse(atob(padded));
}

// ── CORS helper ───────────────────────────────────────────────────────────────

function corsResponse(body, status) {
  return new Response(body, {
    status,
    headers: {
      'Content-Type':                 'text/plain',
      'Access-Control-Allow-Origin':  '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, X-App-Secret, X-User-ID, anthropic-version',
    },
  });
}
