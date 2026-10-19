import Foundation
import PDFKit
import UIKit

/// The documented inspection record.
///
/// What 1926.1412 asks to be produced is narrow and specific: the items checked, the results,
/// and the name, signature and date of the person who did it. So that is what leads the page,
/// with the signature actually drawn on it rather than a typed name pretending to be one.
///
/// Two documents come out of here: one inspection, and a machine's whole retained history.
enum PDFExporter {
    /// One documented inspection — the page handed to whoever asked for it.
    static func export(_ inspection: Inspection) throws -> URL {
        let crane = inspection.crane
        return try render(named: "\(AppConfig.exportFileStem)-\(ISO8601DateFormatter.day.string(from: inspection.date))") { draw in
            draw.title("\(inspection.tier.name) crane inspection")
            draw.line("29 CFR 1926.1412 — \(inspection.role.name)", size: 11, colour: .secondaryLabel)
            draw.rule()

            draw.line(crane?.title ?? "Unassigned machine", size: 13, weight: .semibold, gapAfter: 2)
            var identity: [String] = []
            if let serial = crane?.serialNumber, !serial.isEmpty { identity.append("Serial \(serial)") }
            if let tons = crane?.capacityTons, tons > 0 { identity.append("\(String(format: "%g", tons)) ton") }
            if let kind = crane?.kind.name { identity.append(kind) }
            if let owner = crane?.owner, !owner.isEmpty { identity.append(owner) }
            if !identity.isEmpty { draw.line(identity.joined(separator: "  ·  "), size: 10, colour: .secondaryLabel, gapAfter: 2) }
            if let site = crane?.site, !site.isEmpty { draw.line(site, size: 10, colour: .secondaryLabel) }
            draw.line("Inspected \(inspection.date.formatted(date: .long, time: .omitted))", size: 10, colour: .secondaryLabel)
            draw.rule()

            let colour: UIColor = switch inspection.verdict {
            case .outOfService: .systemRed
            case .deficient: .systemOrange
            case .satisfactory: .systemGreen
            case .incomplete: .secondaryLabel
            }
            draw.line(inspection.verdict.headline.uppercased(), size: 15, weight: .bold, colour: colour, gapAfter: 2)
            draw.line(inspection.verdict.detail, size: 10, colour: .secondaryLabel)
            draw.rule()

            draw.line("Items checked", size: 12, weight: .semibold, gapAfter: 6)
            for item in inspection.items {
                let result = inspection.result(item)
                let mark = switch result {
                case .satisfactory: "OK"
                case .deficient: "DEF"
                case .safetyHazard: "HAZARD"
                case .notApplicable: "N/A"
                case .notChecked: "—"
                }
                let tint: UIColor = switch result {
                case .safetyHazard: .systemRed
                case .deficient: .systemOrange
                case .notChecked: .secondaryLabel
                default: .label
                }
                draw.line("\(mark.padding(toLength: 8, withPad: " ", startingAt: 0))\(item.name)",
                          size: 9, weight: result == .satisfactory ? .regular : .semibold,
                          colour: tint, gapAfter: 1)
                let note = inspection.note(item)
                if !note.isEmpty {
                    draw.line(note, size: 9, colour: .secondaryLabel, indent: 56, gapAfter: 3)
                }
            }

            if !inspection.correctiveAction.isEmpty {
                draw.rule()
                draw.line("Corrective action", size: 12, weight: .semibold, gapAfter: 4)
                draw.line(inspection.correctiveAction, size: 10)
                if let corrected = inspection.correctedOn {
                    draw.line("Corrected \(corrected.formatted(date: .long, time: .omitted))",
                              size: 10, weight: .semibold, colour: .systemGreen)
                }
            }

            if !inspection.notes.isEmpty {
                draw.rule()
                draw.line("Notes", size: 12, weight: .semibold, gapAfter: 4)
                draw.line(inspection.notes, size: 10)
            }

            draw.rule()
            draw.line(inspection.inspectorName.isEmpty ? "Inspector not named" : inspection.inspectorName,
                      size: 11, weight: .semibold, gapAfter: 2)
            draw.line(inspection.role.name, size: 9, colour: .secondaryLabel, gapAfter: 6)
            if let signature = inspection.signature, let image = UIImage(data: signature) {
                draw.image(image, maxHeight: 70)
            } else if inspection.tier.isDocumented {
                draw.line("Not signed. \(inspection.tier.name) inspections are required to carry the "
                          + "signature of the person who conducted them.",
                          size: 9, colour: .systemRed)
            }

            draw.rule()
            if let retention = inspection.tier.retentionMonths {
                draw.line("This record is required to be retained for at least \(retention) months.",
                          size: 9, colour: .secondaryLabel)
            }
            draw.line("Results above are as entered by the person named. \(AppConfig.appName) records "
                      + "the inspection; it does not inspect, certify or approve any equipment, and it "
                      + "does not decide whether a deficiency is a safety hazard — that judgement is "
                      + "the inspector's.", size: 9, colour: .secondaryLabel)
        }
    }

