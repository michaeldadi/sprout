import Charts
import LocalAuthentication
import SwiftUI

struct MoneyAppView: View {
    @StateObject private var store: MoneyStore
    @EnvironmentObject private var deepLinks: DeepLinkManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: MoneyTab = .home
    @State private var insightPath: [MoneyRoute] = []
    @State private var homeOrigin = false
    @State private var expense = false
    @State private var expenseDraft = ExpenseDraft()
    @State private var chatContext: String?
    @State private var locked = false
    @State private var unlocking = false
    @AppStorage("sprout.deviceLock") private var deviceLock = false
    init(identity: AppwriteAccountIdentity) {
        _store = StateObject(wrappedValue: MoneyStore(identity: identity))
        _locked = State(initialValue: UserDefaults.standard.bool(forKey: "sprout.deviceLock"))
    }

    #if DEBUG
        init(review: MoneyWorkspace, tab: MoneyTab = .home, route: MoneyRoute? = nil, expense: Bool = false) {
            _store = StateObject(wrappedValue: MoneyStore(review: review)); _tab = State(initialValue: tab)
            _insightPath = State(initialValue: route.map { [$0] } ?? []); _expense = State(initialValue: expense)
        }
    #endif

    var body: some View {
        Group {
            if locked {
                lockView
            } else if let workspace = store.workspace, workspace.profile.onboarding != "complete" {
                MoneyOnboardingView().environmentObject(store)
            } else if store.workspace == nil {
                ContentUnavailableView {
                    Label(store.refreshing ? "Opening your workspace" : "Your workspace is unavailable", systemImage: "leaf")
                } description: { Text(store.message ?? "Connecting to your saved financial records.") } actions: {
                    Button("Retry") { Task { await store.refresh() } }.buttonStyle(MoneyPrimaryButtonStyle())
                    Button("Sign out") { Task { await signOut() } }
                }
            } else {
                TabView(selection: $tab) {
                    ForEach(MoneyTab.allCases) { destination in
                        Group {
                            if destination == .insights {
                                NavigationStack(path: $insightPath) { content(destination).navigationDestination(for: MoneyRoute.self, destination: route) }
                            } else {
                                NavigationStack { content(destination).navigationDestination(for: MoneyRoute.self, destination: route) }
                            }
                        }
                        .tabItem { Label(destination.title, systemImage: destination.icon).accessibilityLabel(destination.title).accessibilityIdentifier("money.destination.\(destination.rawValue)") }.tag(destination)
                    }
                }
                .sheet(isPresented: $expense, onDismiss: { expenseDraft = ExpenseDraft(); handlePendingLink(); handlePendingShortcut() }) {
                    MoneyExpenseEditor(draft: expenseDraft, onReviewFinished: { try? ExpenseShortcutHandoff.clear(id: expenseDraft.id) }).environmentObject(store).presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
                }
                .onChange(of: insightPath) { old, path in
                    if !old.isEmpty && path.isEmpty && homeOrigin {
                        homeOrigin = false; tab = .home
                    }
                }
            }
        }
        .environmentObject(store)
        .tint(SproutColor.action)
        .preferredColorScheme(store.workspace?.profile.appearance == "dark" ? .dark : store.workspace?.profile.appearance == "light" ? .light : nil)
        .task {
            ExpenseShortcutHandoff.startObserving()
            locked = deviceLock && !store.reviewMode; if locked {
                await unlock()
            }; handlePendingLink(); handlePendingShortcut(); await store.refresh(); handlePendingLink(); handlePendingShortcut()
        }
        .task(id: changeSignalKey) {
            guard !changeSignalKey.isEmpty, let channel = store.workspace?.changeChannel else { return }
            await store.observeChanges(channel: channel)
        }
        .task(id: scenePhase == .active && !locked && !store.reviewMode) {
            guard scenePhase == .active, !locked, !store.reviewMode else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 300_000_000_000) } catch { return }
                await store.refresh()
            }
        }
        .task(id: jobPollingKey) {
            guard !jobPollingKey.isEmpty, !store.reviewMode else { return }
            for attempt in 0 ..< 40 {
                try? await Task.sleep(nanoseconds: UInt64(min(15, 2 + attempt / 4)) * 1_000_000_000)
                guard !Task.isCancelled else { return }
                await store.refresh()
            }
        }
        .onChange(of: tab) { _, destination in
            if !store.reviewMode { AnalyticsManager.shared.trackScreen(destination.rawValue) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active && deviceLock {
                locked = true
            }
            if phase == .active {
                Task {
                    if locked {
                        await unlock()
                    }; handlePendingLink(); handlePendingShortcut(); await store.refresh()
                }
            }
        }
        .onChange(of: deepLinks.pendingDeepLink) { _, _ in handlePendingLink() }
        .onChange(of: store.workspace?.revision) { _, _ in handlePendingLink(); handlePendingShortcut() }
        .onReceive(NotificationCenter.default.publisher(for: ExpenseShortcutHandoff.ready).receive(on: RunLoop.main)) { _ in handlePendingShortcut() }
        .onDisappear { store.deactivate() }
    }

    private var changeSignalKey: String {
        guard scenePhase == .active, !locked, !store.reviewMode else { return "" }
        return store.workspace?.changeChannel ?? ""
    }

    private var jobPollingKey: String {
        guard scenePhase == .active else { return "" }
        return (store.workspace?.jobs ?? []).filter {
            ["assistant", "review.prepare", "privacy.export", "privacy.delete", "bank.sync", "transaction.import", "receipt.reconcile", "receipt.cleanup"].contains($0.type) && ["queued", "running", "retry"].contains($0.status)
        }.map(\.id).sorted().joined(separator: ",")
    }

    @ViewBuilder private func content(_ destination: MoneyTab) -> some View {
        switch destination {
        case .home: MoneyHomeView(onSubscriptions: openSubscriptions, onActivity: { tab = .activity }, onExpense: { expense = true }, onAsk: ask)
        case .budget: MoneyBudgetView(onAsk: ask)
        case .activity: MoneyActivityView(onExpense: { expense = true }, onAsk: ask)
        case .insights: MoneyInsightsView(context: $chatContext)
        case .profile: MoneyProfileView(onSignOut: { Task { await signOut() } })
        }
    }

    @ViewBuilder private func route(_ value: MoneyRoute) -> some View {
        switch value {
        case .subscriptions: MoneySubscriptionsView()
        case let .subscription(id): MoneySubscriptionDetail(id: id, onAsk: ask)
        case let .transaction(id): MoneyTransactionDetail(id: id, onAsk: ask)
        case let .action(id): MoneyActionReview(id: id)
        case .connection: MoneyConnectionView()
        case let .privacy(kind): MoneyPrivacyView(kind: kind)
        case .importTransactions: MoneyImportView()
        }
    }

    private var lockView: some View {
        ContentUnavailableView { Label("Sprout is locked", systemImage: "lock.fill") } description: { Text("Unlock to view your finances.") } actions: { Button("Unlock") { Task { await unlock() } }.buttonStyle(MoneyPrimaryButtonStyle()) }
            .background(SproutColor.canvas)
    }

    private func unlock() async {
        guard !unlocking else { return }; unlocking = true; defer { unlocking = false }
        let context = LAContext(); context.localizedCancelTitle = "Keep locked"
        if (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your Sprout finances")) == true {
            locked = false
        }
    }

    private func openSubscriptions() {
        homeOrigin = tab == .home; tab = .insights; insightPath = [.subscriptions]
    }

    private func ask(_ context: String) {
        chatContext = context; homeOrigin = false; insightPath = []; tab = .insights
    }

    private func signOut() async {
        do { try await AppwriteNativeSession.shared.signOut() } catch { store.message = "Could not sign out. Try again." }
    }

    private func handlePendingLink() {
        guard !locked, store.workspace?.profile.onboarding == "complete", let url = deepLinks.pendingDeepLink, let c = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }
        switch c.path.isEmpty ? "/\(c.host ?? "")" : c.path {
        case "/budget": tab = .budget
        case "/transaction":
            tab = .activity
            // Stable detail selection is handled by the Activity stack.
            deepLinks.activeTransactionId = c.queryItems?.first(where: { $0.name == "id" })?.value
        case "/subscriptions": homeOrigin = false; tab = .insights; insightPath = [.subscriptions]
        case "/subscription":
            if let id = c.queryItems?.first(where: { $0.name == "id" })?.value, id.range(of: #"^[A-Za-z0-9_.:-]{1,128}$"#, options: .regularExpression) != nil { homeOrigin = false; tab = .insights; insightPath = [.subscription(id)] }
        case "/insights": tab = .insights
        case "/actions":
            tab = .insights; homeOrigin = false
            if let id = c.queryItems?.first(where: { $0.name == "id" })?.value {
                insightPath = [.action(id)]
            }
        case "/expense":
            guard !expense else { return }
            do {
                let items = c.queryItems ?? []
                guard Set(items.map(\.name)).count == items.count, items.allSatisfy({ $0.value != nil }), url.absoluteString.utf8.count < 12_000 else { throw ExpenseShortcutError.invalid }
                expenseDraft = try ExpenseDraft.shortcut(ExpenseShortcutInput(fields: Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value!) })))
                expense = true
            } catch { store.message = error.localizedDescription }
        default: break
        }
        deepLinks.pendingDeepLink = nil
    }

    private func handlePendingShortcut() {
        guard !locked, !expense, !store.reviewMode, store.workspace?.profile.onboarding == "complete" else { return }
        do {
            guard let input = try ExpenseShortcutHandoff.load() else { return }
            if store.transactions.contains(where: { $0.id == input.id }) { try ExpenseShortcutHandoff.clear(id: input.id); return }
            expenseDraft = try ExpenseDraft.shortcut(input); expense = true
        } catch ExpenseShortcutError.unavailable { /* Unsigned simulator builds may not have an App Group container. */ }
        catch { store.message = error.localizedDescription }
    }
}

