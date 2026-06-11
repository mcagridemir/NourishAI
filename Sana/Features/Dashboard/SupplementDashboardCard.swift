// Sana — SupplementDashboardCard.swift
// Quick-glance supplement check-in card on the main dashboard.
import SwiftUI
import SwiftData

struct SupplementDashboardCard: View {

    @Query(sort: \Supplement.createdAt) private var allSupplements: [Supplement]
    @Environment(\.modelContext) private var context

    private var active: [Supplement] { allSupplements.filter { $0.isActive } }
    private var doneCount: Int { active.filter { $0.isLoggedToday }.count }

    var body: some View {
        // Only show if user has supplements configured
        if active.isEmpty { EmptyView() } else { cardContent }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Supplements", systemImage: "pill.fill")
                    .font(SanaTheme.Font.headline())
                    .foregroundStyle(SanaTheme.Color.primary)
                Spacer()
                Text("\(doneCount)/\(active.count) taken")
                    .font(SanaTheme.Font.caption(12))
                    .foregroundStyle(doneCount == active.count ? SanaTheme.Color.primary : .secondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(SanaTheme.Color.primary.opacity(0.12))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(SanaTheme.Color.primary)
                        .frame(width: active.isEmpty ? 0 : geo.size.width * Double(doneCount) / Double(active.count), height: 6)
                        .animation(SanaTheme.Animation.smooth, value: doneCount)
                }
            }
            .frame(height: 6)

            // Compact pill list (max 4 shown)
            let shown = Array(active.prefix(4))
            HStack(spacing: 8) {
                ForEach(shown) { supp in
                    Button {
                        toggle(supp)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: supp.isLoggedToday ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 13))
                                .foregroundStyle(supp.isLoggedToday
                                    ? (Color(hex: supp.color) ?? SanaTheme.Color.primary)
                                    : Color.secondary)
                            Text(supp.name.components(separatedBy: " ").first ?? supp.name)
                                .font(SanaTheme.Font.caption(12))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background((Color(hex: supp.color) ?? SanaTheme.Color.primary).opacity(supp.isLoggedToday ? 0.15 : 0.06))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                if active.count > 4 {
                    Text("+\(active.count - 4) more")
                        .font(SanaTheme.Font.caption(11))
                        .foregroundStyle(.secondary)
                }
            }

            if doneCount == active.count {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(SanaTheme.Color.primary)
                        .font(.system(size: 13))
                    Text("All supplements taken today!")
                        .font(SanaTheme.Font.caption(12))
                        .foregroundStyle(SanaTheme.Color.primary)
                }
            }
        }
        .padding()
        .nourishCard()
    }

    private func toggle(_ supp: Supplement) {
        HapticService.selection()
        if supp.isLoggedToday {
            if let log = supp.logs?.first(where: { Calendar.current.isDateInToday($0.loggedAt) }) {
                context.delete(log)
            }
        } else {
            let log = SupplementLog()
            context.insert(log)
            log.supplement = supp
        }
        try? context.save()
    }
}
