import Foundation

// MARK: - Multi-Recipe Cooking Step

/// A single step in a multi-recipe cooking plan.
struct MultiCookingStep: Identifiable, Sendable {
    let id = UUID()
    let recipeTitle: String
    let recipeIndex: Int
    let originalStepNumber: Int
    let instruction: String
    let timer: TimerStep?
    let ingredients: [DirectionIngredientRef]
    let safeTemperature: SafeTemperature?
    let parallelNote: String?
    let isPassive: Bool
}

// MARK: - Multi-Recipe Cooking Plan

/// The complete optimized multi-recipe cooking plan.
struct MultiRecipeCookingPlan: Sendable {
    let recipeTitles: [String]
    let steps: [MultiCookingStep]
    let estimatedTotalMinutes: Int
    let savedMinutesVsSequential: Int
}

// MARK: - Multi-Recipe Cooking Service

enum CookingPlanError: Error {
    case noRecipes
}

enum MultiRecipeCookingService {

    /// Generate an optimized cooking plan from multiple planned meals using AI.
    @MainActor
    static func generatePlan(
        from meals: [PlannedMeal],
        using aiRouter: AIServiceRouter
    ) async throws -> MultiRecipeCookingPlan {
        let recipes = meals.compactMap(\.recipe)
        guard recipes.count >= 2 else {
            guard let recipe = recipes.first else {
                throw CookingPlanError.noRecipes
            }
            return singleRecipePlan(recipe)
        }

        let prompt = buildOptimizationPrompt(recipes: recipes)
        let response = try await aiRouter.generateText(
            prompt: prompt,
            taskType: .cookingOptimization
        )
        return parseOptimizedPlan(from: response, recipes: recipes)
    }

    /// Fallback: simple interleaving without AI.
    static func generateBasicPlan(from meals: [PlannedMeal]) -> MultiRecipeCookingPlan {
        let recipes = meals.compactMap(\.recipe)
        guard recipes.count >= 2 else {
            if let recipe = recipes.first {
                return singleRecipePlan(recipe)
            }
            return MultiRecipeCookingPlan(recipeTitles: [], steps: [], estimatedTotalMinutes: 0, savedMinutesVsSequential: 0)
        }

        let recipeTitles = recipes.map(\.title)

        // Keep each recipe's steps in their original order, then interleave
        // round-robin across recipes so within-recipe order is never broken.
        let recipeSteps: [[RecipeDirection]] = recipes.map {
            $0.directions.sorted { $0.stepNumber < $1.stepNumber }
        }
        let maxLen = recipeSteps.map(\.count).max() ?? 0
        var allSteps: [MultiCookingStep] = []

        for i in 0..<maxLen {
            for (recipeIdx, steps) in recipeSteps.enumerated() {
                guard i < steps.count else { continue }
                let direction = steps[i]
                let recipe = recipes[recipeIdx]
                allSteps.append(MultiCookingStep(
                    recipeTitle: recipe.title,
                    recipeIndex: recipeIdx,
                    originalStepNumber: direction.stepNumber,
                    instruction: direction.instruction,
                    timer: direction.timer,
                    ingredients: direction.ingredients,
                    safeTemperature: direction.safeTemperature,
                    parallelNote: nil,
                    isPassive: direction.timer != nil
                ))
            }
        }

        let sequentialMinutes = recipes.map(\.estimatedTotalMinutes).reduce(0, +)
        // Estimate: overlapping passive time saves ~30% on multi-recipe
        let estimatedMinutes = max(
            recipes.map(\.estimatedTotalMinutes).max() ?? 0,
            Int(Double(sequentialMinutes) * 0.7)
        )
        let saved = sequentialMinutes - estimatedMinutes

        return MultiRecipeCookingPlan(
            recipeTitles: recipeTitles,
            steps: allSteps,
            estimatedTotalMinutes: estimatedMinutes,
            savedMinutesVsSequential: saved
        )
    }

    // MARK: - Private Helpers

    private static func singleRecipePlan(_ recipe: Recipe) -> MultiRecipeCookingPlan {
        let steps = recipe.directions.sorted(by: { $0.stepNumber < $1.stepNumber }).map { direction in
            MultiCookingStep(
                recipeTitle: recipe.title,
                recipeIndex: 0,
                originalStepNumber: direction.stepNumber,
                instruction: direction.instruction,
                timer: direction.timer,
                ingredients: direction.ingredients,
                safeTemperature: direction.safeTemperature,
                parallelNote: nil,
                isPassive: direction.timer != nil
            )
        }
        return MultiRecipeCookingPlan(
            recipeTitles: [recipe.title],
            steps: steps,
            estimatedTotalMinutes: recipe.estimatedTotalMinutes,
            savedMinutesVsSequential: 0
        )
    }

