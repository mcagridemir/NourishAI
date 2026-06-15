// Sana — AuthService.swift
import Foundation
internal import Combine
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthService: ObservableObject {

    static let shared = AuthService()
    private var stateCancellable: AnyCancellable?

    private init() {
        // Keep ClaudeService in sync with auth state so every proxy request
        // carries the correct X-User-ID header for per-user quota enforcement.
        stateCancellable = $state
            .dropFirst() // skip the initial .loading emission on subscribe
            .sink { newState in
                let userID: String? = {
                    if case .signedIn(let id, _) = newState { return id } else { return nil }
                }()
                Task { await ClaudeService.shared.setUserID(userID) }
            }
    }

    // MARK: - State

    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(userID: String, provider: Provider)
    }

    enum Provider: String {
        case apple, email, google
    }

    @Published private(set) var state: State = .loading
    @Published var authError: String?

    // MARK: - Launch check

    func checkAuthState() async {
        #if DEBUG
        if UITestSupport.isActive {
            state = .signedIn(userID: "uitest", provider: .email)
            return
        }
        #endif
        guard let storedID = KeychainService.load(for: .authUserID),
              let providerRaw = KeychainService.load(for: .authProvider),
              let provider = Provider(rawValue: providerRaw) else {
            state = .signedOut
            return
        }

        if provider == .apple {
            let appleProvider = ASAuthorizationAppleIDProvider()
            if let credState = try? await appleProvider.credentialState(forUserID: storedID),
               credState == .revoked {
                signOut()
                return
            }
        }

        state = .signedIn(userID: storedID, provider: provider)
    }

    // MARK: - Apple Sign In

    func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        authError = nil
        switch result {
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            let userID = cred.user

            KeychainService.save(userID, for: .authUserID)
            KeychainService.save(Provider.apple.rawValue, for: .authProvider)

            // Apple only provides email + name on the very first sign-in.
            if let email = cred.email, !email.isEmpty {
                KeychainService.save(email, for: .userEmail)
            }
            if let name = cred.fullName {
                let full = [name.givenName, name.familyName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
                if !full.isEmpty {
                    UserDefaults.standard.set(full, forKey: "sana.pendingName")
                }
            }
            state = .signedIn(userID: userID, provider: .apple)

        case .failure(let error):
            let code = (error as? ASAuthorizationError)?.code
            if code != .canceled {
                authError = error.localizedDescription
            }
        }
    }

    // MARK: - Email Register

    func register(email: String, password: String) {
        authError = nil
        guard email.contains("@"), email.contains(".") else {
            authError = String(localized: "Enter a valid email address.")
            return
        }
        guard password.count >= 8 else {
            authError = String(localized: "Password must be at least 8 characters.")
            return
        }
        // Prevent duplicate registration on same device
        if let existingEmail = KeychainService.load(for: .userEmail),
           !existingEmail.isEmpty,
           KeychainService.load(for: .authPasswordHash) != nil,
           existingEmail.lowercased() == email.lowercased() {
            authError = String(localized: "An account with this email already exists. Try signing in.")
            return
        }

        let hash = sha256(password)
        KeychainService.save(email.lowercased(), for: .userEmail)
        KeychainService.save(hash, for: .authPasswordHash)

        let userID = "email_\(email.lowercased())"
        KeychainService.save(userID, for: .authUserID)
        KeychainService.save(Provider.email.rawValue, for: .authProvider)
        state = .signedIn(userID: userID, provider: .email)
    }

    // MARK: - Email Sign In

    func signIn(email: String, password: String) {
        authError = nil
        guard let storedEmail = KeychainService.load(for: .userEmail),
              storedEmail == email.lowercased(),
              let storedHash = KeychainService.load(for: .authPasswordHash),
              sha256(password) == storedHash else {
            authError = String(localized: "Email or password is incorrect.")
            return
        }
        let userID = "email_\(email.lowercased())"
        KeychainService.save(userID, for: .authUserID)
        KeychainService.save(Provider.email.rawValue, for: .authProvider)
        state = .signedIn(userID: userID, provider: .email)
    }

    // MARK: - Google Sign In

    func signInWithGoogle() async {
        authError = nil
        do {
            let user = try await GoogleSignInService.shared.signIn()

            KeychainService.save(user.id, for: .authUserID)
            KeychainService.save(Provider.google.rawValue, for: .authProvider)
            if !user.email.isEmpty {
                KeychainService.save(user.email, for: .userEmail)
            }
            if !user.name.isEmpty {
                UserDefaults.standard.set(user.name, forKey: "sana.pendingName")
            }
            state = .signedIn(userID: user.id, provider: .google)

        } catch let error as GoogleSignInService.GoogleSignInError {
            if case .cancelled = error { return }
            authError = error.errorDescription
            HapticService.notification(.error)
        } catch {
            authError = error.localizedDescription
            HapticService.notification(.error)
        }
    }

    // MARK: - Sign Out

    func signOut() {
        KeychainService.delete(for: .authUserID)
        KeychainService.delete(for: .authProvider)
        state = .signedOut
    }

    // MARK: - Helpers

    private func sha256(_ input: String) -> String {
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Convenience

    var currentUserID: String? {
        if case .signedIn(let id, _) = state { return id }
        return nil
    }

    var pendingName: String {
        UserDefaults.standard.string(forKey: "sana.pendingName") ?? ""
    }

    func consumePendingName() -> String {
        let name = pendingName
        UserDefaults.standard.removeObject(forKey: "sana.pendingName")
        return name
    }
}
