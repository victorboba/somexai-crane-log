import Foundation

/// A tiny summary the app writes to the shared App Group so the widget can render
/// without touching SwiftData. The app updates it whenever the entry list changes.
struct WidgetSnapshot: Codable {
    var totalEntries: Int = 0
    /// Machines out of service, and machines with a clock past due.
    var outOfService: Int = 0
    var due: Int = 0
    var entriesThisWeek: Int = 0
    var lastEntryTitle: String?
    var lastEntryDate: Date?
    var updatedAt: Date = .now

    static let storageKey = "widget.snapshot"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard
    }

    static func load() -> WidgetSnapshot {
        guard let data = defaults.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return WidgetSnapshot()
        }
        return snapshot
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.defaults.set(data, forKey: Self.storageKey)
    }

    static let placeholder = WidgetSnapshot(totalEntries: 42, entriesThisWeek: 5,
                                            lastEntryTitle: "Morning check", lastEntryDate: .now)
}
