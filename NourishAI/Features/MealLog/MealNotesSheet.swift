// NourishAI — MealNotesSheet.swift
// Rate and annotate a logged meal entry.
import SwiftUI

struct MealNotesSheet: View {

    @Bindable var meal: MealEntry
    @Environment(\.dismiss) private var dismiss
    @State private var draftNotes: String
    @State private var draftRating: Int
    @State private var draftFavourite: Bool

    init(meal: MealEntry) {
        self.meal = meal
        _draftNotes    = State(initialValue: meal.userNotes)
        _draftRating   = State(initialValue: meal.userRating)
        _draftFavourite = State(initialValue: meal.isFavourite)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NourishTheme.Spacing.lg) {

                    // Meal title header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(meal.mealName)
                            .font(NourishTheme.Font.title(20))
                        Text("\(meal.calories) kcal · \(meal.loggedAt.formatted(.dateTime.hour().minute()))")
                            .font(NourishTheme.Font.caption())
                            .foregroundStyle(.secondary)
                    }

                    // Star rating
                    VStack(alignment: .leading, spacing: 10) {
                        Text("How was it?")
                            .font(NourishTheme.Font.headline())
                        HStack(spacing: 12) {
                            ForEach(1...5, id: \.self) { star in
                                Button {
                                    HapticService.selection()
                                    withAnimation(NourishTheme.Animation.snappy) {
                                        draftRating = draftRating == star ? 0 : star
                                    }
                                } label: {
                                    Image(systemName: star <= draftRating ? "star.fill" : "star")
                                        .font(.system(size: 32))
                                        .foregroundStyle(star <= draftRating ? .yellow : Color(.systemGray3))
                                        .scaleEffect(star <= draftRating ? 1.1 : 1.0)
                                }
                                .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
                            }
                            Spacer()
                            if draftRating > 0 {
                                Text(ratingLabel)
                                    .font(NourishTheme.Font.caption())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .nourishCard()

                    // Notes
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Notes")
                            .font(NourishTheme.Font.headline())
                        TextField("How did you feel? Any substitutions or portion notes…",
                                  text: $draftNotes, axis: .vertical)
                            .font(NourishTheme.Font.body(14))
                            .lineLimit(4...8)
                            .padding(12)
                            .background(NourishTheme.Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.md))
                    }
                    .padding()
                    .nourishCard()

                    // Favourite toggle
                    Toggle(isOn: $draftFavourite) {
                        Label("Save to favourites", systemImage: "star.fill")
                            .font(NourishTheme.Font.body())
                            .foregroundStyle(draftFavourite ? .yellow : .primary)
                    }
                    .tint(.yellow)
                    .padding()
                    .nourishCard()
                }
                .padding(NourishTheme.Spacing.md)
            }
            .background(NourishTheme.Color.background)
            .navigationTitle("Meal notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(NourishTheme.Color.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var ratingLabel: String {
        switch draftRating {
        case 1: return "Didn't enjoy it"
        case 2: return "Wasn't great"
        case 3: return "It was okay"
        case 4: return "Really liked it"
        case 5: return "Absolutely loved it!"
        default: return ""
        }
    }

    private func save() {
        meal.userNotes = draftNotes
        meal.userRating = draftRating
        meal.isFavourite = draftFavourite
        HapticService.notification(.success)
        dismiss()
    }
}
