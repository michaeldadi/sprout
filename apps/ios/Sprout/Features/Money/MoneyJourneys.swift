import Charts
import AVFoundation
import LocalAuthentication
import PhotosUI
import SwiftUI
import Vision

struct MoneyActivityView: View {
    private struct DayGroup: Identifiable { let id: String; let items: [MoneyTransaction] }
    @EnvironmentObject private var store: MoneyStore
    @EnvironmentObject private var deepLinks: DeepLinkManager
    @State private var query = ""
    @State private var kind = "All"
    @State private var period = "This month"
    @State private var detail: String?
    var onExpense: () -> Void; var onAsk: (String) -> Void
    private var items: [MoneyTransaction] {
        store.transactions.filter { item in
            (query.isEmpty || "\(item.merchant) \(item.category) \(item.description)".localizedCaseInsensitiveContains(query)) &&
                (kind == "All" || item.type == kind.lowercased()) && (period == "All time" || item.date.hasPrefix(String(store.workspace?.today.prefix(7) ?? "")))
        }
    }
    private var groups: [DayGroup] { Dictionary(grouping: items, by: \.date).map { DayGroup(id: $0.key, items: $0.value) }.sorted { $0.id > $1.id } }

    var body: some View {
        MoneyPage(title: "Activity", lazy: true) {
            Picker("Period", selection: $period) { Text("This month").tag("This month"); Text("All time").tag("All time") }.pickerStyle(.segmented)
            Picker("Transaction type", selection: $kind) { ForEach(["All", "Expense", "Income", "Transfer"], id: \.self) { Text($0).tag($0) } }.pickerStyle(.segmented)
            if !store.mutations.isEmpty {
                MoneyInsightPill(text: store.mutations.allSatisfy(\.conflict) ? "A saved change needs review in Profile before it can sync." : store.mutations.contains(where: \.conflict) ? "Some changes need review in Profile. Other saved changes retry when Sprout connects." : "Saved on this device. Pending changes retry when Sprout can connect.")
            }
            if items.isEmpty {
                ContentUnavailableView.search(text: query.isEmpty ? "No matching activity" : query)
            }
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.id).font(.subheadline.weight(.semibold)).foregroundStyle(SproutColor.textSecondary)
                    MoneyCard { LazyVStack(spacing: 16) { ForEach(group.items) { item in NavigationLink(value: MoneyRoute.transaction(item.id)) { MoneyTransactionRow(item: item, pending: store.pending(item.id)) }.buttonStyle(.plain) } } }
                }
            }
        }
        .searchable(text: $query, prompt: "Search your activity")
        .safeAreaInset(edge: .bottom) { Button(action: onExpense) { Label("Add expense", systemImage: "plus").font(.headline).padding(8) }.buttonStyle(MoneyPrimaryButtonStyle()).buttonBorderShape(.capsule).padding(.bottom, 8) }
        .navigationDestination(isPresented: Binding(get: { detail != nil }, set: {
            if !$0 {
                detail = nil
            }
        })) {
            if let detail {
                MoneyTransactionDetail(id: detail, onAsk: onAsk)
            }
        }
        .onAppear { detail = deepLinks.activeTransactionId; deepLinks.activeTransactionId = nil }
        .onChange(of: deepLinks.activeTransactionId) {
            _, id in if let id {
                detail = id; deepLinks.activeTransactionId = nil
            }
        }
    }
}

struct MoneyTransactionDetail: View {
    @EnvironmentObject private var store: MoneyStore
    @Environment(\.dismiss) private var dismiss
    let id: String; var onAsk: (String) -> Void
    @State private var confirmDelete = false
    @State private var deletionVersion: Int?
    @State private var editDraft: ExpenseDraft?
    var body: some View {
        MoneyPage(title: "Transaction") {
            if let item = store.transactions.first(where: { $0.id == id }) {
                MoneyCard {
                    Text(item.merchant).font(.title2.bold()); MoneyAmountView(minor: item.amount.minor); LabeledContent("Date", value: item.date); LabeledContent("Category", value: item.category); LabeledContent("Source", value: item.source.capitalized); LabeledContent("Account", value: item.accountId); Text(item.description); if store.pending(id) {
                        Text("Pending sync").foregroundStyle(SproutColor.warning)
                    }
                }
                Button("Ask Sprout about this transaction") { onAsk("transaction:\(id)") }
                MoneyReceiptSection(transactionId: id)
                if item.type == "expense", item.source != "plaid" {
                    Button("Edit expense") { editDraft = ExpenseDraft.editing(item) }.disabled(store.pending(id))
                }
                if item.source != "plaid" {
                    Button("Delete transaction", role: .destructive) { deletionVersion = item.version; confirmDelete = true }.disabled(store.pending(id))
                }
            } else {
                ContentUnavailableView("Transaction unavailable", systemImage: "doc.text.magnifyingglass", description: Text("It may have been removed. Refresh Activity to check."))
            }
        }.confirmationDialog("Delete this transaction?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                guard let deletionVersion else { return }
                do { try store.enqueue(["type": "transaction.delete", "id": id, "expectedVersion": deletionVersion], entity: "transaction:\(id)"); dismiss() } catch { store.message = error.localizedDescription }
            }
        }.sheet(item: $editDraft) { draft in MoneyExpenseEditor(draft: draft).environmentObject(store) }
    }
}

