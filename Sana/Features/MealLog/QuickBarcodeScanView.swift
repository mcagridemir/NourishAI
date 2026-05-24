// Sana — QuickBarcodeScanView.swift
// Presented directly from a Quick Action — opens the barcode scanner immediately.
import SwiftUI
import SwiftData

struct QuickBarcodeScanView: View {

    let user: User
    let context: ModelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: MealLogViewModel

    init(user: User, context: ModelContext) {
        self.user = user
        self.context = context
        _vm = StateObject(wrappedValue: MealLogViewModel(user: user, context: context))
    }

    var body: some View {
        Group {
            switch vm.state {
            case .idle:
                // Auto-present barcode scanner
                BarcodeScannerView(
                    onScan: { code in Task { await vm.handleBarcode(code) } },
                    onCancel: { dismiss() }
                )
                .ignoresSafeArea()

            case .analyzing:
                ZStack {
                    Color.black.opacity(0.85).ignoresSafeArea()
                    VStack(spacing: 20) {
                        ProgressView().scaleEffect(1.5).tint(.white)
                        Text("Looking up product…")
                            .font(SanaTheme.Font.headline())
                            .foregroundStyle(.white)
                    }
                }

            case .barcodeResult(let product):
                NavigationStack {
                    ScrollView {
                        BarcodeProductView(
                            product: product,
                            mealType: vm.selectedMealType,
                            allergenWarnings: AllergenChecker.detect(in: product.name, against: user.allergies)
                        ) { grams in
                            vm.saveBarcodeMeal(product: product, grams: grams)
                            dismiss()
                        } onDiscard: { dismiss() }
                        .padding()
                    }
                    .background(SanaTheme.Color.background)
                    .navigationTitle("Product found")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") { dismiss() }
                        }
                    }
                }

            case .error(let msg):
                NavigationStack {
                    VStack(spacing: 20) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("Product not found")
                            .font(SanaTheme.Font.headline(20))
                        Text(msg)
                            .font(SanaTheme.Font.body(14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Try again") { vm.reset() }
                            .buttonStyle(NourishButtonStyle())
                            .padding(.horizontal, 40)
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }

            default:
                EmptyView()
            }
        }
    }
}
