// Sana — GoogleSignInService.swift
// Native Google Sign-In via ASWebAuthenticationSession + PKCE.
// No GoogleSignIn SDK required — reads CLIENT_ID straight from GoogleService-Info.plist.
//
// Setup (one-time):
//  1. Firebase Console → Authentication → Sign-in method → Enable Google
//  2. Download the updated GoogleService-Info.plist (it will contain CLIENT_ID)
//  3. Replace the plist in the project root

import AuthenticationServices
import CryptoKit
internal import UIKit

@MainActor
final class GoogleSignInService: NSObject {

    static let shared = GoogleSignInService()
    private override init() { super.init() }

    // MARK: - Types

    struct GoogleUser {
        let id: String
        let email: String
        let name: String
    }

    enum GoogleSignInError: LocalizedError {
        case missingClientID
        case cancelled
        case invalidCallback
        case tokenExchangeFailed(String)
        case invalidIDToken

        var errorDescription: String? {
            switch self {
            case .missingClientID:
                return "Google Sign-In is not configured yet. Please enable it in Firebase Console first."
            case .cancelled:
                return nil
            case .invalidCallback:
                return "Invalid response received from Google."
            case .tokenExchangeFailed(let msg):
                return "Google sign-in failed: \(msg)"
            case .invalidIDToken:
                return "Could not read your Google account information."
            }
        }
    }

    // MARK: - Config (read from GoogleService-Info.plist at runtime)

    private var clientID: String {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let id = dict["CLIENT_ID"] as? String,
              !id.isEmpty else {
            return ""
        }
        return id
    }

    private var reversedClientID: String {
        // e.g. "123456-abc.apps.googleusercontent.com" → "com.googleusercontent.apps.123456-abc"
        let parts = clientID.components(separatedBy: ".")
        return parts.reversed().joined(separator: ".")
    }

    // MARK: - Sign In

    private var _session: ASWebAuthenticationSession?
    private let contextProvider = _PresentationContextProvider()

    func signIn() async throws -> GoogleUser {
        guard !clientID.isEmpty else { throw GoogleSignInError.missingClientID }

        let redirectScheme = reversedClientID
        let redirectURI   = "\(redirectScheme):/oauth2redirect/google"

        // PKCE
        let verifier  = makePKCEVerifier()
        let challenge = makePKCEChallenge(from: verifier)

        guard var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth") else {
            throw GoogleSignInError.invalidCallback
        }
        components.queryItems = [
            URLQueryItem(name: "client_id",             value: clientID),
            URLQueryItem(name: "redirect_uri",          value: redirectURI),
            URLQueryItem(name: "response_type",         value: "code"),
            URLQueryItem(name: "scope",                 value: "openid profile email"),
            URLQueryItem(name: "code_challenge",        value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        guard let authURL = components.url else {
            throw GoogleSignInError.invalidCallback
        }

        let callbackURL: URL = try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: redirectScheme
            ) { url, error in
                if let error = error {
                    let asError = (error as? ASWebAuthenticationSessionError)?.code
                    cont.resume(throwing: asError == .canceledLogin
                        ? GoogleSignInError.cancelled
                        : error)
                } else if let url = url {
                    cont.resume(returning: url)
                } else {
                    cont.resume(throwing: GoogleSignInError.invalidCallback)
                }
            }
            session.presentationContextProvider = contextProvider
            session.prefersEphemeralWebBrowserSession = false
            _session = session
            session.start()
        }

        _session = nil

        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value else {
            throw GoogleSignInError.invalidCallback
        }

        return try await exchangeCode(code, verifier: verifier, redirectURI: redirectURI)
    }

    // MARK: - Token exchange

    private func exchangeCode(_ code: String, verifier: String, redirectURI: String) async throws -> GoogleUser {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params: [(String, String)] = [
            ("code",          code),
            ("client_id",     clientID),
            ("redirect_uri",  redirectURI),
            ("grant_type",    "authorization_code"),
            ("code_verifier", verifier),
        ]
        request.httpBody = params
            .map { "\($0.0)=\($0.1.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idToken = json["id_token"] as? String else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error_description"] as? String
                ?? String(data: data, encoding: .utf8)
                ?? "Unknown error"
            throw GoogleSignInError.tokenExchangeFailed(msg)
        }

        return try decodeIDToken(idToken)
    }

    // MARK: - JWT payload decode (signature not checked — token came directly from Google's endpoint)

    private func decodeIDToken(_ token: String) throws -> GoogleUser {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else { throw GoogleSignInError.invalidIDToken }

        var payload = parts[1]
        // Base64URL → Base64
        payload = payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload += "=" }

        guard let data   = Data(base64Encoded: payload),
              let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub    = claims["sub"]   as? String,
              let email  = claims["email"] as? String else {
            throw GoogleSignInError.invalidIDToken
        }

        let name = (claims["name"] as? String)
            ?? email.components(separatedBy: "@").first
            ?? "User"

        return GoogleUser(id: "google_\(sub)", email: email, name: name)
    }

    // MARK: - PKCE helpers

    private func makePKCEVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func makePKCEChallenge(from verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Presentation context (non-isolated helper so protocol conformance is fine)

private final class _PresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
            ?? ASPresentationAnchor()
    }
}
