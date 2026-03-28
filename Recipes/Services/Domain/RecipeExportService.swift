import SwiftUI
import UIKit

// MARK: - Recipe Export Service

/// Provides static methods for exporting a Recipe as PDF, shareable card image, or plain text.
enum RecipeExportService {

    // MARK: - PDF Generation

    /// Generates a formatted PDF document from a recipe.
    static func generatePDF(from recipe: Recipe) -> Data {
        let pageWidth: CGFloat = 612   // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )

        return renderer.pdfData { context in
            var cursorY: CGFloat = 0

            func beginPageIfNeeded(spaceNeeded: CGFloat = 60) {
                if cursorY + spaceNeeded > pageHeight - margin {
                    context.beginPage()
                    cursorY = margin
                }
            }

            func drawSeparator() {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin, y: cursorY))
                path.addLine(to: CGPoint(x: pageWidth - margin, y: cursorY))
                UIColor.separator.setStroke()
                path.lineWidth = 0.5
                path.stroke()
                cursorY += 12
            }

            // -- Page 1 --
            context.beginPage()
            cursorY = margin

            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor.label
            ]
            let titleRect = CGRect(x: margin, y: cursorY, width: contentWidth, height: 40)
            (recipe.title as NSString).draw(in: titleRect, withAttributes: titleAttrs)
            cursorY += 44

            // Summary
            if let summary = recipe.summary, !summary.isEmpty {
                let summaryAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                    .foregroundColor: UIColor.secondaryLabel
                ]
                let summarySize = (summary as NSString).boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: summaryAttrs,
                    context: nil
                )
                let summaryRect = CGRect(x: margin, y: cursorY, width: contentWidth, height: summarySize.height + 4)
                (summary as NSString).draw(in: summaryRect, withAttributes: summaryAttrs)
                cursorY += summaryRect.height + 8
            }

            drawSeparator()

            // Metadata row
            let metaAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let metaText = [
                "Cuisine: \(recipe.cuisine.rawValue.capitalized)",
                "Difficulty: \(recipe.difficulty.rawValue.capitalized)",
                "Servings: \(recipe.servings)",
                "Prep: \(recipe.prepTimeMinutes) min",
                "Cook: \(recipe.cookTimeMinutes) min",
                "Total: \(recipe.estimatedTotalMinutes) min"
            ].joined(separator: "  |  ")
            let metaRect = CGRect(x: margin, y: cursorY, width: contentWidth, height: 16)
            (metaText as NSString).draw(in: metaRect, withAttributes: metaAttrs)
            cursorY += 24

            drawSeparator()

            // Section header helper
            let sectionAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.label
            ]

            func drawSectionHeader(_ text: String) {
                beginPageIfNeeded(spaceNeeded: 40)
                let rect = CGRect(x: margin, y: cursorY, width: contentWidth, height: 24)
                (text as NSString).draw(in: rect, withAttributes: sectionAttrs)
                cursorY += 28
            }

            // Ingredients
            drawSectionHeader("Ingredients")

            for ingredient in recipe.ingredients {
                beginPageIfNeeded()
                let line = "\u{2022}  \(ingredient.amount.displayString) \(ingredient.name)"
                let lineSize = (line as NSString).boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin],
                    attributes: bodyAttrs,
                    context: nil
                )
                let lineRect = CGRect(x: margin + 8, y: cursorY, width: contentWidth - 8, height: lineSize.height + 2)
                (line as NSString).draw(in: lineRect, withAttributes: bodyAttrs)
                cursorY += lineRect.height + 4
            }

            cursorY += 8
            drawSeparator()

            // Directions
            drawSectionHeader("Directions")

            let sortedDirections = recipe.directions.sorted { $0.stepNumber < $1.stepNumber }
            for direction in sortedDirections {
                let stepText = "\(direction.stepNumber). \(direction.instruction)"
                let stepSize = (stepText as NSString).boundingRect(
                    with: CGSize(width: contentWidth - 16, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin],
                    attributes: bodyAttrs,
                    context: nil
                )
                beginPageIfNeeded(spaceNeeded: stepSize.height + 10)
                let stepRect = CGRect(x: margin + 8, y: cursorY, width: contentWidth - 16, height: stepSize.height + 2)
                (stepText as NSString).draw(in: stepRect, withAttributes: bodyAttrs)
                cursorY += stepRect.height + 8
            }

            cursorY += 8
            drawSeparator()

            // Nutritional Info
            if let info = recipe.nutritionalInfo {
                drawSectionHeader("Nutritional Info (per serving)")
                let nutritionLines = [
                    "Calories: \(Int(info.calories))",
                    "Protein: \(String(format: "%.1f", info.proteinGrams))g",
                    "Carbs: \(String(format: "%.1f", info.carbsGrams))g",
                    "Fat: \(String(format: "%.1f", info.fatGrams))g"
                ]
                for line in nutritionLines {
                    beginPageIfNeeded()
                    let rect = CGRect(x: margin + 8, y: cursorY, width: contentWidth, height: 16)
                    (line as NSString).draw(in: rect, withAttributes: bodyAttrs)
                    cursorY += 18
                }
                cursorY += 8
                drawSeparator()
            }

            // Tags
            if !recipe.tags.isEmpty {
                drawSectionHeader("Tags")
                let tagText = recipe.tags.joined(separator: ", ")
                let tagRect = CGRect(x: margin + 8, y: cursorY, width: contentWidth, height: 16)
                (tagText as NSString).draw(in: tagRect, withAttributes: bodyAttrs)
                cursorY += 20
            }

            // Footer
            beginPageIfNeeded(spaceNeeded: 30)
            cursorY += 12
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .light),
                .foregroundColor: UIColor.tertiaryLabel
            ]
            let footerText = "Exported from Recipes on \(Self.formattedDate())"
            let footerRect = CGRect(x: margin, y: cursorY, width: contentWidth, height: 14)
            (footerText as NSString).draw(in: footerRect, withAttributes: footerAttrs)
        }
    }

    // MARK: - Card Image Generation

    /// Generates a shareable recipe card as a `UIImage`.
    static func generateCardImage(from recipe: Recipe) -> UIImage {
        let cardWidth: CGFloat = 600
        let padding: CGFloat = 28
        let contentWidth = cardWidth - padding * 2

        // Pre-calculate content height
        let titleFont = UIFont.systemFont(ofSize: 26, weight: .bold)
        let subtitleFont = UIFont.systemFont(ofSize: 13, weight: .medium)
        let bodyFont = UIFont.systemFont(ofSize: 12, weight: .regular)
        let sectionFont = UIFont.systemFont(ofSize: 15, weight: .semibold)

        var estimatedHeight: CGFloat = padding

        // Title
        let titleSize = (recipe.title as NSString).boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: [.font: titleFont],
            context: nil
        )
        estimatedHeight += titleSize.height + 8

        // Subtitle row
        estimatedHeight += 20

        // Summary
        if let summary = recipe.summary, !summary.isEmpty {
            let summarySize = (summary as NSString).boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin],
                attributes: [.font: bodyFont],
                context: nil
            )
            estimatedHeight += summarySize.height + 12
        }

        // Divider + Ingredients header
        estimatedHeight += 36
        estimatedHeight += CGFloat(recipe.ingredients.count) * 18

        // Divider + Directions header
        estimatedHeight += 36
        let sortedDirections = recipe.directions.sorted { $0.stepNumber < $1.stepNumber }
        for direction in sortedDirections {
            let text = "\(direction.stepNumber). \(direction.instruction)"
            let size = (text as NSString).boundingRect(
                with: CGSize(width: contentWidth - 12, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin],
                attributes: [.font: bodyFont],
                context: nil
            )
            estimatedHeight += size.height + 8
        }

        // Nutrition row
        if recipe.nutritionalInfo != nil {
            estimatedHeight += 52
        }

        // Tags
        if !recipe.tags.isEmpty {
            estimatedHeight += 32
        }

        estimatedHeight += padding + 20 // footer + bottom padding

        let cardHeight = estimatedHeight
        let size = CGSize(width: cardWidth, height: cardHeight)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { ctx in
            // Background with rounded rect
            let bgRect = CGRect(origin: .zero, size: size)
            let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: 20)
            UIColor.systemBackground.setFill()
            bgPath.fill()

            // Subtle border
            UIColor.separator.setStroke()
            bgPath.lineWidth = 1
            bgPath.stroke()

            var y: CGFloat = padding
            let labelColor = UIColor.label
            let secondaryColor = UIColor.secondaryLabel
            let accentColor = UIColor.systemOrange

            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: labelColor
            ]
            let titleDrawSize = (recipe.title as NSString).boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin],
                attributes: titleAttrs,
                context: nil
            )
            (recipe.title as NSString).draw(
                in: CGRect(x: padding, y: y, width: contentWidth, height: titleDrawSize.height),
                withAttributes: titleAttrs
            )
            y += titleDrawSize.height + 6

            // Metadata chips row
            let chipAttrs: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: accentColor
            ]
            let chipText = "\(recipe.cuisine.rawValue.capitalized)  \u{2022}  \(recipe.difficulty.rawValue.capitalized)  \u{2022}  \(recipe.servings) servings  \u{2022}  \(recipe.estimatedTotalMinutes) min"
            (chipText as NSString).draw(
                in: CGRect(x: padding, y: y, width: contentWidth, height: 18),
                withAttributes: chipAttrs
            )
            y += 22

            // Summary
            if let summary = recipe.summary, !summary.isEmpty {
                let summaryAttrs: [NSAttributedString.Key: Any] = [
                    .font: bodyFont,
                    .foregroundColor: secondaryColor
                ]
                let sSize = (summary as NSString).boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin],
                    attributes: summaryAttrs,
                    context: nil
                )
                (summary as NSString).draw(
                    in: CGRect(x: padding, y: y, width: contentWidth, height: sSize.height),
                    withAttributes: summaryAttrs
                )
                y += sSize.height + 10
            }

            // Divider
            func drawDivider() {
                let divider = UIBezierPath()
                divider.move(to: CGPoint(x: padding, y: y))
                divider.addLine(to: CGPoint(x: cardWidth - padding, y: y))
                UIColor.separator.setStroke()
                divider.lineWidth = 0.5
                divider.stroke()
                y += 10
            }

            drawDivider()

            // Section header helper
            func drawSection(_ title: String) {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: sectionFont,
                    .foregroundColor: labelColor
                ]
                (title as NSString).draw(
                    in: CGRect(x: padding, y: y, width: contentWidth, height: 20),
                    withAttributes: attrs
                )
                y += 24
            }

            // Ingredients
            drawSection("Ingredients")
            let ingredientAttrs: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: labelColor
            ]
            for ingredient in recipe.ingredients {
                let line = "\u{2022}  \(ingredient.amount.displayString) \(ingredient.name)"
                (line as NSString).draw(
                    in: CGRect(x: padding + 8, y: y, width: contentWidth - 8, height: 16),
                    withAttributes: ingredientAttrs
                )
                y += 18
            }
            y += 4

            drawDivider()

            // Directions
            drawSection("Directions")
            for direction in sortedDirections {
                let text = "\(direction.stepNumber). \(direction.instruction)"
                let tSize = (text as NSString).boundingRect(
                    with: CGSize(width: contentWidth - 12, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin],
                    attributes: ingredientAttrs,
                    context: nil
                )
                (text as NSString).draw(
                    in: CGRect(x: padding + 6, y: y, width: contentWidth - 12, height: tSize.height),
                    withAttributes: ingredientAttrs
                )
                y += tSize.height + 8
            }
            y += 4

            // Nutritional info compact row
            if let info = recipe.nutritionalInfo {
                drawDivider()
                let nutritionAttrs: [NSAttributedString.Key: Any] = [
                    .font: subtitleFont,
                    .foregroundColor: secondaryColor
                ]
                let nutLine = "Cal: \(Int(info.calories))  |  Protein: \(String(format: "%.0f", info.proteinGrams))g  |  Carbs: \(String(format: "%.0f", info.carbsGrams))g  |  Fat: \(String(format: "%.0f", info.fatGrams))g"
                (nutLine as NSString).draw(
                    in: CGRect(x: padding, y: y, width: contentWidth, height: 16),
                    withAttributes: nutritionAttrs
                )
                y += 22
            }

            // Tags
            if !recipe.tags.isEmpty {
                let tagAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: accentColor
                ]
                let tagLine = recipe.tags.map { "#\($0)" }.joined(separator: "  ")
                (tagLine as NSString).draw(
                    in: CGRect(x: padding, y: y, width: contentWidth, height: 14),
                    withAttributes: tagAttrs
                )
                y += 18
            }

            // Footer
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .light),
                .foregroundColor: UIColor.tertiaryLabel
            ]
            let footer = "Exported from Recipes on \(Self.formattedDate())"
            (footer as NSString).draw(
                in: CGRect(x: padding, y: y + 4, width: contentWidth, height: 12),
                withAttributes: footerAttrs
            )
        }
    }

    // MARK: - Plain Text Generation

    /// Generates a plain-text representation of the recipe suitable for sharing.
    static func generatePlainText(from recipe: Recipe) -> String {
        var lines: [String] = []

        // Title
        lines.append(recipe.title.uppercased())
        lines.append(String(repeating: "=", count: recipe.title.count))
        lines.append("")

        // Summary
        if let summary = recipe.summary, !summary.isEmpty {
            lines.append(summary)
            lines.append("")
        }

        // Metadata
        lines.append("Cuisine: \(recipe.cuisine.rawValue.capitalized)")
        lines.append("Difficulty: \(recipe.difficulty.rawValue.capitalized)")
        lines.append("Servings: \(recipe.servings)")
        lines.append("Prep Time: \(recipe.prepTimeMinutes) min")
        lines.append("Cook Time: \(recipe.cookTimeMinutes) min")
        lines.append("Total Time: \(recipe.estimatedTotalMinutes) min")
        lines.append("")

        // Ingredients
        lines.append("INGREDIENTS")
        lines.append(String(repeating: "-", count: 11))
        for ingredient in recipe.ingredients {
            lines.append("- \(ingredient.amount.displayString) \(ingredient.name)")
        }
        lines.append("")

        // Directions
        lines.append("DIRECTIONS")
        lines.append(String(repeating: "-", count: 10))
        let sortedDirections = recipe.directions.sorted { $0.stepNumber < $1.stepNumber }
        for direction in sortedDirections {
            lines.append("\(direction.stepNumber). \(direction.instruction)")
        }
        lines.append("")

        // Nutritional Info
        if let info = recipe.nutritionalInfo {
            lines.append("NUTRITIONAL INFO (per serving)")
            lines.append(String(repeating: "-", count: 30))
            lines.append("Calories: \(Int(info.calories))")
            lines.append("Protein: \(String(format: "%.1f", info.proteinGrams))g")
            lines.append("Carbs: \(String(format: "%.1f", info.carbsGrams))g")
            lines.append("Fat: \(String(format: "%.1f", info.fatGrams))g")
            lines.append("")
        }

        // Tags
        if !recipe.tags.isEmpty {
            lines.append("Tags: \(recipe.tags.joined(separator: ", "))")
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }
}

