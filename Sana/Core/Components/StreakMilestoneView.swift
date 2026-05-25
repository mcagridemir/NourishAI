// Sana — StreakMilestoneView.swift
import SwiftUI

struct StreakMilestoneView: View {

    let streak: Int
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.4
    @State private var opacity: Double = 0
    @State private var confettiOpacity: Double = 1

    private var milestone: Int { StreakMilestoneView.milestone(for: streak) ?? streak }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture { dismiss() }

            ConfettiLayer()
                .opacity(confettiOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 20) {
                Text("🔥")
                    .font(.system(size: 72))
                    .scaleEffect(scale)

                VStack(spacing: 8) {
                    Text("\(milestone)-Day Streak!")
                        .font(SanaTheme.Font.title(28))
                        .foregroundStyle(SanaTheme.Color.primary)
                    Text("You've logged meals for \(milestone) days in a row. Keep it up!")
                        .font(SanaTheme.Font.body())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                Button("Awesome!") { dismiss() }
                    .buttonStyle(NourishButtonStyle())
            }
            .padding(SanaTheme.Spacing.xl)
            .background(SanaTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.xl))
            .padding(.horizontal, 32)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            HapticService.notification(.success)
            withAnimation(SanaTheme.Animation.snappy) {
                scale = 1; opacity = 1
            }
            if !UIAccessibility.isReduceMotionEnabled {
                withAnimation(.easeOut(duration: 2.5).delay(2)) {
                    confettiOpacity = 0
                }
            } else {
                confettiOpacity = 0
            }
        }
    }

    private func dismiss() {
        withAnimation(SanaTheme.Animation.smooth) {
            scale = 0.8; opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onDismiss() }
    }

    static func milestone(for streak: Int) -> Int? {
        [7, 14, 30, 60, 100].first { streak == $0 }
    }
}

private struct ConfettiLayer: View {
    @State private var fallen = false
    private let pieces: [ConfettiPiece] = (0..<50).map { _ in ConfettiPiece() }

    var body: some View {
        GeometryReader { geo in
            ForEach(pieces) { piece in
                RoundedRectangle(cornerRadius: 2)
                    .fill(piece.color)
                    .frame(width: piece.size, height: piece.size * 1.8)
                    .rotationEffect(.degrees(piece.rotation))
                    .position(
                        x: piece.x * geo.size.width,
                        y: fallen ? geo.size.height * 1.2 : -20
                    )
                    .animation(
                        .easeIn(duration: piece.duration).delay(piece.delay),
                        value: fallen
                    )
            }
        }
        .onAppear { fallen = true }
    }
}

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    let x: CGFloat
    let rotation: Double
    let duration: Double
    let delay: Double

    init() {
        color = [Color.orange, .yellow, SanaTheme.Color.primary, .pink, .purple, .cyan].randomElement()!
        size = CGFloat.random(in: 5...12)
        x = CGFloat.random(in: 0...1)
        rotation = Double.random(in: 0...360)
        duration = Double.random(in: 1.2...2.5)
        delay = Double.random(in: 0...0.8)
    }
}
