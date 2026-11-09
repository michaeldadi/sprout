# Internal publication review — November 9, 2026

This record is internal. The public website preserves the approved Clear sky homepage without draft, preview, or unavailable-feature notices.

## Technical release evidence

The staging primary origin is https://staging-getsprout.appwrite.network. The production origin selected by Michael is https://getsprout.appwrite.network. The complete site, private forms, exact design comparison, browser checks, and infrastructure evidence are linked from [validation.md](validation.md).

A full production Terraform refresh/plan completed. It proposed 78 additions, 24 updates, and no deletions, including unrelated native authentication and existing function adoption changes. Those unrelated changes were excluded from the website apply. The website resources were separately reviewed and applied; see the sanitized [review](evidence/production-terraform-review.json). The active production deployment before this release is `6af0f34ec8e168e35a1c` and is the rollback target.

## Product and operating commitments

The approved design is the source of the public claims. Source inspection can identify implementation evidence and gaps; it cannot establish the intended mobile launch behavior or approve a service commitment on the product owner's behalf.

| Claim or policy | Evidence and acceptance needed |
| --- | --- |
| Three-day renewal notices | The selected design states this timing. Verify detection, scheduling, permission denial, time zones, and delivery on the intended launch builds. Website illustrations do not establish delivery. |
| Siri and Google Assistant entry | Native shortcut/deep-link integration code exists. Confirm that the exact illustrated command saves the intended expense end to end on both launch platforms. |
| Biometric lock on every open | Biometric service code exists on both platforms, with an enabled preference. Confirm the intended default, foreground behavior, unsupported-device behavior, and lock coverage before affirming this wording. |
| Read-only bank connection through Plaid | Native Plaid SDK integration code exists. Confirm the production account-linking backend, requested permissions, token handling, and read-only launch behavior. |
| Data gone within 24 hours | The current original checkout's `apps/ios/Sprout/Features/Settings/DeleteAccountView.swift:238` still marks actual account deletion TODO, simulates a delay, and signs out. This does not verify the 24-hour deletion commitment. Confirm the intended launch implementation and operational process. |
| Encryption in transit and at rest | The website uses HTTPS and private Appwrite tables. Confirm coverage for the complete app data path and connected services; these website checks do not audit every native store or processor. |
| Privacy and terms | Finished policies describe the website forms, Appwrite processing, consent, inquiries, and relevant app practices. The product owner must confirm they match intended launch operations before publication. No unrelated-domain contact details were reused. |
| Inquiry ownership | Inquiries are reviewed manually in the production Appwrite Console. Confirm the responsible operator and review process. No email notification or separate ticketing integration is configured. |

Source inspection used the current original checkout without modifying it. Its uncommitted native work is separate from this website branch. These observations are dated, limited checks rather than a mobile release audit.

## Final publication record

- Product/security commitments: Michael approved the copy as intended pre-launch commitments on November 9, 2026, after the source gaps above were disclosed. This acceptance does not establish completed mobile implementation.
- Supporting/legal copy: Michael accepted the current copy in the same publication approval.
- Inquiry review operator/process: Michael owns manual review in the Appwrite Console; no automatic outbound email is configured.
- Actual Safari 200% page zoom: observed reflow without overlap. VoiceOver spoken/rotor output and a separate enlarged-text session remain unverified; the temporary settings were restored.
- Tested release commit: `cca23a0f47b92f114a699cef7786bea02b3b8ca6`. Both hosted builds and GitHub Web CI passed.
- Active staging deployment: `6af1efb7a629d486ef08`; all 33 hosted browser checks passed again.
- Active production deployment: `6af1efadbc0574af4565` at https://getsprout.appwrite.network. All 33 browser checks passed on the public origin. Canonical, sitemap, indexing, assets, private forms, duplicate/retry behavior, rate-limit recovery, and disposable-data cleanup were verified after activation.
- Public activation: completed November 9, 2026, after Michael replied “Approve copy and publish” with the outstanding VoiceOver limitation and product source gaps disclosed. The mobile launch still needs the actual product behavior verified; this website release does not certify it.
