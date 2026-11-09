# Website release and rollback

## Environment configuration

The existing Appwrite sites are staging `6af0f8bf003d74b49da3` and production `6af0f34a002cee7f0cfb`. They use separate projects, databases, state, credentials, and form rows.

The confirmed primary origins are `https://staging-getsprout.appwrite.network` and `https://getsprout.appwrite.network`. Both are recorded in their environment `.tfvars`; staging remains non-indexable. Production indexing is enabled only on its configured primary host. Request middleware adds `X-Robots-Tag: noindex, nofollow` and disallows crawling on other hosts, including branch previews. Do not reuse `getsprout.io`: its observed site belongs to another product.

Terraform creates the runtime variables `SPROUT_MARKETING_DATABASE_ID`, `SPROUT_WAITLIST_TABLE_ID`, `SPROUT_INQUIRIES_TABLE_ID`, and `SPROUT_SITE_ORIGIN`, plus build variables `VITE_SITE_ORIGIN` and `VITE_SITE_INDEXABLE`. Hosted SSR uses the injected project/endpoint and `x-appwrite-key`; no permanent website API key is stored.

`APPWRITE_API_KEY` and `APPWRITE_ORGANIZATION_API_KEY` authenticate the existing Terraform root. The bridge also accepts an optional short-lived `APPWRITE_WEBSITE_API_KEY` for site/firewall API operations when the infrastructure credential lacks those scopes. Never put these values in configuration or logs. The temporary website credential needs only `sites.read`, `sites.write`, `wafRules.read`, `wafRules.write`; add `rows.read`/`rows.write` only for authorized disposable tests.

## Build and verification

1. Run `corepack yarn install --immutable` from the repository root.
2. Run `corepack yarn workspace @sprout/web check`.
3. Install the three Playwright engines and run `yarn workspace @sprout/web test:e2e`. The runner uses a production build.
4. Capture source comparisons with `yarn workspace @sprout/web exec node scripts/capture.mjs` while the production server is running. Run the throttled Chromium performance script separately from browser suites to avoid resource contention.
5. Run `infra/appwrite/tf.sh staging validate`, then a complete staging plan with both required Terraform credentials. Review the saved plan before applying.
6. Confirm the plan preserves existing projects, buckets, native auth/platform settings, functions, and manual-transactions resources. Do not apply an old configuration snapshot that proposes deleting unrelated resources.

Targeted staging applies provisioned website resources without organization-wide changes. A full production refresh/plan subsequently completed using the existing project credential and a temporary read-only organization key. That plan includes unrelated native authentication and function adoption changes, so a separately reviewed website-only plan was applied. A targeted apply is not evidence of zero drift across the whole project. The sanitized review is in [production-terraform-review.json](evidence/production-terraform-review.json).

WAF rule IDs share a global namespace. Production uses its site ID plus endpoint; the existing staging IDs are retained. The bridge never deletes remote rules or tables when Terraform tracking entries are replaced.

## Staging deployment

The source root is `./`; install `corepack yarn install --immutable`; build `corepack yarn workspace @sprout/web build`; output `./apps/web/.output`; framework `tanstack-start`; SSR; Node 22. Default start command is used.

The branch `codex/sprout-clear-sky` is allowed by the site trigger filters. Pushes build a non-active branch preview; `main` is the production branch. A direct VCS deployment can also target the reviewed branch/commit with `activate=false`.

Verify the hosted build rather than inferring success from a local build. Check `/`, nested pages, both compatibility redirects, 404, fonts, brand downloads, and the sitemap. Confirm each form uses the selected staging origin and database. Exercise edge rate limiting: the sixth matching POST from one client IP in a fixed 60-second window must return 429 with retry guidance. Repeat after the window resets.

Use fictional `example.test` addresses for live tests. Inspect records through authorized access; prove anonymous clients cannot read private records or create rows; replay requests; then delete test rows and verify they are absent. Do not export unrelated rows.

## Public activation

Before activation, complete [the internal review](internal-review.md), assign an operator to the inquiry queue, and confirm origin, indexing, rate limits, privacy, and asset checks. This review record stays in the repository; no review banners belong in the published website. Website acceptance cannot verify the mobile app's 24-hour deletion or other intended launch commitments.

Apply a reviewed production Terraform plan using production credentials. Create a deployment from the tested release commit and verify the same hosted checks. Only then activate it. Do not merge to `main` merely to obtain a preview: Appwrite can automatically activate deployments triggered by its configured production branch.

## Rollback

Published November 9, 2026: https://getsprout.appwrite.network, active deployment `6af1efadbc0574af4565`, tested source commit `cca23a0f47b92f114a699cef7786bea02b3b8ca6`. The prior active deployment `6af0f34ec8e168e35a1c` is the rollback target. Public browser, forms, crawler, and asset checks passed; see [validation.md](validation.md). Michael accepted the pre-launch copy, policies, inquiry ownership, and disclosed VoiceOver limitation before activation.

The source remains in the isolated `codex/sprout-clear-sky` branch and PR #3. No merge to `main` was performed; several legacy Appwrite functions also deploy from that branch. Review their build impact before merging rather than using an unreviewed main-branch push to redeploy the website.

Record the current active deployment ID before publication. If acceptance fails, keep the previous active deployment and fix the branch. If a newly activated site regresses, reactivate the recorded previous ready deployment through Appwrite Sites. Do not roll back by deleting tables, changing native app resources, or destroying Terraform state. New form tables are protected with `prevent_destroy`; preserve accepted submissions. After a rollback, verify the public origin, forms, and crawler behavior again.
