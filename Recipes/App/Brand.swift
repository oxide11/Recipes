import SwiftUI
import UIKit

// MARK: - Mise Brand System

enum Brand {

    // MARK: - Background Layers
    /// Primary app background — near-black in dark, warm off-white in light.
    static let midnight  = Color(light: "f8f7f5", dark: "0e0e0e")
    /// Elevated surfaces: cards, sheets, input fields.
    static let surface   = Color(light: "ffffff", dark: "1a1a1a")
    /// Subtle dividers and 0.5pt borders.
    static let border    = Color(light: "e0ddd6", dark: "2a2a2a")

    // MARK: - Text
    /// Primary text — adapts for readability on both light and dark backgrounds.
    static let cream     = Color(light: "1a1a1a", dark: "f0ede6")
    /// Secondary text, metadata, captions.
    static let muted     = Color(light: "666666", dark: "888888")

    // MARK: - Accent
    /// Primary accent — warm tan. Deeper in light mode for contrast.
    static let warmTan   = Color(light: "9a8462", dark: "c8b89a")
    /// Freshness, seasonal indicators, success states.
    static let herbGreen = Color(light: "5a7e5e", dark: "7a9e7e")
    /// Alerts, urgency, destructive actions.
    static let spiceRed  = Color(light: "a04a34", dark: "c0624a")

    // MARK: - Ingredient Category Colors
    // Chosen to feel at home in the brand palette — muted, warm, distinct.
    static let ingredientProtein     = spiceRed                // warm red
    static let ingredientProduce     = herbGreen               // fresh green
    static let ingredientDryGoods    = warmTan                 // pantry tan
    static let ingredientDairy       = Color(hex: "8aacba")   // cool slate blue
    static let ingredientSeasoning   = Color(hex: "c4965a")   // warm amber
    static let ingredientLiquid      = Color(hex: "7a9e96")   // muted teal
}

// MARK: - Typography Helpers

extension Font {
    /// Body text — scales with Dynamic Type (base ~15pt).
    static let miseBody     = Font.subheadline.weight(.regular)
    /// Section headers — scales with Dynamic Type (base ~17pt).
    static let miseHeading  = Font.headline.weight(.medium)
    /// Small metadata labels — scales with Dynamic Type (base 12pt).
    static let miseMeta     = Font.caption
    /// Display / hero text — fixed for now; will be revisited in dashboard redesign.
    static let miseDisplay  = Font.system(size: 26, weight: .medium)
}

extension View {
    /// Standard section header style: weight 500, muted, sentence case, negative tracking.
    func miseSectionHeader() -> some View {
        self
            .font(.caption.weight(.medium))
            .tracking(-0.2)
            .foregroundStyle(Brand.muted)
            .textCase(nil)
    }

    /// Liquid Glass card background — pairs `.background(in:)` with `.glassEffect(.regular, in:)`.
    func glassCard(cornerRadius: CGFloat = 12) -> some View {
        self
            .background(in: .rect(cornerRadius: cornerRadius))
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}

// MARK: - Adaptive Color Initialiser

extension Color {
    /// Creates a color that adapts to the current interface style (light/dark mode).
    init(light: String, dark: String) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        })
    }
}

// MARK: - Hex Color Initialiser

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(
            red:   Double((int >> 16) & 0xff) / 255,
            green: Double((int >> 8)  & 0xff) / 255,
            blue:  Double( int        & 0xff) / 255
        )
    }
}
