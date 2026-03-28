import Foundation
import ActivityKit
import Observation

// MARK: - Cooking Timer Attributes

/// Attributes for the cooking timer Live Activity.
/// Shared definition used by both the app and the widget extension.
struct CookingTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var stepNumber: Int
        var stepInstruction: String
        var remainingSeconds: Int
        var totalSteps: Int
    }

    var recipeTitle: String
    var totalCookTimeMinutes: Int
}

// MARK: - Cooking Timer Live Activity Manager

/// Manages the cooking timer Live Activity lifecycle.
/// Starts, updates, and ends the Dynamic Island / lock screen timer.
@MainActor
@Observable
final class CookingTimerLiveActivityManager {

    static let shared = CookingTimerLiveActivityManager()

    private(set) var currentActivity: Activity<CookingTimerAttributes>?
    private(set) var isActive = false

    private init() {}

    // MARK: - Start

    /// Starts a Live Activity for a cooking timer.
    func startTimer(
        recipeTitle: String,
        totalCookTimeMinutes: Int,
        stepNumber: Int,
        stepInstruction: String,
        durationSeconds: Int,
        totalSteps: Int
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = CookingTimerAttributes(
            recipeTitle: recipeTitle,
            totalCookTimeMinutes: totalCookTimeMinutes
        )

        let state = CookingTimerAttributes.ContentState(
            stepNumber: stepNumber,
            stepInstruction: stepInstruction,
            remainingSeconds: durationSeconds,
            totalSteps: totalSteps
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            isActive = true
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    // MARK: - Update

    /// Updates the Live Activity with new timer state.
    func updateTimer(
        stepNumber: Int,
        stepInstruction: String,
        remainingSeconds: Int,
        totalSteps: Int
    ) async {
        guard let activity = currentActivity else { return }

        let state = CookingTimerAttributes.ContentState(
            stepNumber: stepNumber,
            stepInstruction: stepInstruction,
            remainingSeconds: remainingSeconds,
            totalSteps: totalSteps
        )

        nonisolated(unsafe) let sendableActivity = activity
        await sendableActivity.update(.init(state: state, staleDate: nil))
    }

    // MARK: - End

    /// Ends the Live Activity.
    func endTimer() async {
        guard let activity = currentActivity else { return }

        let finalState = CookingTimerAttributes.ContentState(
            stepNumber: 0,
            stepInstruction: "Cooking complete!",
            remainingSeconds: 0,
            totalSteps: 0
        )

        nonisolated(unsafe) let sendableActivity = activity
        await sendableActivity.end(
            .init(state: finalState, staleDate: nil),
            dismissalPolicy: .after(.now.addingTimeInterval(30))
        )

        currentActivity = nil
        isActive = false
    }
}
