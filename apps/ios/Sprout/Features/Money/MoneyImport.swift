import CryptoKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct MoneyImportRow: Identifiable {
    let sourceIndex: Int
    var fields: [String: String]
    var selected = false
    var warning: String?
    var id: Int { sourceIndex }
    func transaction(batchId: String) -> MoneyTransaction? {
        let date = fields["date", default: ""], merchant = fields["merchant", default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = fields["amount", default: ""], type = fields["type", default: ""], category = fields["category", default: "Other"].trimmingCharacters(in: .whitespacesAndNewlines)
        guard fields["currency"] == "USD", ["expense", "income", "refund", "transfer"].contains(type),
              raw.range(of: #"^-?\d+(\.\d{1,2})?$"#, options: .regularExpression) != nil,
              let absolute = MoneyAmount.parse(raw.hasPrefix("-") ? String(raw.dropFirst()) : raw),
              !merchant.isEmpty, merchant.utf16.count <= 160, !category.isEmpty, category.utf16.count <= 80,
              fields["notes", default: ""].utf16.count <= 1000, Self.validDate(date) else { return nil }
        let minor = raw.hasPrefix("-") ? -absolute : absolute
        guard type == "transfer" || (type == "expense" ? minor < 0 : minor > 0) else { return nil }
        return MoneyTransaction(id: MoneyCSVImport.transactionId(batchId, sourceIndex), amount: MoneyAmount(minor: minor), date: date, merchant: merchant, category: category, type: type, source: "import", accountId: "cash", description: fields["notes", default: ""], pending: false, excluded: false)
    }
    private static func validDate(_ date: String) -> Bool {
        guard date.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else { return false }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.calendar = Calendar(identifier: .gregorian); formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
        guard let parsed = formatter.date(from: date) else { return false }; return formatter.string(from: parsed) == date
    }
}

struct MoneyCSVImport {
    let batchId: String
    var rows: [MoneyImportRow]
    static let template = "date,merchant,amount,type,currency,category,notes\n2026-11-10,Example cafe,-5.40,expense,USD,Food,\n"
    static func transactionId(_ batchId: String, _ sourceIndex: Int) -> String { "import-" + hash(Data("\(batchId):\(sourceIndex)".utf8)) }
    private static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func parse(_ data: Data, existing: [MoneyTransaction] = []) throws -> Self {
        guard data.count <= 500_000, var text = String(data: data, encoding: .utf8), !text.contains("\0") else { throw invalid("Choose a UTF-8 CSV file under 500 KB.") }
        if text.hasPrefix("\u{feff}") { text.removeFirst() }
        text = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let table = try cells(text)
        guard let first = table.first else { throw invalid("This file is empty.") }
        let headers = first.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        let required: Set<String> = ["date", "merchant", "amount", "type", "currency"]
        guard Set(headers).count == headers.count, required.isSubset(of: Set(headers)), Set(headers).isSubset(of: required.union(["category", "notes"])) else { throw invalid("Use the Sprout CSV headers: date, merchant, amount, type, currency, category, notes.") }
        let batchId = hash(Data(text.utf8)); var rows: [MoneyImportRow] = []; var seen = Set<String>()
        for (index, values) in table.dropFirst().enumerated() {
            if values.allSatisfy({ $0.isEmpty }) { continue }
            guard index < 10_000, values.count == headers.count, rows.count < 1000 else { throw invalid("Check column counts and import at most 1,000 records at a time.") }
            var fields = Dictionary(uniqueKeysWithValues: zip(headers, values)); fields["category"] = fields["category"].flatMap { $0.isEmpty ? nil : $0 } ?? "Other"
            var row = MoneyImportRow(sourceIndex: index, fields: fields)
            if let item = row.transaction(batchId: batchId) {
                let key = "\(item.date)|\(item.amount.minor)|\(item.merchant.lowercased())"
                let duplicate = !seen.insert(key).inserted || existing.contains { $0.id == item.id || ($0.date == item.date && $0.amount == item.amount && $0.merchant.lowercased() == item.merchant.lowercased()) }
                row.warning = duplicate ? "Possible duplicate. Excluded until you select it." : nil; row.selected = !duplicate
            }
            rows.append(row)
        }
        guard !rows.isEmpty else { throw invalid("This file has no transaction rows.") }
        return Self(batchId: batchId, rows: rows)
    }
    func command() throws -> [String: Any] {
        let selected = rows.filter(\.selected)
        guard !selected.isEmpty else { throw Self.invalid("Select at least one reviewed row.") }
        let values = try selected.map { row -> [String: Any] in
            guard let transaction = row.transaction(batchId: batchId) else { throw Self.invalid("Correct the selected rows before importing.") }
            return ["sourceIndex": row.sourceIndex, "transaction": transaction.commandValue]
        }
        let command: [String: Any] = ["type": "transaction.import", "batchId": batchId, "rows": values]
        guard try JSONSerialization.data(withJSONObject: command).count < 950_000 else { throw Self.invalid("Select fewer records for this import.") }; return command
    }
    private static func invalid(_ message: String) -> MoneyAPIError { MoneyAPIError(code: "INVALID_IMPORT", message: message) }
    private static func cells(_ text: String) throws -> [[String]] {
        var rows: [[String]] = [], row: [String] = [], field = "", quoted = false, closed = false
        let characters = Array(text); var index = 0
        while index < characters.count {
            let c = characters[index]
            if quoted {
                if c == "\"" {
                    if index + 1 < characters.count && characters[index + 1] == "\"" { field.append("\""); index += 1 }
                    else { quoted = false; closed = true }
                } else { field.append(c) }
            } else if c == "," || c == "\n" {
                row.append(field); field = ""; closed = false
                if c == "\n" { rows.append(row); row = [] }
            } else if c == "\"" && field.isEmpty && !closed { quoted = true }
            else {
                guard !closed && c != "\"" else { throw invalid("Check the quoted CSV fields.") }; field.append(c)
            }
            guard rows.count <= 10_001, field.utf16.count <= 4000 else { throw invalid("This file has too many rows or an oversized field.") }
            index += 1
        }
        guard !quoted else { throw invalid("A quoted CSV field was not closed.") }
        if !field.isEmpty || !row.isEmpty || closed { row.append(field); rows.append(row) }; return rows
    }
}

struct MoneyImportView: View {
    @EnvironmentObject private var store: MoneyStore
    @State private var showPicker = false
    @State private var batch: MoneyCSVImport?
    @State private var error: String?
    @State private var reviewed = false
    @State private var queued = false
    @State private var paste = false
    @State private var csv = ""
    @State private var exportTemplate = false
    var body: some View {
        MoneyPage(title: "Import transactions") {
            Text("Review a CSV of individual USD transactions. Negative amounts are expenses; positive amounts are income or refunds. Transfers do not count as spending. Imported records use your manual cash account.")
            Button("Save CSV template") { exportTemplate = true }
            Button("Choose CSV file") { showPicker = true }.buttonStyle(.bordered)
            DisclosureGroup("Paste CSV text", isExpanded: $paste) {
                TextEditor(text: $csv).frame(minHeight: 120).accessibilityLabel("CSV text").textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Review pasted CSV") { do { try load(Data(csv.utf8)) } catch { self.error = error.localizedDescription } }
            }
            if let batch {
                Text("\(batch.rows.filter(\.selected).count) selected · \(batch.rows.count) rows").font(.headline)
                Text("Check possible duplicates, dates and amount signs. Invalid rows are excluded until corrected. Repeating this file preserves existing records, including edits and deletions.").font(.footnote)
                LazyVStack(spacing: 16) { ForEach(batch.rows.indices, id: \.self) { index in
                    MoneyCard {
                        Toggle("Row \(batch.rows[index].sourceIndex + 2): \(batch.rows[index].fields["merchant", default: "Transaction"])", isOn: Binding(get: { self.batch?.rows[index].selected ?? false }, set: { self.batch?.rows[index].selected = $0; reviewed = false })).disabled(batch.rows[index].transaction(batchId: batch.batchId) == nil || queued)
                        if let warning = batch.rows[index].warning { Text(warning).font(.caption) }
                        if batch.rows[index].transaction(batchId: batch.batchId) == nil { Text("Correct date, merchant, USD currency, type and amount sign before selecting.").font(.caption).foregroundStyle(.red) }
                        DisclosureGroup("Review fields") {
                            ForEach(["date", "merchant", "amount", "type", "currency", "category", "notes"], id: \.self) { key in
                                TextField(key.capitalized, text: Binding(get: { self.batch?.rows[index].fields[key] ?? "" }, set: { self.batch?.rows[index].fields[key] = $0; self.batch?.rows[index].selected = false; reviewed = false })).textInputAutocapitalization(.never).autocorrectionDisabled().disabled(queued)
                            }
                        }
                    }
                } }
                Toggle("I reviewed the selected records", isOn: $reviewed).disabled(queued)
                Button(queued ? "Saved for import" : "Import selected records") {
                    do { try store.enqueue(batch.command(), entity: "import:\(batch.batchId)"); queued = true } catch { self.error = error.localizedDescription }
                }.buttonStyle(MoneyPrimaryButtonStyle()).disabled(!reviewed || queued || batch.rows.allSatisfy({ !$0.selected }))
                if queued { Text("Saved on this device. Import starts when connected; progress appears below.").font(.footnote) }
            }
            MoneyImportJobs(highlightedBatchId: batch?.batchId)
            if let error { Text(error).foregroundStyle(.red) }
        }.fileImporter(isPresented: $showPicker, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            do {
                let url = try result.get(); let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 500_000 else { throw MoneyAPIError(code: "INVALID_IMPORT", message: "Choose a CSV file under 500 KB.") }
                try load(Data(contentsOf: url))
            } catch { self.error = error.localizedDescription }
        }
        .fileExporter(isPresented: $exportTemplate, document: MoneyCSVDocument(), contentType: .commaSeparatedText, defaultFilename: "sprout-transactions") { result in if case let .failure(failure) = result { error = failure.localizedDescription } }
    }
    private func load(_ data: Data) throws { batch = try MoneyCSVImport.parse(data, existing: store.workspace?.transactions ?? []); reviewed = false; queued = false; error = nil; paste = false }
}

struct MoneyCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    init() {}
    init(configuration: ReadConfiguration) throws {}
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(MoneyCSVImport.template.utf8)) }
}

