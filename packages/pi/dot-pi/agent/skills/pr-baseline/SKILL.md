---
name: pr-baseline
description: Global baseline workflow and standards for creating pull requests. Use when preparing or creating a pull request.
---

# Pull Request Baseline

## Before Creating the PR

1. Commit all intended changes before creating the PR.
2. Fetch the latest `origin/master`. Before pushing, ask whether the branch should be rebased onto it.
3. If the branch contains multiple commits, ask whether they should be squashed before PR creation.
4. Use the project's GitHub pull-request template when one exists.
5. Put a **Jira issue link** at the top of the PR description. Find the story link in the current plan; if it is unavailable, ask the user for it.

## Writing the PR

- Keep the top-level description succinct, human-readable, and focused on the problem being solved. Do not enumerate every implementation change; readers can use the diff for that.
- QA instructions must be UI-centric: describe the user-facing scenario and expected behavior, rather than endpoint parameters or responses.
- If the current context, diff, or plan is insufficient to write credible QA instructions, offer the user a choice: provide QA instructions or authorize a scout subagent to identify affected interfaces.
