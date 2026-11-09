# PR #3 merge acceptance — November 9, 2026

Michael authorized resolving remaining blockers and merging PR #3 while preserving unrelated native and backend changes.

## Preservation and deployment scope

- Work remains in the isolated `codex/sprout-clear-sky` worktree. The original `codex/sprout-ui-foundations` checkout has staged, unstaged, and untracked work; its logical index and file hashes were snapshotted before merge work. Do not stash, reset, switch, commit, or pull in that checkout.
- The PR changes no files under `apps/ios`, `apps/android`, `services/api`, or `infra/lib`. Existing Appwrite manual-transaction prerequisites are retained as documented in the implementation plan.
- AWS deploy workflows now exclude both `infra/appwrite/**` and `services/appwrite/**`. Workflow-only edits do not trigger CDK deployment. A glob evaluation against the complete PR diff matched no AWS deployment paths; changes to actual AWS infrastructure and API sources still match.
- Both Appwrite HCP workspaces use local execution with automatic apply disabled. The legacy remote workspace also has automatic apply disabled. No full Terraform apply is part of this merge.
- Five production Appwrite functions track `main` without branch/path filters. Before merging, temporarily set only their branch filters to `**` plus `!main`, preserving all other settings and active deployment IDs. Wait for the website merge deployment, verify that no backend merge deployment was created or activated, then restore the exact original filters and compare settings again.
- Let the production and staging websites build the merged `main` commit. Verify the published origin and both forms after the new build activates. Retain the prior tested Clear sky deployment as a rollback target.

## Checks observed before final merge preparation

Web CI passes: strict TypeScript, lint, 18 unit tests, immutable install, production build, and 33 browser checks. GitGuardian and Terraform Cloud checks pass. Native GitHub jobs correctly skip because no native sources changed.

The separate Bitrise Android release report failed fetching `org.robolectric:android-all-instrumented:15-robolectric-13954326-i7`; 26 of 27 tests passed. This is an artifact-fetch failure, not evidence of a changed native test implementation. A new head commit reruns that external check. The legacy Appwrite Speech recognition preview fails because its existing `npm run setup` command has no corresponding root script. It has no active deployment. Do not invent a setup script or change backend function source merely to green that unrelated preview.

## Completion evidence

Record the final CI results, merge commit, website deployments, backend preservation comparison, original-checkout comparison, and restored trigger filters after the merge.