struct MoneySubscriptionsView: View {
    @EnvironmentObject private var store: MoneyStore
    var body: some View {
        MoneyPage(title: "Subscriptions") {
            if let w = store.workspace {
                MoneyInsightPill(text: "Recurring charges, with the evidence in view.")
                MoneyAmountView(minor: w.snapshot.monthlySubscriptionsMinor)
                Text("Monthly equivalent · confirmed subscriptions").font(.subheadline).foregroundStyle(SproutColor.textSecondary)
                if w.subscriptions.isEmpty {
                    ContentUnavailableView("Nothing recurring yet", systemImage: "repeat", description: Text("Recurring candidates appear after at least three matching charges. You can keep tracking manually."))
                }
                if let first = w.subscriptions.first {
                    MoneyInsightPill(text: "Next estimated renewal · \(first.nextDate)")
                }
                MoneyCard { ForEach(w.subscriptions) { subscription in
                    NavigationLink(value: MoneyRoute.subscription(subscription.id)) {
                        HStack { Text(String(subscription.merchant.prefix(1))).font(.headline).frame(width: 40, height: 40).background(SproutColor.actionSubtle, in: Circle()); VStack(alignment: .leading, spacing: 4) { Text(subscription.merchant).font(.headline); Text("\(subscription.decision.capitalized) · estimated \(subscription.nextDate)").font(.caption).foregroundStyle(SproutColor.textSecondary) }; Spacer(); VStack(alignment: .trailing) { Text(MoneyAmount(minor: subscription.amountMinor).formatted); Text(subscription.cadence).font(.caption) } }
                    }.buttonStyle(.plain).padding(.vertical, 8)
                } }
            }
        }
    }
}

struct MoneySubscriptionDetail: View {
    @EnvironmentObject private var store: MoneyStore
    let id: String; var onAsk: (String) -> Void
    @State private var proposing = false
    var body: some View {
        MoneyPage(title: "Subscription") {
            if let s = store.workspace?.subscriptions.first(where: { $0.id == id }) {
                VStack(alignment: .leading, spacing: 12) { Text(s.merchant).font(.largeTitle.bold()); MoneyAmountView(minor: s.amountMinor); Text("\(s.cadence.capitalized) · estimated renewal \(s.nextDate)").foregroundStyle(SproutColor.textSecondary) }
                MoneyInsightPill(text: s.decision == "confirmed" ? "You confirmed that Sprout should track this subscription." : "A recurring pattern was detected. Review the charges to confirm it.")
                if s.decision != "confirmed" {
                    Button("Track as a subscription") { decide(s, "confirmed") }.buttonStyle(MoneyPrimaryButtonStyle())
                }
                Text("Charge history").font(.title3.bold())
                Chart(Array(s.charges.enumerated()), id: \.offset) { pair in BarMark(x: .value("Charge date", pair.element.date), y: .value("USD", Double(pair.element.minor) / 100)).foregroundStyle(SproutColor.action) }.frame(height: 160).accessibilityLabel("Actual subscription charges")
                MoneyCard { ForEach(s.evidenceIds, id: \.self) {
                    transactionId in if let item = store.transactions.first(where: { $0.id == transactionId }) {
                        NavigationLink(value: MoneyRoute.transaction(item.id)) { MoneyTransactionRow(item: item, pending: false) }.buttonStyle(.plain)
                    }
                }; LabeledContent("Account", value: s.accountId); Text("Bank charges do not show whether you use this service.").font(.footnote).foregroundStyle(SproutColor.textSecondary) }
                let reminder = store.workspace?.reminders.first { $0.data.subscriptionId == id }
                Button(reminder?.data.enabled == true ? "Turn off renewal reminder" : "Remind me before renewal") {
                    do { try store.enqueue(["type": "reminder.set", "subscriptionId": id, "enabled": !(reminder?.data.enabled ?? false), "daysBefore": 3], entity: "reminder:\(id)") } catch { store.message = error.localizedDescription }
                }.buttonStyle(.bordered).disabled(store.workspace?.capabilities.notifications != true)
                if store.workspace?.capabilities.notifications != true {
                    Text("Reminder delivery is not available in this environment.").font(.footnote).foregroundStyle(SproutColor.textSecondary)
                }
                Text("Direct cancellation").font(.title3.bold())
                Text("Coverage must be verified for this merchant. A reminder and a cancellation are separate actions. A submitted request is complete only after the provider confirms it.").font(.footnote).foregroundStyle(SproutColor.textSecondary)
                ForEach(store.workspace?.actions.filter { $0.data.subscriptionId == id } ?? []) { action in NavigationLink(value: MoneyRoute.action(action.id)) { LabeledContent("Cancellation", value: action.data.state.replacingOccurrences(of: "_", with: " ")) } }
                Button("Review cancellation") { propose() }.buttonStyle(MoneyPrimaryButtonStyle()).disabled(proposing || store.workspace?.capabilities.cancellation != true)
                Button("Ask Sprout") { onAsk("subscription:\(id)") }
                Button("This isn't a subscription") { decide(s, "dismissed") }.foregroundStyle(SproutColor.textSecondary)
            } else {
                ContentUnavailableView("Subscription unavailable", systemImage: "repeat", description: Text("The evidence may have changed. Refresh your subscriptions."))
            }
        }
    }

