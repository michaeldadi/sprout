# Sprout native UI refresh: implementation plan

Status: **Android Activity and Home committed; iOS reviewed in an isolated native fixture; full-app gates still open**, updated 2026-11-09 (America/New_York). [Design contract](design-contract.md), [audit](audit.md), and [brief](brief.md) define scope and evidence. This plan preserves the current SwiftUI/Compose architecture, auth, persistence, services, deep links and unrelated dirty work. The implementation record below is separate from the remaining phase gates. Android source is in commit `1d9a480`; the iOS source and its prerequisite app reorganization remain in the local working tree.

## Evidence rules and baseline

- Compare before/after using the same fictional, deterministic fixture; record commit/worktree state, device and OS, window size, theme, text scale, locale, time zone, fixed date/time, and data source. Put review captures under `artifacts/ui-refresh/` without staging unrelated files. Never use production accounts, real bank linking, or real merchant cancellation to create screenshots.
- The linked captures under `artifacts/ui-refresh/` are intentionally ignored local evidence; those relative links do not resolve in a fresh remote checkout.
- Current **observed native before**: Android login, empty-submit validation, sign-up, forgot password, dark mode, and 1.3× text captures listed in `audit.md`. Current **source-only before**: iOS Home/Activity/Budget placeholders and Android authenticated welcome placeholder, iOS merchant recurring comment-only view, no Android subscription route. The four root `sprout-*.png` files are reference art only. Do not present their values as app data or label them after-captures.
- First evidence gate: safe authenticated fixture entry and the existing build failures. The audit records iOS failure in pinned Stream Swift/RevenueCat dependencies, Android build success on JBR 21, and 27/37 failing Android unit tests. Resolve and record the narrow cause before claiming native visual parity; preserve pre-existing staged/unstaged changes. Do not weaken financial or auth tests to obtain screenshots.
- Every phase ends with a source diff, a route/callback check, paired iOS/Android captures when both can run, and explicit remaining source versus runtime gaps. An attractive static frame is not a passed functional journey.

## Ordered phases

### 1. Foundations — one semantic layer per platform

**Bounds:** define semantic light/dark roles, type/number formatting, spacing and feedback primitives in existing theme locations. Add a safe, opt-in fictional fixture path for local/debug previews and tests only. Resolve the iOS dependency build blocker and establish a reproducible Android JBR 21 test baseline. Do not redesign all screens or introduce a new navigation framework.

**Current files/routes:** iOS `Resources/Assets.xcassets/AccentColor.colorset/Contents.json`, `Features/Root/{RootView,MainTabView,CustomTabBarView,Tab}.swift`, `Features/Authentication/{LoginView,SignUpView,ForgotPasswordView,VerificationView}.swift`, `Shared/Components/{LoadingModal,ToastView,FloatingCirclesView}.swift`; Android `ui/theme/{Color,Theme,Type}.kt`, `ui/screens/{Login,SignUp,ForgotPassword,Verification}Screen.kt`, `ui/components/{SocialLoginButton,FloatingCirclesBackground}.kt`, `MainActivity.kt`, `navigation/AuthNavigation.kt`. Paths here are relative to the respective iOS `apps/ios/Sprout/` or Android `apps/android/app/src/main/java/com/michaeldadi/sprout/` roots.

**Before → after evidence:** compare the audit's Android auth captures and source-local colors with native light/dark auth captures using semantic roles; capture iOS auth only after its build succeeds. Record theme role values and contrast on actual surfaces. Fixture entry must visibly identify demo data in review metadata and never ship enabled in production.

**Regression checks:** auth login/sign-up/verification/reset callbacks; no real request in fixture tests; iOS pending deep link after auth; Android auth graph/back; local unit tests at current failing baseline then relevant targeted tests; VoiceOver/TalkBack form labels, 1.3×/2.0× text, dark, IME and reduced motion. Track existing unrelated test failures separately.

**Gate:** both debug apps build in a recorded environment; deterministic fixture is safe and repeatable; semantic roles render in auth without clipping; no second theme system is introduced.

### 2. First complete journey on **both** platforms — Activity → transaction detail → return

**Bounds:** one implemented, source-backed transaction list and detail with empty/loading/partial/error states, filter/search and route restoration. A new-account fixture may be empty; a populated fictional fixture must show income, expense, transfer and sync variants. Do not add net-worth or unverified spend calculations. Keep transaction repositories and data contracts; connect native presentation through current app shells.

**Current files/routes:** iOS `Features/Root/{MainTabView,Tab,CustomTabBarView}.swift`, `Features/Transactions/{TransactionsView,AccountHistoryOverview}.swift`, `Core/Managers/DeepLinkManager.swift`, `Core/Data/Models/Shared/{Transaction,Currency}.swift`. Android `MainActivity.kt` `MainAppContent`, `navigation/AuthNavigation.kt`, `data/entities/TransactionEntity.kt`, `data/repository/TransactionRepository.kt`, `network/models/NetworkModels.kt`; add one authenticated Compose route host under the existing app gate.

**Before → after evidence:** source-only iOS `Text("Transactions View")` and Android centered welcome versus native Activity list/detail on the same fixture, both themes and a large text setting. Capture selected bottom navigation, search/filter scope and count, detail amount/date/source, pending/failed sync, new-account empty, loading and retry. Show iOS and Android as distinct native frames; label fixture data.

**Regression checks:** amount sign/currency/date formatting and transfer semantics; list/detail ID resolution; filter retained on back; iOS `/transaction?id=` after auth opens the correct detail and `/support` still opens support, `/budget` still opens Budget; Android auth-to-main transition/back; offline/sync error behavior; screen reader row and chart-free summary. Preserve existing URL paths and data schemas.

**Gate:** one user can start in the authenticated shell, find a fictional transaction, open its detail, understand its true state, return to the same list, and recover from empty/error on iOS and Android. Both platforms build, targeted tests pass, and paired native captures exist. Any unsupported network path is explicitly labeled.

### 3. Remaining journeys — narrow slices, each with its own gate

Work in the order below. A slice is complete only on **both** platforms before the next begins; each source-backed view uses the contract's state and label rules.

