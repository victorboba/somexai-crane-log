import SwiftUI
import SwiftData

/// The fleet, with anything red-tagged at the top.
///
/// A crane that has been taken out of service is not a row in a list — it is a machine nobody
/// may operate until it is fixed. So it gets its own band at the top of the screen, ahead of
/// every clock, because that is the order the yard cares about.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Crane.unitNumber) private var cranes: [Crane]

    @State private var openCrane: Crane?
    @State private var editingCrane: Crane?
    @State private var showingSettings = false
    @State private var exportFile: ExportFile?
    @State private var exportError: String?

    private var outOfService: [Crane] { cranes.filter(\.isOutOfService) }
    private var inService: [Crane] { cranes.filter { !$0.isOutOfService } }

    var body: some View {
        NavigationStack {
            Group {
                if cranes.isEmpty {
                    ContentUnavailableView {
                        Label("No machines yet", systemImage: "crane")
                    } description: {
                        Text("Add the machine and the app starts its three clocks: the shift check, the monthly record, and the annual.")
                    } actions: {
                        Button("Add a machine") { addCrane() }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        if !outOfService.isEmpty {
                            Section {
                                ForEach(outOfService) { crane in
                                    Button { openCrane = crane } label: { OutOfServiceRow(crane: crane) }
                                        .buttonStyle(.plain)
                                }
                            } header: {
                                Label("Out of service", systemImage: "octagon.fill")
                                    .foregroundStyle(.red)
                            } footer: {
                                Text("A deficiency judged to be a safety hazard takes the machine out of service until it is corrected.")
                            }
                        }

                        Section(outOfService.isEmpty ? "" : "In service") {
                            ForEach(inService) { crane in
                                Button { openCrane = crane } label: { CraneRow(crane: crane) }
                                    .buttonStyle(.plain)
                            }
                            .onDelete { offsets in delete(offsets, in: inService) }
                        }
                    }
                }
            }
            .navigationTitle("Cranes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { HowToView() } label: {
                        Label("How do I use this app?", systemImage: "questionmark.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { addCrane() } label: { Label("Add a machine", systemImage: "plus") }
                        if !cranes.isEmpty {
                            Button { exportCSV() } label: {
                                Label("Every inspection as CSV", systemImage: "tablecells")
                            }
                        }
                        Divider()
                        Button { showingSettings = true } label: { Label("Settings", systemImage: "gear") }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .navigationDestination(item: $openCrane) { CraneView(crane: $0) }
            .sheet(item: $editingCrane) { CraneEditorView(crane: $0) }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
            .alert("Export failed", isPresented: .constant(exportError != nil)) {
                Button("OK") { exportError = nil }
            } message: { Text(exportError ?? "") }
        }
    }

    private func addCrane() {
        let crane = Crane()
        context.insert(crane)
        try? context.save()
        editingCrane = crane
    }

    private func delete(_ offsets: IndexSet, in list: [Crane]) {
        for index in offsets { context.delete(list[index]) }
        try? context.save()
        WidgetSync.update(with: cranes)
    }

    private func exportCSV() {
        do { exportFile = ExportFile(url: try CSVExporter.export(cranes)) }
        catch { exportError = error.localizedDescription }
    }
}

private struct OutOfServiceRow: View {
    let crane: Crane

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "octagon.fill").foregroundStyle(.red)
                Text(crane.title).font(.headline)
            }
            if !crane.outOfServiceReason.isEmpty {
                Text(crane.outOfServiceReason).font(.subheadline).foregroundStyle(.red)
            }
            if let since = crane.outOfServiceSince {
                Text("Since \(since.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct CraneRow: View {
    let crane: Crane

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(crane.title).font(.headline)
            if !crane.site.isEmpty {
                Text(crane.site).font(.subheadline).foregroundStyle(.secondary)
            }

            // Three clocks, side by side, because that is how the standard runs them.
            HStack(spacing: 8) {
                ForEach(crane.clocks(), id: \.tier) { item in
                    ClockChip(tier: item.tier, status: item.status)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ClockChip: View {
    let tier: Tier
    let status: TierStatus

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: tier.symbol).font(.caption)
            Text(tier.name).font(.caption2.weight(.medium))
            Text(short).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
        .foregroundStyle(tint)
    }

    private var short: String {
        switch status {
        case .doneToday: return "done"
        case .dueToday: return "due"
        case .noRecord: return "none"
        case .current(let d): return d > 60 ? "\(d / 30) mo" : "\(d) d"
        case .dueSoon(let d): return "\(d) d"
        case .overdue(let d): return d > 60 ? "-\(d / 30) mo" : "-\(d) d"
        }
    }

    private var tint: Color {
        switch status {
        case .overdue, .noRecord: .red
        case .dueToday, .dueSoon: .orange
        case .doneToday, .current: .green
        }
    }
}
