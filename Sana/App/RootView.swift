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
                ZStack {
                    SanaTheme.Color.background.ignoresSafeArea()
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(SanaTheme.Color.primaryLight)
                                .frame(width: 96, height: 96)
                            Circle()
                                .fill(LinearGradient(
                                    colors: [SanaTheme.Color.primary, SanaTheme.Color.primaryDeep],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                                .frame(width: 80, height: 80)
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: SanaTheme.Color.primary.opacity(0.25), radius: 16, y: 8)
                        Text("Sana")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .kerning(-0.6)
                    }
                    VStack {
                        Spacer()
                        ProgressView()
                            .tint(SanaTheme.Color.primary)
                            .padding(.bottom, 60)
                    }
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
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(SanaTheme.Color.warning)
                    Text("Storage unavailable — data won't be saved this session.")
                        .font(SanaTheme.Font.caption(12))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(SanaTheme.Color.warning.opacity(0.15))
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
