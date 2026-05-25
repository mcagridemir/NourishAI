// Sana — AuthServiceTests.swift
// Tests run serially because AuthService is a @MainActor singleton
// and all tests share the same Keychain space.
import Testing
@testable import Sana

@Suite("AuthService", .serialized)
@MainActor
struct AuthServiceTests {

    private let auth = AuthService.shared

    init() {
        // Reset all auth state before each test
        auth.signOut()
        KeychainService.delete(for: .userEmail)
        KeychainService.delete(for: .authPasswordHash)
        auth.authError = nil
    }

    // MARK: - Initial state after sign-out

    @Test("signOut puts service in signedOut state")
    func initialStateAfterSignOut() {
        if case .signedOut = auth.state { } else {
            Issue.record("Expected .signedOut, got \(auth.state)")
        }
    }

    // MARK: - Email registration

    @Test("registration with valid credentials succeeds")
    func registerSuccess() {
        auth.register(email: "test@example.com", password: "SecurePass1")
        if case .signedIn(let id, let provider) = auth.state {
            #expect(id == "email_test@example.com")
            #expect(provider == .email)
        } else {
            Issue.record("Expected .signedIn after register, got \(auth.state)")
        }
        #expect(auth.authError == nil)
    }

    @Test("registration stores email in Keychain")
    func registerStoresEmail() {
        auth.register(email: "stored@example.com", password: "Password123")
        #expect(KeychainService.load(for: .userEmail) == "stored@example.com")
    }

    @Test("registration with invalid email sets authError")
    func registerInvalidEmail() {
        auth.register(email: "not-an-email", password: "Password123")
        #expect(auth.authError != nil)
        if case .signedOut = auth.state { } else {
            Issue.record("Should remain signed out after invalid email")
        }
    }

    @Test("registration with short password sets authError")
    func registerShortPassword() {
        auth.register(email: "ok@example.com", password: "short")
        #expect(auth.authError != nil)
        if case .signedOut = auth.state { } else {
            Issue.record("Should remain signed out after weak password")
        }
    }

    @Test("registration with exactly 8-char password succeeds")
    func registerMinimumPassword() {
        auth.register(email: "min@example.com", password: "12345678")
        #expect(auth.authError == nil)
    }

    @Test("duplicate registration on same device sets authError")
    func registerDuplicate() {
        auth.register(email: "dup@example.com", password: "Password123")
        auth.authError = nil
        auth.register(email: "dup@example.com", password: "Password123")
        #expect(auth.authError != nil)
    }

    // MARK: - Email sign-in

    @Test("sign-in with correct credentials succeeds")
    func signInSuccess() {
        auth.register(email: "login@example.com", password: "Correct99!")
        auth.signOut()
        auth.signIn(email: "login@example.com", password: "Correct99!")
        if case .signedIn(_, let provider) = auth.state {
            #expect(provider == .email)
        } else {
            Issue.record("Expected .signedIn, got \(auth.state)")
        }
        #expect(auth.authError == nil)
    }

    @Test("sign-in is case-insensitive on email")
    func signInCaseInsensitive() {
        auth.register(email: "case@example.com", password: "Password99")
        auth.signOut()
        auth.signIn(email: "CASE@EXAMPLE.COM", password: "Password99")
        if case .signedIn = auth.state { } else {
            Issue.record("Sign-in should succeed with uppercase email")
        }
    }

    @Test("sign-in with wrong password sets authError")
    func signInWrongPassword() {
        auth.register(email: "wrong@example.com", password: "CorrectPass1")
        auth.signOut()
        auth.signIn(email: "wrong@example.com", password: "WrongPass99")
        #expect(auth.authError != nil)
        if case .signedOut = auth.state { } else {
            Issue.record("Should remain signed out after wrong password")
        }
    }

    @Test("sign-in with unknown email sets authError")
    func signInUnknownEmail() {
        auth.signIn(email: "nobody@example.com", password: "AnyPassword1")
        #expect(auth.authError != nil)
    }

    // MARK: - Sign out

    @Test("signOut clears auth state")
    func signOutClearsState() {
        auth.register(email: "out@example.com", password: "Password123")
        auth.signOut()
        if case .signedOut = auth.state { } else {
            Issue.record("Expected .signedOut after signOut")
        }
    }

    @Test("signOut clears stored userID from Keychain")
    func signOutClearsKeychain() {
        auth.register(email: "clear@example.com", password: "Password123")
        auth.signOut()
        #expect(KeychainService.load(for: .authUserID) == nil)
        #expect(KeychainService.load(for: .authProvider) == nil)
    }

    // MARK: - currentUserID

    @Test("currentUserID returns nil when signed out")
    func currentUserIDNilWhenSignedOut() {
        #expect(auth.currentUserID == nil)
    }

    @Test("currentUserID returns expected value when signed in")
    func currentUserIDAfterSignIn() {
        auth.register(email: "id@example.com", password: "Password123")
        #expect(auth.currentUserID == "email_id@example.com")
    }
}