    private func decide(_ s: MoneySubscription, _ value: String) {
        do { try store.enqueue(["type": "recurring.decide", "id": id, "decision": value, "expectedVersion": s.decisionVersion], entity: "recurring:\(id)") } catch { store.message = error.localizedDescription }
    }

    private func propose() {
        do { try store.enqueue(["type": "action.propose", "subscriptionId": id], entity: "action:\(id)") } catch { store.message = error.localizedDescription }
    }
}

struct MoneyActionReview: View {
    @EnvironmentObject private var store: MoneyStore
    let id: String
    @State private var confirm = false
    var body: some View {
        MoneyPage(title: "Cancellation") {
            if let a = store.workspace?.actions.first(where: { $0.id == id }) {
                MoneyCard { Text(a.data.merchant).font(.title2.bold()); LabeledContent("Status", value: a.data.state.replacingOccurrences(of: "_", with: " ")); Text("Cancel this specific subscription. Any refunds and access end dates depend on the merchant. You may need to authenticate with the cancellation partner.") }
                if a.data.state == "proposed" {
                    Button("Approve this cancellation") { confirm = true }.buttonStyle(MoneyPrimaryButtonStyle())
                }
                if a.data.state == "needs_attention" {
                    Text("The outcome is uncertain. Sprout must reconcile this request before a new attempt.").foregroundStyle(SproutColor.warning)
                }
                Text("Approval expires after 24 hours or a material change to the evidence.").font(.footnote).foregroundStyle(SproutColor.textSecondary)
            } else {
                ContentUnavailableView("Action unavailable", systemImage: "clock.arrow.circlepath")
            }
        }.confirmationDialog("Approve cancellation?", isPresented: $confirm, titleVisibility: .visible) { Button("Approve cancellation") {
            guard let a = store.workspace?.actions.first(where: { $0.id == id }) else { return }
            do { try store.enqueue(["type": "action.approve", "id": id, "expectedVersion": a.version, "evidenceHash": a.data.evidenceHash], entity: "action:\(id)") } catch { store.message = error.localizedDescription }
        } }
    }
}

