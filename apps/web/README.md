# Sprout website

The Clear sky marketing website uses TanStack Start, React, Vite/Nitro, and compiled Tailwind. Run commands from the repository root with Node 22.12+ (Node 24 also supported) and Corepack/Yarn 4.9.2.

```sh
corepack yarn install --immutable
corepack yarn web:dev
corepack yarn web:check
corepack yarn workspace @sprout/web exec playwright install chromium firefox webkit
corepack yarn workspace @sprout/web test:e2e
```

Browser tests target a production build. `web:check` builds first; Playwright starts the production server if no local server is running. Run `yarn workspace @sprout/web start` to inspect the built SSR site.

Copy `.env.example` to a local ignored environment file for local staging submissions. The development server reads Vite environment files; the production Node entrypoint requires runtime variables supplied by the process/host. Do not prefix credentials with `VITE_`. Hosted Appwrite SSR uses its injected endpoint/project and per-request `x-appwrite-key`, never a browser SDK or stored production key. Each environment needs the exact site origin, marketing database ID, and table IDs. Until configured, endpoints return a retryable error and never claim a submission was saved.

The waitlist and inquiry pages work without an account. No outbound email is sent. Review private submissions in the Appwrite Console. Deletion requests require operator identity verification before account changes.

See [the implementation plan](../../docs/web/implementation-plan.md), [validation evidence](../../docs/web/validation.md), and [release runbook](../../docs/web/release.md). Website infrastructure is defined under `infra/appwrite`, including firewall rules and the narrowly scoped SSR key. Public indexing is opt-in with `VITE_SITE_INDEXABLE=true`; canonical and sitemap origins use `VITE_SITE_ORIGIN`/`SPROUT_SITE_ORIGIN`.

The original starter's MIT license is retained in `LICENSE`. Font and direct software notices are served from `/licenses`. Reference screenshots are not shipped in the website bundle.
