// Sana — RootView.swift
import SwiftUI
import SwiftData

struct RootView: View {

    @Query private var users: [User]
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var auth: AuthService
    @State private var showingWhatsNew = false

    var body: some View {
        Group {
            switch auth.state {
            case .loading:
                // Brief splash while Keychain / Apple credential check runs
                ZStack {
                    SanaTheme.Color.background.ignoresSafeArea()
                    ProgressView()
                        .tint(SanaTheme.Color.primary)
                        .scaleEffect(1.2)
                }

            case .signedOut:
                AuthView()

            case .signedIn:
                if users.isEmpty {
                    OnboardingFlowView()
                } else {
                    mainContent(user: users[0])
                }
            }
        }
        .overlay(alignment: .top) {
            if AppContainer.shared.storageIsTemporary {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text("Storage unavailable — data won't be saved this session.")
                        .font(SanaTheme.Font.caption(12))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
                .padding(.top, 8)
            }
        }
        .task { await auth.checkAuthState() }
    }

    @ViewBuilder
    private func mainContent(user: User) -> some View {
        MainTabView(user: user)
            .sheet(isPresented: $router.showingMealLog) {
                MealLogView(user: user, context: context)
            }
            .fullScreenCover(isPresented: $router.showingBarcodeScanner) {
                QuickBarcodeScanView(user: user, context: context)
            }
            .sheet(isPresented: $showingWhatsNew) {
                WhatsNewView()
            }
            .onAppear {
                if WhatsNewView.shouldShow() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        showingWhatsNew = true
                    }
                }
            }
    }
}
