// Sana — GroceryListView.swift
import SwiftUI

struct GroceryListView: View {
    @Bindable var user: User
    @StateObject private var vm: GroceryListViewModel

    init(user: User) {
        self.user = user
        _vm = StateObject(wrappedValue: GroceryListViewModel(user: user))
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.isGenerating { LoadingCard(message: "Building your grocery list…") }
                else if vm.sections.isEmpty { EmptyGroceryView(onGenerate: { Task { await vm.generate() } }) }
                else { groceryListContent }
            }
            .background(SanaTheme.Color.background)
            .navigationTitle("Grocery list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Regenerate list") { Task { await vm.generate() } }
                        Button("Uncheck all") { vm.uncheckAll() }
                        Button("Share list") { vm.shareList() }
                    } label: { Image(systemName: "ellipsis.circle") }
                    .accessibilityLabel(Text("List options"))
                }
            }
        }
        .task { vm.loadList() }
        .onDisappear { vm.saveCurrentState() }
        .sheet(isPresented: $vm.showPaywall) { PaywallView() }
    }

    private var groceryListContent: some View {
        VStack(spacing: 0) {
            // Progress bar
            HStack {
                Text(String(format: NSLocalizedString("%d/%d items", comment: ""), vm.checkedCount, vm.totalCount))
                    .font(SanaTheme.Font.caption()).foregroundStyle(.secondary)
                Spacer()
                Text(String(format: NSLocalizedString("%d%% done", comment: ""), Int(vm.progress * 100)))
                    .font(SanaTheme.Font.caption()).foregroundStyle(SanaTheme.Color.primary)
            }
            .padding(.horizontal, SanaTheme.Spacing.md)
            .padding(.vertical, 8)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(SanaTheme.Color.primaryLight).frame(height: 4)
                    Capsule().fill(
                        vm.progress >= 1
                            ? LinearGradient(colors: [SanaTheme.Color.primary, SanaTheme.Color.primaryDeep],
                                             startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [SanaTheme.Color.primary, SanaTheme.Color.primary],
                                             startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: max(4, geo.size.width * vm.progress), height: 4)
                    .animation(SanaTheme.Animation.smooth, value: vm.progress)
                }
            }
            .frame(height: 4)
            Divider()

            List {
                ForEach($vm.sections, id: \.category) { $section in
                    Section {
                        ForEach($section.items, id: \.id) { $item in
                            GroceryItemRow(item: $item)
                        }
                    } header: {
                        HStack {
                            Image(systemName: section.icon).foregroundStyle(SanaTheme.Color.primary)
                            Text(section.category)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

private struct GroceryItemRow: View {
    @Binding var item: GroceryItem

    var body: some View {
        Button {
            HapticService.selection()
            withAnimation(SanaTheme.Animation.snappy) { item.isChecked.toggle() }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isChecked ? SanaTheme.Color.primary : .secondary)
                    .font(.system(size: 22, weight: .light))
                    .contentTransition(.symbolEffect(.replace))
                    .animation(SanaTheme.Animation.snappy, value: item.isChecked)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(SanaTheme.Font.body())
                        .strikethrough(item.isChecked, color: .secondary)
                        .foregroundStyle(item.isChecked ? .secondary : .primary)
                    Text(item.formattedQuantity)
                        .font(SanaTheme.Font.caption(11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.isChecked
            ? "\(item.name), \(item.formattedQuantity) – in cart. Tap to remove."
            : "\(item.name), \(item.formattedQuantity) – not yet in cart. Tap to add.")
    }
}

private struct EmptyGroceryView: View {
    let onGenerate: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(SanaTheme.Color.primaryLight)
                        .frame(width: 96, height: 96)
                    Image(systemName: "cart.badge.plus")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(SanaTheme.Color.primary)
                }
                VStack(spacing: 8) {
                    Text("No grocery list yet")
                        .font(SanaTheme.Font.headline(22))
                    Text("Generate a smart shopping list\nfrom your active meal plan.")
                        .font(SanaTheme.Font.body())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Button("Generate from meal plan", action: onGenerate)
                    .buttonStyle(NourishButtonStyle())
                    .padding(.horizontal, 40)
            }
            Spacer()
        }
        .padding()
    }
}