struct MoneyPage<Content: View>: View {
    let title: String
    var lazy = false
    @ViewBuilder var content: Content
    @EnvironmentObject private var store: MoneyStore
    var body: some View {
        ScrollView {
            Group {
                if lazy { LazyVStack(alignment: .leading, spacing: 24) { pageContent } }
                else { VStack(alignment: .leading, spacing: 24) { pageContent } }
            }.padding(20).frame(maxWidth: 680).frame(maxWidth: .infinity, alignment: .center)
        }
        .background(SproutColor.canvas).foregroundStyle(SproutColor.textPrimary)
        .navigationTitle(title).navigationBarTitleDisplayMode(.large)
        .refreshable { await store.refresh() }
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            if store.refreshing { ProgressView().accessibilityLabel("Syncing") }
        } }
    }
    @ViewBuilder private var pageContent: some View {
        if let message = store.message {
                    Label(message, systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90").font(.footnote).foregroundStyle(SproutColor.warning).accessibilityIdentifier("money.syncStatus")
                }
                if !store.mutations.isEmpty {
                    Text("\(store.mutations.count) pending change\(store.mutations.count == 1 ? "" : "s") · totals reflect the last server snapshot").font(.caption).foregroundStyle(SproutColor.textSecondary)
                }
        content
    }
}

