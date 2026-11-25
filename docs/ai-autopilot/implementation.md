# Sprout AI money autopilot implementation

Approved direction: 2026-11-09. This replaces the earlier four-tab, narrow UI-refresh plan. **Implementation is in progress. The financial backend is deployed to staging with verified native manual-entry journeys; the complete product is not launch-ready.**

## Product and design decisions

Sprout watches your money, shows what is coming, and helps you take care of it. The complete product loop is observe → predict → explain → propose → approve → execute → verify. Users are US young professionals managing individual finances in USD. Bank access is read-only; merchant cancellation is a separate capability requiring specific approval.

Use the existing **Sprout Mobile** AIDesigner project `GxWskg4Eq62t` at `/Users/michaeldadi/AIDesigner/sprout`. Selected sources are B Living demo onboarding and B Insight first signed-in screens for each platform; C Dark mint contributes the dark palette. Do not create another exploration. [The manifest](../../design/aidesigner-manifest.json) records source frame IDs, revisions and hashes. [Semantic tokens](../../design/tokens.json) generate Swift asset colors and Kotlin roles with `node scripts/generate-design-tokens.mjs`.

Native implementation uses SwiftUI, SwiftData, Compose and Room. Navigation has stable identities: Home, Budget, Activity, Insights and Profile. Subscriptions belongs to Insights; Home-origin navigation returns to Home, while a cold notification starts in Insights. Preserve `/budget`, `/transaction`, and add `/subscriptions`, `/insights`, `/actions`, `/expense`. Activity retains filters and search when returning from detail. Native navigation supplies Liquid Glass on supported iOS versions; no glass simulation is drawn. Android pins Material 3 1.4.0 and uses composed controls where newer expressive APIs are unavailable.

Prototype values are never production defaults. “Safe to spend” becomes an eligible available-after-planned-bills forecast, otherwise remaining budget. “Saved balance” becomes connected cash balance with coverage and freshness. Do not infer usage from charges, guarantee prevention of a renewal charge, infer a trial end from missing history, invent supported institutions, or claim deletion completed merely because a request was accepted. Keep merchant facts consistent across platforms.

## Delivery state

The native finance and Appwrite implementation started in the isolated `codex/sprout-ai-native` worktree and was reconciled with the original UI worktree and current `main` for review. The earlier staging deployment used reviewed financial infrastructure and immutable function bundles. The existing daily seven-day financial backup was imported with its schedule and scope preserved. See the [validation record](validation.md) for the historical evidence and remaining release gates.

