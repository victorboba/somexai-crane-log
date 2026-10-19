import Foundation
import SwiftData

/// One machine, and the three inspection clocks OSHA runs on it at once.
///
/// 29 CFR 1926.1412 is unusually specific about what has to be written down, and the app is
/// built on exactly that distinction:
///
/// - **Each shift** — a competent person, visually, before or during every shift. The rule
///   asks for no documentation at all. So this app keeps it light and says so, rather than
///   pretending a legal record is being made.
/// - **Monthly** — the same items, by a competent person, and this one *is* documented: the
///   items checked, the results, and the name, signature and date of whoever did it. Retained
///   for at least three months.
/// - **Annual/comprehensive** — a qualified person, at least every twelve months, documented
///   the same way and retained for at least twelve.
///
/// The other thing the standard is blunt about: a deficiency that is a safety hazard means the
/// machine comes out of service until it is corrected. That is a state, not a note, so it is
/// modelled as one.
@Model
final class Crane {
    var id: UUID = UUID()
    var unitNumber: String = ""
    var make: String = ""
    var model: String = ""
    var serialNumber: String = ""
    var capacityTons: Double = 0
    var kindRaw: String = CraneKind.mobile.rawValue
    var owner: String = ""
    var site: String = ""
    var isRailMounted: Bool = false
    var hasTires: Bool = true
    var hasCab: Bool = false

    /// Out of service until corrected, which is where a safety-related deficiency puts it.
    var outOfServiceSince: Date? = nil
    var outOfServiceReason: String = ""

    @Attribute(.externalStorage) var photoData: Data? = nil
    var notes: String = ""

    @Relationship(deleteRule: .cascade, inverse: \Inspection.crane)
    var inspections: [Inspection]? = nil

    var createdAt: Date = Date()

    init(unitNumber: String = "", make: String = "", model: String = "") {
        self.id = UUID()
        self.unitNumber = unitNumber
        self.make = make
        self.model = model
        self.createdAt = .now
    }

    var kind: CraneKind {
        get { CraneKind(rawValue: kindRaw) ?? .mobile }
        set { kindRaw = newValue.rawValue }
    }

    var isOutOfService: Bool { outOfServiceSince != nil }

    var sortedInspections: [Inspection] {
        (inspections ?? []).sorted { $0.date > $1.date }
    }

    func latest(_ tier: Tier) -> Inspection? {
        sortedInspections.first { $0.tier == tier }
    }

    var title: String {
        let unit = unitNumber.isEmpty ? "Unnumbered" : unitNumber
        let machine = [make, model].filter { !$0.isEmpty }.joined(separator: " ")
        return machine.isEmpty ? unit : "\(unit) — \(machine)"
    }

    func nextDue(_ tier: Tier) -> Date? {
        guard let interval = tier.intervalMonths, let last = latest(tier) else { return nil }
        return Calendar.current.date(byAdding: .month, value: interval, to: last.date)
    }

    func status(_ tier: Tier, asOf today: Date = .now) -> TierStatus {
        if tier == .shift {
            guard let last = latest(.shift) else { return .noRecord }
            return Calendar.current.isDate(last.date, inSameDayAs: today) ? .doneToday : .dueToday
        }
        guard let due = nextDue(tier) else { return .noRecord }
        let days = Calendar.current.dateComponents(
            [.day], from: Calendar.current.startOfDay(for: today),
            to: Calendar.current.startOfDay(for: due)).day ?? 0
        if days < 0 { return .overdue(byDays: -days) }
        if days <= 14 { return .dueSoon(inDays: days) }
        return .current(inDays: days)
    }

    /// Worst first, which is the order somebody standing in a yard wants them.
    func clocks(asOf today: Date = .now) -> [(tier: Tier, status: TierStatus)] {
        Tier.scheduled.map { ($0, status($0, asOf: today)) }
            .sorted { $0.1.urgency > $1.1.urgency }
    }

    /// Whether the documented record actually covers the window the standard asks for.
    /// Being unable to produce it is its own finding, separate from having failed anything.
    func retentionGap(_ tier: Tier, asOf today: Date = .now) -> String? {
        guard let months = tier.retentionMonths, let interval = tier.intervalMonths,
              let earliest = Calendar.current.date(byAdding: .month, value: -months, to: today)
        else { return nil }
        // How many of this tier the window should contain: three monthlies in three months,
        // but only one annual in twelve. Dividing by the retention period rather than the
        // interval is how you end up asking for twelve annual inspections in a year.
        let expected = max(1, months / interval)
        let held = sortedInspections.filter { $0.tier == tier && $0.date >= earliest }
        guard held.count < expected else { return nil }
        return "\(held.count) of \(expected) \(tier.name.lowercased()) "
             + "\(expected == 1 ? "record" : "records") inside the \(months)-month retention window"
    }
}