struct MoneyCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }.frame(maxWidth: .infinity, alignment: .leading).padding(20).background(SproutColor.surface, in: RoundedRectangle(cornerRadius: SproutDesignTokens.groupCorner))
    }
}

struct MoneyPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundStyle(SproutColor.onAction)
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(SproutColor.action.opacity(configuration.isPressed ? 0.85 : 1), in: Capsule())
            .opacity(enabled ? 1 : 0.45)
    }
}

struct MoneyInsightPill: View {
    let text: String
    var body: some View {
        Label(text, systemImage: "sparkles").font(.subheadline.weight(.medium)).padding(.horizontal, 16).padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading).background(SproutColor.actionSubtle, in: RoundedRectangle(cornerRadius: 22)).foregroundStyle(SproutColor.textPrimary).accessibilityElement(children: .combine)
    }
}

struct MoneyAmountView: View {
    let minor: Int64?
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize = 48
    var body: some View {
        Text(minor.map { MoneyAmount(minor: $0).formatted } ?? "—").font(.system(size: amountSize, weight: .bold, design: .rounded)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
    }
}

struct MoneyTransactionRow: View {
    let item: MoneyTransaction
    let pending: Bool
    var body: some View {
        HStack(spacing: 12) {
            Text(String(item.merchant.prefix(1)).uppercased()).font(.headline).frame(width: 42, height: 42).background(SproutColor.surfaceSubtle, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) { Text(item.merchant).font(.body.weight(.medium)); Text("\(item.category) · \(pending ? "Waiting to sync" : item.source == "plaid" ? "Bank" : "Manual")").font(.caption).foregroundStyle(SproutColor.textSecondary) }
            Spacer(minLength: 8); Text(item.amount.formatted).font(.body.weight(.semibold)).monospacedDigit().foregroundStyle(item.type == "income" ? SproutColor.action : SproutColor.textPrimary)
        }.padding(.vertical, 8).accessibilityElement(children: .combine)
    }
}

struct MoneyHomeView: View {
    @EnvironmentObject private var store: MoneyStore
    var onSubscriptions: () -> Void; var onActivity: () -> Void; var onExpense: () -> Void; var onAsk: (String) -> Void
    var body: some View {
        MoneyPage(title: "Home") {
            if let w = store.workspace {
                Text("Good to see you\(w.profile.name.isEmpty ? "" : ", \(w.profile.name)") · \(w.transactions.count) saved").font(.footnote).foregroundStyle(SproutColor.textSecondary)
                MoneyInsightPill(text: w.insights.first?.title ?? "Your money, with a little more clarity.")
                VStack(alignment: .leading, spacing: 16) {
                    Text(w.snapshot.heroLabel).font(.subheadline).foregroundStyle(SproutColor.textSecondary)
                    MoneyAmountView(minor: w.snapshot.heroMinor)
                    Text(w.snapshot.heroMinor == nil ? "Set your monthly target in Budget to get started." : "Based on saved spending this month.").font(.footnote).foregroundStyle(SproutColor.textSecondary)
                    Divider()
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 6) { Text("Connected cash balance").font(.caption); Text(w.snapshot.balanceMinor.map { MoneyAmount(minor: $0).formatted } ?? "—").font(.title3.bold()).monospacedDigit() }.frame(maxWidth: .infinity, alignment: .leading)
                        Button(action: onSubscriptions) { VStack(alignment: .leading, spacing: 6) { Text("Subscriptions / month").font(.caption); Text(MoneyAmount(minor: w.snapshot.monthlySubscriptionsMinor).formatted).font(.title3.bold()) }.frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.plain)
                    }
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(SproutColor.actionSubtle, in: RoundedRectangle(cornerRadius: SproutDesignTokens.groupCorner))
                VStack(alignment: .leading, spacing: 6) {
                    Text(w.snapshot.coverage).font(.caption).foregroundStyle(SproutColor.textSecondary)
                    Text("Snapshot \(w.snapshot.asOf.prefix(16).replacingOccurrences(of: "T", with: " ")) UTC").font(.caption2).foregroundStyle(SproutColor.textSecondary)
                }
                if let next = w.subscriptions.filter({ $0.decision == "confirmed" }).first {
                    Button(action: onSubscriptions) { MoneyInsightPill(text: "\(next.merchant) · estimated renewal \(next.nextDate)") }.buttonStyle(.plain)
                }
                Text("Category pace").font(.title3.bold())
                if w.snapshot.budget.categories.isEmpty {
                    MoneyCard { Text("Give your money a plan").font(.headline); Text("Add category limits in Budget. Your target is always your choice.").foregroundStyle(SproutColor.textSecondary) }
                } else {
                    MoneyCard { ForEach(w.snapshot.budget.categories.prefix(3)) { MoneyPaceRow(pace: $0) } }
                }
                HStack { Text("Latest activity").font(.title3.bold()); Spacer(); Button("View all", action: onActivity) }
                MoneyCard {
                    if store.transactions.isEmpty {
                        Text("Your first expense starts here.").foregroundStyle(SproutColor.textSecondary)
                    }
                    ForEach(store.transactions.prefix(4)) { item in NavigationLink(value: MoneyRoute.transaction(item.id)) { MoneyTransactionRow(item: item, pending: store.pending(item.id)) }.buttonStyle(.plain) }
                }
                Button("Ask Sprout about this month") { onAsk("budget:\(w.snapshot.budget.month)") }.frame(maxWidth: .infinity).buttonStyle(.bordered)
            }
        }.safeAreaInset(edge: .bottom) { Button(action: onExpense) { Label("Add expense", systemImage: "plus").font(.headline).padding(.horizontal, 20).padding(.vertical, 8) }.buttonStyle(MoneyPrimaryButtonStyle()).buttonBorderShape(.capsule).padding(.bottom, 8) }
    }
}

