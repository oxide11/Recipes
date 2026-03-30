import Foundation

/// Formats a duration in seconds as "M:SS" (e.g. 90 → "1:30").
func formatTime(_ totalSeconds: Int) -> String {
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%d:%02d", minutes, seconds)
}
