// Sana — RootView.swift
import SwiftUI
import SwiftData

struct RootView: View {

    @Query private var users: [User]
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var router: AppRouter
    @State private var showingWhatsNew = false

    var body: some View {
        Group {
            if users.isEmpty {
                OnboardingFlowView()
            } else {
                MainTabView(user: users[0])
                    .sheet(isPresented: $router.showingMealLog) {
                        MealLogView(user: users[0], context: context)
                    }
                    .fullScreenCover(isPresented: $router.showingBarcodeScanner) {
                        QuickBarcodeScanView(user: users[0], context: context)
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
    }
}
