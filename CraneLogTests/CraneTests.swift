import Testing
import Foundation
import PDFKit
@testable import CraneLog

/// The checklist has to fit the machine. A crawler asked about tire pressure is an app that
/// gets deleted on the first job.
struct ItemApplicabilityTests {
    private func crane(tires: Bool = true, rail: Bool = false, cab: Bool = true,
                       kind: CraneKind = .mobile) -> Crane {
        let c = Crane(unitNumber: "RT-04", make: "Grove", model: "RT770E")
        c.hasTires = tires; c.isRailMounted = rail; c.hasCab = cab; c.kind = kind
        return c
    }

    @Test func aCrawlerIsNeverAskedAboutTires() {
        #expect(!CheckItem.items(for: .shift, crane: crane(tires: false)).contains(.tires))
        #expect(CheckItem.items(for: .shift, crane: crane(tires: true)).contains(.tires))
    }

    @Test func railItemsOnlyAppearOnRailMountedMachines() {
        #expect(!CheckItem.items(for: .shift, crane: crane()).contains(.railsAndStops))
        #expect(CheckItem.items(for: .shift, crane: crane(rail: true)).contains(.railsAndStops))
    }

    @Test func aTowerCraneIsNotAskedAboutOutriggers() {
        #expect(!CheckItem.items(for: .shift, crane: crane(kind: .tower)).contains(.outriggers))
        #expect(CheckItem.items(for: .shift, crane: crane(kind: .mobile)).contains(.outriggers))
    }

    @Test func theMonthlyCoversTheSameItemsAsTheShift() {
        // 1926.1412(d): the monthly inspection covers the items in the shift inspection.
        let c = crane()
        #expect(CheckItem.items(for: .monthly, crane: c) == CheckItem.items(for: .shift, crane: c))
    }

    @Test func theAnnualGoesFurtherThanTheMonthly() {
        let c = crane()
        let monthly = Set(CheckItem.items(for: .monthly, crane: c))
        let annual = Set(CheckItem.items(for: .annual, crane: c))
        #expect(monthly.isSubset(of: annual))
        #expect(annual.contains(.structure))
        #expect(annual.contains(.boltsRivets))
        #expect(annual.count > monthly.count)
    }

    @Test func wireRopeIsOnEveryTier() {
        for tier in Tier.allCases {
            #expect(CheckItem.items(for: tier, crane: crane()).contains(.wireRopeCondition),
                    "\(tier) must look at the rope")
        }
    }
}

/// What the standard says gets written down, and what it does not.
struct TierTests {
    @Test func onlyMonthlyAndAnnualAreDocumented() {
        #expect(!Tier.shift.isDocumented, "the standard asks for no record of the shift inspection")
        #expect(Tier.monthly.isDocumented)
        #expect(Tier.annual.isDocumented)
    }

    @Test func retentionPeriodsMatchTheRule() {
        #expect(Tier.monthly.retentionMonths == 3)
        #expect(Tier.annual.retentionMonths == 12)
        #expect(Tier.shift.retentionMonths == nil)
    }

    @Test func theAnnualNeedsAQualifiedPersonAndTheMonthlyACompetentOne() {
        #expect(Tier.monthly.role == .competent)
        #expect(Tier.shift.role == .competent)
        #expect(Tier.annual.role == .qualified)
        #expect(Tier.postAssembly.role == .qualified)
    }
}

/// The consequential judgement: deficiency versus safety hazard.
struct VerdictTests {
    private func inspection(_ tier: Tier = .monthly,
                            _ configure: (Inspection, Crane) -> Void) -> Inspection {
        let c = Crane(unitNumber: "BT-11", make: "National", model: "NBT45")
        let i = Inspection(date: .now, tier: tier)
        i.crane = c
        c.inspections = [i]
        configure(i, c)
        return i
    }

    @Test func anUntouchedInspectionIsNotSatisfactory() {
        let i = inspection { _, _ in }
        #expect(i.verdict == .incomplete)
    }

    @Test func allOkIsSatisfactory() {
        let i = inspection { i, _ in for item in i.items { i.set(.satisfactory, for: item) } }
        #expect(i.verdict == .satisfactory)
    }