struct MoneyInsightsView: View {
    @EnvironmentObject private var store: MoneyStore
    @Binding var context: String?
    @State private var mode = "Feed"
    @State private var question = ""
    @State private var answer = ""
    @State private var answerJobId: String?
    @State private var asking = false
    var body: some View {
        MoneyPage(title: "Insights") {
            Picker("Insights mode", selection: $mode) { Text("Feed").tag("Feed"); Text("Chat").tag("Chat") }.pickerStyle(.segmented)
            if mode == "Feed" {
                NavigationLink(value: MoneyRoute.subscriptions) { MoneyInsightPill(text: "Your subscriptions and upcoming renewals") }.buttonStyle(.plain)
                let review = store.workspace?.jobs?.filter { $0.type == "review.prepare" }.sorted { ($0.updatedAt ?? "") > ($1.updatedAt ?? "") }.first
                Button("Review last week") { do { try store.enqueue(["type":"review.weekly"], entity:"weekly-review") } catch { store.message = error.localizedDescription } }.buttonStyle(.bordered).disabled(store.mutations.contains { $0.entityKey == "weekly-review" } || review.map { ["queued","running","retry"].contains($0.status) } == true)
                if let review, ["queued","running","retry"].contains(review.status) { MoneyInsightPill(text: review.error == "INCOMPLETE_HISTORY" ? "Your review is waiting for the current import to finish." : "Your weekly review is saved and being prepared.") }
                if review?.result?.status == "empty" { Text("No completed records from last week yet. Add your history to create a review.").font(.footnote) }
                if store.workspace?.insights.isEmpty != false {
                    MoneyCard { Image(systemName: "sparkles").font(.largeTitle).foregroundStyle(SproutColor.action); Text("Clarity comes with a little history.").font(.headline); Text("Sprout will show evidence-backed changes here as you build your financial picture.").foregroundStyle(SproutColor.textSecondary) }
                }
                ForEach(store.workspace?.insights ?? []) { insight in MoneyCard {
                    Text(insight.title).font(.headline); Text(insight.detail).foregroundStyle(SproutColor.textSecondary)
                    ForEach(insight.evidenceIds.prefix(3), id: \.self) { id in NavigationLink("View supporting transaction", value: MoneyRoute.transaction(id)).font(.footnote) }
                    HStack { Button("Ask Sprout") { context = "insight:\(insight.id)"; mode = "Chat" }; Spacer(); Button("Dismiss") { feedback(insight.id, "dismissed") }; Button("Snooze") { feedback(insight.id, "snoozed") } }.font(.footnote)
                } }
            } else {
                MoneyInsightPill(text: "Ask a question. Review the evidence. Choose what happens next.")
                if let context {
                    Label("Context: \(context)", systemImage: "link").font(.caption); Button("Clear context") { self.context = nil }.font(.caption)
                }
                if !answer.isEmpty, answerJobId == nil || store.workspace?.jobs?.contains(where: { $0.id == answerJobId }) != true {
                    MoneyCard { Text(answer).textSelection(.enabled) }
                }
                ForEach(store.workspace?.conversations?.sorted { $0.data.createdAt < $1.data.createdAt } ?? []) { conversation in
                    MoneyCard {
                        Text(conversation.data.question).font(.headline)
                        Text(conversation.data.answer.message).textSelection(.enabled)
                        ForEach(conversation.data.answer.references, id: \.id) { reference in
                            ForEach(reference.evidenceIds, id: \.self) { id in NavigationLink("Supporting transaction", value: MoneyRoute.transaction(id)).font(.footnote) }
                        }
                        ForEach(conversation.data.answer.proposalIds, id: \.self) { id in NavigationLink("Review proposed action", value: MoneyRoute.action(id)) }
                    }
                }
                ForEach(store.workspace?.jobs?.filter { $0.type == "assistant" && $0.status != "succeeded" } ?? []) { job in
                    MoneyInsightPill(text: "Assistant request · \(job.status.replacingOccurrences(of: "_", with: " "))")
                }
                Button("Refresh conversation") { Task { await store.refresh() } }
                if asking {
                    ProgressView("Your question is being processed…")
                }
                if store.workspace?.capabilities.ai != true {
                    Text("AI is not enabled for this environment. Your saved records remain available in Activity.").foregroundStyle(SproutColor.textSecondary)
                }
            }
        }.safeAreaInset(edge: .bottom) {
            if mode == "Chat" {
                HStack(alignment: .bottom) { TextField("Ask Sprout", text: $question, axis: .vertical).lineLimit(1 ... 5).textFieldStyle(.roundedBorder).accessibilityIdentifier("money.chat.composer"); Button { Task { await ask() } } label: { Image(systemName: "arrow.up").font(.headline).frame(width: 44, height: 44) }.buttonStyle(MoneyPrimaryButtonStyle()).buttonBorderShape(.circle).disabled(question.trimmingCharacters(in: .whitespaces).isEmpty || asking || store.workspace?.capabilities.ai != true) }.padding().background(.regularMaterial)
            }
        }.onChange(of: context) {
            _, value in if value != nil {
                mode = "Chat"
            }
        }.onAppear {
            if context != nil {
                mode = "Chat"
            }
        }
    }

    private func feedback(_ id: String, _ value: String) {
        do { try store.enqueue(["type": "insight.feedback", "id": id, "feedback": value], entity: "insight:\(id)") } catch { store.message = error.localizedDescription }
    }

    private func ask() async {
        asking = true; defer { asking = false }
        do {
            let body = try JSONSerialization.data(withJSONObject: ["question": question, "context": context as Any? ?? NSNull(), "requestId": UUID().uuidString.lowercased()])
            let data = try await store.request(path: "/v1/assistant", body: body)
            let value = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            answer = value?["message"] as? String ?? "Your request was accepted. Check the conversation for its result."
            answerJobId = value?["id"] as? String
            question = ""
            await store.refresh()
        } catch { answerJobId = nil; answer = error.localizedDescription }
    }
}

struct MoneyExpenseEditor: View {
    @EnvironmentObject private var store: MoneyStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ExpenseDraft
    let onReviewFinished: () -> Void
    init(draft: ExpenseDraft = ExpenseDraft(), onReviewFinished: @escaping () -> Void = {}) {
        _draft = State(initialValue: draft)
        self.onReviewFinished = onReviewFinished
    }