| Area                | Implemented source                                                                                                                                                                                                                           | Still required                                                                                                                                                                   |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Design handoff      | 24 selected B frames plus C references, hashes, generated semantic palette, shared fictional review data                                                                                                                                     | Per-frame native comparison, documented deltas, accessibility acceptance and wider-device review                                                                                 |
| Native shell        | Five destinations, onboarding checkpoints, Home/Budget/Activity/Insights/Profile and subscription/detail/expense presentations                                                                                                               | Full native navigation restoration, adaptive wide layouts, complete states and visual acceptance                                                                                 |
| Identity            | Appwrite email session and existing native Apple/Google ID-token exchange; owner/env-specific local stores                                                                                                                                   | Live OAuth enablement and device sign-in, signed-device acceptance and legacy identity migration                                     |
| Manual transactions | Integer cents, reviewed unified draft, persistent SwiftData/Room outboxes, incremental bounded cursor application, versioned conflicts and tombstones; live cross-platform edits, deletion and Android offline recovery passed               | Reviewed legacy Double/identity migration and remaining recovery permutations; native expense/goal conflicts and account switching passed                                                                   |
| Financial backend   | Seven deployed staging boundaries, runtime contracts, atomic receipts/change log, owner-bound queries, guarded transactions; live simultaneous same-mutation replay and expected-version concurrency proved                                  | Bank-history scale/load, monitored rollback and full release verification                                                                                                        |
| Bank integration    | Link/exchange API, quota reservation, encrypted credentials, verified raw-body webhook, full-cycle cursor restart, repeat-safe ingestion and pending replacement                                                                             | Authorized native Plaid sandbox end-to-end tests, ambiguous exchange recovery, account lifecycle and removed-account reconciliation                                              |
| Planning            | Category budgets, historical period projection, deterministic pace, coherent snapshots and virtual goal allocations; iOS to Android to iOS allocation edits passed                                                                           | User correction model, pending/manual duplicate review, forecast/scenario eligibility and held-out calibration                                                                   |
| AI                  | Bounded Responses tools, async jobs and foreground progress refresh, quota reservation, evidence rendering and persistent conversation result                                                                                                | Deferred OpenAI credentials, curated model evaluations, measured cost/latency, scenario/insight tools and optional evaluated escalation                                          |
| Cancellation        | Explicit proposal/approval contracts and review UI, exact evidence/version checks, closed provider adapter                                                                                                                                   | ScribeUp proof/terms/SDKs, five verified merchants, complete append-only lifecycle, interrupted partner flow, reconciliation and platform successes                              |
| Notifications       | Durable reminder rule/job, deduplication/leases, superseded-evidence check, discreet OneSignal acceptance                                                                                                                                    | Material price/budget/forecast alerts, device/provider identity and delivery callbacks; first-party weekly review passed, external delivery remains deferred                             |
| Capture             | Typed, voice, scan and shortcut inputs produce reviewed drafts; bounded orientation-aware OCR, reviewed total/merchant/date suggestions, explicit-amount ambiguity checks, shared receipt and shortcut fixtures and native reviewed URL-entry saves passed                                                         | complete physical camera/permission acceptance and actual signed-device Siri invocation                                        |
| Membership          | Verified RevenueCat webhook projection; server-side allowances                                                                                                                                                                               | RevenueCat account identity, purchase/restore/paywall, downgrade connection choice, out-of-order reconciliation and refund tests                                                 |
| Privacy             | Native private export download/share preparation; checkpointed first-party erasure with separate receipt progress, disabled anonymous Auth reservation and independent restoration ledger; server erasure and isolated restore proofs passed | Both native confirmation, owner-local cleanup, receipt restoration and return to Welcome passed; deferred provider/analytics cleanup and remaining privacy recovery permutations |
| Operations          | Staging financial IaC, reused daily seven-day backup, seven deployed bundles, checked source/bundle manifests, isolated restore proof and CI source; legacy AWS deployment manual-only                                                       | Final full-root drift check after the latest changes, hosted CI, operational alerting/load/cost and tested rollback                                                              |

Michael confirmed on November 9, 2026 that cancellation partner onboarding is still needed and no approved sandbox is available yet. Vendor access is an external dependency for the ScribeUp-first proof, with Knot as fallback.

Cancellation remains disabled and unsupported until partner onboarding. First-party erasure can complete for an account without provider dependencies; deferred provider cleanup enters `needs_attention` with an explicit checklist. Do not advertise end-to-end provider deletion until those integrations are validated.

## Contracts and infrastructure

The `/v1` API is executed as the authenticated `sprout-api` Appwrite Function. It derives identity from Appwrite, validates all commands, and never trusts an owner supplied by the client. The expected-account header/body marker additionally prevents account-switch races; bootstrap identity is checked before local cache writes. [OpenAPI](../../services/contracts/openapi.json) documents request surfaces; response schemas and native cursor application remain incomplete. Provider secrets stay in Functions. Operational provider credentials and webhook receipts are server-only; financial rows have no broad table grants and read permission only for the verified owner.

Financial POSTs are disabled by default behind `SPROUT_FINANCIAL_WRITES` until actual TablesDB concurrency and two-device isolation pass. Job bookkeeping uses a separately deletion-tolerant store; bank and AI canonical writes still participate in the deletion lock. In-flight notification acceptance is preserved as evidence and submitted-action reconciliation remains possible. Snapshot time and provider retrieval time are never substituted for an unknown institution source timestamp.

| Function            | Responsibility                                                                                 |
| ------------------- | ---------------------------------------------------------------------------------------------- |
| `sprout-api`        | Bootstrap, changes, mutations, onboarding, provider session initiation, async request creation |
| `sprout-webhooks`   | Verify provider authorization/signatures, accept durable receipts, enqueue work                |
| `sprout-worker`     | Bank cycles, derived work, notification attempts, action reconciliation boundary               |
| `sprout-ai`         | Bounded OpenAI requests and application tools, persistent answer result                        |
| `sprout-dispatcher` | Five-minute recovery sweep, private async dispatch of due jobs                                 |
| `sprout-privacy`    | Private export and separately scoped deletion workflow                                         |

