import SwiftUI

// MARK: - Mise Brand System

enum Brand {

    // MARK: - Background Layers
    /// Primary app background — near-black.
    static let midnight  = Color(hex: "0e0e0e")
    /// Elevated surfaces: cards, sheets, input fields.
    static let surface   = Color(hex: "1a1a1a")
    /// Subtle dividers and 0.5pt borders.
    static let border    = Color(hex: "2a2a2a")

    // MARK: - Text
    /// Primary text on dark backgrounds.
    static let cream     = Color(hex: "f0ede6")
    /// Secondary text, metadata, captions.
    static let muted     = Color(hex: "888888")

    // MARK: - Accent
    /// Primary accent — warm tan. Used for tints, highlights, featured items.
    static let warmTan   = Color(hex: "c8b89a")
    /// Freshness, seasonal indicators, success states.
    static let herbGreen = Color(hex: "7a9e7e")
    /// Alerts, urgency, destructive actions.
    static let spiceRed  = Color(hex: "c0624a")

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
    /// Body text — weight 400, default size.
    static let miseBody     = Font.system(size: 14, weight: .regular)
    /// Section headers — weight 500, slight negative tracking.
    static let miseHeading  = Font.system(size: 18, weight: .medium)
    /// Small metadata labels.
    static let miseMeta     = Font.system(size: 12, weight: .regular)
    /// Display / hero text.
    static let miseDisplay  = Font.system(size: 26, weight: .medium)
}

extension View {
    /// Standard section header style: weight 500, muted, sentence case, negative tracking.
    func miseSectionHeader() -> some View {
        self
            .font(.system(size: 12, weight: .medium))
            .tracking(-0.2)
            .foregroundStyle(Brand.muted)
            .textCase(nil)
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
