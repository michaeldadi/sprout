import SwiftUI

struct MoneyGoalsSection: View {
    @EnvironmentObject private var store: MoneyStore
    @State private var editing: MoneyRecord<MoneyGoal>?
    @State private var adding = false
    @State private var showArchived = false
    var body: some View {
        MoneyCard {
            Text("Goals").font(.title3.bold())
            Text("Virtual allocations record your plan. They do not move money or change your remaining budget.").font(.footnote).foregroundStyle(SproutColor.textSecondary)
            let records = store.goals.filter { showArchived || !$0.data.archived }
            if records.isEmpty { Text("Give a future priority a name and a target.") }
            ForEach(records) { record in
                VStack(alignment: .leading, spacing: 8) {
                    Text(record.data.name).font(.headline)
                    Text("\(record.data.allocated.formatted) allocated of \(record.data.target.formatted)")
                    ProgressView(value: Double(record.data.allocated.minor), total: Double(record.data.target.minor)).tint(SproutColor.action)
                    if let date = record.data.targetDate { Text("Target date: \(date)").font(.caption) }
                    if record.data.archived { Text("Archived").font(.caption) }
                    if store.pendingGoal(record.id) { Text("Pending sync").font(.caption) }
                    Button("Edit \(record.data.name)") { editing = record }.disabled(store.pendingGoal(record.id))
                }.padding(.vertical, 8)
            }
            if store.goals.contains(where: { $0.data.archived }) { Toggle("Show archived goals", isOn: $showArchived) }
            ForEach(store.mutations.filter { $0.conflict && $0.entityKey.hasPrefix("goal:") }, id: \.id) { mutation in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Goal changed on another device").font(.headline)
                    Text(store.goalConflictDescription(mutation)).font(.footnote)
                    Text("The goal above shows the server version. Review both before choosing.").font(.caption)
                    MoneyEditConflictButton(mutation: mutation)
                    Button("Use server goal", role: .destructive) { do { try store.useServerVersion(mutation) } catch { store.message = error.localizedDescription } }
                }
            }
            Button("Add goal") { adding = true }.buttonStyle(.bordered)
        }
        .sheet(isPresented: $adding) { MoneyGoalEditor(record: nil).environmentObject(store) }
        .sheet(item: $editing) { MoneyGoalEditor(record: $0).environmentObject(store) }
    }
}

private struct MoneyGoalEditor: View {
    @EnvironmentObject private var store: MoneyStore
    @Environment(\.dismiss) private var dismiss
    let record: MoneyRecord<MoneyGoal>?
    @State private var id = UUID().uuidString.lowercased()
    @State private var name = ""
    @State private var target = ""
    @State private var allocated = "0"
    @State private var date = ""
    @State private var archived = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Your goal") {
                    TextField("Goal name", text: $name)
                    TextField("Goal target in USD", text: $target).keyboardType(.decimalPad)
                    TextField("Virtual allocation in USD", text: $allocated).keyboardType(.decimalPad)
                    TextField("Target date (YYYY-MM-DD, optional)", text: $date).textInputAutocapitalization(.never)
                    Toggle("Archive goal", isOn: $archived)
                }
                Text("This is a virtual plan. Saving does not transfer funds.").font(.footnote)
                if let error { Text(error).foregroundStyle(SproutColor.error) }
            }
            .navigationTitle(record == nil ? "Add goal" : "Edit goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save goal") { save() } }
            }
        }.onAppear {
            guard let value = record?.data else { return }
            id = value.id; name = value.name; target = NSDecimalNumber(decimal: Decimal(value.target.minor) / 100).stringValue
            allocated = NSDecimalNumber(decimal: Decimal(value.allocated.minor) / 100).stringValue; date = value.targetDate ?? ""; archived = value.archived
        }
    }
    private static func validDate(_ text: String) -> Bool {
        guard text.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else { return false }
        let format = DateFormatter(); format.calendar = Calendar(identifier: .gregorian); format.locale = Locale(identifier: "en_US_POSIX"); format.dateFormat = "yyyy-MM-dd"; format.isLenient = false
        guard let date = format.date(from: text) else { return false }; return format.string(from: date) == text
    }
    private func save() {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let zero = ["0", "0.0", "0.00"].contains(allocated.trimmingCharacters(in: .whitespaces))
        guard !clean.isEmpty, clean.utf16.count <= 80, let targetMinor = MoneyAmount.parse(target), let allocation = zero ? Int64(0) : MoneyAmount.parse(allocated), allocation <= targetMinor, date.isEmpty || Self.validDate(date) else { error = "Review the name, target, allocation and optional calendar date. Allocation must be between zero and the target."; return }
        let goal = MoneyGoal(id: id, name: clean, target: MoneyAmount(minor: targetMinor), allocated: MoneyAmount(minor: allocation), targetDate: date.isEmpty ? nil : date, archived: archived)
        do { try store.enqueue(["type": "goal.upsert", "goal": goal.commandValue, "expectedVersion": record?.version ?? 0], entity: "goal:\(id)"); dismiss() } catch { self.error = error.localizedDescription }
    }
}