struct MoneyPaceRow: View {
    let pace: MoneyCategoryPace
    var body: some View {
        VStack(alignment: .leading, spacing: 8) { HStack { Text(pace.category).font(.body.weight(.medium)); Spacer(); Text("\(MoneyAmount(minor: pace.spentMinor).formatted) / \(MoneyAmount(minor: pace.plannedMinor).formatted)").font(.caption).monospacedDigit() }; ProgressView(value: Double(max(0, pace.spentMinor)), total: Double(max(1, pace.plannedMinor))).tint(pace.aheadOfPace ? SproutColor.warning : SproutColor.action); Text("\(MoneyAmount(minor: pace.remainingMinor).formatted) remaining").font(.caption).foregroundStyle(SproutColor.textSecondary) }.accessibilityElement(children: .combine)
    }
}

private struct MoneyPlanEdit: Identifiable {
    let id = UUID()
    let baseline: MoneyWorkspace
    let month: String
    let categoryOnly: Bool
}

struct MoneyBudgetView: View {
    @EnvironmentObject private var store: MoneyStore
    var onAsk: (String) -> Void
    @State private var editing: MoneyPlanEdit?
    @State private var choosingEdit = false
    @State private var selectedMonth = ""
    var body: some View {
        MoneyPage(title: "Budget") {
            if let w = store.workspace {
                let periods = w.budgetPeriods ?? [w.snapshot.budget]
                let period = periods.first { $0.month == selectedMonth } ?? w.snapshot.budget
                let current = period.month == w.snapshot.budget.month
                Picker("Budget period", selection: Binding(get: { period.month }, set: { selectedMonth = $0 })) { ForEach(periods, id: \.month) { Text($0.month).tag($0.month) } }.accessibilityIdentifier("money.budget.period")
                MoneyInsightPill(text: period.categories.contains(where: \.aheadOfPace) ? "A category is moving ahead of its planned pace." : "A little direction for every dollar.")
                Text(period.state == "closed" ? "Completed period" : current ? "Current period" : "Upcoming period").font(.subheadline).foregroundStyle(SproutColor.textSecondary)
                MoneyAmountView(minor: current ? w.snapshot.heroMinor : period.categories.isEmpty ? nil : period.remainingMinor)
                Text(current ? "Remaining monthly target" : "Remaining category budgets").foregroundStyle(SproutColor.textSecondary)
                if !period.categories.isEmpty {
                    Chart(period.categories) { category in SectorMark(angle: .value("Spent", max(0, category.spentMinor)), innerRadius: .ratio(0.72)).foregroundStyle(by: .value("Category", category.category)) }.chartForegroundStyleScale(range: [SproutColor.action, SproutColor.info, SproutColor.warning, SproutColor.textSecondary]).frame(height: 190).accessibilityLabel("Posted spending in budgeted categories")
                }
                MoneyCard {
                    if period.categories.isEmpty {
                        Text(current ? "Create your first category budget." : "No category budgets were saved for this period.")
                    }; ForEach(period.categories) { MoneyPaceRow(pace: $0) }
                }
                Text("Budget pace uses posted expenses in this period. Transfers and pending charges are excluded.").font(.footnote).foregroundStyle(SproutColor.textSecondary)
                if current {
                    Button("Edit your plan") { choosingEdit = true }.buttonStyle(MoneyPrimaryButtonStyle()).buttonBorderShape(.capsule)
                        .confirmationDialog("Edit your plan", isPresented: $choosingEdit, titleVisibility: .visible) {
                            Button("Monthly target") { editing = MoneyPlanEdit(baseline: w, month: period.month, categoryOnly: false) }
                            Button("Category budgets") { editing = MoneyPlanEdit(baseline: w, month: period.month, categoryOnly: true) }
                        }
                } else {
                    Button("Edit category budgets") { editing = MoneyPlanEdit(baseline: w, month: period.month, categoryOnly: true) }.buttonStyle(MoneyPrimaryButtonStyle())
                }
                MoneyBudgetConflictsSection()
                MoneyGoalsSection()
                Button("Ask Sprout") { onAsk("budget:\(period.month)") }
            }
        }.sheet(item: $editing) { edit in MoneyBudgetEditor(edit: edit).environmentObject(store) }
    }
}

