import SwiftUI

// MARK: - Star Rating View

/// Reusable star rating display and input component.
/// Use `onRate` closure for interactive mode, omit for display-only.
struct StarRatingView: View {
    let rating: Int
    var maxRating: Int = 5
    var font: Font = .caption2
    var onRate: ((Int) -> Void)? = nil

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...maxRating, id: \.self) { star in
                if let onRate {
                    Button {
                        onRate(star)
                    } label: {
                        starImage(for: star)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
                    .accessibilityHint(star == rating ? "Current rating" : "Double tap to rate")
                } else {
                    starImage(for: star)
                }
            }
        }
    }

    private func starImage(for star: Int) -> some View {
        Image(systemName: star <= rating ? "star.fill" : "star")
            .font(font)
            .foregroundStyle(Brand.warmTan)
    }
}