    @Test func aDeficiencyIsNotOutOfService() {
        let i = inspection { i, _ in
            for item in i.items { i.set(.satisfactory, for: item) }
            i.set(.deficient, for: .pressurizedLines)
        }
        #expect(i.verdict == .deficient, "a deficiency is something to fix, not a red tag")
        #expect(i.safetyHazards.isEmpty)
    }

    @Test func aSafetyHazardOutranksEverything() {
        let i = inspection { i, _ in
            for item in i.items { i.set(.satisfactory, for: item) }
            i.set(.deficient, for: .pressurizedLines)
            i.set(.safetyHazard, for: .wireRopeCondition)
        }
        #expect(i.verdict == .outOfService)
        #expect(i.safetyHazards == [.wireRopeCondition])
    }

    @Test func aDocumentedRecordIsNotCompleteWithoutASignature() {
        let i = inspection(.monthly) { i, _ in
            for item in i.items { i.set(.satisfactory, for: item) }
            i.inspectorName = "D. Castellanos"
        }
        #expect(!i.isRecordComplete, "the rule asks for a signature, so an unsigned monthly is not a record")
        i.signature = Data([0x1])
        #expect(i.isRecordComplete)
    }

    @Test func aShiftInspectionNeedsNoSignatureToBeComplete() {
        let i = inspection(.shift) { i, _ in for item in i.items { i.set(.satisfactory, for: item) } }
        #expect(i.isRecordComplete)
    }

    @Test func resultsAreStoredByNameSoAddingAnItemCannotRewriteHistory() {
        let i = inspection { i, _ in i.set(.safetyHazard, for: .hooksLatches) }
        #expect(i.resultsRaw["hooksLatches"] == "safetyHazard")
        #expect(i.result(.structure) == .notChecked)
    }
}

struct ClockTests {
    private func crane(shift: Int? = nil, monthly: Int? = nil, annual: Int? = nil) -> Crane {
        let c = Crane(unitNumber: "RT-04", make: "Grove", model: "RT770E")
        var list: [Inspection] = []
        for (tier, days) in [(Tier.shift, shift), (.monthly, monthly), (.annual, annual)] {
            guard let days else { continue }
            let i = Inspection(date: Calendar.current.date(byAdding: .day, value: -days, to: .now)!, tier: tier)
            i.crane = c
            list.append(i)
        }
        c.inspections = list
        return c
    }

    @Test func aShiftCheckDoneTodayIsDoneAndYesterdaysIsNot() {
        #expect(crane(shift: 0).status(.shift) == .doneToday)
        #expect(crane(shift: 1).status(.shift) == .dueToday)
        #expect(crane().status(.shift) == .noRecord)
    }

    @Test func theMonthlyRunsOnAMonthAndTheAnnualOnAYear() {
        let c = crane(monthly: 10, annual: 100)
        if case .current = c.status(.monthly) {} else { Issue.record("monthly should be current") }
        if case .current = c.status(.annual) {} else { Issue.record("annual should be current") }
    }

    @Test func pastTheIntervalIsOverdue() {
        let c = crane(monthly: 50, annual: 400)
        guard case .overdue = c.status(.monthly) else { Issue.record("monthly overdue"); return }
        guard case .overdue = c.status(.annual) else { Issue.record("annual overdue"); return }
    }

    @Test func clocksComeBackWorstFirst() {
        let c = crane(shift: 0, monthly: 50, annual: 10)
        #expect(c.clocks().first?.tier == .monthly, "the overdue one leads")
        #expect(c.clocks().last?.tier == .shift, "the one done today goes last")
    }

    @Test func aThinFileIsReportedAsARetentionGap() {
        // Three monthly records are expected inside the three-month window; one is held.
        let c = crane(monthly: 10)
        let gap = c.retentionGap(.monthly)
        #expect(gap != nil)
        #expect(gap?.contains("1 of 3") == true)
        #expect(c.retentionGap(.shift) == nil, "no record is required, so there is no gap")
    }

    @Test func oneAnnualInsideTwelveMonthsIsAFullFileNotAGap() {
        // The window is twelve months and the interval is twelve months, so one record fills
        // it. Asking for twelve annual inspections in a year is the bug this guards.
        #expect(crane(annual: 100).retentionGap(.annual) == nil)
        #expect(crane().retentionGap(.annual) != nil, "no annual at all is still a gap")
        #expect(crane(monthly: 10, annual: 100).retentionGap(.monthly)?.contains("1 of 3") == true)
    }
}