    /// The machine's retained history, for the day somebody asks to see the file.
    static func exportHistory(_ crane: Crane, asOf today: Date = .now) throws -> URL {
        try render(named: "\(AppConfig.exportFileStem)-history-\(ISO8601DateFormatter.day.string(from: today))") { draw in
            draw.title("Crane inspection history")
            draw.line(crane.title, size: 12, colour: .secondaryLabel)
            draw.rule()

            for tier in Tier.scheduled {
                let status = crane.status(tier, asOf: today)
                var text = "\(tier.name.padding(toLength: 12, withPad: " ", startingAt: 0))\(status.headline)"
                if let due = crane.nextDue(tier) {
                    text += "  (\(ISO8601DateFormatter.day.string(from: due)))"
                }
                draw.line(text, size: 10, weight: status.needsAttention ? .semibold : .regular,
                          colour: status.needsAttention ? .systemOrange : .label, gapAfter: 2)
                if let gap = crane.retentionGap(tier, asOf: today) {
                    draw.line(gap, size: 9, colour: .systemOrange, indent: 12, gapAfter: 2)
                }
            }

            if crane.isOutOfService {
                draw.rule()
                draw.line("OUT OF SERVICE", size: 13, weight: .bold, colour: .systemRed, gapAfter: 2)
                draw.line(crane.outOfServiceReason, size: 10, colour: .secondaryLabel)
            }

            draw.rule()
            draw.line("Inspections", size: 12, weight: .semibold, gapAfter: 6)
            if crane.sortedInspections.isEmpty {
                draw.line("No inspections have been recorded for this machine.", size: 10, colour: .secondaryLabel)
            }
            for i in crane.sortedInspections {
                var parts = [i.tier.name, i.verdict.headline]
                if !i.inspectorName.isEmpty { parts.append(i.inspectorName) }
                if i.tier.isDocumented { parts.append(i.signature == nil ? "unsigned" : "signed") }
                draw.line("\(ISO8601DateFormatter.day.string(from: i.date))   \(parts.joined(separator: "  ·  "))",
                          size: 10, weight: i.verdict == .satisfactory ? .regular : .semibold,
                          colour: i.verdict == .outOfService ? .systemRed : .label, gapAfter: 1)
                for item in i.safetyHazards + i.deficiencies {
                    let note = i.note(item)
                    draw.line("\(item.name)\(note.isEmpty ? "" : ": \(note)")",
                              size: 9, colour: .systemRed, indent: 12, gapAfter: 1)
                }
            }

            draw.rule()
            draw.line("Monthly records are required to be retained for at least three months and "
                      + "annual records for at least twelve. \(AppConfig.appName) records what was "
                      + "entered; it does not inspect or certify any equipment.",
                      size: 9, colour: .secondaryLabel)
        }
    }

    // MARK: - Page plumbing

    private final class Draw {
        let ctx: UIGraphicsPDFRendererContext
        let pageWidth: CGFloat = 612, pageHeight: CGFloat = 792, margin: CGFloat = 48
        var y: CGFloat = 48

        init(_ ctx: UIGraphicsPDFRendererContext) { self.ctx = ctx }

        func title(_ text: String) { line(text, size: 22, weight: .semibold) }

        func line(_ text: String, size: CGFloat = 11, weight: UIFont.Weight = .regular,
                  colour: UIColor = .label, indent: CGFloat = 0, gapAfter: CGFloat = 4) {
            let font = UIFont.systemFont(ofSize: size, weight: weight)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: colour]
            let width = pageWidth - margin * 2 - indent
            let bounding = (text as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
            if y + bounding.height > pageHeight - margin { ctx.beginPage(); y = margin }
            (text as NSString).draw(
                with: CGRect(x: margin + indent, y: y, width: width, height: bounding.height),
                options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
            y += bounding.height + gapAfter
        }

        func image(_ image: UIImage, maxHeight: CGFloat) {
            let scale = min(maxHeight / image.size.height, (pageWidth - margin * 2) / image.size.width, 1)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            if y + size.height > pageHeight - margin { ctx.beginPage(); y = margin }
            image.draw(in: CGRect(origin: CGPoint(x: margin, y: y), size: size))
            y += size.height + 6
        }

        func rule(gap: CGFloat = 10) {
            y += gap / 2
            let path = UIBezierPath()
            path.move(to: CGPoint(x: margin, y: y))
            path.addLine(to: CGPoint(x: pageWidth - margin, y: y))
            UIColor.separator.setStroke(); path.lineWidth = 0.5; path.stroke()
            y += gap / 2
        }
    }

    private static func render(named name: String, _ body: (Draw) -> Void) throws -> URL {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).pdf")
        try renderer.writePDF(to: url) { ctx in
            ctx.beginPage()
            body(Draw(ctx))
        }
        return url
    }
}
