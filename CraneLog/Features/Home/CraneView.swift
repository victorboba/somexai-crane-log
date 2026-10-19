import SwiftUI
import SwiftData

/// One machine: its three clocks, its red tag, and its history.
struct CraneView: View {
    @Bindable var crane: Crane
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview

    @State private var inspecting: Inspection?
    @State private var editing = false
    @State private var returningToService = false
    @State private var exportFile: ExportFile?

    var body: some View {
        List {
            if crane.isOutOfService {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Out of service", systemImage: "octagon.fill")
                            .font(.headline).foregroundStyle(.red)
                        if !crane.outOfServiceReason.isEmpty {
                            Text(crane.outOfServiceReason).font(.subheadline)
                        }
                        if let since = crane.outOfServiceSince {
                            Text("Since \(since.formatted(date: .long, time: .omitted))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Button("Return to service") { returningToService = true }
                        .foregroundStyle(.green)
                } footer: {
                    Text("Only return it once the deficiency has actually been corrected. The app records that you said so, and when.")
                }
            }

            Section("Start an inspection") {
                ForEach(Tier.scheduled) { tier in
                    Button { start(tier) } label: {
                        HStack {
                            Label(tier.name, systemImage: tier.symbol)
                            Spacer()
                            Text(crane.status(tier).headline)
                                .font(.caption)
                                .foregroundStyle(crane.status(tier).needsAttention ? .orange : .secondary)
                        }
                    }
                }
                Menu {
                    ForEach([Tier.postAssembly, .severeService, .repaired]) { tier in
                        Button { start(tier) } label: { Label(tier.name, systemImage: tier.symbol) }
                    }
                } label: {
                    Label("Triggered by an event", systemImage: "bolt.badge.clock")
                }
            }

            Section {
                ForEach(Tier.scheduled) { tier in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tier.name).font(.subheadline.weight(.medium))
                        Text(tier.requirement).font(.caption).foregroundStyle(.secondary)
                        if let gap = crane.retentionGap(tier) {
                            Label(gap, systemImage: "tray.full")
                                .font(.caption2).foregroundStyle(.orange)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("What the standard asks for")
            } footer: {
                Text("29 CFR 1926.1412. Your employer, the manufacturer or the site may ask for more; none of them may ask for less.")
            }

            Section("History") {
                if crane.sortedInspections.isEmpty {
                    Text("Nothing recorded yet.").foregroundStyle(.secondary)
                }
                ForEach(crane.sortedInspections) { inspection in
                    Button { inspecting = inspection } label: { HistoryRow(inspection: inspection) }
                        .buttonStyle(.plain)
                }
                .onDelete(perform: deleteInspections)
            }

            Section {
                Button { exportHistory() } label: {
                    Label("Inspection history (PDF)", systemImage: "doc.richtext")
                }
            }
        }
        .navigationTitle(crane.unitNumber.isEmpty ? "Machine" : crane.unitNumber)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editing = true } label: { Label("Machine details", systemImage: "info.circle") }
            }
        }
        .sheet(item: $inspecting) { InspectionView(inspection: $0) }
        .sheet(isPresented: $editing) { CraneEditorView(crane: crane) }
        .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
        .alert("Return to service", isPresented: $returningToService) {
            Button("Cancel", role: .cancel) {}
            Button("Return to service") {
                crane.outOfServiceSince = nil
                crane.outOfServiceReason = ""
                try? context.save()
                WidgetSync.update(with: (try? context.fetch(FetchDescriptor<Crane>())) ?? [])
            }
        } message: {
            Text("Confirm the deficiency that took this machine out of service has been corrected.")
        }
    }

    private func start(_ tier: Tier) {
        let inspection = Inspection(tier: tier)
        inspection.inspectorName = UserDefaults.standard.string(forKey: "inspector.name") ?? ""
        inspection.crane = crane
        context.insert(inspection)
        try? context.save()
        inspecting = inspection
    }

    private func deleteInspections(_ offsets: IndexSet) {
        let list = crane.sortedInspections
        for index in offsets { context.delete(list[index]) }
        try? context.save()
    }

    private func exportHistory() {
        try? context.save()
        if let url = try? PDFExporter.exportHistory(crane) {
            exportFile = ExportFile(url: url)
            ReviewPrompter.recordSuccess(request: requestReview)
        }
    }
}

private struct HistoryRow: View {
    let inspection: Inspection

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: inspection.verdict.symbol)
                .foregroundStyle(tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(inspection.tier.name) · \(inspection.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline.weight(.medium))
                Text(inspection.verdict.headline).font(.caption).foregroundStyle(tint)
                if !inspection.inspectorName.isEmpty {
                    Text(inspection.inspectorName).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if inspection.tier.isDocumented && inspection.signature == nil {
                Label("unsigned", systemImage: "signature")
                    .font(.caption2).foregroundStyle(.orange).labelStyle(.titleOnly)
            }
        }
        .padding(.vertical, 2)
    }

    private var tint: Color {
        switch inspection.verdict {
        case .outOfService: .red
        case .deficient: .orange
        case .satisfactory: .green
        case .incomplete: .secondary
        }
    }
}

/// The machine's identity, which is most of what makes a record admissible later.
struct CraneEditorView: View {
    @Bindable var crane: Crane
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            Form {
                Section("Machine") {
                    TextField("Unit number", text: $crane.unitNumber)
                    TextField("Make", text: $crane.make)
                    TextField("Model", text: $crane.model)
                    TextField("Serial number", text: $crane.serialNumber)
                    LabeledContent("Capacity") {
                        HStack(spacing: 4) {
                            TextField("—", value: $crane.capacityTons, format: .number)
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            Text("tons").foregroundStyle(.secondary)
                        }
                    }
                    Picker("Type", selection: $crane.kind) {
                        ForEach(CraneKind.allCases) { Text($0.name).tag($0) }
                    }
                }

                Section {
                    Toggle("On tires", isOn: $crane.hasTires)
                    Toggle("Rail-mounted", isOn: $crane.isRailMounted)
                    Toggle("Has an operator cab", isOn: $crane.hasCab)
                } header: {
                    Text("What it has")
                } footer: {
                    Text("These decide which items the inspection asks about. A crawler is never asked about tires and never failed for them.")
                }

                Section("Where it is") {
                    TextField("Owner", text: $crane.owner)
                    TextField("Site or yard", text: $crane.site)
                }

                Section("Photo") {
                    PhotoField(data: $crane.photoData, label: "Photo of the machine or its data plate")
                }

                Section("Notes") {
                    TextField("Anything worth remembering", text: $crane.notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    Button("Delete this machine", role: .destructive) {
                        context.delete(crane)
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Machine details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { try? context.save(); dismiss() }
                }
            }
        }
    }
}