    @State private var error: String?
    @State private var photo: PhotosPickerItem?
    @State private var extracting = false
    @State private var camera = false
    @State private var saved = false
    @State private var listening = false
    @StateObject private var speech = SpeechRecognizer()
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("0.00", text: $draft.amount).font(.largeTitle.weight(.semibold)).keyboardType(.decimalPad).accessibilityLabel("Expense amount in US dollars")
                    TextField("Merchant", text: $draft.merchant)
                    Picker("Category", selection: $draft.category) { ForEach(["Food", "Groceries", "Transport", "Shopping", "Health", "Entertainment", "Bills", "Other"], id: \.self) { Text($0) } }
                    DatePicker("Date", selection: $draft.date, displayedComponents: .date)
                    LabeledContent("Account", value: "Manual / cash")
                    TextField("Notes (optional)", text: $draft.notes, axis: .vertical)
                    if draft.notes.utf16.count > 1000 { Text("Keep notes to 1,000 characters or fewer.").font(.footnote).foregroundStyle(SproutColor.error) }
                    if draft.merchant.trimmingCharacters(in: .whitespacesAndNewlines).utf16.count > 160 { Text("Keep the merchant name to 160 characters or fewer.").font(.footnote).foregroundStyle(SproutColor.error) }
                }.disabled(extracting)
                Section("Capture") {
                    Button {
                        Task {
                            if listening {
                                listening = false; speech.stopTranscribing()
                            } else if await speech.requestAccess() {
                                listening = true; draft.source = "voice"; speech.startTranscribing()
                            } else {
                                error = "Allow speech and microphone access in Settings, or type your expense."
                            }
                        }
                    } label: { Label(listening ? "Stop voice capture" : "Use voice", systemImage: "mic") }.disabled(extracting)
                    PhotosPicker(selection: $photo, matching: .images) { Label("Scan receipt from photo", systemImage: "doc.viewfinder") }
                        .disabled(extracting)
                    Button {
                        Task {
                            listening = false; speech.stopTranscribing()
                            guard UIImagePickerController.isSourceTypeAvailable(.camera) else { error = "Camera is unavailable. Choose a receipt photo or type its details."; return }
                            if await AVCaptureDevice.requestAccess(for: .video) { camera = true }
                            else { error = "Allow camera access in Settings, or choose a receipt photo and enter its details manually." }
                        }
                    } label: { Label("Take receipt photo", systemImage: "camera") }.disabled(extracting)
                    if extracting {
                        ProgressView("Reading receipt on this device…")
                    }
                    if !draft.transcript.isEmpty {
                        if draft.source == "scan" { receiptSuggestions }
                        Text(draft.transcript).font(.footnote); Text("Review the total, merchant, date and category. Audio is not retained. Receipt text is read on this device; a compressed image is uploaded only if you choose to keep it.").font(.caption).foregroundStyle(SproutColor.textSecondary)
                    }
                    if draft.receiptJPEG != nil { Toggle("Keep compressed receipt with this expense", isOn: $draft.keepReceipt); Text("The copy is private to your Sprout account and can be removed from the transaction. The original photo is unchanged. Beta limits: 100 retained copies, 50 MB per account, 650 KB per copy.").font(.caption).foregroundStyle(SproutColor.textSecondary) }
                }
                if let error {
                    Text(error).foregroundStyle(SproutColor.error)
                }
            }
            .navigationTitle(draft.expectedVersion == 0 ? "Add expense" : "Edit expense").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onReviewFinished(); dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save to Activity") { do { try store.save(draft); saved = true; onReviewFinished(); dismiss() } catch { self.error = error.localizedDescription } }.disabled(draft.transaction() == nil || saved || extracting) } }
            .interactiveDismissDisabled(draft.source == "shortcut")
            .onChange(of: speech.transcript) {
                _, text in guard draft.source == "voice", !extracting, !camera else { return }; draft.transcript = text; let amounts = ExpenseDraft.explicitAmounts(in: text); draft.amount = amounts.count == 1 ? amounts[0] : ""; if amounts.count != 1 {
                    error = "Choose the expense total; the transcript contains no single explicit amount."
                }
            }
            .onChange(of: photo) { _, photo in listening = false; speech.stopTranscribing(); Task { await scan(photo) } }
            .sheet(isPresented: $camera) { MoneyReceiptCamera { data in camera = false; if let data { Task { await scanData(data) } } } }
            .onDisappear { speech.stopTranscribing() }
        }
    }

    private func scan(_ photo: PhotosPickerItem?) async {
        guard !extracting else { return }
        extracting = true; defer { extracting = false }
        do { if let data = try await photo?.loadTransferable(type: Data.self) { await applyScannedData(data) } }
        catch { self.error = "Couldn't open this receipt photo. You can enter its details manually." }
    }

    private var receiptSuggestions: some View {
        let suggested = MoneyReceiptExtraction.parse(draft.transcript)
        return VStack(alignment: .leading, spacing: 12) {
            if suggested.totals.count > 1 {
                Text("Several totals were found. Check the receipt before choosing.").font(.footnote)
                ForEach(suggested.totals, id: \.self) { total in Button("Use total \(MoneyAmount(minor: total).formatted)") { draft.amount = NSDecimalNumber(decimal: Decimal(total) / 100).stringValue } }
            }
            if let merchant = suggested.merchant, merchant != draft.merchant { Button("Use merchant \(merchant)") { draft.merchant = merchant } }
            if let date = suggested.date {
                Button("Use receipt date \(date)") {
                    let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
                    if let value = formatter.date(from: date) { draft.date = value }
                }
            }
        }
    }

    private func scanData(_ data: Data) async {
        guard !extracting else { return }
        extracting = true; defer { extracting = false }
        await applyScannedData(data)
    }

    private func applyScannedData(_ data: Data) async {
        draft.receiptJPEG = nil; draft.keepReceipt = false
        do {
            let result = try await MoneyReceiptOCR.scan(data); let text = result.text
            draft.receiptJPEG = result.jpeg; draft.keepReceipt = false; draft.receiptId = UUID().uuidString.lowercased()
            let extracted = MoneyReceiptExtraction.parse(text)
            draft.source = "scan"; draft.transcript = String(text.prefix(SproutReceiptRules.maxCharacters)); draft.amount = extracted.amount
            if draft.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { draft.merchant = extracted.merchant ?? "" }
            error = extracted.totals.count == 1 ? nil : "Review the receipt and choose or enter the final total. Tax, subtotal and total can differ."
        } catch { self.error = "Couldn't read this receipt. You can enter its details manually." }
    }
}

