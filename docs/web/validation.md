# Clear sky validation — November 9, 2026

## Implemented

Complete homepage and supporting routes; mobile menu; waitlist dialog and standalone route; private waitlist/contact endpoints; local fonts, brand downloads, social artwork, metadata, structured data, compatibility redirects, sitemap/robots, and branded 404. No public draft/preview/unavailable-feature labels were added.

## Local verification

- Yarn 4.9.2 immutable installation: passed.
- Strict TypeScript, scoped ESLint, 16 form-boundary tests, and Nitro production build: passed.
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

These checks do not establish a hosted site's request-scoped key injection or edge rate-limit behavior. Verify those after the site builds in Appwrite.

## Hosted build and GitHub CI

The signed website implementation `0b7f9cffc8459b0493e2a2084fe35bcb81d4d0fb` passed [Web CI](https://github.com/michaeldadi/sprout/actions/runs/42640988729): 16 unit tests and 33 browser checks. The staging Appwrite VCS deployment `6af1e0f752d1f0370856` built successfully, reached `ready`, and distributed to all six edges with `activate=false`. This verifies the locked root-workspace install, Node 22 build, Nitro output selection, and Appwrite packaging; it does not establish hosted form-origin or firewall acceptance without the preview URL.

The unchanged production site's automatic non-active branch build compiled the website, then failed because its existing output directory is `./dist`. The Terraform change to root build context and `./apps/web/.output` is the prepared correction, not a production configuration already applied.

Production function preview logs exposed a missing `husky` dependency in the restored root manifest's existing prepare script. The follow-up adds that declared dependency and preserves the original function template's npm UUID override. No function source or active function deployment was changed. The obsolete root npm lockfile from the template was removed so Yarn owns the single root lockfile; legacy functions use `npm install`, not `npm ci`.

## Infrastructure limits and release state

Staging resource changes are in the existing HCP Terraform state. Applies were deliberately targeted because available credentials cover the project/website resources but not the whole organization's administration. No production infrastructure changes, native auth changes, mobile changes, or public activation were performed.

Exact generated staging/production site URLs were requested because the connector cannot list their proxy rules (`rules.read` is missing). Hosted origin checks remain fail-closed until configured. Full-environment refresh/plan, hosted build/edge checks, internal copy/legal review, inquiry ownership, and public activation remain explicit release gates. Refer to [release.md](release.md).
