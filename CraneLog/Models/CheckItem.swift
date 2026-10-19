import Foundation

/// The items the standard names, in the order somebody actually walks a machine: the ground
/// it is standing on, then round the carrier, then up into the boom and rope, then into the cab.
///
/// Shift and monthly share a list, because 1926.1412(d) says the monthly covers the same items
/// as the shift inspection. The annual adds the structural and mechanical items a qualified
/// person opens things up to see. Wire rope items come from 1926.1413, which runs its own
/// shift / monthly / annual ladder alongside this one.
///
/// These are field prompts, not a reprint of the standard. The standard is the authority.
enum CheckItem: String, CaseIterable, Identifiable {
    // Ground and setup
    case groundConditions, levelPosition, outriggers
    // Carrier and powerplant
    case tires, controlMechanisms, driveMechanisms, pressurizedLines, hydraulicFluid
    case electricalApparatus, powerplant, travelSteeringBraking
    // Load path
    case hooksLatches, wireRopeReeving, wireRopeCondition, wireRopeEndConnections
    case sheavesDrums, chainsSprockets
    // Structure, opened up for the annual
    case structure, boltsRivets, pinsBearingsShafts, brakesClutches
    // Cab and safety
    case safetyDevices, operationalAids, loadChartPresent, cabWindows, decalsPlacards
    // Rail-mounted only
    case railsAndStops

    var id: String { rawValue }

    var name: String {
        switch self {
        case .groundConditions: return "Ground conditions and support"
        case .levelPosition: return "Equipment level"
        case .outriggers: return "Outriggers and stabilisers"
        case .tires: return "Tires: inflation and condition"
        case .controlMechanisms: return "Control mechanisms for maladjustment"
        case .driveMechanisms: return "Control and drive mechanisms for wear and contamination"
        case .pressurizedLines: return "Air, hydraulic and pressurised lines"
        case .hydraulicFluid: return "Hydraulic system fluid level"
        case .electricalApparatus: return "Electrical apparatus"
        case .powerplant: return "Powerplant"
        case .travelSteeringBraking: return "Travel, steering, braking and locking devices"
        case .hooksLatches: return "Hooks and latches"
        case .wireRopeReeving: return "Wire rope reeving"
        case .wireRopeCondition: return "Wire rope condition"
        case .wireRopeEndConnections: return "Rope end connections"
        case .sheavesDrums: return "Sheaves and drums"
        case .chainsSprockets: return "Chains and chain drive sprockets"
        case .structure: return "Structure: boom, jib and frame"
        case .boltsRivets: return "Bolts and rivets for looseness"
        case .pinsBearingsShafts: return "Pins, bearings, shafts, gears and rollers"
        case .brakesClutches: return "Brake and clutch parts, linings, pawls and ratchets"
        case .safetyDevices: return "Safety devices"
        case .operationalAids: return "Operational aids"
        case .loadChartPresent: return "Load chart present and legible"
        case .cabWindows: return "Operator cab windows"
        case .decalsPlacards: return "Safety decals and placards"
        case .railsAndStops: return "Rails, rail stops, clamps and supporting surfaces"
        }
    }