struct MoneyOnboardingView: View {
    @EnvironmentObject private var store: MoneyStore
    @State private var target = ""
    @State private var selectionOverrides: [String: Bool] = [:]
    @State private var error: String?
    var body: some View {
        NavigationStack {
            MoneyPage(title: title) {
                ProgressView(value: Double(step), total: 4).accessibilityLabel("Setup step \(step) of 4")
                if step <= 2 {
                    Image(systemName: "building.columns.fill").font(.system(size: 80)).frame(maxWidth: .infinity).padding(32).foregroundStyle(SproutColor.action)
                    Text("A clearer picture starts here.").font(.largeTitle.bold())
                    Text("Connect one bank connection free. Bank access is read-only. You can also skip and add expenses yourself.").foregroundStyle(SproutColor.textSecondary)
                    NavigationLink("Connect a bank", value: MoneyRoute.connection).buttonStyle(MoneyPrimaryButtonStyle())
                    Button(store.workspace?.connections?.isEmpty == false ? "Continue" : "Skip for now") { advance("subscriptions-found") }
                } else if step == 3 {
                    MoneyAmountView(minor: (store.workspace?.subscriptions ?? []).filter { isSelected($0) }.reduce(0) { $0 + $1.monthlyMinor })
                    Text("Estimated monthly cost of your selected subscriptions").foregroundStyle(SproutColor.textSecondary)
                    if store.workspace?.subscriptions.isEmpty != false {
                        MoneyCard { Text("No recurring candidates yet.").font(.headline); Text("Keep adding history or continue now. You can review subscriptions later in Insights.") }
                    }
                    ForEach(store.workspace?.subscriptions ?? []) { s in Toggle(isOn: Binding(get: { isSelected(s) }, set: { selectionOverrides[s.id] = $0 })) { VStack(alignment: .leading) { Text(s.merchant); Text("\(MoneyAmount(minor: s.monthlyMinor).formatted) / month · \(s.decision)").font(.caption) } } }
                    Text("Confirming means track these charges. It does not subscribe, cancel or authorize an external action.").font(.footnote)
                    Button("Track \((store.workspace?.subscriptions ?? []).filter { isSelected($0) }.count) and continue") { confirmCandidates() }.buttonStyle(MoneyPrimaryButtonStyle())
                } else {
                    MoneyInsightPill(text: "A plan that starts with you.")
                    Text("Your monthly spending target").font(.title2.bold())
                    TextField("Enter your target in USD", text: $target).keyboardType(.decimalPad).font(.largeTitle).textFieldStyle(.roundedBorder)
                    Text("There isn't enough synced history to show a reliable historical average yet. You can change your target later.").font(.footnote).foregroundStyle(SproutColor.textSecondary)
                    Text("Reminder and alert controls become available when delivery is configured.").font(.footnote)
                    Button("Save my plan") { guard let value = MoneyAmount.parse(target), var p = store.workspace?.profile else { error = "Enter a monthly target."; return }; p.monthlyTargetMinor = value; p.onboarding = "complete"; save(p) }.buttonStyle(MoneyPrimaryButtonStyle())
                    Button("Decide later") { advance("complete") }
                }
                if let error {
                    Text(error).foregroundStyle(SproutColor.error)
                }
            }.navigationDestination(for: MoneyRoute.self) { _ in MoneyConnectionView() }
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Sign out") { Task { try? await AppwriteNativeSession.shared.signOut() } } } }
        }
    }

