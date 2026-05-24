// NourishAI — MealHeatmapView.swift
// GitHub-style contribution heatmap showing meal-logging consistency.
import SwiftUI

struct MealHeatmapView: View {

    let mealEntries: [MealEntry]

    // Show the last `weeks` weeks ending today
    private let weeks = 17
    private let calendar = Calendar.current

    // Build a dictionary of day → meal count
    private var countByDay: [Date: Int] {
        Dictionary(
            grouping: mealEntries,
            by: { calendar.startOfDay(for: $0.loggedAt) }
        ).mapValues { $0.count }
    }

    // All day cells: (column, row) grid, newest day = bottom-right
    private var cells: [(date: Date, col: Int, row: Int)] {
        let today = calendar.startOfDay(for: .now)
        // Start from the Monday (or Sunday) of the week `weeks` ago
        let weekdayToday = (calendar.component(.weekday, from: today) - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -(weeks * 7 - 1 + weekdayToday), to: today) else { return [] }

        var result: [(date: Date, col: Int, row: Int)] = []
        for col in 0..<weeks {
            for row in 0..<7 {
                if let date = calendar.date(byAdding: .day, value: col * 7 + row, to: gridStart),
                   date <= today {
                    result.append((date, col, row))
                }
            }
        }
        return result
    }

    private func color(for date: Date) -> Color {
        let count = countByDay[date] ?? 0
        switch count {
        case 0:    return Color(.systemGray5)
        case 1:    return NourishTheme.Color.primary.opacity(0.25)
        case 2:    return NourishTheme.Color.primary.opacity(0.50)
        case 3:    return NourishTheme.Color.primary.opacity(0.75)
        default:   return NourishTheme.Color.primary
        }
    }

    // Month labels: find columns where the month changes
    private var monthLabels: [(col: Int, text: String)] {
        var labels: [(Int, String)] = []
        var lastMonth = -1
        for cell in cells where cell.row == 0 {
            let month = calendar.component(.month, from: cell.date)
            if month != lastMonth {
                let name = cell.date.formatted(.dateTime.month(.abbreviated))
                labels.append((cell.col, name))
                lastMonth = month
            }
        }
        return labels
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Logging streak").font(NourishTheme.Font.headline())

            GeometryReader { geo in
                let cellSize = (geo.size.width - CGFloat(weeks - 1) * 3) / CGFloat(weeks)
                ZStack(alignment: .topLeading) {
                    // Month labels
                    ForEach(monthLabels, id: \.col) { col, text in
                        Text(text)
                            .font(NourishTheme.Font.caption(9))
                            .foregroundStyle(.secondary)
                            .offset(x: CGFloat(col) * (cellSize + 3), y: 0)
                    }

                    // Grid cells
                    ForEach(cells, id: \.date) { cell in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color(for: cell.date))
                            .frame(width: cellSize, height: cellSize)
                            .offset(
                                x: CGFloat(cell.col) * (cellSize + 3),
                                y: 16 + CGFloat(cell.row) * (cellSize + 3)
                            )
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(
                                "\(cell.date.formatted(.dateTime.month(.abbreviated).day())): \(countByDay[cell.date] ?? 0) meals"
                            )
                    }
                }
            }
            .frame(height: 16 + 7 * 16 + 6 * 3) // label + 7 rows of cells

            // Legend
            HStack(spacing: 4) {
                Text("Less").font(NourishTheme.Font.caption(10)).foregroundStyle(.secondary)
                ForEach([0, 1, 2, 3, 4], id: \.self) { level in
                    let c: Color = level == 0 ? Color(.systemGray5) : NourishTheme.Color.primary.opacity(0.25 * Double(level))
                    RoundedRectangle(cornerRadius: 2).fill(c).frame(width: 12, height: 12)
                }
                Text("More").font(NourishTheme.Font.caption(10)).foregroundStyle(.secondary)
            }
        }
        .padding()
        .nourishCard()
    }
}
