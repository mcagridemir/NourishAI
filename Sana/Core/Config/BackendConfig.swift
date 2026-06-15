// Sana — BackendConfig.swift
// Switch between direct Anthropic API and the Cloudflare Worker proxy.
// See Backend/README.md for deployment instructions.

import Foundation

nonisolated enum BackendConfig {

    // MARK: - Proxy

    // After `wrangler deploy`, paste your worker URL here and set appSecret.
    // Leaving proxyURL nil keeps the current direct-API behaviour.
    static let proxyURL: URL? = URL(string: "https://sana-ai-proxy.cagriidemirr.workers.dev")

    // Must match APP_SECRET set via `wrangler secret put APP_SECRET`.
    // Set via `wrangler secret put APP_SECRET` — never commit the real value here.
    static let appSecret: String = ""

    // MARK: - CloudKit

    // iCloud.com.cagri.Sana is provisioned. After first run on device the
    // SwiftData schema will be pushed to CloudKit Development environment.
    // Run "Deploy Schema to Production" in CloudKit Console before App Store release.
    static let cloudKitEnabled: Bool = true
}
