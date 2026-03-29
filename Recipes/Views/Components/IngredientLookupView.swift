import SwiftUI
import UIKit

// MARK: - Ingredient Lookup View

/// A sheet that provides culinary context for an ingredient — similar to Apple's
/// Look Up feature but tailored for cooking. Shows an AI-generated description
/// with what it is, how it's used, common substitutes, and storage tips.
struct IngredientLookupView: View {
    let ingredientName: String
    let category: IngredientCategory
    @Environment(AIServiceRouter.self) private var aiRouter
    @Environment(\.dismiss) private var dismiss

    @State private var lookupResult: IngredientLookupResult?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingDictionary = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with category badge
                    headerSection

                    if isLoading {
                        loadingSection
                    } else if let result = lookupResult {
                        resultSection(result)
                    } else if let error = errorMessage {
                        errorSection(error)
                    }
                }
                .padding()
            }
            .navigationTitle("Look Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await performLookup() }
        .sheet(isPresented: $showingDictionary) {
            DictionaryLookupView(term: ingredientName)
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(category.displayColor.swiftUIColor)
                .frame(width: 14, height: 14)

            Text(ingredientName.capitalized)
                .font(.title2)
                .fontWeight(.bold)

            Spacer()

            Text(category.rawValue.capitalized)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(category.displayColor.swiftUIColor.opacity(0.15), in: .capsule)
                .foregroundStyle(category.displayColor.swiftUIColor)
        }
    }

    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Brand.warmTan)
            Text("Looking up \(ingredientName)…")
                .font(.subheadline)
                .foregroundStyle(Brand.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func resultSection(_ result: IngredientLookupResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Description
            lookupCard(title: "What is it?", icon: "info.circle", content: result.description)

            // Culinary uses
            if !result.culinaryUses.isEmpty {
                lookupCard(title: "How it's used", icon: "frying.pan", content: result.culinaryUses)
            }

            // Substitutes
            if !result.substitutes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Substitutes", systemImage: "arrow.triangle.swap")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    ForEach(result.substitutes, id: \.self) { substitute in
                        HStack(spacing: 8) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 4))
                                .foregroundStyle(Brand.muted)
                            Text(substitute)
                                .font(.subheadline)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(in: .rect(cornerRadius: 12))
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
            }

            // Storage
            if !result.storageTips.isEmpty {
                lookupCard(title: "Storage", icon: "refrigerator", content: result.storageTips)
            }

            // Season
            if !result.seasonalInfo.isEmpty {
                lookupCard(title: "In Season", icon: "leaf", content: result.seasonalInfo)
            }

            // Dictionary lookup button
            dictionaryButton
        }
    }

    private func errorSection(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(Brand.muted)

            Text(error)
                .font(.subheadline)
                .foregroundStyle(Brand.muted)
                .multilineTextAlignment(.center)

            dictionaryButton
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private func lookupCard(title: String, icon: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.semibold)

            Text(content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(in: .rect(cornerRadius: 12))
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }

    private var dictionaryButton: some View {
        Button {
            showingDictionary = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "character.book.closed")
                Text("Look Up in Dictionary")
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(Brand.warmTan)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Brand.warmTan.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Lookup

    private func performLookup() async {
        let prompt = """
        You are a culinary encyclopedia. Provide information about the ingredient "\(ingredientName)".
        Return ONLY a JSON object with these keys:
        - "description": (String) What this ingredient is — 1-2 sentences.
        - "culinaryUses": (String) How it's commonly used in cooking — 1-2 sentences.
        - "substitutes": (Array of String) 2-4 common substitutes, each as a brief phrase.
        - "storageTips": (String) How to store it — 1 sentence.
        - "seasonalInfo": (String) When it's in season — 1 sentence. Empty string if year-round.
        """

        do {
            let response = try await aiRouter.generateText(prompt: prompt, taskType: .ingredientLookup)
            let cleaned = response
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let data = cleaned.data(using: .utf8),
               let parsed = try? JSONDecoder().decode(IngredientLookupResult.self, from: data) {
                withAnimation { lookupResult = parsed }
            } else {
                // Fallback: show raw text as description
                withAnimation {
                    lookupResult = IngredientLookupResult(
                        description: response,
                        culinaryUses: "",
                        substitutes: [],
                        storageTips: "",
                        seasonalInfo: ""
                    )
                }
            }
        } catch {
            errorMessage = "Couldn't look up this ingredient. Try the dictionary instead."
        }

        isLoading = false
    }
}

// MARK: - Lookup Result Model

struct IngredientLookupResult: Decodable {
    let description: String
    let culinaryUses: String
    let substitutes: [String]
    let storageTips: String
    let seasonalInfo: String
}

// MARK: - Dictionary Lookup (UIReferenceLibraryViewController wrapper)

struct DictionaryLookupView: UIViewControllerRepresentable {
    let term: String

    func makeUIViewController(context: Context) -> UIReferenceLibraryViewController {
        UIReferenceLibraryViewController(term: term)
    }

    func updateUIViewController(_ uiViewController: UIReferenceLibraryViewController, context: Context) {}
}
