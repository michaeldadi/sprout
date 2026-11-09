# Clear sky implementation and acceptance

Approved November 9, 2026. Deliver the complete AIDesigner Sprout Marketing Variant A in `apps/web`, with exact homepage copy and fictional figures, every footer destination, launch waitlist, and categorized inquiries. Do not put draft, preview, or unavailable-feature notices in the product.

## Reference and composition

- AIDesigner frame `fr_rxqvhmc4x`, exploration `ex_giaq76yad`.
- Immutable original: [reference/clear-sky.html](reference/clear-sky.html), SHA-256 `5438294e88529912b9dc1b9dfe592f13c83bb269c1fe240f24fbbec8ff4f3d05`.
- Sage canvas, forest action, Fraunces/Inter/JetBrains Mono. Preserve the source DOM/SVG phone illustration, patterned fields, glass navigation, 1200px container, source breakpoints, and all seven sections plus footer.
- Source desktop section geometry is 4855px at 1440px; tablet 5570px at 834px; phone 6465px at 390px. The committed measurement report compares every section edge and height.
- Functional additions are the disclosure menu, waitlist dialog, insight controls, form feedback, and supporting pages. Advice controls occupy existing spacing so subsequent sections retain their positions.

## Implementation

TanStack Start + strict TypeScript, Vite + Nitro, compiled Tailwind, self-hosted fonts. CSS and IntersectionObserver implement motion; reduced motion leaves content immediately readable. Yarn 4.9.2 and the root lockfile own the web dependencies. The current officially documented `nitro/vite` integration is published as `3.0.261103-rc`; it is explicitly pinned rather than following the `latest` tag. This is a documented dependency exception to the original preference for stable packages.

Header navigation preserves the five source anchors. Store links retain their source artwork and text, open a native dialog with the selected platform, and fall back to `/waitlist`. Advice pauses for hover, focus, offscreen/hidden documents, reduced motion, and manual pause. Inactive links are inert. All illustrations remain separate from functional account controls.

Local typed content owns product pages, About, Careers, Press, Help, in-app support, Status, Privacy, Terms, deletion guidance, licenses, Contact, two complete journal articles, and the waitlist. Footer links are mapped to real routes or section anchors. Legal compatibility URLs redirect permanently. No CMS, outbound email, financial account operations, or administrative application is introduced.

`POST /api/waitlist`: normalized email, platform, placement, consent version/time; private table; unique email index; identical successful response for duplicate signups. `POST /api/contact`: UUID-based retry idempotency, optional name, email, category, message, private review status. Both enforce request origin, JSON/body/field limits, honeypot handling, safe errors, and no-store responses. Credentials are server-only; hosted SSR uses per-request Appwrite keys scoped to `rows.write`.

Terraform owns both private tables, columns/index, site variables, build settings, site scopes, branch/path filters, and separate five-per-minute per-IP firewall rules. Existing staging and production sites are reused. The settings bridge owns API fields absent from provider 2.3.0. Review and apply environment changes independently.

## Acceptance

- Immutable install, typecheck, scoped lint, unit tests, production build.
- Three-browser route, interaction, keyboard, form, reduced-motion, responsive, and accessibility checks.
- 1440/834/390 source screenshots and section measurements; overflow checks from 320px to 1920px.
- Live staging form persistence/replays, anonymous access denial, rate limits, credential leakage checks, and cleanup.
- Internal copy/product/security/legal review before public activation; no public review notices.
- Generated Appwrite primary domain initially; branch previews non-indexable; public deployment indexable after origin configuration.

## Prerequisite provenance

Remote `main` at `3851bd1` contains the TanStack starter but its root package and README were overwritten by Appwrite function templates. This branch restores workspace settings while retaining the root FCM function dependency/entrypoint. Existing Appwrite Terraform configuration is carried from `a17d9e0`, with the already-live manual-transactions definitions and source from `6fc4449` retained so a future full plan does not delete those resources. These prerequisites are not newly authored mobile features. Existing native files and the user's working checkout are untouched.

## Verification records

See [validation.md](validation.md), [route inventory](routes.md), [release runbook](release.md), and [evidence](evidence/).