private struct MoneyBudgetEditor: View {
    @EnvironmentObject private var store: MoneyStore
    @Environment(\.dismiss) private var dismiss
    let edit: MoneyPlanEdit
    @State private var monthly: String
    @State private var category: String
    @State private var categoryAmount: String
    @State private var error: String?

    init(edit: MoneyPlanEdit) {
        self.edit = edit
        let first = edit.baseline.budgets.first { $0.data.month == edit.month }
        _monthly = State(initialValue: edit.baseline.profile.monthlyTargetMinor.map { NSDecimalNumber(decimal: Decimal($0) / 100).stringValue } ?? "")
        _category = State(initialValue: first?.data.category ?? "Food")
        _categoryAmount = State(initialValue: first.map { NSDecimalNumber(decimal: Decimal($0.data.limit.minor) / 100).stringValue } ?? "")
    }

    var body: some View {
        NavigationStack { Form {
            if edit.categoryOnly {
                Section("Category budget · \(edit.month)") {
                    let saved = edit.baseline.budgets.filter { $0.data.month == edit.month }
                    if !saved.isEmpty {
                        NavigationLink("Choose a saved category") {
                            MoneySavedBudgetPicker(budgets: saved) { item in
                                category = item.data.category
                                categoryAmount = NSDecimalNumber(decimal: Decimal(item.data.limit.minor) / 100).stringValue
                            }
                        }
                    }
                    TextField("Category", text: $category)
                    TextField("Limit in USD", text: $categoryAmount).keyboardType(.decimalPad)
                    Text("This limit applies only to \(edit.month).").font(.caption)
                }
            } else {
                Section("Monthly spending target") { TextField("Your amount in USD", text: $monthly).keyboardType(.decimalPad); Text("This target applies to your ongoing monthly plan.").font(.caption) }
            }
            Text("If this plan changes on another device, Sprout will keep your edit for review.").font(.caption)
            if let error { Text(error).foregroundStyle(SproutColor.error) }
        }.navigationTitle(edit.categoryOnly ? "Category budget" : "Monthly target").toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
        } }
    }

    private func save() {
        do {
            if edit.categoryOnly {
                let name = category.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let minor = MoneyAmount.parse(categoryAmount), !name.isEmpty else { error = "Review the category and its limit."; return }
                let previous = edit.baseline.budgets.first { MoneyBudget.categoryKey($0.data.category) == MoneyBudget.categoryKey(name) && $0.data.month == edit.month }
                let id = previous?.id ?? UUID().uuidString.lowercased()
                try store.enqueue(["type": "budget.upsert", "budget": ["id": id, "category": previous?.data.category ?? name, "month": edit.month, "limit": ["minor": minor, "currency": "USD"]], "expectedVersion": previous?.version ?? 0], entity: "budget:\(id)")
            } else {
                guard let target = MoneyAmount.parse(monthly) else { error = "Enter your monthly target."; return }
                var profile = edit.baseline.profile
                profile.monthlyTargetMinor = target
                try store.saveProfile(profile, expectedVersion: edit.baseline.profileVersion)
            }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

private struct MoneySavedBudgetPicker: View {
    @Environment(\.dismiss) private var dismiss
    let budgets: [MoneyRecord<MoneyBudget>]
    let select: (MoneyRecord<MoneyBudget>) -> Void
    var body: some View {
        List(budgets) { item in
            Button { select(item); dismiss() } label: {
                HStack { Text(item.data.category); Spacer(); Text(item.data.limit.formatted).foregroundStyle(SproutColor.textSecondary).monospacedDigit() }
            }.accessibilityLabel(item.data.category).accessibilityValue(item.data.limit.formatted)
        }.navigationTitle("Saved categories")
    }
}
