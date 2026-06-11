// Sana — AuthView.swift
import SwiftUI
import AuthenticationServices

struct AuthView: View {

    @EnvironmentObject private var auth: AuthService
    @State private var showingEmailAuth = false

    var body: some View {
        ZStack {
            SanaTheme.Color.background.ignoresSafeArea()

            // Decorative blobs
            Circle()
                .fill(SanaTheme.Color.primary.opacity(0.06))
                .frame(width: 320, height: 320)
                .offset(x: -80, y: -320)
                .ignoresSafeArea()
            Circle()
                .fill(SanaTheme.Color.accent.opacity(0.05))
                .frame(width: 200, height: 200)
                .offset(x: 120, y: -280)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // MARK: - Brand
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(SanaTheme.Color.primaryLight)
                            .frame(width: 88, height: 88)
                        Circle()
                            .fill(LinearGradient(
                                colors: [SanaTheme.Color.primary, SanaTheme.Color.primaryDeep],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 72, height: 72)
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: SanaTheme.Color.primary.opacity(0.25), radius: 16, y: 8)

                    Text("Sana")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .kerning(-0.8)
                    Text("Your personal AI nutrition coach")
                        .font(SanaTheme.Font.body())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 28)

                // MARK: - Feature highlights
                VStack(spacing: 8) {
                    AuthFeatureRow(icon: "camera.viewfinder",
                                   color: SanaTheme.Color.primary,
                                   title: "Snap any meal",
                                   sub: "AI estimates calories & macros instantly")
                    AuthFeatureRow(icon: "sparkles",
                                   color: SanaTheme.Color.accent,
                                   title: "AI nutrition coach",
                                   sub: "Personalised plans, goals & weekly insights")
                    AuthFeatureRow(icon: "heart.fill",
                                   color: .pink,
                                   title: "Apple Health sync",
                                   sub: "Steps, sleep & activity in one view")
                }
                .padding(.horizontal, SanaTheme.Spacing.lg)
                .padding(.bottom, 28)

                // MARK: - Sign-in buttons
                VStack(spacing: 12) {

                    // Apple Sign In
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        HapticService.impact(.medium)
                        auth.handleAppleResult(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.xl))

                    // Google Sign-In via ASWebAuthenticationSession + PKCE.
                    // Requires Google enabled in Firebase Console + updated GoogleService-Info.plist.
                    GoogleSignInButton()

                    // Divider
                    HStack {
                        Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
                        Text("or").font(SanaTheme.Font.caption()).foregroundStyle(.secondary).padding(.horizontal, 12)
                        Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
                    }

                    // Email
                    Button {
                        HapticService.impact(.light)
                        showingEmailAuth = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 16))
                            Text("Continue with email")
                                .font(SanaTheme.Font.headline())
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(SanaTheme.Color.primary)
                        .overlay(
                            RoundedRectangle(cornerRadius: SanaTheme.Radius.xl)
                                .stroke(SanaTheme.Color.primary, lineWidth: 1.5)
                        )
                    }
                }
                .padding(.horizontal, SanaTheme.Spacing.lg)

                // MARK: - Error
                if let error = auth.authError {
                    Text(error)
                        .font(SanaTheme.Font.caption(12))
                        .foregroundStyle(SanaTheme.Color.danger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SanaTheme.Spacing.lg)
                        .padding(.top, 12)
                }

                // MARK: - Legal
                VStack(spacing: 4) {
                    Text("By continuing you agree to our")
                        .font(SanaTheme.Font.caption(11))
                        .foregroundStyle(.tertiary)
                    HStack(spacing: 4) {
                        Link("Terms of Service", destination: URL(string: "https://sana-pages.pages.dev/terms")!)
                        Text("and")
                        Link("Privacy Policy", destination: URL(string: "https://sana-pages.pages.dev/privacy")!)
                    }
                    .font(SanaTheme.Font.caption(11))
                    .foregroundStyle(SanaTheme.Color.primary)
                }
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showingEmailAuth) {
            EmailAuthView()
        }
    }
}

// MARK: - Auth feature row