// MARK: - Export Format

enum RecipeExportFormat: String, CaseIterable, Identifiable {
    case pdf = "PDF"
    case cardImage = "Card Image"
    case plainText = "Plain Text"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .pdf: return "doc.richtext"
        case .cardImage: return "photo"
        case .plainText: return "doc.plaintext"
        }
    }
}

// MARK: - Recipe Export View

struct RecipeExportView: View {
    let recipe: Recipe

    @State private var selectedFormat: RecipeExportFormat = .pdf
    @State private var previewImage: UIImage?
    @State private var plainTextPreview: String = ""
    @State private var exportData: Data?
    @State private var showShareSheet = false
    @State private var isGenerating = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    formatPicker

                    previewSection

                    exportButton
                }
                .padding()
            }
            .navigationTitle("Export Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedFormat) {
                updatePreview()
            }
            .onAppear {
                updatePreview()
            }
            .sheet(isPresented: $showShareSheet) {
                if let items = shareItems() {
                    ShareSheet(activityItems: items)
                }
            }
        }
    }

    // MARK: - Format Picker

    private var formatPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Export Format")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(RecipeExportFormat.allCases) { format in
                    Button {
                        selectedFormat = format
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: format.systemImage)
                                .font(.title2)
                            Text(format.rawValue)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity, minHeight: 70)
                    }
                    .buttonStyle(.glass)
                    .opacity(selectedFormat == format ? 1.0 : 0.5)
                }
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Preview")
                .font(.headline)

            Group {
                switch selectedFormat {
                case .pdf:
                    pdfPreview
                case .cardImage:
                    cardImagePreview
                case .plainText:
                    plainTextPreviewView
                }
            }
            .frame(maxWidth: .infinity, minHeight: 200)
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
        }
    }

    private var pdfPreview: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("PDF Document")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(recipe.title)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var cardImagePreview: some View {
        Group {
            if let image = previewImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(8)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
    }

    private var plainTextPreviewView: some View {
        ScrollView {
            Text(plainTextPreview)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .frame(maxHeight: 300)
    }

    // MARK: - Export Button

    private var exportButton: some View {
        Button {
            performExport()
        } label: {
            HStack {
                if isGenerating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
                Text(isGenerating ? "Generating..." : "Export \(selectedFormat.rawValue)")
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.glass)
        .disabled(isGenerating)
    }

    // MARK: - Actions

    private func updatePreview() {
        switch selectedFormat {
        case .pdf:
            previewImage = nil
            plainTextPreview = ""
        case .cardImage:
            previewImage = RecipeExportService.generateCardImage(from: recipe)
            plainTextPreview = ""
        case .plainText:
            previewImage = nil
            plainTextPreview = RecipeExportService.generatePlainText(from: recipe)
        }
    }

    private func performExport() {
        isGenerating = true
        DispatchQueue.global(qos: .userInitiated).async {
            let items = generateExportItems()
            DispatchQueue.main.async {
                isGenerating = false
                exportData = items.data
                showShareSheet = true
            }
        }
    }

    private func generateExportItems() -> (data: Data?, items: [Any]) {
        switch selectedFormat {
        case .pdf:
            let data = RecipeExportService.generatePDF(from: recipe)
            return (data, [data])
        case .cardImage:
            let image = RecipeExportService.generateCardImage(from: recipe)
            let data = image.pngData()
            return (data, [image])
        case .plainText:
            let text = RecipeExportService.generatePlainText(from: recipe)
            let data = text.data(using: .utf8)
            return (data, [text])
        }
    }

    private func shareItems() -> [Any]? {
        switch selectedFormat {
        case .pdf:
            let data = RecipeExportService.generatePDF(from: recipe)
            return [data]
        case .cardImage:
            let image = RecipeExportService.generateCardImage(from: recipe)
            return [image]
        case .plainText:
            let text = RecipeExportService.generatePlainText(from: recipe)
            return [text]
        }
    }
}

// MARK: - Share Sheet (UIKit Bridge)

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
