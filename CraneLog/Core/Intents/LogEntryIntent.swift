import AppIntents
import Foundation

/// "Log an entry in <App>" from Siri, Spotlight or the Shortcuts app. Opens the app straight to a new entry.
struct LogEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "Log an Entry"
    static var description = IntentDescription("Opens the fleet ready to start a shift, monthly or annual inspection.")
    static var openAppWhenRun = true

    static let pendingKey = "intent.openNewEntry"

    func perform() async throws -> some IntentResult {
        WidgetSnapshot.defaults.set(true, forKey: Self.pendingKey)
        return .result()
    }
}

struct CraneLogShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogEntryIntent(),
            phrases: ["Open \(.applicationName)", "Start an inspection in \(.applicationName)"],
            shortTitle: "Inspect Crane",
            systemImageName: "plus.circle"
        )
    }
}