    private static func buildOptimizationPrompt(recipes: [Recipe]) -> String {
        var prompt = """
        You are a professional chef planning to cook multiple recipes simultaneously. \
        Optimize the order of cooking steps across all recipes so the total cooking time \
        is minimized. Interleave steps so that passive waiting time (oven, simmering, \
        marinating) is filled with active steps from other recipes.

        Output ONLY a JSON array of objects with these keys:
        - "recipeIndex": (Int) zero-based index of the recipe
        - "stepNumber": (Int) the original step number
        - "parallelNote": (String or null) a brief note like "While the chicken roasts..." if this step can overlap with a previous passive step

        Recipes:\n\n
        """

        for (idx, recipe) in recipes.enumerated() {
            prompt += "Recipe \(idx): \(recipe.title)\n"
            prompt += "  Estimated: \(recipe.prepTimeMinutes) min prep + \(recipe.cookTimeMinutes) min cook\n"
            for direction in recipe.directions.sorted(by: { $0.stepNumber < $1.stepNumber }) {
                prompt += "  Step \(direction.stepNumber): \(direction.instruction)"
                if let timer = direction.timer {
                    prompt += " [TIMER: \(timer.displayDuration)]"
                }
                if let temp = direction.safeTemperature {
                    prompt += " [SAFE TEMP: \(temp.protein) \(Int(temp.minimumFahrenheit))°F]"
                }
                prompt += "\n"
            }
            prompt += "\n"
        }

        return prompt
    }

    private static func parseOptimizedPlan(from response: String, recipes: [Recipe]) -> MultiRecipeCookingPlan {
        // Try to parse the AI JSON response
        let recipeTitles = recipes.map(\.title)

        // Extract JSON array from response (may have markdown wrapping)
        let cleaned = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        struct StepOrder: Codable {
            let recipeIndex: Int
            let stepNumber: Int
            let parallelNote: String?
        }

        guard let data = cleaned.data(using: .utf8),
              let orders = try? JSONDecoder().decode([StepOrder].self, from: data) else {
            // Fallback: return steps in recipe order
            return fallbackPlan(recipes: recipes, recipeTitles: recipeTitles)
        }

        var steps: [MultiCookingStep] = []
        for order in orders {
            guard order.recipeIndex >= 0, order.recipeIndex < recipes.count else { continue }
            let recipe = recipes[order.recipeIndex]
            guard let direction = recipe.directions.first(where: { $0.stepNumber == order.stepNumber }) else { continue }

            steps.append(MultiCookingStep(
                recipeTitle: recipe.title,
                recipeIndex: order.recipeIndex,
                originalStepNumber: direction.stepNumber,
                instruction: direction.instruction,
                timer: direction.timer,
                ingredients: direction.ingredients,
                safeTemperature: direction.safeTemperature,
                parallelNote: order.parallelNote,
                isPassive: direction.timer != nil
            ))
        }

        // If parsing yielded no steps, fallback
        if steps.isEmpty {
            return fallbackPlan(recipes: recipes, recipeTitles: recipeTitles)
        }

        let sequentialMinutes = recipes.map(\.estimatedTotalMinutes).reduce(0, +)
        let estimatedMinutes = max(
            recipes.map(\.estimatedTotalMinutes).max() ?? 0,
            Int(Double(sequentialMinutes) * 0.65) // AI optimization tends to be better
        )

        return MultiRecipeCookingPlan(
            recipeTitles: recipeTitles,
            steps: steps,
            estimatedTotalMinutes: estimatedMinutes,
            savedMinutesVsSequential: sequentialMinutes - estimatedMinutes
        )
    }

    private static func fallbackPlan(recipes: [Recipe], recipeTitles: [String]) -> MultiRecipeCookingPlan {
        var steps: [MultiCookingStep] = []
        for (idx, recipe) in recipes.enumerated() {
            for direction in recipe.directions.sorted(by: { $0.stepNumber < $1.stepNumber }) {
                steps.append(MultiCookingStep(
                    recipeTitle: recipe.title,
                    recipeIndex: idx,
                    originalStepNumber: direction.stepNumber,
                    instruction: direction.instruction,
                    timer: direction.timer,
                    ingredients: direction.ingredients,
                    safeTemperature: direction.safeTemperature,
                    parallelNote: nil,
                    isPassive: direction.timer != nil
                ))
            }
        }
        let total = recipes.map(\.estimatedTotalMinutes).reduce(0, +)
        return MultiRecipeCookingPlan(
            recipeTitles: recipeTitles,
            steps: steps,
            estimatedTotalMinutes: total,
            savedMinutesVsSequential: 0
        )
    }
}
