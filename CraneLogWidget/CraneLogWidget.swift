import WidgetKit
import SwiftUI

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: context.isPreview ? .placeholder : WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load())
        let refresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

struct CraneLogWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Cranes", systemImage: entry.snapshot.outOfService > 0 ? "octagon.fill" : "crane")
                .font(.caption.weight(.semibold))
                .foregroundStyle(entry.snapshot.outOfService > 0 ? .red : .secondary)

            Spacer(minLength: 0)

            if entry.snapshot.totalEntries == 0 {
                Text("Add your first machine").font(.footnote).foregroundStyle(.secondary)
            } else if entry.snapshot.outOfService > 0 {
                Text("\(entry.snapshot.outOfService)")
                    .font(.system(size: family == .systemSmall ? 38 : 46, weight: .bold, design: .rounded))
                    .foregroundStyle(.red)
                Text(entry.snapshot.outOfService == 1 ? "out of service" : "out of service")
                    .font(.caption2).foregroundStyle(.secondary)
                if let unit = entry.snapshot.lastEntryTitle, family != .systemSmall {
                    Text(unit).font(.caption2).foregroundStyle(.red)
                }
            } else if entry.snapshot.due > 0 {
                Text("\(entry.snapshot.due)")
                    .font(.system(size: family == .systemSmall ? 38 : 46, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                Text("need an inspection").font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("All current").font(.headline).foregroundStyle(.green)
                Text("\(entry.snapshot.totalEntries) machines").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct CraneLogWidget: Widget {
    let kind = "CraneLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            CraneLogWidgetView(entry: entry)
        }
        .configurationDisplayName(AppConfig.appName)
        .description("\(AppConfig.entryNounPlural) this week and your latest one.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct CraneLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        CraneLogWidget()
    }
}