| Slice and bound | Current routes/components | Before → after evidence | Regression and completion gate |
| --- | --- | --- | --- |
| **Home orientation:** scoped summary or honest empty state, one next action; no synthetic net worth/trend. | iOS `Features/Dashboard/DashboardView.swift` via `MainTabView.swift`; Android `MainActivity.kt` `MainAppContent`. | Placeholder source versus native Home light/dark, new-account and populated fixture. | Values trace to source and period; account privacy, freshness and navigation tested. Gate: Home leads to the first Activity journey without changing auth state. |
| **Budget/goal:** only existing verified budget/goal data and operations; otherwise useful empty state. | iOS `Features/Budget/{BudgetView,BudgetGoalsView}.swift`, `Tab.swift`, `DeepLinkManager.swift`; Android new destination within `MainAppContent`. | Source placeholder versus native budget/goal state with valid target fixture or honest unavailable state. | Goal numerator/denominator/period, over-target text, deep link `/budget`, large-text progress semantics. Gate: no invented percentage or action. |
| **Recurring merchant payments:** list/detail and confirmed versus possible recurrence; no cancellation until an actual supported operation and readback exist. | iOS `Features/Transactions/RecurringTransactionsView.swift`; Android new destination within `MainAppContent`; existing transaction `isRecurring` fields. | Comment-only/no route versus native list/detail with cadence/source/unknown state. | Inference label, next-date provenance, no fake success timeline, screen reader state. Gate: app-plan billing and merchant recurrence are separate. |
| **Sprout plan, profile and recovery:** show only verified entitlement and working management destinations; fix misleading mock/no-op controls. | iOS `Features/Profile/ProfileView.swift` and `Features/Settings/{SettingsView,SubscriptionSettingsView,NotificationSettingsView,AccountSettingsView,DeleteAccountView}.swift`; Android authenticated profile/settings destination and RevenueCat initialization in `SproutApplication.kt`. | Current iOS mock Premium and settings sheets/Android no route versus honest native settings and recovery states. | Purchase/restore/cancel semantics, persistence of notification preferences or clearly unavailable controls, sign-out/delete confirmations, back/sheet focus. Gate: no control claims completion when it only logs or opens a store. |

The slices do not authorize a new merchant-cancellation integration, billing purchase path, Plaid linking, or notification delivery backend. If one lacks a verified contract, ship the truthful unavailable/empty presentation and record the functional dependency separately.

### 4. Craft pass — consistency without a second system

**Bounds:** refine hierarchy, spacing, icons, native surfaces, text scaling, accessibility and restrained motion across completed routes. Consolidate duplicate auth fields, buttons and settings rows only after all their consumers use the semantic family. Remove temporary wrappers, starter purple tokens and obsolete decorative motion after call-site verification.

**Current files/routes:** iOS `Features/Authentication/*`, `Features/Root/{CustomTabBarView,SplashScreenView,RootView}.swift`, `Features/Settings/SettingsView.swift`, `Shared/Components/*`; Android `ui/theme/*`, `ui/screens/*`, `ui/components/*` and XML themes. This phase may choose native `TabView`/Material adaptive navigation if route parity is proved, while preserving the existing owners.

**Before → after evidence:** paired screen grids across iOS/Android, light/dark, default/accessibility text, compact/expanded width; annotate only measurable changes such as row count, contrast, clipping and task completion. Reference PNGs remain visual direction, never before captures.

**Regression checks:** exact action labels and destinations, deep links, auth and settings persistence, VoiceOver/TalkBack order and focus, reduced motion, touch targets, chart accessible summaries, locale/currency, window resize and rotation. Search for all old wrappers and hard-coded legacy colors before deletion.

**Gate:** no permanent parallel theme, field, button or row families; no clipped essential content at supported sizes; all completed journeys keep their prior gates.

### 5. Acceptance — evidence and sign-off

