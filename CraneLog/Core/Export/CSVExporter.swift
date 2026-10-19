import Foundation

/// One row per inspection, with a column per item, which is how a safety manager reconciles a
/// fleet against a citation.
enum CSVExporter {
    static func export(_ cranes: [Crane]) throws -> URL {
        var header = ["unit", "make", "model", "serial", "capacity_tons", "kind",
                      "date", "tier", "inspector", "role", "verdict", "signed",
                      "deficiencies", "safety_hazards", "corrective_action", "corrected_on", "notes"]
        header.append(contentsOf: CheckItem.allCases.map(\.rawValue))
        var rows = [header.joined(separator: ",")]

        for crane in cranes.sorted(by: { $0.unitNumber < $1.unitNumber }) {
            for i in crane.sortedInspections {
                var cells = [
                    crane.unitNumber, crane.make, crane.model, crane.serialNumber,
                    crane.capacityTons == 0 ? "" : String(format: "%g", crane.capacityTons),
                    crane.kind.name,
                    ISO8601DateFormatter.day.string(from: i.date), i.tier.name,
                    i.inspectorName, i.role.name, i.verdict.headline,
                    i.signature == nil ? "no" : "yes",
                    i.deficiencies.map(\.name).joined(separator: "; "),
                    i.safetyHazards.map(\.name).joined(separator: "; "),
                    i.correctiveAction,
                    i.correctedOn.map { ISO8601DateFormatter.day.string(from: $0) } ?? "",
                    i.notes,
                ]
                cells.append(contentsOf: CheckItem.allCases.map { item in
                    i.result(item) == .notChecked ? "" : i.result(item).name
                })
                rows.append(cells.map(escape).joined(separator: ","))
            }
        }
        let text = rows.joined(separator: "\n") + "\n"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(AppConfig.exportFileStem)-\(ISO8601DateFormatter.day.string(from: .now)).csv")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func escape(_ value: String) -> String {
        value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" })
            ? "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
            : value
    }
}

extension ISO8601DateFormatter {
    static let day: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()
}