/// One inspection, at one tier, of one machine.
@Model
final class Inspection {
    var id: UUID = UUID()
    var date: Date = Date()
    var tierRaw: String = Tier.shift.rawValue
    var inspectorName: String = ""
    /// The standard names the role: a competent person for shift and monthly, a qualified
    /// person for the annual. The app records which one signed.
    var roleRaw: String = InspectorRole.competent.rawValue
    var resultsRaw: [String: String] = [:]
    var deficiencyNotes: [String: String] = [:]
    var correctiveAction: String = ""
    var correctedOn: Date? = nil
    /// 1926.1412 asks for the signature of the person who conducted the inspection.
    @Attribute(.externalStorage) var signature: Data? = nil
    @Attribute(.externalStorage) var photoData: Data? = nil
    var notes: String = ""
    var crane: Crane? = nil

    init(date: Date = .now, tier: Tier = .shift) {
        self.id = UUID()
        self.date = date
        self.tierRaw = tier.rawValue
        self.roleRaw = tier.role.rawValue
    }

    var tier: Tier {
        get { Tier(rawValue: tierRaw) ?? .shift }
        set { tierRaw = newValue.rawValue; roleRaw = newValue.role.rawValue }
    }

    var role: InspectorRole {
        get { InspectorRole(rawValue: roleRaw) ?? .competent }
        set { roleRaw = newValue.rawValue }
    }

    var items: [CheckItem] { CheckItem.items(for: tier, crane: crane) }

    func result(_ item: CheckItem) -> ItemResult {
        ItemResult(rawValue: resultsRaw[item.rawValue] ?? "") ?? .notChecked
    }

    func set(_ result: ItemResult, for item: CheckItem) {
        resultsRaw[item.rawValue] = result.rawValue
    }

    func note(_ item: CheckItem) -> String { deficiencyNotes[item.rawValue] ?? "" }

    func setNote(_ text: String, for item: CheckItem) {
        if text.isEmpty { deficiencyNotes.removeValue(forKey: item.rawValue) }
        else { deficiencyNotes[item.rawValue] = text }
    }

    var deficiencies: [CheckItem] { items.filter { result($0) == .deficient } }

    /// Deficiencies the inspector marked as a safety hazard. These are the ones that take the
    /// machine out of service, and they are deliberately a separate call from "something is
    /// worn" — the standard leaves that judgement to the competent person, and so does this.
    var safetyHazards: [CheckItem] { items.filter { result($0) == .safetyHazard } }

    var answeredCount: Int { items.filter { result($0) != .notChecked }.count }

    var verdict: InspectionVerdict {
        if !safetyHazards.isEmpty { return .outOfService }
        if !deficiencies.isEmpty { return .deficient }
        if items.contains(where: { result($0) == .notChecked }) { return .incomplete }
        return .satisfactory
    }

    /// A documented tier is not documented without the signature the rule asks for.
    var isRecordComplete: Bool {
        guard tier.isDocumented else { return verdict != .incomplete }
        return verdict != .incomplete && signature != nil && !inspectorName.isEmpty
    }

    var day: Date { Calendar.current.startOfDay(for: date) }
}

// MARK: - The vocabulary of the standard

enum Tier: String, CaseIterable, Identifiable {
    case shift, monthly, annual, postAssembly, severeService, repaired

    var id: String { rawValue }

    /// The three that run on a clock. The others are triggered by an event.
    static var scheduled: [Tier] { [.shift, .monthly, .annual] }

    var name: String {
        switch self {
        case .shift: return "Shift"
        case .monthly: return "Monthly"
        case .annual: return "Annual"
        case .postAssembly: return "Post-assembly"
        case .severeService: return "Severe service"
        case .repaired: return "After repair"
        }
    }

    var intervalMonths: Int? {
        switch self {
        case .monthly: return 1
        case .annual: return 12
        default: return nil
        }
    }

    /// How long the standard says the record must be kept. Nil where no record is required.
    var retentionMonths: Int? {
        switch self {
        case .monthly: return 3
        case .annual: return 12
        default: return nil
        }
    }

    var isDocumented: Bool { retentionMonths != nil }

    var role: InspectorRole {
        switch self {
        case .annual, .postAssembly, .severeService, .repaired: return .qualified
        case .shift, .monthly: return .competent
        }
    }

