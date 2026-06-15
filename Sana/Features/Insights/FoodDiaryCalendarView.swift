// Sana — FoodDiaryCalendarView.swift
import SwiftUI

struct FoodDiaryCalendarView: View {

    let user: User
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var editingMeal: MealEntry?

    private var calendar: Calendar { .current }

    private var mealsOnSelected: [MealEntry] {
        (user.mealEntries ?? [])
            .filter { calendar.isDate($0.loggedAt, inSameDayAs: selectedDate) }
            .sorted { $0.loggedAt < $1.loggedAt }
    }

    private var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let start = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: start) }
    }

    private var firstWeekdayOffset: Int {
        let weekday = calendar.component(.weekday, from: daysInMonth.first ?? Date())
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SanaTheme.Spacing.lg) {
                    monthHeader
                    calendarGrid
                    Divider()
                    dayDetail
                }
                .padding(SanaTheme.Spacing.md)
            }
            .background(SanaTheme.Color.background)
            .navigationTitle("Food diary")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editingMeal) { meal in
                MealNotesSheet(meal: meal)
            }
        }
    }

    // MARK: - Month navigation

    private var monthHeader: some View {
        HStack {
            Button {
                withAnimation(SanaTheme.Animation.snappy) {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(SanaTheme.Color.primary)
                    .frame(width: 36, height: 36)
            }
            Spacer()
            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(SanaTheme.Font.headline(18))
            Spacer()
            Button {
                withAnimation(SanaTheme.Animation.snappy) {
                    let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                    if next <= Date() { displayedMonth = next }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(SanaTheme.Color.primary)
                    .frame(width: 36, height: 36)
            }
            .disabled(calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month))
        }
    }

    // MARK: - Calendar grid

    private var calendarGrid: some View {
        VStack(spacing: 4) {
            // Day-of-week headers
            HStack(spacing: 0) {
                ForEach(["Su","Mo","Tu","We","Th","Fr","Sa"], id: \.self) { d in
                    Text(d)
                        .font(SanaTheme.Font.caption(11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day cells
            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            LazyVGrid(columns: columns, spacing: 4) {
                // Offset blanks
                ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                    Color.clear.frame(height: 40)
                }
                ForEach(daysInMonth, id: \.self) { day in
                    DayCell(
                        date: day,
                        isSelected: calendar.isDate(day, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(day),
                        mealCount: mealCount(on: day),
                        calories: caloriesLogged(on: day)
                    )
                    .onTapGesture {
                        HapticService.selection()
                        withAnimation(SanaTheme.Animation.snappy) { selectedDate = day }
                    }
                }
            }
        }
        .padding()
        .nourishCard()
    }

    // MARK: - Day detail

    @ViewBuilder
    private var dayDetail: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedDate.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(SanaTheme.Font.headline())
                Spacer()
                if !mealsOnSelected.isEmpty {
                    Text("\(mealsOnSelected.map { $0.calories }.reduce(0, +)) kcal")
                        .font(SanaTheme.Font.numeric)
                        .foregroundStyle(SanaTheme.Color.primary)
                }
            }

            if mealsOnSelected.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 36))
                        .foregroundStyle(SanaTheme.Color.primary)
                    Text("No meals logged")
                        .font(SanaTheme.Font.body(14))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(mealsOnSelected) { meal in
                    Button {
                        HapticService.selection()
                        editingMeal = meal
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(SanaTheme.Color.primaryLight)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: meal.mealType.icon)
                                        .foregroundStyle(SanaTheme.Color.primary)
                                        .font(.system(size: 14))
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(meal.mealName)
                                    .font(SanaTheme.Font.body(14))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                HStack(spacing: 4) {
                                    Text(meal.loggedAt.formatted(.dateTime.hour().minute()))
                                        .font(SanaTheme.Font.caption())
                                        .foregroundStyle(.secondary)
                                    if meal.userRating > 0 {
                                        HStack(spacing: 1) {
                                            ForEach(1...meal.userRating, id: \.self) { _ in
                                                Image(systemName: "star.fill")
                                                    .font(.system(size: 8))
                                                    .foregroundStyle(.yellow)
                                            }
                                        }
                                    }
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(meal.calories) kcal")
                                    .font(SanaTheme.Font.headline(13))
                                    .foregroundStyle(SanaTheme.Color.primary)
                                Text("\(Int(meal.protein))g protein")
                                    .font(SanaTheme.Font.caption(11))
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    if meal.id != mealsOnSelected.last?.id { Divider() }
                }
            }
        }
        .padding()
        .nourishCard()
    }

    // MARK: - Helpers

    private func mealCount(on date: Date) -> Int {
        (user.mealEntries ?? []).filter { calendar.isDate($0.loggedAt, inSameDayAs: date) }.count
    }

    private func caloriesLogged(on date: Date) -> Int {
        (user.mealEntries ?? [])
            .filter { calendar.isDate($0.loggedAt, inSameDayAs: date) }
            .map { $0.calories }
            .reduce(0, +)
    }
}

// MARK: - Day cell

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let mealCount: Int
    let calories: Int

    private let cal = Calendar.current

    var body: some View {
        VStack(spacing: 3) {
            Text("\(cal.component(.day, from: date))")
                .font(.system(size: 13, weight: isToday ? .bold : .regular))
                .foregroundStyle(isSelected ? .white : isToday ? SanaTheme.Color.primary : .primary)

            // Dot indicators for meals logged
            if mealCount > 0 {
                HStack(spacing: 2) {
                    ForEach(0..<min(mealCount, 3), id: \.self) { _ in
                        Circle()
                            .fill(isSelected ? .white.opacity(0.8) : SanaTheme.Color.primary)
                            .frame(width: 4, height: 4)
                    }
                }
            } else {
                Color.clear.frame(height: 4)
            }
        }
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? SanaTheme.Color.primary : isToday ? SanaTheme.Color.primaryLight : Color.clear)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(date.formatted(.dateTime.month().day())). \(mealCount) meals, \(calories) calories.")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
