// Sana — MealNotesSheet.swift
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
                VStack(alignment: .leading, spacing: SanaTheme.Spacing.lg) {

                    // Meal title header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(meal.mealName)
                            .font(SanaTheme.Font.title(20))
                        Text("\(meal.calories) kcal · \(meal.loggedAt.formatted(.dateTime.hour().minute()))")
                            .font(SanaTheme.Font.caption())
                            .foregroundStyle(.secondary)
                    }

                    // Star rating
                    VStack(alignment: .leading, spacing: 10) {
                        Text("How was it?")
                            .font(SanaTheme.Font.headline())
                        HStack(spacing: 12) {
                            ForEach(1...5, id: \.self) { star in
                                Button {
                                    HapticService.selection()
                                    withAnimation(SanaTheme.Animation.snappy) {
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
                                    .font(SanaTheme.Font.caption())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .nourishCard()

                    // Notes
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Notes")
                            .font(SanaTheme.Font.headline())
                        TextField("How did you feel? Any substitutions or portion notes…",
                                  text: $draftNotes, axis: .vertical)
                            .font(SanaTheme.Font.body(14))
                            .lineLimit(4...8)
                            .padding(12)
                            .background(SanaTheme.Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
                    }
                    .padding()
                    .nourishCard()

                    // Favourite toggle
                    Toggle(isOn: $draftFavourite) {
                        Label("Save to favourites", systemImage: "star.fill")
                            .font(SanaTheme.Font.body())
                            .foregroundStyle(draftFavourite ? .yellow : .primary)
                    }
                    .tint(.yellow)
                    .padding()
                    .nourishCard()
                }
                .padding(SanaTheme.Spacing.md)
            }
            .background(SanaTheme.Color.background)
            .navigationTitle("Meal notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(SanaTheme.Color.primary)
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