    var requirement: String {
        switch self {
        case .shift:
            return "A competent person, visually, before or during each shift. The standard asks for no documentation of this one — it is for the crew's protection, not for the file. Keeping it here anyway means a deficiency found on a Tuesday is not lost by Friday."
        case .monthly:
            return "The same items as the shift inspection, monthly, by a competent person. This one is documented: the items checked, the results, and the name, signature and date of whoever did it. Keep it at least three months."
        case .annual:
            return "A qualified person, at least every twelve months, going further than the monthly and disassembling where it is needed to see. Documented the same way and kept at least twelve months."
        case .postAssembly:
            return "A qualified person, after assembly and before first use, that the equipment is configured as the manufacturer requires."
        case .severeService:
            return "A qualified person, where the equipment has been through conditions severe enough to damage it."
        case .repaired:
            return "A qualified person, on whatever was repaired, modified or adjusted, before the machine goes back to work."
        }
    }

    var symbol: String {
        switch self {
        case .shift: return "sun.horizon"
        case .monthly: return "calendar"
        case .annual: return "calendar.badge.clock"
        case .postAssembly: return "wrench.and.screwdriver"
        case .severeService: return "cloud.bolt.rain"
        case .repaired: return "hammer"
        }
    }
}

enum InspectorRole: String, CaseIterable, Identifiable {
    case competent, qualified
    var id: String { rawValue }
    var name: String { self == .competent ? "Competent person" : "Qualified person" }
}

enum TierStatus: Equatable {
    case noRecord
    case doneToday
    case dueToday
    case current(inDays: Int)
    case dueSoon(inDays: Int)
    case overdue(byDays: Int)

    var headline: String {
        switch self {
        case .noRecord: return "Nothing recorded"
        case .doneToday: return "Done today"
        case .dueToday: return "Due this shift"
        case .current(let d): return d > 60 ? "Due in \(d / 30) months" : "Due in \(d) days"
        case .dueSoon(let d): return d == 0 ? "Due today" : "Due in \(d) days"
        case .overdue(let d): return d > 60 ? "Overdue by \(d / 30) months" : "Overdue by \(d) days"
        }
    }

    var urgency: Int {
        switch self {
        case .overdue: return 5
        case .noRecord: return 4
        case .dueToday: return 3
        case .dueSoon: return 2
        case .current: return 1
        case .doneToday: return 0
        }
    }

    var needsAttention: Bool { urgency >= 2 }
}

enum ItemResult: String, CaseIterable, Identifiable {
    case notChecked, satisfactory, deficient, safetyHazard, notApplicable
    var id: String { rawValue }

    var name: String {
        switch self {
        case .notChecked: return "Not checked"
        case .satisfactory: return "OK"
        case .deficient: return "Deficiency"
        case .safetyHazard: return "Safety hazard"
        case .notApplicable: return "N/A"
        }
    }

    var symbol: String {
        switch self {
        case .notChecked: return "circle"
        case .satisfactory: return "checkmark.circle.fill"
        case .deficient: return "exclamationmark.triangle.fill"
        case .safetyHazard: return "octagon.fill"
        case .notApplicable: return "minus.circle"
        }
    }
}

enum InspectionVerdict {
    case incomplete, satisfactory, deficient, outOfService

    var headline: String {
        switch self {
        case .incomplete: return "Not finished"
        case .satisfactory: return "Satisfactory"
        case .deficient: return "Deficiencies noted"
        case .outOfService: return "Take it out of service"
        }
    }

    var detail: String {
        switch self {
        case .incomplete:
            return "Answer every item before this counts as an inspection."
        case .satisfactory:
            return "Every item inspected on this date was found in working order."
        case .deficient:
            return "Deficiencies were found that the inspector did not judge to be a safety hazard. They still have to be corrected."
        case .outOfService:
            return "A deficiency was judged to be a safety hazard. The standard requires the equipment to be taken out of service until it is corrected."
        }
    }

    var symbol: String {
        switch self {
        case .incomplete: return "ellipsis.circle"
        case .satisfactory: return "checkmark.seal.fill"
        case .deficient: return "exclamationmark.triangle.fill"
        case .outOfService: return "octagon.fill"
        }
    }
}

enum CraneKind: String, CaseIterable, Identifiable {
    case mobile, boomTruck, tower, overhead, carryDeck, crawler, articulating
    var id: String { rawValue }

    var name: String {
        switch self {
        case .mobile: return "Mobile / hydraulic"
        case .boomTruck: return "Boom truck"
        case .tower: return "Tower"
        case .overhead: return "Overhead / gantry"
        case .carryDeck: return "Carry deck"
        case .crawler: return "Crawler"
        case .articulating: return "Articulating / knuckle boom"
        }
    }
}
