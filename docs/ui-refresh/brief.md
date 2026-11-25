# Sprout native UI refresh: audit brief

Date: 2026-11-08 (America/New_York). Scope: the existing SwiftUI iOS app and Jetpack Compose Android app in this worktree. This phase records the baseline; it does not change application code or add financial features.

## Intended experience

For adults roughly 21–35 who struggle to manage finances and subscriptions, make existing tasks easier to understand and more enjoyable while retaining native platform behavior. Plaid-connected tracking, subscription reminders and actual merchant cancellation, and in-app goals are intended capabilities, **not assumed to be implemented**. Copilot, Uber, Robinhood, and Coinbase are visual references, not specifications or evidence of current Sprout behavior.

## Invariants

- Preserve working authorization, persistence, API contracts, calculations, user data, supported tasks, and deep links.
- Keep SwiftUI and Compose. Do not import web screens, migrate frameworks, scaffold a replacement app, or use a web prototype as native proof.
- No live account linking, merchant cancellation, payments, production credentials in screenshots, public publication, or destructive operations during this audit.
- During the baseline audit, preserve the substantial pre-existing changes without staging or committing them. Keep fictional-data visual evidence under ignored `artifacts/ui-refresh/`; later explicit commit requests govern reviewed implementation work.

## Evidence standard

`audit.md` distinguishes source inspection, build/test result, native runtime capture, and unverified visual reference. No authenticated financial screen is called a baseline unless it is rendered by this worktree with a safe fixture and recorded device settings. The four untracked root PNGs are not treated as native runtime evidence.