struct MoneyImportJobs: View {
    @EnvironmentObject private var store: MoneyStore
    var highlightedBatchId: String?
    var body: some View {
        ForEach((store.workspace?.jobs?.filter { $0.type == "transaction.import" } ?? []).sorted { a, b in if (a.batchId == highlightedBatchId) != (b.batchId == highlightedBatchId) { return a.batchId == highlightedBatchId }; return (a.updatedAt ?? "") > (b.updatedAt ?? "") }) { job in
            MoneyCard {
                if job.batchId == highlightedBatchId { Text("Current file").font(.caption.bold()) }
                Text("CSV import · \(job.status.replacingOccurrences(of: "_", with: " "))").font(.headline)
                if let text = job.updatedAt, let date = Self.date(text) { Text("Updated \(date.formatted(date: .abbreviated, time: .complete))").font(.caption).foregroundStyle(SproutColor.textSecondary) }
                if let p = job.progress { Text("\(p.processed) of \(p.total) processed · \(p.imported) added · \(p.preserved) existing records preserved").font(.footnote).accessibilityIdentifier("money.import.progress.\(job.batchId ?? job.id)") }
                if job.status == "needs_attention" { Button("Resume import") { do { try store.enqueue(["type": "transaction.import.resume", "id": job.id], entity: "import-resume:\(job.id)") } catch { store.message = error.localizedDescription } } }
            }
        }
        Button("Refresh import progress") { Task { await store.refresh() } }
    }
    private static func date(_ value: String) -> Date? { let format = ISO8601DateFormatter(); format.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return format.date(from: value) ?? ISO8601DateFormatter().date(from: value) }
}
