---
name: upgrade-rails
description: Plan and execute a safe Ruby on Rails version upgrade. Use when upgrading Rails between supported minor or patch versions, researching Rails compatibility changes, generating framework defaults, validating dependency compatibility, or preparing upgrade commits and CI validation.
---

# Upgrade Rails

Perform Rails upgrades as an evidence-based, incremental compatibility migration. Keep dependency resolution, framework-default behavior changes, and deployment validation distinct.

## Origin

This skill was created from the following request:

> We are going to handle this story: https://doximity.atlassian.net/browse/CSCT-1011
>
> Can you use researcher to determine relevant breaking changes for a rails 8.0 -> 8.1 upgrade, scout to determine how those changes affect us, and oracle to verify results.
>
> We'll then need to create a plan for what changes need to occur in this app for an upgrade.

## First: establish scope

1. Read the issue/story and extract the required Rails range, EOL/deploy deadline, and acceptance criteria.
2. Inspect the current branch, working tree, `Gemfile`, `Gemfile.lock`, Ruby-version files, `Dockerfile`, CI configuration, `config/application.rb`, environment files, initializers, and test commands.
3. Ask only decisions that code cannot answer. Default questions:
   - Which exact supported Rails patch is the target? Prefer the latest version allowed by the story.
   - Should the first upgrade retain the existing `config.load_defaults` version? Recommended: yes; enable new defaults in small follow-up commits.
   - Are external clients known to use legacy query-string formats? If not known, identify the responsible API/integration owners.
4. Do not overwrite application configuration wholesale with `bin/rails app:update`.

## Required evidence workflow

When delegated research is authorized, use these independent roles:

1. **Researcher:** use official Rails release notes, upgrade guide, changelogs, and security releases to list behavior changes, removals, and new defaults.
2. **Scout:** map each candidate change to exact repository paths, dependency versions, runtime/deployment constraints, and existing tests.
3. **Oracle:** reconcile the reports, reject unsupported conclusions, distinguish required code changes from runtime checks, and rank risks.

Record the findings in a plan before modifying production code. Do not claim an API is unused merely because a limited search has no match; private gems and external callers require runtime or owner validation.

## Commit strategy

Use separate commits:

1. **Compatibility dependency commit**
   - Bump Rails to the exact target in `Gemfile`.
   - Run Bundler in the project-supported Ruby/container environment, not a system Ruby that does not match the repository.
   - Inspect all lockfile changes and vendored gems when `vendor/cache` is tracked.
   - Upgrade dependencies that explicitly reject the target Rails version or emit upgrade deprecations.
   - Keep the old `config.load_defaults` value.
2. **Regression fixes**
   - Add narrowly scoped fixes for observed changed behavior and tests that demonstrate the prior contract.
3. **One commit per framework-default risk group**
   - Generate the new defaults initializer, but enable only one coherent group at a time.
   - Run focused tests after every group.
4. Push after each meaningful commit so credentialed CI can validate the production build.

Use conventional commits only for the first branch commit; use `fixup:` titles for later commits when project convention requires it.

## Dependency and runtime validation

Run the repository-supported equivalents of:

```bash
bundle update rails
git diff -- Gemfile Gemfile.lock vendor/cache
a supported-container-command bin/rails runner 'Rails.application.eager_load!'
a supported-container-command bundle exec rspec <focused paths>
a supported-container-command env SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile
```

Validate these separately:

- Rails boot and eager load.
- Job adapter and background-job library compatibility.
- ORM/auditing/serialization libraries that cap supported Active Record versions.
- Private/internal gem compatibility, ideally via Bundler resolution, boot, and CI.
- Production Docker build and asset precompile. If the local Docker build cannot access a private gem registry, do not add secrets or weaken the Dockerfile; push the branch and use the credentialed CI build as the gate.
- Full backend and frontend suites. Classify failures by root cause; stale local services (for example, Elasticsearch aliases) are environment blockers, not proof of a Rails regression.

## Run `app:update` safely

First inspect only:

```bash
bin/rails app:update --pretend
```

Then generate missing defaults without overwriting existing files:

```bash
bin/rails app:update --skip
```

This can create unrelated files (for example, CI scripts). Remove only newly generated, out-of-scope files after confirming they are untracked/generated. Keep and commit `config/initializers/new_framework_defaults_<version>.rb`.

Do not set `config.load_defaults <new-version>` until every intended default is enabled and validated; then make that a separate cleanup commit.

## Framework-default risk groups

Use the generated initializer as the source of truth for the target Rails version. Typical groups:

1. **Active Record ordering** — enable required finder ordering; audit model/relation `first`, `last`, `second`, etc. String/array calls are unrelated.
2. **JSON serialization** — enable any response/JavaScript escaping changes; exercise JSON endpoints and error responses.
3. **Redirect safety** — enable path-relative redirect protection; test controller redirects, especially action-based and externally supplied destinations.
4. **Rendering and forms** — enable view dependency tracking and hidden-field behavior changes; audit Rails form helpers and run asset/template checks.
5. **Runtime performance** — assess optional JIT/runtime settings only using production-like memory and latency measurements. Do not enable an option merely because it is available, and do not invent it if it is absent from the generated defaults initializer.

## Rails 8.0 → 8.1 case-study findings

For this specific transition, investigate:

- Removed support for leading-bracket parameter names and semicolon query separators. Source inspection cannot prove external clients do not send them.
- Removed deprecated APIs/configuration; inspect public application code but retain private-gem risk until resolved/booted.
- Possible alphabetical `schema.rb` output. Commit a schema diff only if an intentional schema dump produces it; do not absorb unrelated schema changes.
- Active Storage/libvips security and image processing behavior. Exercise attachments and use the production image path; do not add image-processing dependencies without actual variant usage.
- `Hash#to_query` compatibility where external APIs distinguish a blank value (`key=`) from a valueless key (`key`). Preserve required contracts by normalizing `nil` to `""` and add a focused regression test.
- Sidekiq adapter compatibility/deprecation; update the Sidekiq family only if the resolved version requires it.
- Gems with explicit Active Record upper bounds (for example, auditing libraries); upgrade to the first compatible release and rerun boot/tests.

## Generic decisions already resolved in the case study

- Target the latest story-approved Rails patch, rather than the first release in the range.
- Retain existing framework defaults in the first dependency commit.
- Create separate risk-group commits for defaults.
- Treat local Docker registry-auth failure as a CI-validation concern, not a reason to embed registry credentials.
- Fix observed upgrade regressions before moving to defaults.
- Confirm legacy external-query usage with client owners rather than assuming source searches are conclusive.

## Completion checklist

Before requesting review, report:

- Target Rails/Ruby versions and every forced dependency upgrade.
- Commits and pushed branch/PR.
- Exact passing focused tests, frontend tests, asset precompile, and CI/Docker status.
- Any failures classified as environment-only, with their remediation owner.
- Defaults enabled, intentionally deferred, and remaining `app:update` cleanup.
- External integration confirmations still pending.
