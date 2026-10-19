import SwiftUI
import SwiftData

/// The inspection.
///
/// The interesting judgement in this app lives here: an inspector marking something wrong has
/// to say whether it is a **deficiency** or a **safety hazard**, because the standard attaches
/// a consequence to the second one — the machine comes out of service until it is corrected.
/// The app never makes that call for them, and never quietly downgrades it either.
struct InspectionView: View {
    @Bindable var inspection: Inspection
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview

    @State private var noteFor: CheckItem?
    @State private var exportFile: ExportFile?

    private var items: [CheckItem] { inspection.items }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(inspection.tier.requirement)
                        .font(.caption).foregroundStyle(.secondary)
                    if !inspection.tier.isDocumented {
                        Label("No record of this tier is required by the standard.",
                              systemImage: "info.circle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        for item in items where inspection.result(item) == .notChecked {
                            inspection.set(.satisfactory, for: item)
                        }
                    } label: {
                        Label("Mark everything remaining as OK", systemImage: "checkmark.circle.fill")
                    }
                }

                Section {
                    ForEach(items) { item in
                        ItemRow(item: item,
                                result: inspection.result(item),
                                note: inspection.note(item)) { result in
                            inspection.set(result, for: item)
                            if result == .deficient || result == .safetyHazard { noteFor = item }
                        } editNote: {
                            noteFor = item
                        }
                    }
                } header: {
                    Text("Items")
                } footer: {
                    Text("A deficiency is something to fix. A safety hazard takes the machine out of service until it is corrected — that call is yours, not the app's.")
                }

                Section("Inspector") {
                    TextField("Name", text: $inspection.inspectorName)
                    Picker("Role", selection: $inspection.role) {
                        ForEach(InspectorRole.allCases) { Text($0.name).tag($0) }
                    }
                    DatePicker("Date", selection: $inspection.date, displayedComponents: .date)
                }

                if inspection.tier.isDocumented {
                    Section {
                        SignaturePad(data: $inspection.signature, name: inspection.inspectorName)
                    } header: {
                        Text("Signature")
                    } footer: {
                        Text("The standard asks for the name and signature of the person who conducted the inspection, and for this record to be kept at least \(inspection.tier.retentionMonths ?? 0) months.")
                    }
                }

                if inspection.verdict == .deficient || inspection.verdict == .outOfService {
                    Section {
                        TextField("What needs doing", text: $inspection.correctiveAction, axis: .vertical)
                            .lineLimit(2...5)
                        PhotoField(data: $inspection.photoData, label: "Photo of the deficiency")
                        Toggle("Corrected", isOn: Binding(
                            get: { inspection.correctedOn != nil },
                            set: { inspection.correctedOn = $0 ? Date() : nil }))
                    } header: {
                        Text("Corrective action")
                    }
                }

                Section("Notes") {
                    TextField("Anything else", text: $inspection.notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    VerdictRow(verdict: inspection.verdict,
                               answered: inspection.answeredCount,
                               total: items.count,
                               unsigned: inspection.tier.isDocumented && inspection.signature == nil)
                    if inspection.tier.isDocumented && inspection.isRecordComplete {
                        Button { export() } label: {
                            Label("Inspection record (PDF)", systemImage: "doc.richtext")
                        }
                    }
                }
            }
            .navigationTitle("\(inspection.tier.name) inspection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { cancel() } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { save() } }
            }
            .sheet(item: $noteFor) { item in
                DeficiencyNoteView(item: item, text: inspection.note(item)) { text in
                    inspection.setNote(text, for: item)
                }
            }
            .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
        }
    }

    private func cancel() {
        if inspection.answeredCount == 0 { context.delete(inspection) }
        try? context.save()
        dismiss()
    }

    private func save() {
        UserDefaults.standard.set(inspection.inspectorName, forKey: "inspector.name")
        if inspection.answeredCount == 0 {
            context.delete(inspection)
        } else if inspection.verdict == .outOfService, let crane = inspection.crane, !crane.isOutOfService {
            // The standard's consequence, applied the moment the inspector makes the call.
            crane.outOfServiceSince = inspection.date
            crane.outOfServiceReason = inspection.safetyHazards.map(\.name).joined(separator: ", ")
        }
        try? context.save()
        WidgetSync.update(with: (try? context.fetch(FetchDescriptor<Crane>())) ?? [])
        if inspection.verdict != .incomplete { ReviewPrompter.recordSuccess(request: requestReview) }
        dismiss()
    }

    private func export() {
        try? context.save()
        if let url = try? PDFExporter.export(inspection) { exportFile = ExportFile(url: url) }
    }
}

private struct ItemRow: View {
    let item: CheckItem
    let result: ItemResult
    let note: String
    let setResult: (ItemResult) -> Void
    let editNote: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(item.name).font(.subheadline.weight(.medium))
                if item.isWireRope {
                    Text("rope").font(.caption2)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(.secondary.opacity(0.18), in: Capsule())
                        .foregroundStyle(.secondary)
                }
            }
            Text(item.hint).font(.caption).foregroundStyle(.secondary)

            ChoiceChips(options: [.satisfactory, .deficient, .safetyHazard, .notApplicable],
                        selection: Binding(get: { result }, set: setResult),
                        title: \.name,
                        tint: { result in
                            switch result {
                            case .safetyHazard: .red
                            case .deficient: .orange
                            case .satisfactory: .green
                            default: .secondary
                            }
                        })

            if result == .deficient || result == .safetyHazard {
                Button(action: editNote) {
                    Label(note.isEmpty ? "Describe what you found" : note,
                          systemImage: note.isEmpty ? "square.and.pencil" : "text.alignleft")
                        .font(.caption).multilineTextAlignment(.leading)
                }
                .foregroundStyle(result == .safetyHazard ? .red : .orange)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct VerdictRow: View {
    let verdict: InspectionVerdict
    let answered: Int
    let total: Int
    let unsigned: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(verdict.headline, systemImage: verdict.symbol)
                .font(.headline).foregroundStyle(tint)
            Text(verdict.detail).font(.caption).foregroundStyle(.secondary)
            if verdict == .incomplete {
                Text("\(answered) of \(total) items answered")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            if unsigned {
                Label("Not signed yet", systemImage: "signature")
                    .font(.caption2).foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }

    private var tint: Color {
        switch verdict {
        case .outOfService: .red
        case .deficient: .orange
        case .satisfactory: .green
        case .incomplete: .secondary
        }
    }
}

private struct DeficiencyNoteView: View {
    let item: CheckItem
    @State var text: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What you found", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text(item.name)
                } footer: {
                    Text(item.hint)
                }
            }
            .navigationTitle("Finding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onSave(text); dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