    /// What the inspector is looking at, written for someone standing at the machine.
    var hint: String {
        switch self {
        case .groundConditions: return "Firm, drained and graded enough to hold the machine and its outrigger loads. Look for fill, slopes, and anything buried."
        case .levelPosition: return "Within the manufacturer's tolerance. Most charts assume level."
        case .outriggers: return "Fully extended or as the chart used requires, pads sound, no drift."
        case .tires: return "Inflation and condition, where the machine is on tires."
        case .controlMechanisms: return "Each control for maladjustment that interferes with proper operation."
        case .driveMechanisms: return "Excessive wear of components and contamination by lubricants, water or other foreign matter."
        case .pressurizedLines: return "Deterioration or leakage, particularly at lines flexing in normal operation."
        case .hydraulicFluid: return "Level in the sight glass or dipstick, cold, on level ground."
        case .electricalApparatus: return "Malfunctioning, signs of excessive deterioration, dirt or moisture accumulation."
        case .powerplant: return "Engine or motor: fluids, belts, exhaust, mounts, guards."
        case .travelSteeringBraking: return "Travel, steering, braking and locking devices, including the parking brake."
        case .hooksLatches: return "Deformation, cracks, excessive wear, and a latch that closes and holds."
        case .wireRopeReeving: return "Reeved as the manufacturer specifies, no crossed or jumped wraps."
        case .wireRopeCondition: return "Broken wires, corrosion, kinks, birdcaging, heat damage, core protrusion, diameter reduction. This one has its own rule, and its own monthly record."
        case .wireRopeEndConnections: return "Wedge sockets, swages and clips: correct, tight and undamaged."
        case .sheavesDrums: return "Cracks and excessive wear in grooves and flanges."
        case .chainsSprockets: return "Chain stretch, sprocket wear, lubrication."
        case .structure: return "Booms, jibs and frame for deformation, cracks and corrosion."
        case .boltsRivets: return "Looseness, particularly at slew ring, boom foot and outrigger boxes."
        case .pinsBearingsShafts: return "Wear, cracks, distortion, and locking devices in place."
        case .brakesClutches: return "Parts, linings, pawls and ratchets for excessive wear."
        case .safetyDevices: return "Boom stops, jib stops, anti-two-block, outrigger position sensors, horn."
        case .operationalAids: return "Load indicators, boom angle and length indicators, LMI, drum rotation indicator."
        case .loadChartPresent: return "The chart for this configuration, in the cab, legible, and the one being worked to."
        case .cabWindows: return "Significant cracks, breaks or other deficiencies that would hinder the view."
        case .decalsPlacards: return "The safety and warning decals originally provided, present and readable."
        case .railsAndStops: return "Rail-mounted machines only: rails, stops, clamps and the surfaces carrying them."
        }
    }

    /// Wire rope runs its own inspection ladder under 1926.1413, so those items are marked.
    var isWireRope: Bool {
        self == .wireRopeCondition || self == .wireRopeReeving || self == .wireRopeEndConnections
    }

    /// The items a shift and a monthly inspection cover. The monthly is the same list.
    static let shiftItems: [CheckItem] = [
        .groundConditions, .levelPosition, .outriggers,
        .tires, .controlMechanisms, .driveMechanisms, .pressurizedLines, .hydraulicFluid,
        .electricalApparatus,
        .hooksLatches, .wireRopeReeving, .wireRopeCondition,
        .safetyDevices, .operationalAids, .loadChartPresent, .cabWindows,
        .railsAndStops,
    ]

    /// The annual goes further: structure, fasteners, the parts you have to open something to see.
    static let annualExtras: [CheckItem] = [
        .powerplant, .travelSteeringBraking, .wireRopeEndConnections,
        .sheavesDrums, .chainsSprockets,
        .structure, .boltsRivets, .pinsBearingsShafts, .brakesClutches,
        .decalsPlacards,
    ]

    /// What this machine at this tier actually has to answer. A machine on crawlers is never
    /// asked about tires, and a machine that is not rail-mounted is never asked about rails.
    static func items(for tier: Tier, crane: Crane?) -> [CheckItem] {
        let base: [CheckItem]
        switch tier {
        case .shift, .monthly:
            base = shiftItems
        case .annual, .postAssembly, .severeService, .repaired:
            base = shiftItems + annualExtras
        }
        return base.filter { item in
            switch item {
            case .railsAndStops: return crane?.isRailMounted ?? false
            case .tires: return crane?.hasTires ?? true
            case .cabWindows: return crane?.hasCab ?? true
            case .outriggers: return (crane?.kind ?? .mobile) != .tower && (crane?.kind ?? .mobile) != .overhead
            default: return true
            }
        }
    }
}
