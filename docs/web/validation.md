# Clear sky validation — November 9, 2026

## Implemented

Complete homepage and supporting routes; mobile menu; waitlist dialog and standalone route; private waitlist/contact endpoints; local fonts, brand downloads, social artwork, metadata, structured data, compatibility redirects, sitemap/robots, and branded 404. No public draft/preview/unavailable-feature labels were added.

## Local verification

- Yarn 4.9.2 immutable installation: passed.
- Strict TypeScript, scoped ESLint, 16 form-boundary tests, two crawler-policy tests, and Nitro production build: passed.
- Chromium, Firefox, and WebKit route/link, waitlist, menu, advice, contact retry, help search, responsive, and automated accessibility checks: passed after correcting a WebKit focus-restoration issue. WebKit's four-page accessibility scan needs the configured 60-second test timeout on this machine; a 30-second run under concurrent capture load timed out.
- Additional no-JavaScript navigation/form-page fallback and HTTP 429 retry checks: passed in all three engines. A 200% zoom-equivalent CSS viewport also passed; this is not a claim of a manual browser-zoom or VoiceOver session.
- No document overflow at 320, 375, 390, 768, 834, 1024, 1280, 1440, or 1920 CSS pixels.
- Automated WCAG A/AA scans of homepage, waitlist, contact, and help: no reported violations. Manual VoiceOver acceptance remains a release check.
- Production client assets contain no server credential variable or request-key handler. The server SDK is excluded from client chunks.

Every measured section top and height matches at all three reference widths (maximum delta 0 CSS pixels). See [measurements](evidence/measurements.json) and the corresponding reference/implementation screenshots. The source is copied unchanged and checksum-identified; the capture harness replaces remote fonts with the same local font files for deterministic comparison. The reference-only Tailwind runtime is never shipped in the website.

## Mobile lab profile

A production Chromium run at 390×844, 4× CPU slowdown, 150ms latency, and 1.6Mbps download measured:

- LCP: 1.42 seconds.
- CLS: 0.0038.
- Sum of long-task blocking portions during the captured session: 62ms.

This is a local CDP/PerformanceObserver lab measurement, not Lighthouse or field INP data. The build's initial JavaScript totals 123,312 gzip bytes (about 120.4KiB), below the 200KB target. Local Node serves assets without transport compression; the Appwrite CDN must be checked on the hosted deployment. [Raw measurements](evidence/performance.json).

## Live staging

Terraform created the two private tables, ten required columns, and unique email index in project `6af0f72200383d2f1084`. It updated the existing site's root Yarn/Nitro build settings, set the `rows.write` site scope and branch/path filters, declared six public/runtime configuration variables, and reconciled both site-scoped five-per-minute WAF rules.

[Live form evidence](evidence/live-staging-forms.json) covers the production endpoint code running locally against the actual staging TablesDB:

- Four simultaneous waitlist submissions stored exactly one row.
- Duplicate replies were identical; the original platform preference was retained.
- Two contact submissions with one UUID stored exactly one private inquiry.
- Anonymous clients could not retrieve private records or create rows. Appwrite may return an empty successful list for inaccessible rows; individual private-record reads were denied.
- All disposable records were deleted and filtered readback confirmed zero matching rows.

The primary staging deployment `6af1e833e1abab3ef3b2` subsequently passed real hosted submissions: request-scoped key injection worked, duplicate waitlist preferences and contact retry IDs were retained, and private readback matched the submitted values. Both site-scoped WAF rules returned 429 on the sixth matching POST and accepted requests after the window reset. All disposable records were removed. See [hosted form evidence](evidence/hosted-staging-forms.json).

All 33 browser checks also passed against `https://staging-getsprout.appwrite.network` across Chromium, Firefox, and WebKit. Canonical metadata uses the selected origin; staging meta robots and robots.txt prevent indexing. Foreign-origin submissions returned 403, malformed JSON returned 400, and GET requests to both form endpoints returned 405. API replies were no-store. Appwrite served the primary JavaScript using Brotli with immutable caching. See [hosted browser evidence](evidence/hosted-staging-browser.json).

## Hosted build and GitHub CI

The signed website implementation `0b7f9cffc8459b0493e2a2084fe35bcb81d4d0fb` passed [Web CI](https://github.com/michaeldadi/sprout/actions/runs/42640988729): 16 unit tests and 33 browser checks. The staging Appwrite VCS deployment `6af1e0f752d1f0370856` built successfully, reached `ready`, and distributed to all six edges with `activate=false`. This verifies the locked root-workspace install, Node 22 build, Nitro output selection, and Appwrite packaging; it does not establish hosted form-origin or firewall acceptance without the preview URL.

The production site's original automatic non-active branch build compiled the website, then failed because its previous output directory was `./dist`. The reviewed website-only Terraform apply has now corrected the root build context, immutable Yarn install, workspace build, and `./apps/web/.output` selection. Production also has the separate private form schema, six environment variables, rows.write site scope, trigger filters, and two site-scoped WAF rules. Its previous active deployment is preserved while the new release candidate is verified.

Production function preview logs exposed a missing `husky` dependency in the restored root manifest's existing prepare script. The follow-up adds that declared dependency and preserves the original function template's npm UUID override. No function source or active function deployment was changed. The obsolete root npm lockfile from the template was removed so Yarn owns the single root lockfile; legacy functions use `npm install`, not `npm ci`.

## Infrastructure limits and release state

Website resource changes for staging and production are in their existing separate HCP Terraform states. A full production refresh/plan completed: 78 additions, 24 updates, and no deletions. Because it also included unrelated native authentication and function adoption changes, only a separately reviewed website plan was applied. No native auth settings, mobile source, existing function configuration, or active production deployment was changed. See [the sanitized Terraform review](evidence/production-terraform-review.json).

Michael supplied both generated primary origins, which are now configured. The existing production Terraform credential was retrieved through the authenticated console without creating or expanding a permanent key. Temporary read-only organization credentials used for the review were revoked. Internal product/security and policy acceptance, inquiry ownership, manual accessibility checks, and public activation remain recorded in [the internal review](internal-review.md). Refer to [release.md](release.md) for publication and rollback.
