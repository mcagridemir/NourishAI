# Sana AI Proxy — Cloudflare Worker

Proxies Claude API calls from the iOS app so the Anthropic key never lives in the binary.

## First-time setup

```bash
# 1. Install Wrangler (Cloudflare's CLI)
npm install -g wrangler

# 2. Log in to your Cloudflare account
wrangler login

# 3. Set secrets (you'll be prompted to paste each value)
wrangler secret put ANTHROPIC_API_KEY   # your sk-ant-api03-... key
wrangler secret put APP_SECRET          # see step 4

# 4. Generate a random app secret and note it — you'll paste it in step 6:
python3 -c "import secrets; print(secrets.token_hex(32))"

# 5. Deploy
wrangler deploy

# 6. Copy the worker URL printed by Wrangler (e.g. https://sana-ai-proxy.YOUR.workers.dev)
#    Open Sana/Core/Config/BackendConfig.swift and:
#      - Set proxyURL to your worker URL
#      - Set appSecret to the hex string from step 4
```

## Local development

```bash
wrangler dev
# The worker runs at http://localhost:8787 — you can point BackendConfig.proxyURL there for simulator testing.
```

## Updating the Anthropic key

```bash
wrangler secret put ANTHROPIC_API_KEY
# No redeploy needed — secrets are hot-swapped.
```