private struct AuthFeatureRow: View {
    let icon: String; let color: Color; let title: String; let sub: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SanaTheme.Font.headline(14))
                    .foregroundStyle(.primary)
                Text(sub)
                    .font(SanaTheme.Font.caption(12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(SanaTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: SanaTheme.Radius.md)
            .stroke(SanaTheme.Color.hairline, lineWidth: 0.5))
    }
}

// MARK: - Google Sign-In button

private struct GoogleSignInButton: View {
    @EnvironmentObject private var auth: AuthService
    @State private var isLoading = false

    var body: some View {
        Button {
            guard !isLoading else { return }
            HapticService.impact(.light)
            isLoading = true
            Task {
                await auth.signInWithGoogle()
                isLoading = false  // always reset, even on error
            }
        } label: {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 20)
                } else {
                    // Google "G" logo colours
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 20, height: 20)
                        Text("G")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                    }
                }
                Text(isLoading ? "Signing in…" : "Continue with Google")
                    .font(SanaTheme.Font.headline())
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color(red: 0.26, green: 0.52, blue: 0.96))
            .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.xl))
        }
        .disabled(isLoading)
    }
}

// MARK: - Email auth sheet

struct EmailAuthView: View {

    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    enum Mode { case signIn, register }
    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @FocusState private var focused: Field?

    enum Field { case email, password, confirm }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SanaTheme.Spacing.lg) {

                    // Mode picker
                    Picker("", selection: $mode) {
                        Text("Sign in").tag(Mode.signIn)
                        Text("Create account").tag(Mode.register)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: mode) { _, _ in auth.authError = nil }

                    // Fields
                    VStack(spacing: 12) {
                        NourishTextField(placeholder: "Email address", text: $email)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($focused, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focused = .password }

                        SecureInputField(placeholder: "Password", text: $password)
                            .focused($focused, equals: .password)
                            .submitLabel(mode == .signIn ? .done : .next)
                            .onSubmit {
                                if mode == .register { focused = .confirm } else { submit() }
                            }

                        if mode == .register {
                            SecureInputField(placeholder: "Confirm password", text: $confirmPassword)
                                .focused($focused, equals: .confirm)
                                .submitLabel(.done)
                                .onSubmit { submit() }
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .animation(SanaTheme.Animation.smooth, value: mode)

                    // Error
                    if let error = auth.authError {
                        Text(error)
                            .font(SanaTheme.Font.caption(13))
                            .foregroundStyle(SanaTheme.Color.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Submit
                    Button {
                        focused = nil
                        submit()
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text(mode == .signIn ? "Sign in" : "Create account")
                                    .font(SanaTheme.Font.headline())
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(NourishButtonStyle())
                    .disabled(isLoading || email.isEmpty || password.isEmpty)

                    // Forgot password (sign-in only)
                    if mode == .signIn {
                        Button("Forgot password?") {
                            auth.authError = "Password reset will be available once email sync is set up. Sign in with Apple as an alternative."
                        }
                        .font(SanaTheme.Font.caption(13))
                        .foregroundStyle(SanaTheme.Color.primary)
                    }
                }
                .padding(SanaTheme.Spacing.lg)
            }
            .background(SanaTheme.Color.background)
            .navigationTitle(mode == .signIn ? "Sign in" : "Create account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear { auth.authError = nil }
    }

    private func submit() {
        HapticService.impact(.medium)
        guard !email.isEmpty, !password.isEmpty else { return }
        if mode == .register {
            guard password == confirmPassword else {
                auth.authError = "Passwords don't match."
                HapticService.notification(.error)
                return
            }
            auth.register(email: email, password: password)
        } else {
            auth.signIn(email: email, password: password)
        }
        if auth.authError != nil {
            HapticService.notification(.error)
        }
    }
}

// MARK: - Secure field helper

private struct SecureInputField: View {
    let placeholder: String
    @Binding var text: String
    @State private var isRevealed = false

    var body: some View {
        HStack {
            Group {
                if isRevealed {
                    TextField(placeholder, text: $text)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .font(SanaTheme.Font.body())

            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
            }
            .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
        }
        .padding()
        .background(SanaTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
    }
}