    private var step: Int {
        switch store.workspace?.profile.onboarding { case "subscriptions-found": 3; case "your-plan": 4; default: 2 }
    }

    private var title: String {
        step == 3 ? "Subscriptions found" : step == 4 ? "Your plan" : "Connect your bank"
    }

    private func advance(_ stage: String) {
        guard var p = store.workspace?.profile else { return }; p.onboarding = stage; save(p)
    }

    private func save(_ p: MoneyProfile) {
        do { try store.saveProfile(p) } catch { self.error = error.localizedDescription }
    }

    private func isSelected(_ subscription: MoneySubscription) -> Bool {
        selectionOverrides[subscription.id] ?? (subscription.decision == "confirmed")
    }

    private func confirmCandidates() {
        do {
            for s in store.workspace?.subscriptions ?? [] {
                try store.enqueue(["type": "recurring.decide", "id": s.id, "decision": isSelected(s) ? "confirmed" : "dismissed", "expectedVersion": s.decisionVersion], entity: "recurring:\(s.id)")
            }
            advance("your-plan")
        } catch { self.error = error.localizedDescription }
    }
}

struct MoneyConnectionView: View {
    var body: some View {
        MoneyBankConnectionView()
    }
}

struct MoneyProfileView: View {
    @ObservedObject private var accountSession = AppwriteNativeSession.shared
    @EnvironmentObject private var store: MoneyStore
    @AppStorage("sprout.deviceLock") private var deviceLock = false
    @State private var appearance = "system"
    @State private var notifications = false
    @State private var password = false
    @State private var support = false
    var onSignOut: () -> Void
    private var notificationSummary: String { "Quiet hours \((store.workspace?.profile.quietHours?.enabled ?? true) ? "on" : "off") · \(store.workspace?.profile.timezone ?? "")" }
    var body: some View {
        MoneyPage(title: "Profile & security") {
            MoneyCard { Label(store.identity.name.isEmpty ? "Your Sprout" : store.identity.name, systemImage: "person.crop.circle.fill").font(.title2.bold()); Text(store.identity.email).foregroundStyle(SproutColor.textSecondary) }
            MoneyCard { NavigationLink(value: MoneyRoute.connection) { LabeledContent("Linked accounts", value: "Manage") }; LabeledContent("Membership", value: store.workspace?.entitlements.plus == true ? "Sprout Plus" : "Free"); Text("Membership is verified by the server. Purchase restoration and upgrade are available after billing setup.").font(.footnote).foregroundStyle(SproutColor.textSecondary) }
            MoneyCard {
                if accountSession.identity?.id == store.identity.id, accountSession.identity?.hasPassword == true { Button("Change password") { password = true }.accessibilityIdentifier("money.security.password") }
                Button { notifications = true } label: { VStack(alignment:.leading,spacing:4) { Text("Notification preferences"); Text(notificationSummary).font(.caption).foregroundStyle(SproutColor.textSecondary) } }
                    .accessibilityIdentifier("money.notification.preferences").accessibilityLabel("Notification preferences").accessibilityValue(notificationSummary).disabled(store.workspace == nil)
                Toggle("Lock on this device", isOn: Binding(get: { deviceLock }, set: { value in Task {
                    if !value {
                        deviceLock = false; return
                    }; let auth = LAContext(); if (try? await auth.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Enable the Sprout app lock")) == true {
                        deviceLock = true
                    }
                } }))
                Picker("Appearance", selection: $appearance) { Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark") }
                Button("Save appearance") { guard var p = store.workspace?.profile else { return }; p.appearance = appearance; do { try store.saveProfile(p) } catch { store.message = error.localizedDescription } }
                Text("The app lock uses this device's authentication and is independent of your Sprout account password.").font(.caption).foregroundStyle(SproutColor.textSecondary)
            }
            if store.mutations.contains(where: \.conflict) {
                MoneyCard { Text("Changes needing review").font(.headline); ForEach(store.mutations.filter(\.conflict), id: \.id) { mutation in VStack(alignment: .leading) { Text(store.pendingExpenseDescription(mutation)).font(.footnote); Text("Activity shows the server version. Your edit remains on this device until you choose what to keep.").font(.caption); if mutation.entityKey.hasPrefix("transaction:") { MoneyEditConflictButton(mutation: mutation) } else if mutation.entityKey.hasPrefix("goal:") { Text("Review both goal versions in Budget.").font(.caption) } else if mutation.entityKey.hasPrefix("budget:") { Text("Review both budget versions in Budget.").font(.caption) } else if mutation.entityKey.hasPrefix("receipt-upload:") { MoneyPendingReceiptButton(mutation: mutation) }; Button("Discard this edit and use server version", role: .destructive) { do { try store.useServerVersion(mutation) } catch { store.message = error.localizedDescription } } } } }
            }
            MoneyCard { NavigationLink("Import transactions", value: MoneyRoute.importTransactions); NavigationLink("Export my data", value: MoneyRoute.privacy("export")); NavigationLink("Delete my account", value: MoneyRoute.privacy("delete")); Link("Privacy policy", destination: URL(string: "https://getsprout.appwrite.network/privacy")!); Link("Terms", destination: URL(string: "https://getsprout.appwrite.network/terms")!) }
            Button("Help & support") { support = true }.buttonStyle(.bordered)
            Button("Sign out", action: onSignOut).buttonStyle(.bordered)
        }.onAppear { appearance = store.workspace?.profile.appearance ?? "system" }
            .sheet(isPresented: $notifications) { if let workspace = store.workspace { MoneyNotificationPreferencesView(profile: workspace.profile, version: workspace.profileVersion) } }
            .sheet(isPresented: $password) { MoneyPasswordView(owner: store.identity.id) }
            .sheet(isPresented: $support) { MoneySupportView() }
    }
}

struct MoneyPrivacyView: View {
    @EnvironmentObject private var store: MoneyStore
    let kind: String
    @State private var confirm = false
    @State private var status = ""
    @State private var requestJobId: String?
    @State private var busy = false
    private var requests: [MoneyJob] { (store.workspace?.jobs?.filter { $0.type == "privacy.\(kind)" } ?? []).sorted { ($0.updatedAt ?? "") > ($1.updatedAt ?? "") } }
    var body: some View {
        MoneyPage(title: kind == "delete" ? "Delete account" : "Export data") {
            Text(kind == "delete" ? "Deletion stops new work and tracks removal of active records, attachments and provider connections. Provider and backup retention have separate timelines." : "Request a private archive of your financial records, settings and ready retained receipt copies.")
            if !status.isEmpty, requestJobId == nil || store.workspace?.jobs?.contains(where: { $0.id == requestJobId }) != true {
                MoneyInsightPill(text: status)
            }
            ForEach(Array(requests.prefix(10))) {
                job in LabeledContent("Request", value: job.status.replacingOccurrences(of: "_", with: " ")); if job.status == "retry" {
                    Text("Your request is saved. Sprout will retry automatically.").font(.footnote)
                } else if ["failed", "needs_attention"].contains(job.status) {
                    Text("This request needs support before it can be completed.").font(.footnote)
                }
                if job.id == requests.first?.id, job.status == "succeeded", let file = job.result?.fileId, let bucket = job.result?.bucketId {
                    if let generated = job.result?.generatedAt, let date = ISO8601DateFormatter().date(from: generated) ?? { let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return formatter.date(from: generated) }() {
                        Text("Created \(date.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(SproutColor.textSecondary)
                    }
                    MoneyExportButton(fileId: file, bucketId: bucket)
                }
            }
            Button("Refresh progress") { Task { await store.refresh() } }
            Button(kind == "delete" ? "Request account deletion" : "Request export", role: kind == "delete" ? .destructive : nil) { confirm = true }.buttonStyle(MoneyPrimaryButtonStyle()).disabled(busy)
        }.confirmationDialog(kind == "delete" ? "Permanently delete this account?" : "Create an export?", isPresented: $confirm, titleVisibility: .visible) { Button("Confirm", role: kind == "delete" ? .destructive : nil) { Task { await submit() } } }
    }

    private func submit() async {
        busy = true; defer { busy = false }
        do {
            if kind == "delete" { _ = try MoneyDeletionState.shared.prepare(owner: store.identity.id); return }
            let fields: [String: Any] = ["type": kind, "requestId": UUID().uuidString.lowercased()]
            let result = try await store.request(path: "/v1/privacy", body: JSONSerialization.data(withJSONObject: fields))
            let value = try JSONSerialization.jsonObject(with: result) as? [String: Any]; requestJobId = value?["id"] as? String; status = "Your request is \(value?["status"] as? String ?? "queued")."; await store.refresh()
        } catch { requestJobId = nil; status = error.localizedDescription; if kind == "delete" { await MoneyDeletionState.shared.refresh() } }
    }
}
