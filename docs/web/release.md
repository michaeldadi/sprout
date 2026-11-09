# Website release and rollback

## Environment configuration

The existing Appwrite sites are staging `6af0f8bf003d74b49da3` and production `6af0f34a002cee7f0cfb`. They use separate projects, databases, state, credentials, and form rows.

Set `marketing_site_origin` in each environment's `.tfvars` to its exact generated primary HTTPS origin, without a path or trailing slash. Set `marketing_site_indexable=true` only for the public production release. Do not reuse `getsprout.io`: its observed site belongs to another product. The connector cannot currently list proxy rules (`rules.read` is missing), so the origins must be read from Appwrite's Sites → Domains UI by an authorized operator.

Terraform creates the runtime variables `SPROUT_MARKETING_DATABASE_ID`, `SPROUT_WAITLIST_TABLE_ID`, `SPROUT_INQUIRIES_TABLE_ID`, and `SPROUT_SITE_ORIGIN`, plus build variables `VITE_SITE_ORIGIN` and `VITE_SITE_INDEXABLE`. Hosted SSR uses the injected project/endpoint and `x-appwrite-key`; no permanent website API key is stored.

`APPWRITE_API_KEY` and `APPWRITE_ORGANIZATION_API_KEY` authenticate the existing Terraform root. The bridge also accepts an optional short-lived `APPWRITE_WEBSITE_API_KEY` for site/firewall API operations when the infrastructure credential lacks those scopes. Never put these values in configuration or logs. The temporary website credential needs only `sites.read`, `sites.write`, `wafRules.read`, `wafRules.write`; add `rows.read`/`rows.write` only for authorized disposable tests.

## Build and verification

1. Run `corepack yarn install --immutable` from the repository root.
2. Run `corepack yarn workspace @sprout/web check`.
3. Install the three Playwright engines and run `yarn workspace @sprout/web test:e2e`. The runner uses a production build.
4. Capture source comparisons with `yarn workspace @sprout/web exec node scripts/capture.mjs` while the production server is running. Run the throttled Chromium performance script separately from browser suites to avoid resource contention.
5. Run `infra/appwrite/tf.sh staging validate`, then a complete staging plan with both required Terraform credentials. Review the saved plan before applying.
6. Confirm the plan preserves existing projects, buckets, native auth/platform settings, functions, and manual-transactions resources. Do not apply an old configuration snapshot that proposes deleting unrelated resources.

Targeted staging applies were used during this implementation because only the existing project key and narrower short-lived website credentials were available. They provisioned and verified website resources without making organization-wide changes. A targeted plan is not evidence of zero drift across the whole project. Complete full-environment refresh/plan before production application.

## Staging deployment

The source root is `./`; install `corepack yarn install --immutable`; build `corepack yarn workspace @sprout/web build`; output `./apps/web/.output`; framework `tanstack-start`; SSR; Node 22. Default start command is used.

The branch `codex/sprout-clear-sky` is allowed by the site trigger filters. Pushes build a non-active branch preview; `main` is the production branch. A direct VCS deployment can also target the reviewed branch/commit with `activate=false`.

Verify the hosted build rather than inferring success from a local build. Check `/`, nested pages, both compatibility redirects, 404, fonts, brand downloads, and the sitemap. Confirm each form uses the selected staging origin and database. Exercise edge rate limiting: the sixth matching POST from one client IP in a fixed 60-second window must return 429 with retry guidance. Repeat after the window resets.

Use fictional `example.test` addresses for live tests. Inspect records through authorized access; prove anonymous clients cannot read private records or create rows; replay requests; then delete test rows and verify they are absent. Do not export unrelated rows.

## Public activation

Before activation, record internal review of product/security claims and legal copy, assign an operator to the inquiry queue, and confirm origin, indexing, rate limits, privacy, and asset checks. This review record stays in the repository; no review banners belong in the published website.

Apply a reviewed production Terraform plan using production credentials. Create a deployment from the tested release commit and verify the same hosted checks. Only then activate it. Do not merge to `main` merely to obtain a preview: Appwrite can automatically activate deployments triggered by its configured production branch.

## Rollback

Record the current active deployment ID before publication. If acceptance fails, keep the previous active deployment and fix the branch. If a newly activated site regresses, reactivate the recorded previous ready deployment through Appwrite Sites. Do not roll back by deleting tables, changing native app resources, or destroying Terraform state. New form tables are protected with `prevent_destroy`; preserve accepted submissions. After a rollback, verify the public origin, forms, and crawler behavior again.