The initial physical records use a versioned JSON envelope plus owner, entity ID, version, updated-at and tombstone. Jobs additionally index state/due time and connections index provider reference. This is a flexible first slice, not a proven high-volume financial query schema. Before beta, replace full-account scans where needed with indexed financial columns, stable pagination and bounded snapshot projections. All canonical writers must use the same per-user sync-head transaction guard. A unit-memory test is not proof of TablesDB concurrency.

Mutation commits include canonical records, a durable receipt and ordered change-log entry. A duplicate retry with identical content returns the original result; reused IDs with changed content are rejected. Server versions govern conflicts. Native caches/outboxes are partitioned by endpoint, project and user; local stores are separate v1 stores so legacy data remains recoverable. Native refresh uses signed account-bound cursors and fixed-revision pages. Both clients accumulate pages privately, then save the coherent projection, canonical transactions, cursor and acknowledged-outbox removals together. Invalid/expired cursors rebootstrap without dropping pending edits. Workspace projection version 3 supplies an owner-only Appwrite revision channel. Native foreground subscriptions debounce signals and retrieve facts through cursor sync; a five-minute foreground timer recovers missed signals and refreshes time-dependent projections. Both native delivery tests passed, including iOS 18.5 on a small iPhone. Swift refresh coalesces in-flight requests; Android separates sync serialization from short local-write locks so network calls cannot block saving an expense. Full legacy identity/Double-data migration acceptance remains open.

Manual expense edits reuse the reviewed draft, pin the server version at editor opening and keep source, account, date and exclusions. Delete confirmation also pins the reviewed version. Android schedules post-save sync from the surviving navigation scope so dismissing an editor does not cancel the upload attempt. Onboarding review restores confirmed choices; explicit local changes drive the same selection, total and CTA state. Cross-device interruption and partial-confirmation acceptance are still release gates.

Home values use one snapshot revision. Connected cash is the sum of included USD depository-account current balances, not net worth or savings. Spending excludes transfers and pending holds and nets explicit refunds. Recurrence requires at least three eligible charges, keeps evidence and cadence, and distinguishes inferred/confirmed/dismissed decisions. Forecast code excludes scheduled historical charges from variable spending and stays hidden until coverage, freshness and calibration gates pass. A narrow schedule-only projection may precede the eight-week full baseline.

OpenAI uses `store:false`, which alone does not provide Zero Data Retention. The first adapter uses `gpt-6-luna` unless an explicitly evaluated server configuration selects another model. It can retrieve bounded context, search transactions and create a proposal. It cannot approve, execute, access a shell, use arbitrary network tools, read credentials or query unrestricted tables. Model-selected evidence IDs and an explanation template are validated; financial values are rendered by application code. Do not widen model tools or enable costly escalation without evaluations and budget measurements.

Plaid exchanges are one-use operations. If a response is lost before credential custody is durable, preserve the exchanging reservation and require recovery; never repeatedly exchange a public token. A complete `/transactions/sync` pagination cycle is fetched before applying batches. The cursor is committed only after all batches; importing state remains visible meanwhile. Replay IDs and provider IDs prevent duplicate canonical facts. Uncertain connection recovery and concurrent cycles still need live validation.

## Required screen journeys

1. Welcome authenticates or restores the Appwrite account using truthful terms/privacy destinations.
2. Connect bank distinguishes token exchange from historical import, supports Skip and repair, and enforces the Item allowance.
3. Subscriptions found persists review decisions and derives selected count, total and CTA from the same state. Confirmation tracks a charge pattern; it authorizes no external action.
4. Your plan saves an explicitly chosen target and monitoring preferences. Do not silently apply a sample preset.
5. Home leads with one scoped amount, insight, category pace and Activity, and links renewal summaries into canonical Subscriptions.
6. Budget supports periods, edits, deterministic pace and virtual goal allocations, with incomplete-data states.
7. Activity provides local transactions, search/filter restoration, detail, retry and conflict recovery with stable IDs.
8. Subscriptions separates normalized monthly cost, actual charge cadence, next-date confidence, user trial dates and reminder state.
9. Detail shows actual evidence/history and separate reminder/cancellation paths. Usage is a user answer, never an inference from bank data.
10. Insights provides feed feedback, persistent contextual chat, evidence navigation, usage limits and async progress/history.
11. Add expense unifies type, voice, scan and shortcut inputs into review → local save → outbox → server acknowledgement. Ambiguous totals cannot auto-save; raw audio is not retained.
12. Profile reflects actual identity, accounts versus connections, membership, device-local lock, appearance, support and trackable privacy jobs.

