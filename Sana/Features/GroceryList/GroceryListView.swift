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
                }
            }
        }
        .task { vm.loadList() }
    }

    private var groceryListContent: some View {
        VStack(spacing: 0) {
            // Progress bar
            HStack {
                Text("\(vm.checkedCount)/\(vm.totalCount) items")
                    .font(SanaTheme.Font.caption()).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(vm.progress * 100))% done")
                    .font(SanaTheme.Font.caption()).foregroundStyle(SanaTheme.Color.primary)
            }
            .padding(.horizontal, SanaTheme.Spacing.md)
            .padding(.vertical, 8)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(SanaTheme.Color.primaryLight).frame(height: 3)
                    Rectangle().fill(SanaTheme.Color.primary)
                        .frame(width: geo.size.width * vm.progress, height: 3)
                        .animation(SanaTheme.Animation.smooth, value: vm.progress)
                }
            }
            .frame(height: 3)
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
        HStack {
            Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isChecked ? SanaTheme.Color.primary : .secondary)
                .font(.title3)
                .onTapGesture { withAnimation { item.isChecked.toggle() } }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(SanaTheme.Font.body())
                    .strikethrough(item.isChecked, color: .secondary)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
                Text(item.formattedQuantity)
                    .font(SanaTheme.Font.caption()).foregroundStyle(.secondary)
            }
        }
    }
}

private struct EmptyGroceryView: View {
    let onGenerate: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "cart.badge.plus").font(.system(size: 60)).foregroundStyle(SanaTheme.Color.primaryLight)
            Text("No grocery list yet").font(SanaTheme.Font.headline(22))
            Text("Generate a smart shopping list from your active meal plan.").font(SanaTheme.Font.body()).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal)
            Button("Generate from meal plan", action: onGenerate).buttonStyle(NourishButtonStyle()).padding(.horizontal, 40)
        }
    }
}
