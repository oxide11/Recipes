import Foundation

// MARK: - Receipt Matching Service

/// Matches scanned receipt line items to grocery list items using fuzzy string matching,
/// with optional LLM-assisted matching for ambiguous cases.
enum ReceiptMatchingService {

    // MARK: - Types

    struct MatchResult: Identifiable, @unchecked Sendable {
        let id = UUID()
        let receiptItem: ReceiptLineItem
        var groceryItem: GroceryItem?
        let confidence: Double  // 0.0 to 1.0
        var isConfirmed: Bool = false
    }

    // MARK: - Fuzzy Matching

    /// Match receipt line items to grocery items using fuzzy string comparison.
    @MainActor
    static func matchReceiptItems(
        _ receiptItems: [ReceiptLineItem],
        to groceryItems: [GroceryItem]
    ) -> [MatchResult] {
        receiptItems.map { receiptItem in
            var bestMatch: GroceryItem?
            var bestConfidence: Double = 0

            for groceryItem in groceryItems {
                let conf = similarity(receiptItem.name, groceryItem.name)
                if conf > bestConfidence {
                    bestConfidence = conf
                    bestMatch = groceryItem
                }
            }

            return MatchResult(
                receiptItem: receiptItem,
                groceryItem: bestConfidence >= 0.4 ? bestMatch : nil,
                confidence: bestConfidence
            )
        }
    }

    /// Apply confirmed matches — sets actualPrice on grocery items.
    @MainActor
    static func applyMatches(_ matches: [MatchResult]) {
        for match in matches where match.isConfirmed {
            guard let item = match.groceryItem else { continue }
            item.actualPrice = match.receiptItem.price
            if !item.isPurchased {
                item.isPurchased = true
            }
        }
    }

    /// Use LLM for ambiguous matches (confidence between 0.3 and 0.5).
    @MainActor
    static func llmAssistedMatch(
        receiptItems: [ReceiptLineItem],
        groceryItems: [GroceryItem],
        using aiRouter: AIServiceRouter
    ) async throws -> [MatchResult] {
        let receiptList = receiptItems.enumerated().map { "\($0.offset + 1). \"\($0.element.name)\" ($\(String(format: "%.2f", $0.element.price)))" }.joined(separator: "\n")
        let groceryList = groceryItems.enumerated().map { "\($0.offset + 1). \"\($0.element.name)\" (\(String(format: "%.1f", $0.element.quantity)) \($0.element.unit.rawValue))" }.joined(separator: "\n")

        let prompt = """
        Match these receipt items to grocery list items. Return JSON array of objects with "receiptIndex" (1-based) and "groceryIndex" (1-based, or null if no match). Only match items that clearly refer to the same product.

        Receipt items:
        \(receiptList)

        Grocery list items:
        \(groceryList)

        Respond with only the JSON array, no other text.
        """

        let response = try await aiRouter.generateText(prompt: prompt, taskType: .classification)

        // Parse the JSON response
        guard let data = response.data(using: String.Encoding.utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return jsonArray.compactMap { dict -> MatchResult? in
            guard let receiptIdx = dict["receiptIndex"] as? Int,
                  receiptIdx >= 1, receiptIdx <= receiptItems.count else { return nil }
            let receiptItem = receiptItems[receiptIdx - 1]

            if let groceryIdx = dict["groceryIndex"] as? Int,
               groceryIdx >= 1, groceryIdx <= groceryItems.count {
                return MatchResult(
                    receiptItem: receiptItem,
                    groceryItem: groceryItems[groceryIdx - 1],
                    confidence: 0.8
                )
            }

            return MatchResult(receiptItem: receiptItem, groceryItem: nil, confidence: 0)
        }
    }

    // MARK: - String Similarity

    /// Normalized similarity score between two strings (0.0 to 1.0).
    /// Combines Levenshtein distance with substring containment.
    private static func similarity(_ a: String, _ b: String) -> Double {
        let a = a.lowercased().trimmingCharacters(in: .whitespaces)
        let b = b.lowercased().trimmingCharacters(in: .whitespaces)

        // Exact match
        if a == b { return 1.0 }

        // Substring containment bonus
        if a.contains(b) || b.contains(a) {
            let shorter = min(a.count, b.count)
            let longer = max(a.count, b.count)
            return 0.6 + 0.4 * (Double(shorter) / Double(longer))
        }

        // Word overlap
        let aWords = Set(a.components(separatedBy: .whitespaces))
        let bWords = Set(b.components(separatedBy: .whitespaces))
        let overlap = aWords.intersection(bWords)
        let union = aWords.union(bWords)
        let jaccard = union.isEmpty ? 0 : Double(overlap.count) / Double(union.count)

        // Levenshtein-based similarity
        let maxLen = max(a.count, b.count)
        guard maxLen > 0 else { return 0 }
        let distance = levenshtein(a, b)
        let levenshteinSim = 1.0 - (Double(distance) / Double(maxLen))

        // Weighted combination
        return max(jaccard * 0.6 + levenshteinSim * 0.4, levenshteinSim)
    }

    /// Levenshtein edit distance.
    private static func levenshtein(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let m = aChars.count
        let n = bChars.count

        if m == 0 { return n }
        if n == 0 { return m }

        var prev = Array(0...n)
        var curr = Array(repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,      // deletion
                    curr[j - 1] + 1,  // insertion
                    prev[j - 1] + cost // substitution
                )
            }
            prev = curr
        }

        return curr[n]
    }
}