**Bounds:** review the [representative frame set](design-contract.md#representative-frames-for-approval) against actual native builds and the approved composition. Run journey, state, accessibility and platform-difference acceptance; do not expand functionality during this phase.

**Current routes:** iOS `RootView/MainTabView` plus auth, Home, Transactions/detail, Budget/Goals, recurring and Settings destinations; Android `SproutApp/AuthNavigation/MainAppContent` plus the corresponding authenticated routes.

**Before → after evidence:** one indexed capture set per platform with fixture version, build SHA/worktree diff, device/OS, viewport, theme, text scale, locale/time zone, data age and action outcome. Include source-only baseline limitations and list unresolved data/service gates. Record a task walkthrough for the first complete Activity journey on both platforms.

**Regression checks:** builds, relevant unit/UI tests, deep links, sign-in/out, navigation/back, value formatting and source trace, empty/loading/error/offline, accessibility, reduced motion and resize. Confirm no production fixture flag or secrets enter release artifacts.

**Gate:** reviewer can identify what is implemented, what is only designed, and what is blocked; representative native frames and both-platform journey evidence pass the contract. Approval is explicit before release or further scope.

## Infrastructure decision

Use hand-maintained semantic roles in the existing SwiftUI asset catalog and Compose Material theme for the first journey. Token generation adds a build and synchronization surface before there are stable repeated roles; Code Connect adds mapping maintenance before an approved Figma library and native components exist. Reconsider either only after at least two implemented journeys show repeated cross-platform drift, and record the measurable benefit and migration cost. Neither is a prerequisite or completion gate here.

## Foundations implementation record — 2026-11-08

Branch: `codex/sprout-ui-foundations`. The repository already had roughly 250 staged and unstaged changes before this phase; they were preserved. No commit or feature journey migration was made. All fixture data below is fictional, date fixed in review UI to 8 Nov 2026, currency USD, with no account or network connection.

### Implemented

- Android: semantic light/dark roles in `ui/theme/{Color,Theme,Type,Spacing}.kt`, complete Material surface roles, and matching XML window colors/themes. Starter purple from Material defaults was removed from the review switch by specifying container roles. The `MainActivity` auth gate, routes, ViewModels, persistence, network code, and callbacks were not edited.
- iOS: light/dark semantic asset colors and AccentColor, `Shared/Design/SproutTheme.swift`, and app-level tint. `SocialLoginButton` moved from `LoginView.swift` into `Shared/Components/` without changing its call-site parameters. Existing toast colors and surface now use semantic roles; floating circles respect Reduce Motion; loading modal uses semantic progress/separator treatment.
- Both platforms: native shared amount, action, transaction row, input, banner, and empty/loading state components. Rows stack the amount below long labels to avoid collisions and show unknown as “Amount unavailable.” Selection, busy, disabled, error, warning, and destructive variants are represented. These display components do not own finance calculations, authentication, navigation, or persistence.
- Final review corrections: disabled/loading actions now retain readable semantic foregrounds; the iOS unknown-amount row is a readable noninteractive display instead of a dimmed disabled button. Amount display no longer caps fractional digits at four on iOS or at the currency default on Android. Android `BigDecimal` scale is retained; the current iOS `Decimal` value does not preserve source trailing-zero precision metadata.
- The Android review activity exists only in `src/debug`; the iOS `FoundationReviewView` is `#if DEBUG` and its isolated `FoundationReviewHost` compiles the actual Sprout component source and assets. Neither review entry mounts an auth or financial service. Generated host project/Info.plist and captured images are ignored.

### Native review and commands

| Check | Result |
| --- | --- |
| `xcodegen -s project.yml` in `apps/ios/FoundationReviewHost`, then `xcodebuild -project FoundationReviewHost.xcodeproj -scheme FoundationReviewHost -configuration Debug -destination 'platform=iOS Simulator,id=AE9767BE-CAA3-4000-837B-8666AA6E20D6' -derivedDataPath /tmp/sprout-foundation-review-ios-derived CODE_SIGNING_ALLOWED=NO build` | Built with Xcode 27.2; installed/launched on iPhone 17 Pro, iOS 26.4. The final `maestro --udid AE9767BE-CAA3-4000-837B-8666AA6E20D6 test /tmp/sprout-foundations-ios-flow.yaml` passed launch, selection, scroll, and inline-error checks after button styling changed. The coordinate dark-mode flow also passed. |
| `JAVA_HOME='/Users/michaeldadi/Library/Java/JavaVirtualMachines/jbr-21.0.9/Contents/Home' ./gradlew :app:assembleDebug` in `apps/android`, then `adb install -r .../app-debug.apk` and `adb shell am start -n com.michaeldadi.sprout/.ui.review.FoundationReviewActivity` | APK built and review launched on API 37 emulator at 1080×2400. `adb` interaction changed “Selected: no” to “Selected: yes” and switched to dark mode. |
| `JAVA_HOME=... ./gradlew :app:assembleDebug :app:testDebugUnitTest` and final `:app:testDebugUnitTest` | APK assembled; existing JVM suite remains 27 failures of 37, the same count as the pre-edit baseline and the final rerun. Failures are in Apple, Auth, and Google sign-in tests, outside changed presentation code. |

Review images in ignored `artifacts/ui-refresh/foundations/`: `ios-review-light-default.png`, `ios-review-light-rows.png`, `ios-review-dark-top.png`, `ios-review-light-accessibility-large.png`, `ios-review-light-accessibility-large-rows.png`, `android-review-light-default.png`, `android-review-dark-selected.png`, `android-review-light-2x.png`, and `android-review-light-2x-rows.png`. Captures show actual native controls and the same review fixture. iOS system text was set to Accessibility Large; Android font scale was set to 2.0 for the large-text captures. Both settings were returned to defaults after review. The final iOS large-text `maestro` `scrollUntilVisible` assertion did not match the visually present heading; the resulting row image was inspected directly and is not counted as an automated pass.

### Compatibility and open gate

- Android `MainActivity` login was launched and captured in light and dark after the global theme update (`android-main-login-after-theme.png`, `android-main-login-dark-after-theme.png`). Its green auth layout remains visually consistent with the baseline and retains hard-coded local styling; it has not yet adopted the semantic canvas. This is a documented legacy area, not approval to copy its styling to new screens. Sign-up, reset, verification, and authenticated placeholder were not exhaustively reviewed after the theme change.
- The normal iOS app build still fails before Sprout source compilation in the pinned StreamCore dependency at `Sort.swift:153` under Xcode 27.2. The isolated host proves the changed shared SwiftUI components compile and run, but not `SproutApp` bootstrap, auth/deep links, or full-app visual compatibility. The prior Swift 5 override diagnostic also failed later in RevenueCat. Do not claim the full iOS app is green.
- No real account linking, merchant cancellation, payment, or production data was used. VoiceOver/TalkBack, reduced-motion runtime, iPad/expanded-width, 320 dp, and full auth callback tests remain unchecked. No feature screen is using the new finance components yet.
- Additional corrections came from the final native review: explicit readable disabled/loading action colors, an undimmed noninteractive unknown-amount row on iOS, and source-precision amount display. Review screenshots were refreshed after these changes. The Android review button changed from “Selected: no” to “Selected: yes” through `adb` after the final install.
- A local Foundation formatter smoke check printed `$12.3456` for both the Swift `Decimal` and Java `BigDecimal` algorithms (Swift also printed `¥12.3456` when the fictional JPY source carried four fractional digits). This checks the formatter rule, not the app's API or persistence path.
- **Phase 1 gate remains open** until the full iOS debug app builds, the four auth screens are migrated or explicitly exempted with native evidence, app-wide light/dark and large-text regressions are reviewed, and relevant failing tests are triaged. The user's subsequent explicit approval of the first journey superseded the earlier instruction to pause phase 2 at this gate; the open risks are recorded below.

### Private Figma review draft

[Sprout native foundations review draft](https://www.figma.com/design/AyAb6UrghiQyGQBVzOYdiU) was created in the account's private drafts on 2026-11-08. It contains six editable component sets (action, amount, transaction row, input, status banner, state panel), 52 color variables (26 semantic aliases and 26 hidden primitives), 13 dimension variables, 10 text styles, and separate iOS/Android light/dark frames built from component instances. The four frames use the same fictional fixture and are static design specimens, not native runtime evidence. Light and dark frames were visually inspected after correcting instance text and matching button shapes/outlines to the native controls.

The account's Figma Starter plan permits one mode per variable collection, so `semantic/light/*` and `semantic/dark/*` are separate variables rather than switchable modes. The Figma screenshot renderer left SF Pro text blank; the static iOS frames use Inter as a visual fallback. SwiftUI keeps the native system font. No file sharing or publication was changed.

### Foundations change manifest

These are the exact files edited or added for this phase, relative to the repository root. Paths already dirty before the branch was created retain their earlier work; this list identifies the foundations edits, not ownership of every diff hunk in those files.

```text
apps/android/app/src/debug/AndroidManifest.xml
apps/android/app/src/debug/java/com/michaeldadi/sprout/ui/review/FoundationReviewActivity.kt
apps/android/app/src/main/java/com/michaeldadi/sprout/ui/components/SproutFoundationComponents.kt
apps/android/app/src/main/java/com/michaeldadi/sprout/ui/theme/Color.kt
apps/android/app/src/main/java/com/michaeldadi/sprout/ui/theme/Spacing.kt
apps/android/app/src/main/java/com/michaeldadi/sprout/ui/theme/Theme.kt
apps/android/app/src/main/java/com/michaeldadi/sprout/ui/theme/Type.kt
apps/android/app/src/main/res/values/colors.xml
apps/android/app/src/main/res/values/themes.xml
apps/android/app/src/main/res/values-night/colors.xml
apps/android/app/src/main/res/values-night/themes.xml
apps/ios/FoundationReviewHost/.gitignore
apps/ios/FoundationReviewHost/FoundationReviewHostApp.swift
apps/ios/FoundationReviewHost/project.yml
apps/ios/Sprout/App/SproutApp.swift
apps/ios/Sprout/Core/Managers/ToastManager.swift
apps/ios/Sprout/Features/Authentication/LoginView.swift
apps/ios/Sprout/Resources/Assets.xcassets/AccentColor.colorset/Contents.json
apps/ios/Sprout/Resources/Assets.xcassets/SproutAction.colorset/Contents.json
apps/ios/Sprout/Resources/Assets.xcassets/SproutActionSubtle.colorset/Contents.json
apps/ios/Sprout/Resources/Assets.xcassets/SproutCanvas.colorset/Contents.json
apps/ios/Sprout/Resources/Assets.xcassets/SproutError.colorset/Contents.json
apps/ios/Sprout/Resources/Assets.xcassets/SproutInfo.colorset/Contents.json
apps/ios/Sprout/Resources/Assets.xcassets/SproutOnAction.colorset/Contents.json
apps/ios/Sprout/Resources/Assets.xcassets/SproutSeparator.colorset/Contents.json
apps/ios/Sprout/Resources/Assets.xcassets/SproutSuccess.colorset/Contents.json
apps/ios/Sprout/Resources/Assets.xcassets/SproutSurface.colorset/Contents.json
apps/ios/Sprout/Resources/Assets.xcassets/SproutSurfaceSubtle.colorset/Contents.json
apps/ios/Sprout/Resources/Assets.xcassets/SproutTextPrimary.colorset/Contents.json
apps/ios/Sprout/Resources/Assets.xcassets/SproutTextSecondary.colorset/Contents.json
apps/ios/Sprout/Resources/Assets.xcassets/SproutWarning.colorset/Contents.json
apps/ios/Sprout/Shared/Components/FloatingCirclesView.swift
apps/ios/Sprout/Shared/Components/LoadingModal.swift
apps/ios/Sprout/Shared/Components/SocialLoginButton.swift
apps/ios/Sprout/Shared/Components/ToastView.swift
apps/ios/Sprout/Shared/Design/FoundationReviewView.swift
apps/ios/Sprout/Shared/Design/SproutFoundationComponents.swift
apps/ios/Sprout/Shared/Design/SproutTheme.swift
artifacts/ui-refresh/.gitignore
docs/ui-refresh/plan.md
```

## Home orientation implementation record — 2026-11-08

This is the **next ordered slice** after Activity. Android Home and Activity are committed in `1d9a480`; iOS work remains uncommitted on `codex/sprout-ui-foundations`, and the unrelated staged work was preserved. Home is implemented in the existing authenticated shells and reviewed with isolated, fictional native fixtures. Full-app iOS compilation and authenticated end-to-end acceptance remain open. No second journey, balance calculation, Plaid flow, merchant cancellation, or production fixture was added.

### BEFORE → TARGET → ACTUAL

| Platform | Before | Approved target | Actual native review |
| --- | --- | --- | --- |
| iOS | `DashboardView` rendered only “Dashboard View”; no safe authenticated Home before-capture exists. | Scoped, fresh-or-honestly-unknown orientation, one next action, source-backed record or useful empty state. | [Light](../../artifacts/ui-refresh/home/ios-home-light.png), [dark](../../artifacts/ui-refresh/home/ios-home-dark.png), [Accessibility Large](../../artifacts/ui-refresh/home/ios-home-large-text.png). SwiftUI Home uses the existing native Home tab and leads to Activity. |
| Android | Authenticated `MainAppContent` opened Activity; no Home route or safe Home before-capture existed. | The same meaning with Material navigation, no invented balance or trend. | [Light](../../artifacts/ui-refresh/home/android-home-light.png), [dark](../../artifacts/ui-refresh/home/android-home-dark.png), [2× text](../../artifacts/ui-refresh/home/android-home-large-text.png). Home and Activity now have a shared, labeled Material bottom bar; transaction detail remains a pushed destination. |
| Recovery and uncertain data | Home had no loading, empty, stale, offline, or read-error UI. | Preserve saved records with accurate scope and state; provide a working recovery action. | iOS [empty](../../artifacts/ui-refresh/home/ios-home-empty.png), [older only](../../artifacts/ui-refresh/home/ios-home-older.png), [loading](../../artifacts/ui-refresh/home/ios-home-loading.png), [error](../../artifacts/ui-refresh/home/ios-home-error.png), [stale](../../artifacts/ui-refresh/home/ios-home-stale.png), [offline](../../artifacts/ui-refresh/home/ios-home-offline.png); Android [empty](../../artifacts/ui-refresh/home/android-home-empty.png), [older only](../../artifacts/ui-refresh/home/android-home-older.png), [loading](../../artifacts/ui-refresh/home/android-home-loading.png), [error](../../artifacts/ui-refresh/home/android-home-error.png), [record sync age](../../artifacts/ui-refresh/home/android-home-stale.png), [offline](../../artifacts/ui-refresh/home/android-home-offline.png). The fixture error’s Try again returned to saved records on both platforms. |

There is no separate approved Home Figma frame. The approved [design contract](design-contract.md#thesis-hierarchy-and-architecture) is the target; the root reference PNGs remain unverified art, not native before-images. The same five fictional Activity records and fixed 2026-11-08 09:41 EST review time were reused. Four fall in the last 30 local calendar days; North Market USD 84.27 is the most recent. Review headers identify **DEMO DATA**; production Home reads only the authenticated user’s existing saved records. The cited iOS Home captures were retaken on the final native-tab review build, including the recovery, dark, and large-text frames.

### Source, behavior, and intentional platform differences

- iOS Home and Activity now use one `ActivityRecordSource` adapter for the same authenticated, non-deleted SwiftData query and type, currency, amount, date, and sync mapping. Home reloads on appearance, after sync completes, and on user identity change. Android Home observes the existing account-scoped `ActivityViewModel`/Room Flow; no new request or financial calculation was introduced. Its `stateFor` gate prevents a previous account’s cached list from drawing during an identity change.
- Both Home views use the existing 30-day Activity filter for the count and latest record. The prominent USD 84.27 is labeled as the **latest saved transaction/source amount**, not spend, cash balance, net worth, or a trend. Transfers retain their type label. Empty and older-only accounts get separate copy; no zero balance is inferred. Unsynced records are identified as Sprout record-sync states, separate from bank status.
- iOS can display the current `SyncService.lastSyncDate` and a full-sync-age warning when available. Android has no verified account full-sync timestamp in this path, so it says “Full sync time unavailable”; its age warning names only the latest record’s own `lastSyncedAt`. The Android stale fixture changes that record timestamp only. Offline keeps saved records visible on both platforms.
- iOS retains its four native tab identities, selecting Activity from Home. Android now has two real authenticated destinations and uses one shared Material bar for Home/Activity; detail hides that bar and back returns to Activity. The card and bar route to the existing Activity UI, whose search, period, type filters, and detail semantics are unchanged. No legacy component or local styling was removed because other consumers still exist.

### Build, interaction, and regression evidence

| Check | Result |
| --- | --- |
| `xcodegen -s project.yml`, then `xcodebuild -project FoundationReviewHost.xcodeproj -scheme FoundationReviewHost -configuration Debug -destination 'platform=iOS Simulator,id=AE9767BE-CAA3-4000-837B-8666AA6E20D6' -derivedDataPath /tmp/sprout-home-ios-derived CODE_SIGNING_ALLOWED=NO test` in `apps/ios/FoundationReviewHost` | Built and ran on iPhone 17 Pro, iOS 26.4, 1206×2622 pixels; **2/2 focused tests passed**. The host compiles the production Home and Activity presentation and SwiftData adapters with inert auth/sync stubs. Maestro passed Home → Activity → Home, Home → Activity → North Market detail, empty/older/loading/error/retry, stale/offline, and the separate Activity list → detail → back → Expenses filter regression. |
| `JAVA_HOME=/Users/michaeldadi/Library/Java/JavaVirtualMachines/jbr-21.0.9/Contents/Home ./gradlew :app:assembleDebug :app:testDebugUnitTest --tests 'com.michaeldadi.sprout.ui.activity.ActivityFilterTest' --tests 'com.michaeldadi.sprout.ui.home.HomeSnapshotTest'` in `apps/android` | Final APK built; **4/4 focused Activity/Home tests passed** on the final bottom-bar implementation. Installed and interacted on the API 37, 1080×2400, 420 dpi emulator, English/US-style formatting and America/New_York time zone. ADB/UIAutomator confirmed Home → Activity, Expenses → detail → back, Home → Activity, with “2 of 5 saved transactions” retained. Maestro passed empty/older/loading/error/retry/record-age/offline on the final APK. |
| Full Android `./gradlew :app:testDebugUnitTest` after the final build | **41 tests, 27 failed**, the same 27 Apple/Auth/Google tests as the earlier 37-test baseline; the four focused Activity/Home tests pass. |
| Full iOS `Sprout - Debug` simulator build | Still blocked before Sprout source compilation: pinned RevenueCat `PaywallColor.swift:57` reports an invalid redeclaration under Xcode 27.2. An earlier build stopped in StreamCore. The isolated host does not prove full-app bootstrap, tabs, auth, or deep-link runtime behavior. |

The debug review does not authenticate a real user or write Room/SwiftData records. Android auth → Home with account data, iOS full-app Home tab, VoiceOver/TalkBack, 320 dp and expanded widths, rotation, reduced motion, and screen-reader focus remain unverified. The large-text captures show reflow without fixed-height clipping; content below the first viewport remains scrollable. Device theme and text-size settings were restored after review. The Home slice is complete as source and native fixture behavior, while those full-app acceptance gates remain open.

**Next recommended journey:** Budget/goal, the next row in the ordered plan. First verify whether real goal data and operations exist; otherwise implement an honest unavailable/empty orientation with the existing `/budget` route. No goal percentage or save action may be invented. Do not start it in this pass.

Files edited or added for this Home slice (repository-relative; some were already dirty before this slice):

```text
apps/ios/Sprout/Features/Dashboard/DashboardView.swift
apps/ios/Sprout/Features/Dashboard/HomeOrientationView.swift
apps/ios/Sprout/Features/Transactions/ActivityRecordSource.swift
apps/ios/Sprout/Features/Transactions/TransactionsView.swift
apps/ios/Sprout/Features/Root/MainTabView.swift
apps/ios/FoundationReviewHost/ActivityReviewView.swift
apps/ios/FoundationReviewHost/HomeReviewView.swift
apps/ios/FoundationReviewHost/FoundationReviewHostApp.swift
apps/ios/FoundationReviewHost/ActivityPresentationTests.swift
apps/ios/FoundationReviewHost/project.yml
apps/android/app/src/main/java/com/michaeldadi/sprout/MainActivity.kt
apps/android/app/src/main/java/com/michaeldadi/sprout/ui/activity/ActivityViewModel.kt
apps/android/app/src/main/java/com/michaeldadi/sprout/ui/components/SproutAuthenticatedNavigationBar.kt
apps/android/app/src/main/java/com/michaeldadi/sprout/ui/home/HomePresentation.kt
apps/android/app/src/main/java/com/michaeldadi/sprout/ui/home/HomeScreen.kt
apps/android/app/src/debug/AndroidManifest.xml
apps/android/app/src/debug/java/com/michaeldadi/sprout/ui/review/ActivityReviewActivity.kt
apps/android/app/src/test/java/com/michaeldadi/sprout/ui/home/HomeSnapshotTest.kt
docs/ui-refresh/plan.md
```

## First Activity journey implementation record — 2026-11-08

The user explicitly approved this next slice. Android Activity is committed in `1d9a480`; iOS work remains uncommitted on `codex/sprout-ui-foundations`, and the unrelated staged work was preserved. The native journey is implemented, while full-app iOS compilation and authenticated end-to-end acceptance remain open. No merchant cancellation, account linking, payment, balance calculation, or production fixture was added.

### BEFORE → TARGET → ACTUAL

| Platform and state | Before, from the audit | Approved target in the design contract | Actual native review evidence |
| --- | --- | --- | --- |
| iOS Activity list and detail | Source-only `Text("Transactions View")`; the pending `/transaction?id=` ID had no visible consumer. No safe authenticated before screenshot exists. | Scope/freshness, search/type/period, count, scannable grouped rows, source amount and sync state; native detail push and filter-preserving return. | [List](../../artifacts/ui-refresh/activity/ios-list-light.png), [detail](../../artifacts/ui-refresh/activity/ios-detail-light.png), [expense filter after return](../../artifacts/ui-refresh/activity/ios-expenses-filter-return.png). A `TabView` keeps the four existing tab identities; `NavigationStack` pushes the detail. |
| Android Activity list and detail | Source-only centered authenticated welcome placeholder; no Activity route or safe authenticated before screenshot. | The same financial meaning, with Material selection, destination/back and a Room-backed account scope. | [List](../../artifacts/ui-refresh/activity/android-list-light.png), [detail](../../artifacts/ui-refresh/activity/android-detail-light.png), [expense filter](../../artifacts/ui-refresh/activity/android-expenses-filter.png). The authenticated branch now hosts the Activity destination in one Compose `NavHost`. |
| Empty, loading, partial, stale, offline, failed | No reachable Activity UI; these were source-only gaps, not screenshot baselines. | Explicit scope and recovery; no invented zero balance, bank settlement, or sync completion. | iOS [empty](../../artifacts/ui-refresh/activity/ios-empty.png), [loading](../../artifacts/ui-refresh/activity/ios-loading.png), [error](../../artifacts/ui-refresh/activity/ios-error.png), [stale](../../artifacts/ui-refresh/activity/ios-stale.png), [offline](../../artifacts/ui-refresh/activity/ios-offline.png); Android [empty](../../artifacts/ui-refresh/activity/android-empty.png), [loading](../../artifacts/ui-refresh/activity/android-loading.png), [error](../../artifacts/ui-refresh/activity/android-error.png), [stale](../../artifacts/ui-refresh/activity/android-stale.png), [offline](../../artifacts/ui-refresh/activity/android-offline.png). The populated lists contain pending and failed record-sync examples. Both retry controls returned to records in the debug fixtures. |

There is no separate approved Activity frame in Figma. The target for this slice is the approved [design contract](design-contract.md#thesis-hierarchy-and-architecture), including its native mapping and representative Activity frame requirements. The four root `sprout-*.png` files remain unverified visual references; neither they nor the debug fixtures are a production baseline.

### Source and behavior

- iOS `TransactionsView` reads non-deleted SwiftData transactions scoped to the authenticated user, maps existing type/currency/date/sync fields to presentation state, and reloads after sync. `ActivityJourneyView` owns only display filters and detail path. The existing `/transaction?id=` deep link now opens the matching saved record, including after authentication; `/support` and `/budget` keep their route semantics. These paths compiled in an isolated host but were not driven through the full app.
- Android `ActivityViewModel` observes the existing Room repository for the Cognito token subject and does not issue a new network request. The authenticated `MainAppContent` preserves the auth gate and adds Activity list/detail destinations. Its filter values survive detail/back. The list uses lazy keyed rows for larger histories while retaining one visually grouped surface. Connectivity is a display signal; “full sync time unavailable” is honest because this path has no verified full-sync timestamp. Date filtering uses local calendar days, including daylight saving changes.
- Both render source amounts with currency codes and explicit income/expense/transfer labels; they do not infer a balance or subtract transfers from spending. Detail shows the full date in the device time zone, source type/category, optional payment method/notes, and record sync metadata. Pending/failed sync describes Sprout's record state, not bank settlement. A stale or offline banner never blocks review of locally available rows.
- iOS uses SF Symbols, SwiftUI segmented period control, semantic search input, labeled native tabs and a navigation push. Android uses Material filter chips, a neutral monogram, Compose destination/back, and Room `Flow`. A Material bottom bar is deferred until another authenticated destination is actually implemented; adding inactive destinations now would misrepresent feature availability.

### Reproducible native review

Debug-only review entry points use the **same fictional fixture**, fixed at 2026-11-08 09:41 EST in `America/New_York`: North Market expense USD 84.27, payroll income USD 2,480.00, transfer USD 350.00 pending sync, Metro ride expense USD 21.40 failed sync, and an older Cinema expense excluded from the default 30-day view. No account, merchant, or network call is used. Device locale was not pinned; the captured device formatting is English/US-style. The review banner states DEMO DATA.

| Platform | Environment and checks actually run | Result |
| --- | --- | --- |
| iOS | iPhone 17 Pro simulator, iOS 26.4, 1206×2622 pixels; light/dark, standard `large` text and `accessibility-large`. `xcodebuild -project FoundationReviewHost.xcodeproj -scheme FoundationReviewHost -configuration Debug -destination 'platform=iOS Simulator,id=AE9767BE-CAA3-4000-837B-8666AA6E20D6' -derivedDataPath /tmp/sprout-activity-ios-derived CODE_SIGNING_ALLOWED=NO test` in `apps/ios/FoundationReviewHost`; `simctl install/launch`; Maestro list→detail→back/filter, state/retry, and debug transaction-link flows. | Isolated host compiles the actual Activity presentation and `TransactionsView` adapter; one focused XCTest passed. Native list/detail, return, filter retention, empty/loading/error/retry/stale/offline were interacted with or captured. The debug link control opened the specified Metro ride detail. [Dark list](../../artifacts/ui-refresh/activity/ios-list-dark.png), [dark detail](../../artifacts/ui-refresh/activity/ios-detail-dark.png), [large text rows](../../artifacts/ui-refresh/activity/ios-list-large-text-rows.png). Native review found and corrected the cramped detail card width and low-contrast dark search placeholder. |
| Android | API 37 emulator, 1080×2400 pixels, 420 dpi, `America/New_York`, font scale 1.0 and 2.0; light/dark. `JAVA_HOME='/Users/michaeldadi/Library/Java/JavaVirtualMachines/jbr-21.0.9/Contents/Home' ./gradlew :app:assembleDebug` and `:app:testDebugUnitTest --tests 'com.michaeldadi.sprout.ui.activity.ActivityFilterTest'` in `apps/android`; `adb install`, launch `ActivityReviewActivity`, UIAutomator/ADB taps and screenshots. | APK builds; three focused filter tests pass. Native detail→back→filtered list and error→retry were observed. [Dark list](../../artifacts/ui-refresh/activity/android-list-dark.png), [large text rows](../../artifacts/ui-refresh/activity/android-list-large-text-rows.png). Large-text review led to stacking amounts below labels on both platforms. |

After the final lazy-row build, `JAVA_HOME=... ./gradlew :app:testDebugUnitTest` ran **40 tests, 27 failed**; the same 27 Auth/Apple/Google failures existed in the 37-test baseline. The final APK built and all three focused Activity tests passed; native detail/back/filter were repeated after installing it. Full iOS `Sprout - Debug` build was attempted with `xcodebuild -project apps/ios/Sprout.xcodeproj -scheme 'Sprout - Debug' -configuration Debug -destination 'platform=iOS Simulator,id=AE9767BE-CAA3-4000-837B-8666AA6E20D6' -derivedDataPath /tmp/sprout-ios-foundations-derived CODE_SIGNING_ALLOWED=NO build` and still fails in pinned `stream-core-swift/Sources/StreamCore/Query/Sort.swift:153` under Xcode 27.2 before Sprout source compilation (non-Sendable comparator conversion). The isolated host does not prove full-app bootstrap, authentication, or deep-link runtime behavior.

### Remaining gate and manifest

The native debug fixtures demonstrate visual and interaction behavior, not authenticated production data flow. The iOS full app must compile before the Activity adapter, tabs and deep links can be run end-to-end. Android authenticated sign-in → Room population was not exercised with a real account or safe fixture entry. VoiceOver/TalkBack, compact/expanded layouts, rotation, reduced motion, screen-reader focus, and large-history performance remain unchecked. These are open acceptance limits, not evidence of successful live finance integration. Stop here; no Home, Goal, recurring-payment, or plan journey migration is authorized by this slice.

Journey files edited or added, relative to the repository root (some were dirty before this slice):

```text
apps/ios/Sprout/Features/Transactions/ActivityPresentation.swift
apps/ios/Sprout/Features/Transactions/ActivityJourneyView.swift
apps/ios/Sprout/Features/Transactions/TransactionsView.swift
apps/ios/Sprout/Features/Root/MainTabView.swift
apps/ios/Sprout/Features/Root/Tab.swift
apps/ios/Sprout/Core/Managers/DeepLinkManager.swift
apps/ios/Sprout/Shared/Design/SproutFoundationComponents.swift
apps/ios/FoundationReviewHost/FoundationReviewHostApp.swift
apps/ios/FoundationReviewHost/ActivityReviewView.swift
apps/ios/FoundationReviewHost/ActivityAdapterStubs.swift
apps/ios/FoundationReviewHost/ActivityPresentationTests.swift
apps/ios/FoundationReviewHost/project.yml
apps/android/app/src/main/java/com/michaeldadi/sprout/MainActivity.kt
apps/android/app/src/main/java/com/michaeldadi/sprout/ui/activity/ActivityPresentation.kt
apps/android/app/src/main/java/com/michaeldadi/sprout/ui/activity/ActivityJourney.kt
apps/android/app/src/main/java/com/michaeldadi/sprout/ui/activity/ActivityViewModel.kt
apps/android/app/src/debug/AndroidManifest.xml
apps/android/app/src/debug/java/com/michaeldadi/sprout/ui/review/ActivityReviewActivity.kt
apps/android/app/src/test/java/com/michaeldadi/sprout/ui/activity/ActivityFilterTest.kt
docs/ui-refresh/plan.md
```

## Senior craft pass — 2026-11-08

Scope: one correction pass across the implemented native Home and Activity journeys, their shared display components, and transaction detail. The approved data, navigation, auth, and service contracts stay in place. The running iPhone 17 Pro/iOS 26.4 review host and Android API 37 debug build were inspected at default text size; the review host uses the same fictional records as the journey evidence. The iOS full app remains blocked by its pinned dependency build, so review-host captures do not prove its auth shell.

### Highest-impact defects identified before editing

| ID | Evidence in running build or current capture | Craft consequence | Pass disposition |
| --- | --- | --- | --- |
| C1 | [Android sign-in](../../artifacts/ui-refresh/craft/before/android-login-light.png) still has a full green gradient, floating circles, emoji field icons, and faint input copy. | Auth reads as a separate visual product and its fields have weak contrast. | Open: auth is a distinct unfinished journey; no one-screen treatment here. |
| C2 | [iOS Home](../../artifacts/ui-refresh/craft/before/ios-home-light.png) and [Android Home](../../artifacts/ui-refresh/craft/before/android-home-light.png) repeat “Recent activity,” count, “Latest saved transaction,” and a large card before a small “View activity” link. | The main action is visually weaker than the container and the first glance takes too long. | Correct in this pass. |
| C3 | Home and [Android Activity](../../artifacts/ui-refresh/craft/before/android-activity-light.png) show tall “Some records need sync” panels even though Activity rows carry the exact state. | Repeated chrome displaces useful records and makes record sync look like a bank warning. | Correct in this pass. |
| C4 | The [running iOS Activity](../../artifacts/ui-refresh/craft/before/ios-activity-light.png) and Android Activity place title, scope, search, two filter rows, count, then a warning before the list. Roughly two rows fit in the first default-size viewport. | Scanning recent activity starts below the fold; the contract targets 3–5 useful rows. | Correct in this pass. |
| C5 | In the [Android search keyboard state](../../artifacts/ui-refresh/craft/before/android-search-keyboard.png), the bottom bar stays above the IME and results disappear. Android search has no explicit Search IME action; iOS Activity has no explicit keyboard exit. | Search interrupts the user’s path to a result. | Correct in this pass; retest typed query and return. |
| C6 | The [large-text iOS](../../artifacts/ui-refresh/activity/ios-list-large-text-rows.png) and [Android](../../artifacts/ui-refresh/activity/android-list-large-text-rows.png) rows devote width to decorative direction/monogram tiles, and the fixture reads “Transfer · Transfer.” | Long names wrap sooner and duplicated labels slow scanning. | Correct in this pass. |
| C7 | [iOS detail](../../artifacts/ui-refresh/activity/ios-detail-light.png) and [running Android detail](../../artifacts/ui-refresh/craft/before/android-detail-light.png) repeat Type and Currency inside one tall white card; iOS also renders seconds in both full timestamps. | Source, date, payment method, and sync are harder to skim. | Correct in this pass while keeping every distinct fact. |
| C8 | iOS Activity says “All accounts” while Android says “This account” for signed-in-user records. | Financial scope is inconsistent across platforms. | Correct to explicit Sprout-account scope. |
| C9 | Android Activity’s “May be out of date” message is triggered by the newest *record* sync timestamp, not an account full-sync timestamp. | The title can imply a stronger freshness claim than the source supports. | Correct the label and explanation. |
| C10 | Home and Activity empty panels say “No balance is inferred” in [iOS](../../artifacts/ui-refresh/home/ios-home-empty.png) and [Android](../../artifacts/ui-refresh/home/android-home-empty.png). | Implementation caveats consume space without helping the user recover. | Correct to useful, truthful next-step copy. |
| C11 | Home and Activity display money with no user privacy-concealment control. The current flows do not expose an approved preference or persistence contract. | Amounts remain visible during shoulder-surfing. | Open product/data decision; do not invent a setting in a craft pass. |

No verified time series or goal data is present in these implemented journeys, so there is no chart, axis, legend, scrubbing, or accessible chart alternative to tune. Adding a chart would invent a financial claim. The auth, privacy, compact/expanded layout, and screen-reader gates remain explicit follow-up work.

### One bounded correction pass

The existing SwiftUI and Compose journeys now use a plain Home summary with a full-width **View activity** action, a compact Sprout record-sync line, a shorter account-scope label, and a denser Activity list without decorative row tiles. Transfer no longer reads “Transfer · Transfer.” Detail keeps date, category, payment method, source amount/currency, and record-sync information but removes the large enclosing card and redundant Type/Currency rows. Search has a clear action on both platforms; Android hides the authenticated bottom bar while its keyboard is open. The Android stale banner now names the *record* sync source and says full account sync time is unavailable. Empty copy says what appears when records exist or how to reach older records. No financial calculation, source query, API contract, persistence rule, route, or deep link was changed.

| Defect | Before | Native after evidence | Result |
| --- | --- | --- | --- |
| C2–C3 Home hierarchy and sync chrome | [Android Home](../../artifacts/ui-refresh/craft/before/android-home-light.png), [iOS Home](../../artifacts/ui-refresh/craft/before/ios-home-light.png) | [Android Home](../../artifacts/ui-refresh/craft/after/android-home-light.png) | The transaction and primary action read in sequence; the sync message is a single line. iOS source builds, but its after capture is still a runtime gate below. |
| C4, C6, C8 Activity density, rows, scope | [Android Activity](../../artifacts/ui-refresh/craft/before/android-activity-light.png), [iOS Activity](../../artifacts/ui-refresh/craft/before/ios-activity-light.png) | [Android Activity](../../artifacts/ui-refresh/craft/after/android-activity-light.png) | Four useful Android rows fit at default size, up from roughly two; the duplicate transfer label and decorative tile are gone. Both implementations say “Your Sprout account.” |
| C5 Search interruption | [Android keyboard](../../artifacts/ui-refresh/craft/before/android-search-keyboard.png) | [Typed result above keyboard](../../artifacts/ui-refresh/craft/after/android-search-keyboard.png), [submitted search](../../artifacts/ui-refresh/craft/after/android-search-submitted.png) | One matching row remains visible while typing; Search dismisses the keyboard and restores the bottom bar. iOS Search submit/clear is compiled but not device-verified. |
| C7 Detail grouping | [Android detail](../../artifacts/ui-refresh/craft/before/android-detail-light.png), [iOS detail](../../artifacts/ui-refresh/activity/ios-detail-light.png) | [Android detail](../../artifacts/ui-refresh/craft/after/android-detail-light.png) | Distinct facts remain in a flatter list; full dates use minutes and the device time zone. iOS after capture is pending. |
| C9 Stale wording | [Android stale](../../artifacts/ui-refresh/activity/android-stale.png) | [Android stale](../../artifacts/ui-refresh/craft/after/android-activity-stale.png) | The warning is scoped to the latest saved record sync, not a claimed full account sync. |
| C10 Empty guidance | [Android Home empty](../../artifacts/ui-refresh/home/android-home-empty.png), [Android Activity empty](../../artifacts/ui-refresh/activity/android-empty.png) | [Android Home empty](../../artifacts/ui-refresh/craft/after/android-home-empty.png), [Android Activity empty](../../artifacts/ui-refresh/craft/after/android-activity-empty.png) | Technical caveat copy was removed; Home still offers Activity. |

The Android [dark](../../artifacts/ui-refresh/craft/after/android-activity-dark.png) and [1.3× text](../../artifacts/ui-refresh/craft/after/android-activity-large-text.png) captures show readable list content and natural wrapping. The type filter is horizontally scrollable at 1.3×. Android `:app:assembleDebug` succeeded and the focused `ActivityFilterTest` and `HomeSnapshotTest` suites passed **4/4**. The isolated iOS `FoundationReviewHost` build succeeded. A full iOS Sprout build remains blocked upstream by the pinned `stream-core-swift` compile error recorded above; this pass did not change that dependency.

Android `dumpsys gfxinfo` during this overloaded emulator run reported 96 frames, 36 janky (37.5%), median 23 ms and 90th percentile 1,500 ms. A system UI “isn't responding” dialog appeared during the large-text capture, and the macOS host was under heavy load. These numbers do **not** establish app smoothness or a regression; a controlled device trace with representative data is still needed. Screen-reader navigation, focus order, reduced-motion behavior, compact/expanded layouts, rotation, authenticated flow, and iOS after captures remain unverified. iOS simulator install/launch/screenshot calls stalled after a device restart, and a second device failed to boot with `launchd_sim` not responding; no invalid home-screen capture is being used as evidence.

### Remaining issues after this pass

- C1: redesign the existing authentication journey separately; the running Android sign-in still has the gradient, floating circles, emoji fields, and weak input contrast.
- C11: decide the privacy-concealment behavior and persistence contract before adding a control for visible amounts.
- Complete iOS native after captures of Home, Activity, keyboard, detail, empty, stale, dark, and large text once the simulator service is healthy. Verify search exit, detail/back, scroll continuity, and reduced motion on a running build.
- Measure interaction and scroll frames on a stable physical or emulator device with representative history, then perform VoiceOver/TalkBack and compact/expanded layout checks.
- Keep the existing full-app dependency, authenticated-data, and deep-link acceptance gates from the Home and Activity records above.

Stop after this pass. No auth, Budget/goal, subscription, or cancellation journey was started.

## Android auth test gate — 2026-11-08

The 27 failures recorded above were the baseline before this separate repair. Commit `fe2a4e2` on draft PR #1 injects the Cognito and Credential Manager clients into the existing services for isolated tests, replaces an impossible Apple token-exchange assertion with a fake exchanger, and runs the Google request test with Robolectric on API 35. It does not change the production auth protocol or user-facing flows. On JBR 21, `:app:assembleDebug :app:testDebugUnitTest` passed, and the XML reports contain **41 tests, 0 failures, 0 errors**. The PR's hosted Java 17 Android and iOS checks and Bitrise were still running when this note was written; their outcomes must be checked separately.

Update 2026-11-09: PR #1 is merged; its iOS, Android, Mobile CI gate, Bitrise, and GitGuardian checks completed successfully. The isolated Android UI snapshot from commit `1d9a480` also built and passed 41/41 JVM tests on JBR 21. These results do not verify the uncommitted iOS app migration or live financial behavior.

## Appwrite migration handoff — 2026-11-09

The target backend is Appwrite for both native apps. `infra/appwrite/` now holds one Terraform root selected by environment data and a matching HCP Terraform workspace; the official provider resources and a Terraform-managed API settings bridge cover the existing staging and production inventory. `terraform fmt -check -recursive` and `terraform validate` pass locally. The existing Appwrite databases contain no financial tables. The production template functions' latest deployments were failing at inventory time, and the landing site points to an absent `apps/web` directory. These are release gates, not completed features.

On 2026-11-09, the staging Terraform project key was created in Appwrite with the 28 declared scopes. Its generated ID was read back and recorded in `environments/staging.tfvars`; the secret is held locally in macOS Keychain, not in the repository. The first staging plan read live project settings but did not complete: the provider requires an organization key for importing the existing project and project key, and two project-resource reads timed out. The Sprout Finance organization Settings menu exposed only General, Members, and Billing; the documented Partners key section was not available in that console session. No Terraform state import or apply has completed. Obtain an organization credential or a supported provider path, then rerun and inspect a complete staging plan before any apply. Production still needs access to its existing project key credential.

Both native clients now take the Appwrite endpoint and project ID from build configuration. iOS uses the system Apple sheet with a SHA-256 nonce and GoogleSignIn with a configured web client ID; Android uses Credential Manager for Google and no longer presents the browser-based Apple flow. Provider ID tokens are exchanged for Appwrite sessions. An Appwrite session opens an account-only state explaining that financial data is unavailable in this build; it does not enter the Cognito-backed financial screens. Existing Cognito sign-in behavior is retained until account/data migration is designed and verified. Android `:app:assembleDebug :app:testDebugUnitTest` passed with 28 tests, including a local native Google session request/cookie test. The iOS simulator app build passed; the Sentry debug-symbol upload still reports a project configuration warning. No live Apple/Google sign-in, session restoration on devices, or financial-data migration has been verified.

### iOS client configuration and shortcut safety

The local iOS migration was hardened on 2026-11-09. The `Secrets.swift` generator now emits only client configuration; it no longer copies an AWS access key, AWS secret access key, or server API secret into either app target. Its mapping is explicit for Debug, Staging, and Release, with no invented endpoint defaults or fallback from a missing Staging/Release value to a different environment. The Xcode generation phase was previously restricted to deployment postprocessing, so ordinary builds could compile an old ignored file; it now runs before the app's Sources phase on normal builds. ShellCheck, three-configuration marker and environment-isolation tests, and inspection of the regenerated ignored files found no server credential fields. An Appwrite-only build can initialize without a legacy API URL; legacy requests return unavailable when that URL is missing or invalid, and Stream Chat initialization waits for a configured client key.

The bundled App Intents no longer write expenses to a separate shared-defaults array or turn a missing balance into `$0`. Add Expense, Check Balance, and the dummy extension intent are hidden from discovery and return an unavailable message if an existing Shortcut invokes them. The app's Siri screen no longer advertises unsupported financial commands, and their unused activity identifiers were removed from `Info.plist`. Real shortcuts remain a separate integration gate: authenticated account ownership, a single transaction store, balance provenance, and semantic readback must be in place first. These iOS edits remain in the uncommitted migration worktree; no live provider sign-in or financial write is implied.

The legacy Cognito sign-in path now requires a nonempty account subject in its ID token before storing a new session, and a token response without credentials fails instead of allowing the UI to report success. Restored and refreshed sessions also require a nonempty subject. Migration from legacy plaintext storage must succeed in Keychain before it can restore a session. This preserves the old account boundary during the Appwrite migration. The full iOS simulator Debug build passed after the generator phase and auth guards; the Sentry debug-symbol upload still warns that its project is not found. Release signing and device runtime behavior are unverified.

Android's matching legacy-session hardening is signed commit `9b557e7`, pushed to `codex/sprout-ui-foundations`. A partial Cognito token response now fails, and refresh retrieves and verifies the user identity before restoring authenticated state. Plaintext token migration must succeed in Android Keystore storage before that session can be read. `:app:assembleDebug :app:testDebugUnitTest --offline` passed on JBR 21 with 29 tests, 0 failures and 0 errors. These local checks do not establish live Cognito or Appwrite sign-in.
