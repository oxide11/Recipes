import Foundation
import ActivityKit
import Observation
import OSLog

private let logger = Logger(subsystem: "com.recipes", category: "LiveActivity")

// MARK: - Timer Deep Link Router

/// Holds the pending deep link destination from a Live Activity tap.
/// Injected into the environment from RecipesApp.
@Observable
final class TimerDeepLink {
    var pendingRecipeID: UUID? = nil
    var pendingStep: Int = 1

    /// Parse a `recipes://timer/{recipeID}/{stepNumber}` URL.
    func handle(_ url: URL) {
        guard url.scheme == "recipes",
              url.host == "timer" else { return }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard let uuidString = parts.first,
              let recipeID = UUID(uuidString: uuidString) else { return }
        pendingRecipeID = recipeID
        let step = parts.dropFirst().first.flatMap(Int.init) ?? 1
        pendingStep = max(1, min(step, 200))
    }

    func clear() {
        pendingRecipeID = nil
        pendingStep = 1
    }
}

// MARK: - Cooking Timer Attributes

/// Shared definition used by both the app and the widget extension.
/// Must stay in sync with the copy in RecipesWidgets.swift.
struct CookingTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var stepNumber: Int
        var stepInstruction: String
        var totalSteps: Int
        /// Non-nil while the timer is counting down; nil when paused or ended.
        var endDate: Date?
        var isPaused: Bool
        /// Seconds remaining at the moment of pause. Nil when running or ended.
        var remainingSeconds: Int?
    }

    var recipeTitle: String
    var recipeID: String   // UUID string — used for the widgetURL deep link
}

// MARK: - Cooking Timer Live Activity Manager

/// Manages one Live Activity for a single cooking timer.
/// Create one instance per timer — do NOT share across steps.
@MainActor
@Observable
final class CookingTimerLiveActivityManager {

    private(set) var currentActivity: Activity<CookingTimerAttributes>?
    private(set) var isActive = false

    // MARK: - Start

    func start(
        recipeTitle: String,
        recipeID: UUID,
        stepNumber: Int,
        stepInstruction: String,
        durationSeconds: Int,
        totalSteps: Int
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let endDate = Date().addingTimeInterval(Double(durationSeconds))
        let attributes = CookingTimerAttributes(recipeTitle: recipeTitle, recipeID: recipeID.uuidString)
        let state = CookingTimerAttributes.ContentState(
            stepNumber: stepNumber,
            stepInstruction: stepInstruction,
            totalSteps: totalSteps,
            endDate: endDate,
            isPaused: false
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),   // nil = never stale; avoids iOS auto-dismiss
                pushType: nil
            )
            isActive = true
        } catch {
            logger.error("Failed to start Live Activity: \(error)")
        }
    }

    // MARK: - Reconnect

    /// Re-attaches this manager to an already-running Live Activity (e.g. after
    /// the view disappears and reappears due to navigation).
    func reconnect(to activity: Activity<CookingTimerAttributes>) {
        currentActivity = activity
        isActive = true
    }

    // MARK: - Pause

    func pause(remainingSeconds: Int) async {
        guard let activity = currentActivity else { return }
        var state = activity.content.state
        state.isPaused = true
        state.endDate = nil
        state.remainingSeconds = remainingSeconds
        nonisolated(unsafe) let a = activity
        await a.update(.init(state: state, staleDate: nil))
    }

    // MARK: - Resume

    func resume(remainingSeconds: Int) async {
        guard let activity = currentActivity else { return }
        let newEnd = Date().addingTimeInterval(Double(remainingSeconds))
        var state = activity.content.state
        state.isPaused = false
        state.endDate = newEnd
        nonisolated(unsafe) let a = activity
        await a.update(.init(state: state, staleDate: nil))
    }

    // MARK: - End

    func end() async {
        guard let activity = currentActivity else { return }
        var finalState = activity.content.state
        finalState.endDate = nil
        finalState.isPaused = false
        nonisolated(unsafe) let a = activity
        await a.end(
            .init(state: finalState, staleDate: nil),
            dismissalPolicy: .after(.now.addingTimeInterval(30))
        )
        currentActivity = nil
        isActive = false
    }
}
