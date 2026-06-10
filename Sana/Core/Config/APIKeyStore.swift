// Sana — APIKeyStore.swift
//
// The Claude API key is stored XOR-obfuscated so it does NOT appear as a
// plain string in the compiled binary or in Info.plist.
//
// ⚠️  To set up your own key:
//   1. Run:  python3 Scripts/generate_api_key.py "sk-ant-api03-YOUR_KEY"
//   2. Paste the output arrays below and delete the placeholder empty arrays.
//
// Long-term goal: replace this with a backend proxy so the key never
// ships in the client binary at all.
import Foundation

enum APIKeyStore {

    // MARK: - Claude

    static let claudeAPIKey: String = {
        let bytes = zip(_claudeObfuscated, _claudeSalt).map { $0 ^ $1 }
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }()

    // Fill these in by running Scripts/generate_api_key.py with your key.
    private static let _claudeObfuscated: [UInt8] = []

    private static let _claudeSalt: [UInt8] = []

    // MARK: - Decoder

    private static func decode(obfuscated: [UInt8], salt: [UInt8]) -> String {
        let bytes = zip(obfuscated, salt).map { $0 ^ $1 }
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }
}