All journeys need relevant loading, empty, stale, offline, failure and recovery presentations. Add matching operational screens for transaction detail, denied permissions, connection repair, action approval/result, paywall and privacy progress. Native controls must remain reachable above navigation, sheets and keyboards. Test small phones, wider layouts, large text, VoiceOver/TalkBack, contrast, reduced motion/transparency and Android Back.

## Milestones and release gates

| Phase                        | Exit condition                                                                                                 |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------- |
| 0 — Freeze/prove feasibility | Selected frame traceability, build baseline, legacy inventory, credible cancellation terms and beta budget     |
| 1 — Native/Appwrite core     | Both native shells and authenticated two-device manual financial slice pass with recoverable migration         |
| 2 — Onboarding/finance       | Resumable setup, native Plaid, complete ingestion, candidate review and reconciling totals                     |
| 3 — Home/planning            | Coherent snapshots, editable budgets, virtual goals, validated eligible forecasts and subscription evidence    |
| 4 — Insights/automation      | Bounded evaluated AI, durable reminders, approvals, actual partner cancellation and uncertain-outcome recovery |
| 5 — Launch completeness      | Unified capture/shortcuts, real membership/profile/privacy, full native/accessibility acceptance               |
| 6 — Controlled beta          | Advance roughly 10 → 25 → 100 users based on correctness, outcomes, retention and measured spend               |

The approved estimate remains about 20–28 founder engineering weeks, conditional on Phase 0. Partner onboarding can extend elapsed time. No phase is complete merely because its UI compiles.

Public launch requires both authenticated platforms passing; accepted native evidence for every selected type; no known record loss or financial double-counting defect; isolation/repeat-submission checks; forecast improvement over a held-out baseline; zero unsupported numerical claims in the curated AI release set; five named merchants with verified coverage; two authorized cancellation successes per platform; unknown-outcome recovery; export/deletion/restoration proof; measured operating cost within the ceiling; and accurate claims/disclosures.

Use separate server flags for linking, forecasts, AI, notifications, scanning assistance and new cancellations. Disabling new actions must preserve reconciliation of already submitted work. Prioritize privacy and submitted-action recovery over growth work when spend is constrained. Targets: useful cached screens within one second, typical backend reads under two seconds p95 at beta load, persistent progress for longer operations.

## Economics and measurement

Free: manual entry/import, basic budgets/history/export, one live Plaid Item, recurring list/reminders and on-device capture. Plus: initially up to three Items, forecasts/scenarios, bounded AI and supported cancellation. Initial allowances are thirty AI requests and three new cancellation attempts monthly; free AI has a small preview. Preserve records on downgrade and reconcile already-submitted actions; let the user choose which connection stays live.

The $500/month allocation is $75 Appwrite/storage/backups, $75 OpenAI, $50 monitoring/delivery, $100 Plaid, $150 cancellation partner and $50 contingency. These are allocations, not quotes. Test $9.99/month or $79.99/year only after vendor terms and contribution margin are known. Limit invites, Items, model calls and duplicate jobs; use cached summaries and on-device extraction.

Measure time to useful insight, setup/import success, insight acceptance/correction, cancellation completion/time, forecast accuracy, weekly verified useful outcomes, week-one/month-one retention, conversion/churn, notification opt-outs and cost per connected/paid user. Use one analytics destination and an allowlist; never send amounts, merchant names, account IDs, raw URLs, transcripts or receipt text.

Transfers, investments, shared households, autonomous negotiation and standing external-action mandates remain outside this release.

## Reproducible local checks

```sh
yarn install --immutable
node scripts/generate-design-tokens.mjs --check
node scripts/verify-design-manifest.mjs
yarn workspace @sprout/services generate --check
yarn workspace @sprout/services build
yarn workspace @sprout/services test
yarn workspace @sprout/services bundle
terraform -chdir=infra/appwrite fmt -recursive -check
terraform -chdir=infra/appwrite init -backend=false -input=false
terraform -chdir=infra/appwrite validate
```

