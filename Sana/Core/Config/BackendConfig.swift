// Sana — BackendConfig.swift
// Switch between direct Anthropic API and the Cloudflare Worker proxy.
// See Backend/README.md for deployment instructions.

import Foundation

enum BackendConfig {

    // MARK: - Proxy

    // After `wrangler deploy`, paste your worker URL here and set appSecret.
    // Leaving proxyURL nil keeps the current direct-API behaviour.
    static let proxyURL: URL? = URL(string: "https://sana-ai-proxy.cagriidemirr.workers.dev")

    // Must match APP_SECRET set via `wrangler secret put APP_SECRET`.
    static let appSecret: String = "f0a41d8b47e79f4ff7b39c966f49ec70018b3bcc967b8072b88c85ed204e71b0"

    // MARK: - CloudKit

    // Developer account active — CloudKit is enabled.
    static let cloudKitEnabled: Bool = true
}
