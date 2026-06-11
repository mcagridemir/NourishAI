// Sana — SupplementTrackerView.swift
// Track daily vitamins and supplements with streak monitoring.
import SwiftUI
import SwiftData

struct SupplementTrackerView: View {

    @Environment(\.modelContext) private var context
    @Query(sort: \Supplement.createdAt) private var supplements: [Supplement]

    @State private var showingAdd = false
    @State private var editingSupp: Supplement?

    private var active: [Supplement] { supplements.filter { $0.isActive } }
    private var todayDoneCount: Int { active.filter { $0.isLoggedToday }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SanaTheme.Spacing.lg) {

                    // Progress header
                    if !active.isEmpty {
                        progressHeader
                    }

                    // Today's checklist
                    if !active.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Today")
                                .font(SanaTheme.Font.headline())
                                .padding(.horizontal, SanaTheme.Spacing.md)
                                .padding(.bottom, 8)

                            ForEach(active) { supp in
                                supplementRow(supp)
                                if supp.id != active.last?.id {
                                    Divider().padding(.leading, 72)
                                }
                            }
                        }
                        .padding(.vertical, 12)
                        .nourishCard()
                        .padding(.horizontal, SanaTheme.Spacing.md)
                    } else {
                        emptyState
                    }

                    // Archived / inactive
                    let inactive = supplements.filter { !$0.isActive }
                    if !inactive.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Archived")
                                .font(SanaTheme.Font.headline())
                                .padding(.horizontal, SanaTheme.Spacing.md)
                            ForEach(inactive) { supp in
                                HStack {
                                    Text(supp.name)
                                        .font(SanaTheme.Font.body(14))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button("Restore") {
                                        supp.isActive = true
                                    }
                                    .font(SanaTheme.Font.caption())
                                    .foregroundStyle(SanaTheme.Color.primary)
                                }
                                .padding(.horizontal, SanaTheme.Spacing.md)
                                .padding(.vertical, 8)
                            }
                        }
                    }
                }
                .padding(.vertical, SanaTheme.Spacing.md)
            }
            .background(SanaTheme.Color.background)
            .navigationTitle("Supplements")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(SanaTheme.Color.primary)
                    }
                    .accessibilityLabel("Add supplement")
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddSupplementSheet()
            }
            .sheet(item: $editingSupp) { supp in
                EditSupplementSheet(supplement: supp)
            }
        }
    }

    // MARK: - Progress ring header
    private var progressHeader: some View {
        HStack(spacing: SanaTheme.Spacing.lg) {
            ZStack {
                Circle()
                    .stroke(SanaTheme.Color.primary.opacity(0.15), lineWidth: 10)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: active.isEmpty ? 0 : Double(todayDoneCount) / Double(active.count))
                    .stroke(SanaTheme.Color.primary,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 80, height: 80)
                    .animation(SanaTheme.Animation.smooth, value: todayDoneCount)
                VStack(spacing: 0) {
                    Text("\(todayDoneCount)")
                        .font(SanaTheme.Font.title(22))
                        .foregroundStyle(SanaTheme.Color.primary)
                    Text("of \(active.count)")
                        .font(SanaTheme.Font.caption(10))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(headerMessage)
                    .font(SanaTheme.Font.headline())
                let best = active.max(by: { $0.currentStreak < $1.currentStreak })
                if let best, best.currentStreak > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill").foregroundStyle(.orange).font(.caption)
                        Text("\(best.name) · \(best.currentStreak) ") + Text("day streak")
                            .font(SanaTheme.Font.caption(12))
                            .foregroundStyle(.orange)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .background(SanaTheme.Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg))
        .padding(.horizontal, SanaTheme.Spacing.md)
    }

    private var headerMessage: String {
        guard !active.isEmpty else { return "All caught up!" }
        if todayDoneCount == active.count { return "All taken today 🎉" }
        if todayDoneCount == 0 { return "Time to take your supplements" }
        return "\(active.count - todayDoneCount) remaining today"
    }

    // MARK: - Supplement row
    private func supplementRow(_ supp: Supplement) -> some View {
        HStack(spacing: 14) {
            // Icon with color
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill((Color(hex: supp.color) ?? SanaTheme.Color.primary).opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: iconFor(supp.name))
                    .font(.system(size: 20))
                    .foregroundStyle(Color(hex: supp.color) ?? SanaTheme.Color.primary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(supp.name)
                    .font(SanaTheme.Font.headline(15))
                HStack(spacing: 6) {
                    Text(supp.dosageDisplay)
                        .font(SanaTheme.Font.caption(12))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(supp.timeOfDay)
                        .font(SanaTheme.Font.caption(12))
                        .foregroundStyle(.secondary)
                    if supp.currentStreak > 1 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                            Text("\(supp.currentStreak)")
                                .font(SanaTheme.Font.caption(11))
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            Spacer()

            // Check button
            Button {
                toggleLog(supp)
            } label: {
                Image(systemName: supp.isLoggedToday ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundStyle(supp.isLoggedToday
                                     ? (Color(hex: supp.color) ?? SanaTheme.Color.primary)
                                     : Color.secondary.opacity(0.4))
                    .animation(SanaTheme.Animation.snappy, value: supp.isLoggedToday)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(supp.isLoggedToday
                ? "\(supp.name) – marked as taken. Tap to undo."
                : "Mark \(supp.name) as taken")
        }
        .padding(.horizontal, SanaTheme.Spacing.md)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onLongPressGesture { editingSupp = supp }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "pill.fill")
                .font(.system(size: 48))
                .foregroundStyle(SanaTheme.Color.primary.opacity(0.3))
            Text("No supplements yet")
                .font(SanaTheme.Font.headline())
                .foregroundStyle(.secondary)
            Text("Tap + to add vitamins, minerals, or any supplement you take regularly.")
                .font(SanaTheme.Font.body(14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showingAdd = true
            } label: {
                Label("Add supplement", systemImage: "plus")
            }
            .buttonStyle(NourishButtonStyle())
            .padding(.horizontal, 60)
        }
        .padding(.vertical, 40)
        .padding(.horizontal, SanaTheme.Spacing.lg)
    }

    // MARK: - Helpers
    private func toggleLog(_ supp: Supplement) {
        HapticService.selection()
        if supp.isLoggedToday {
            // Remove today's log
            if let log = supp.logs?.first(where: { Calendar.current.isDateInToday($0.loggedAt) }) {
                context.delete(log)
            }
        } else {
            let log = SupplementLog()
            context.insert(log)
            log.supplement = supp
            if supp.currentStreak > 0 {
                HapticService.notification(.success)
            }
        }
        try? context.save()
    }

    private func iconFor(_ name: String) -> String {
        let n = name.lowercased()
        if n.contains("vitamin d") || n.contains("d3") { return "sun.max.fill" }
        if n.contains("vitamin c") { return "leaf.fill" }
        if n.contains("vitamin b") || n.contains("b12") { return "bolt.fill" }
        if n.contains("omega") || n.contains("fish") { return "drop.fill" }
        if n.contains("magnesium") { return "sparkle" }
        if n.contains("iron") { return "waveform.path.ecg" }
        if n.contains("calcium") { return "shield.fill" }
        if n.contains("zinc") { return "star.fill" }
        if n.contains("probiotic") { return "ladybug.fill" }
        if n.contains("collagen") { return "figure.stand" }
        if n.contains("protein") || n.contains("creatine") { return "bolt.heart.fill" }
        return "pill.fill"
    }
}

// MARK: - Add Supplement Sheet

struct AddSupplementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var dosage: String = "1"
    @State private var unit = "mg"
    @State private var frequency = "Daily"
    @State private var timeOfDay = "Morning"
    @State private var notes = ""
    @State private var selectedColor = "#2D9E75"

    private let units = ["mg", "mcg", "IU", "g", "tablet", "capsule", "ml"]
    private let frequencies = ["Daily", "Twice daily", "3x daily", "Weekly", "As needed"]
    private let times = ["Morning", "Afternoon", "Evening", "With meals", "Before bed"]
    private let colorPresets = ["#2D9E75", "#F0853A", "#5856D6", "#007AFF", "#FF3B30", "#FF9500", "#34C759", "#AF52DE"]

    private let commonSupps = ["Vitamin D3", "Vitamin C", "Vitamin B12", "Omega-3", "Magnesium",
                                "Zinc", "Iron", "Calcium", "Probiotics", "Collagen", "Creatine"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Vitamin D3", text: $name)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(commonSupps, id: \.self) { s in
                                Button(s) { name = s }
                                    .font(SanaTheme.Font.caption(12))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(name == s ? SanaTheme.Color.primary : SanaTheme.Color.surface)
                                    .foregroundStyle(name == s ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Dosage") {
                    HStack {
                        TextField("Amount", text: $dosage)
                            .keyboardType(.decimalPad)
                        Picker("Unit", selection: $unit) {
                            ForEach(units, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("Schedule") {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(frequencies, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Time of day", selection: $timeOfDay) {
                        ForEach(times, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("Colour") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(colorPresets, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex) ?? .green)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle().stroke(.white, lineWidth: selectedColor == hex ? 3 : 0)
                                )
                                .scaleEffect(selectedColor == hex ? 1.15 : 1)
                                .onTapGesture { withAnimation(SanaTheme.Animation.snappy) { selectedColor = hex } }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Notes (optional)") {
                    TextField("e.g. Take with food", text: $notes)
                }
            }
            .navigationTitle("Add Supplement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .font(SanaTheme.Font.headline(15))
                }
            }
        }
    }

    private func save() {
        let d = Double(dosage) ?? 1
        let supp = Supplement(name: name.trimmingCharacters(in: .whitespaces),
                              dosage: d, unit: unit,
                              frequency: frequency, timeOfDay: timeOfDay,
                              notes: notes, color: selectedColor)
        context.insert(supp)
        try? context.save()
        // Schedule reminder if frequency is daily or similar
        if frequency != "As needed" {
            NotificationService.shared.scheduleSupplementReminder(
                name: supp.name, timeOfDay: supp.timeOfDay, id: supp.id.uuidString)
        }
        dismiss()
    }
}

// MARK: - Edit Supplement Sheet

struct EditSupplementSheet: View {
    @Bindable var supplement: Supplement
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private let units = ["mg", "mcg", "IU", "g", "tablet", "capsule", "ml"]
    private let frequencies = ["Daily", "Twice daily", "3x daily", "Weekly", "As needed"]
    private let times = ["Morning", "Afternoon", "Evening", "With meals", "Before bed"]
    private let colorPresets = ["#2D9E75", "#F0853A", "#5856D6", "#007AFF", "#FF3B30", "#FF9500", "#34C759", "#AF52DE"]

    @State private var dosageText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $supplement.name)
                }
                Section("Dosage") {
                    HStack {
                        TextField("Amount", text: $dosageText)
                            .keyboardType(.decimalPad)
                            .onChange(of: dosageText) { _, v in supplement.dosage = Double(v) ?? supplement.dosage }
                        Picker("Unit", selection: $supplement.unit) {
                            ForEach(units, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                    }
                }
                Section("Schedule") {
                    Picker("Frequency", selection: $supplement.frequency) {
                        ForEach(frequencies, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Time of day", selection: $supplement.timeOfDay) {
                        ForEach(times, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section("Colour") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(colorPresets, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex) ?? .green)
                                .frame(width: 30, height: 30)
                                .overlay(Circle().stroke(.white, lineWidth: supplement.color == hex ? 3 : 0))
                                .scaleEffect(supplement.color == hex ? 1.15 : 1)
                                .onTapGesture { withAnimation(SanaTheme.Animation.snappy) { supplement.color = hex } }
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Notes") {
                    TextField("Notes", text: $supplement.notes)
                }
                Section {
                    Toggle("Active", isOn: $supplement.isActive)
                }
                Section {
                    Button("Delete supplement", role: .destructive) {
                        NotificationService.shared.cancelSupplementReminder(id: supplement.id.uuidString)
                        context.delete(supplement)
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit Supplement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(SanaTheme.Font.headline(15))
                }
            }
            .onAppear {
                dosageText = supplement.dosage == supplement.dosage.rounded()
                    ? "\(Int(supplement.dosage))"
                    : String(format: "%.1f", supplement.dosage)
            }
        }
    }
}