Android requires a configured Android SDK and supported JDK (local checks use JDK 21). Run `:app:assembleDebug :app:testDebugUnitTest` from `apps/android`. iOS uses scheme `Sprout CI`; run `MoneyDomainTests` and `MoneyDesignAcceptanceTests` on a supported simulator. Review fixtures are explicitly fictional and read-only, available only through Debug entrypoints. Acceptance results and remaining gates are recorded in [validation.md](validation.md).

## Privacy restoration decision and verified scope

First-party erasure retains a disabled anonymous Appwrite Auth ID and an independently stored privacy ledger. Hard-deleting that Auth ID would allow a new account to register the same identifier and inherit permissions from an old restored financial row. The privacy ledger has no client grants; its high-entropy receipt endpoint returns progress without identity or financial facts. It survives financial database restoration, blocks late writers and supports recovery after the financial job is purged. Provider-dependent cleanup enters an explicit attention state; it never claims full erasure while external work remains.

A dedicated synthetic account passed financial/sync-row removal, private attachment removal, identity anonymization, session revocation, duplicate-ID denial and unrelated-account preservation. Its pre-erasure financial snapshot was restored into a separate, quarantined database and filtered against the independent ledger. Neither native app was pointed at the restored database. The manual archive and disabled validation clone were removed after proof; the existing daily seven-day policy was preserved. See the sanitized validation evidence for the actual boundary; this is not a claim that every provider or backup permutation has passed.

App Intent implementation uses the system authenticated intent and a protected App Group handoff to the normal draft editor. Apple's [OpenURLIntent documentation](https://developer.apple.com/documentation/appintents/openurlintent) limits that intent to universal links; the custom `sprout://expense` route is validated independently. Actual Siri invocation and signed-device capability acceptance remain distinct from native URL entry.

Monthly category budgets enforce logical uniqueness inside the same per-user transaction guard, including simultaneous offline creations with different client IDs. Category matching trims whitespace and normalizes case for spending calculations. The live race proof confirms one saved budget and one explicit conflict.

Deletion revokes first-party access before evaluating deferred provider cleanup. Records needed for vendor recovery are retained when cleanup requires attention. API requests reject new provider-session work before making provider calls, in addition to guarded canonical writes.

