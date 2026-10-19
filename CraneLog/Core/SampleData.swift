import Foundation
import SwiftData

/// Debug fixtures: a small fleet with one machine red-tagged, because a yard where everything
/// is fine does not show what the app is for.
enum SampleData {
    static func insert(into context: ModelContext) {
        func crane(_ unit: String, _ make: String, _ model: String, tons: Double,
                   kind: CraneKind, site: String, tires: Bool = true) -> Crane {
            let c = Crane(unitNumber: unit, make: make, model: model)
            c.capacityTons = tons
            c.kind = kind
            c.site = site
            c.hasTires = tires
            c.hasCab = true
            c.owner = "Hallam Rigging"
            c.serialNumber = "SN-\(Int.random(in: 100000...999999))"
            context.insert(c)
            return c
        }

        func inspect(_ c: Crane, _ tier: Tier, daysAgo: Int,
                     hazards: [(CheckItem, String)] = [],
                     deficiencies: [(CheckItem, String)] = [],
                     signed: Bool = true) {
            let i = Inspection(date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now,
                               tier: tier)
            i.inspectorName = tier == .annual ? "M. Oyelaran" : "D. Castellanos"
            i.crane = c
            for item in CheckItem.items(for: tier, crane: c) { i.set(.satisfactory, for: item) }
            for (item, note) in deficiencies { i.set(.deficient, for: item); i.setNote(note, for: item) }
            for (item, note) in hazards { i.set(.safetyHazard, for: item); i.setNote(note, for: item) }
            if !hazards.isEmpty || !deficiencies.isEmpty {
                i.correctiveAction = "Reported to the shop; parts on order."
            }
            if signed && tier.isDocumented {
                // A one-pixel placeholder stands in for a drawn signature in the fixtures.
                i.signature = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")
            }
            context.insert(i)
        }

        let rt = crane("RT-04", "Grove", "RT770E", tons: 70, kind: .mobile, site: "Yard")
        inspect(rt, .shift, daysAgo: 0)
        inspect(rt, .monthly, daysAgo: 12)
        inspect(rt, .annual, daysAgo: 96)

        let bt = crane("BT-11", "National", "NBT45", tons: 45, kind: .boomTruck, site: "Wexford St job")
        inspect(bt, .shift, daysAgo: 1)
        inspect(bt, .monthly, daysAgo: 44,
                deficiencies: [(.pressurizedLines, "Weep at the hoist line fitting; watched, not dripping.")])
        inspect(bt, .annual, daysAgo: 300)

        // The red-tagged machine.
        let cd = crane("CD-02", "Broderson", "IC-80", tons: 8.5, kind: .carryDeck, site: "Yard")
        inspect(cd, .shift, daysAgo: 2,
                hazards: [(.wireRopeCondition, "Six broken wires in one lay, just above the wedge socket.")])
        cd.outOfServiceSince = Calendar.current.date(byAdding: .day, value: -2, to: .now)
        cd.outOfServiceReason = "Wire rope condition"
        inspect(cd, .monthly, daysAgo: 20)

        let crawler = crane("CR-01", "Link-Belt", "218 HSL", tons: 110, kind: .crawler,
                            site: "Riverside", tires: false)
        inspect(crawler, .monthly, daysAgo: 38, signed: false)

        try? context.save()
    }
}