struct ExportTests {
    private func loaded() -> Crane {
        let c = Crane(unitNumber: "CD-02", make: "Broderson", model: "IC-80")
        c.serialNumber = "SN-448120"
        c.capacityTons = 8.5
        c.kind = .carryDeck
        c.owner = "Hallam Rigging"
        let i = Inspection(date: Calendar.current.date(byAdding: .day, value: -2, to: .now)!, tier: .monthly)
        i.inspectorName = "D. Castellanos"
        i.crane = c
        for item in CheckItem.items(for: .monthly, crane: c) { i.set(.satisfactory, for: item) }
        i.set(.safetyHazard, for: .wireRopeCondition)
        i.setNote("Six broken wires in one lay, above the wedge socket.", for: .wireRopeCondition)
        i.correctiveAction = "Rope condemned; replacement ordered."
        c.inspections = [i]
        c.outOfServiceSince = i.date
        c.outOfServiceReason = "Wire rope condition"
        return c
    }

    @Test func csvHasAHeaderAndOneRowPerInspection() throws {
        let text = try String(contentsOf: try CSVExporter.export([loaded()]), encoding: .utf8)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        #expect(lines.count == 2)
        #expect(lines[0].hasPrefix("unit,make,model,serial"))
        #expect(lines[0].contains("wireRopeCondition"))
    }

    @Test func csvRecordsWhetherTheInspectionWasSigned() throws {
        let c = loaded()
        var text = try String(contentsOf: try CSVExporter.export([c]), encoding: .utf8)
        #expect(text.contains(",no,"), "an unsigned documented record must say so")
        c.sortedInspections.first?.signature = Data([0x1])
        text = try String(contentsOf: try CSVExporter.export([c]), encoding: .utf8)
        #expect(text.contains(",yes,"))
    }

    @Test func thePdfLeadsWithTheVerdictAndNamesTheRule() throws {
        let c = loaded()
        let url = try PDFExporter.export(try #require(c.sortedInspections.first))
        let doc = try #require(PDFDocument(url: url))
        let text = (doc.string ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        #expect(text.contains("Monthly crane inspection"))
        #expect(text.contains("1926.1412"))
        #expect(text.contains("TAKE IT OUT OF SERVICE"))
        #expect(text.contains("Competent person"))
    }

    @Test func thePdfSaysWhenADocumentedRecordIsUnsigned() throws {
        let c = loaded()
        let url = try PDFExporter.export(try #require(c.sortedInspections.first))
        let doc = try #require(PDFDocument(url: url))
        let text = (doc.string ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        #expect(text.contains("Not signed"))
        #expect(text.contains("retained for at least 3 months"))
    }

    @Test func thePdfCarriesTheHazardAndItsNote() throws {
        let c = loaded()
        let url = try PDFExporter.export(try #require(c.sortedInspections.first))
        let doc = try #require(PDFDocument(url: url))
        let text = (doc.string ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        #expect(text.contains("HAZARD"))
        #expect(text.contains("Six broken wires in one lay"))
    }

    @Test func thePdfDoesNotClaimToJudgeAHazard() throws {
        let c = loaded()
        let url = try PDFExporter.export(try #require(c.sortedInspections.first))
        let doc = try #require(PDFDocument(url: url))
        let text = (doc.string ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        #expect(text.contains("that judgement is the inspector's"))
    }

    @Test func theHistoryShowsTheRedTagAndTheRetentionGap() throws {
        let url = try PDFExporter.exportHistory(loaded())
        let doc = try #require(PDFDocument(url: url))
        let text = (doc.string ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        #expect(text.contains("OUT OF SERVICE"))
        #expect(text.contains("Wire rope condition"))
        #expect(text.contains("retention window"))
    }

    @Test func anEmptyMachineSaysSo() throws {
        let url = try PDFExporter.exportHistory(Crane(unitNumber: "NEW-1", make: "", model: ""))
        let doc = try #require(PDFDocument(url: url))
        let text = (doc.string ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        #expect(text.contains("No inspections have been recorded"))
    }
}