Budget editors capture the reviewed workspace version and submit one category or monthly-target command per save. Historical limits can be edited without changing the ongoing target. The iOS saved-category list uses native navigation and displays each stored amount. A shared generated analytics policy limits both event names and string values; unknown names, financial fields, raw errors, URLs, profile properties and identifiers do not reach the analytics destination. Named SDK storage keeps legacy queued events separate. Automatic Firebase, Facebook and AppsFlyer analytics initialization is disabled in the active app path; delivery remains off in Debug builds. See [Mixpanel's native API](https://mixpanel.github.io/mixpanel-swift/Classes/MixpanelInstance.html) and [Firebase collection controls](https://firebase.google.com/docs/analytics/ios/configure-data-collection?platform=ios).

An unreadable iOS deletion receipt hides financial screens until it can be reopened. Missing receipts and unavailable or corrupt receipts have separate behavior; clearing a completed receipt requires successful Keychain deletion.


Capture amount interpretation uses one portable rule set with shared native/backend fixtures. A regression showed `$1,234.56` could be truncated to `$1`; grouped values now normalize as exact cents. Numeric dollar-and-cent phrases are combined, while corrections, ranges, unit prices and unsupported currency/direction remain for explicit review. The live staging API passed all 31 cases; parsing never saves a transaction.


Release acceptance now distinguishes packaging from runtime proof. Both native Release apps completed normal authenticated expense entry against staging and independent readback; the installed iOS binary hash matched the Release artifact. Android release testing runs from an independent UI Automator app so optimizer behavior is tested without retaining test-only libraries in the shipping app. Native hardware/store acceptance and the rest of the launch gates remain open.

Reviewed CSV import now runs through both native review implementations and persistent Appwrite jobs. Batches preserve existing records and intentional deletions, retain bounded server-only input parts, and checkpoint facts with progress. Android native acceptance and the separate live checkpoint/isolation proof passed; iOS native acceptance also passed. Twenty shared parser cases cover quoted and multiline fields, UTF-8, explicit sign/currency/date validation and duplicates. Legacy store ownership and Double conversion remain separate: the configured Cognito pool JWKS endpoint returned HTTP 404 on November 10. Preserve source stores and require authoritative prior-owner verification before exposing or uploading their financial rows.


Opt-in receipt retention now uses one compressed JPEG (at most 650 KB) in a protected, owner/environment-partitioned native file outbox. Replay records contain a file reference and hash, not base64. File creation uses the existing private-data function; server-only reservations, bounded IO leases, recovery jobs and cancellation tombstones protect retry, removal and account erasure. Live staging proved real-image hash readback, peer/anonymous/direct-function denial, replay and authoritative file removal. Native system-picker, extraction, opt-in, private preview and removal passed on both platforms. Overlapping export/upload/deletion recovery passed independent zero-row, zero-file and disabled-account readback. Beta retention limits are 100 copies and 50 MB per account; on-device OCR remains usable without opting in.


Exports use immutable job snapshots. Active concurrent requests may coalesce; a new request after completion creates a new snapshot. Staging verifies actual file bytes and records their checksum, size and revision, including recovery from an already-created file. Native ZIP assembly includes ready retained copies without creating a second server-side image archive; a missing or changed image requires retry or a fresh export. Native archive acceptance passed on both platforms with independent JSON, image, checksum, size and CRC readback. Quiet-hour/timezone preference editing passed native saves on iOS and Android, with unchanged unrelated profile fields and financial facts; the final iOS readback also passed.


Expense and goal conflicts now passed independent native acceptance on both platforms. A competing authenticated client commits while the editor remains open; restoration preserves the original draft, explicit review displays both amounts, and approval updates only the reviewed server version. Canonical readback verifies exactly one record and unchanged unrelated facts. Android visual captures were refreshed and inspected after waiting for window transitions and rejecting System UI stalls.

Weekly review is a deterministic first-party artifact, not an AI numerical prediction. A manual Feed action queues durable work without opting into notifications. Automatic weekly scheduling respects the account timezone, quiet hours and opt-out; incomplete ingestion delays preparation, expired weeks do not fan out, and a provider pause preserves retry capacity. Saved reviews retain their original evidence and preparation date. The current backend passes 148 tests; staging deployment is active, native acceptance passed on both platforms with independent arithmetic, restoration and unchanged financial/opt-in state. External notification delivery stays disabled.


Account security uses credential-aware native controls. A short-lived JWT is verified against the expected Appwrite user through an isolated cookie-free transport before a password update; another app session cannot retarget that request. Redirects are disabled, passwords stay out of the financial outbox and analytics, and transport failures do not imply a completed change. The iOS native proof passed wrong-password rejection, a confirmed update, fresh sign-in, rejected old credentials and roundtrip account isolation with unchanged financial data. Android acceptance also passed, followed by live private-channel Realtime validation. The SDK revocation error is contained by a bounded revision-signal listener that never treats event payloads as financial records. See [Appwrite JWT permissions](https://appwrite.io/docs/products/auth/jwt) and [Account endpoints](https://appwrite.io/docs/references/cloud/client-apple/account).

The active Profile now has a support presentation using the existing configured support email. It leaves chat gated until an authenticated support-identity path is available; existing Zendesk integration code is preserved. No support message is sent automatically.


The forecast helper now requires an explicit server observation time and continuous cash-account history coverage. Invalid, future or stale balance observations fail closed; first/last charge dates cannot establish eight weeks of coverage. Cash scope excludes credit purchases, and supplied card-payment commitments affect cash once. This remains an uncalibrated, disabled helper; a connected forecast API/UI and held-out acceptance are not established by its domain tests.

A bounded staging read benchmark passed forty bootstrap reads at four concurrent requests across two isolated synthetic accounts: server p95 1.339 seconds, client p95 1.565 seconds, with unchanged financial data and preferences. This is separate from bank-history scale and a hundred-user cohort. JPEG-only storage recovery passed exact-byte readback in a disabled isolated bucket, followed by verified cleanup. Mixed JSON/JPEG archival failed inside Appwrite migration while decoding JSON files; full mixed-storage recovery remains open. Restoration also ignored the requested storage destination ID and generated another bucket ID, which was independently discovered before verification and cleanup.


The compatible staging API rollback drill passed against immutable source hashes: activate the reviewed earlier API deployment, verify isolated account reads and unchanged financial state, restore the expected current deployment, and verify it again. It performs no schema or financial writes. `scripts/validate-live-rollback.ts` checks the expected active version immediately before activation and refuses to overwrite an unexpected concurrent deployment. Appwrite has no activation compare-and-swap in this path, so other deployers must stay quiescent. Schema, worker and production rollback remain separate gates.
