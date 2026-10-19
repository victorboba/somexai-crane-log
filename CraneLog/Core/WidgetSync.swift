import Foundation
import WidgetKit

enum WidgetSync {
    /// The Home Screen answers what a yard asks first: is anything red-tagged, and is
    /// anything past due.
    static func update(with cranes: [Crane]) {
        var snapshot = WidgetSnapshot()
        snapshot.totalEntries = cranes.count
        snapshot.outOfService = cranes.filter(\.isOutOfService).count
        snapshot.due = cranes.filter { crane in
            crane.clocks().contains { $0.status.needsAttention }
        }.count
        snapshot.lastEntryTitle = cranes.first(where: \.isOutOfService)?.unitNumber
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
