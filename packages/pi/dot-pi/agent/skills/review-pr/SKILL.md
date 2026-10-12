---
name: review-pr
description: >
  Review a GitHub pull request and print a detailed analysis to the terminal. Use this skill
  whenever the user invokes /review-pr, asks to "review PR #N", "review pull request N", "look at
  PR 1234", "can you review this PR", or provides a GitHub PR URL and wants feedback. Works with
  just a number (#7809 or 7809), a full URL, or no argument (reviews the current branch's PR).
  Output is always local — never posts comments to GitHub.
---

# PR Review Skill

Review a GitHub pull request thoroughly and print the analysis to the terminal. Never post anything
to GitHub — this is a local, read-only review.

All `gh` commands **must** be prefixed with `op run -- ` (e.g., `op run -- gh pr view ...`).

## Step 1: Resolve the PR identifier

Parse the user's input:

- **Full URL** (e.g., `https://github.com/org/repo/pull/123`) — extract `org/repo` and PR number directly.
- **`repo/number`** (e.g., `dialer-web/7708`) — treat as `doximity/<repo>`, constructing the URL as `https://github.com/doximity/<repo>/pull/<number>`.
- **Number only** (e.g., `7809` or `#7809`) — determine the repo from git (see below), then use that number.
- **No argument** — determine the repo from git, then find the PR for the current branch using `op run -- gh pr view --json number`.

**Detecting the repo from git:**

```bash
REMOTE=$(git config branch.master.remote 2>/dev/null || echo "origin")
REMOTE_URL=$(git remote get-url "$REMOTE")
```

Convert the remote URL to `org/repo` format:
- SSH `git@github.com:org/repo.git` → `org/repo`
- HTTPS `https://github.com/org/repo.git` → `org/repo`

Strip the `.git` suffix if present.

## Step 2: Fetch PR data

```bash
# Full PR metadata
op run -- gh pr view <number> --repo <org/repo> \
  --json title,body,state,author,createdAt,comments,reviews,labels,assignees,baseRefName,headRefName,url

# Full diff
op run -- gh pr diff <number> --repo <org/repo>
```

Also fetch any linked issues if mentioned in the PR body (look for `Fixes #N`, `Closes #N`, etc.):

```bash
op run -- gh issue view <N> --repo <org/repo> --json title,body
```

## Step 3: Load project conventions (if available)

If a `CLAUDE.md` or `AGENTS.md` file exists in the current working directory or its `.claude/`
subdirectory, read it to understand project-specific patterns, conventions, and gotchas before
evaluating style and architecture. Don't fail if these files don't exist.

## Step 4: Print the review

Output a structured review directly to the terminal. The review is organized as inline comments
grouped by file — mirroring how a GitHub code review actually looks. Follow this format:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PR Review: #<number> — <title>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
URL:     <url>
Author:  <author>
Branch:  <base> ← <head>
State:   <state>

── <path/to/file.rb> ──────────────────────────────────────────────
Line <N> · [<label>]
  ❯ <quoted code snippet — the relevant line(s) from the diff>
  <Your comment: what the issue is, why it matters, and what to do instead.>

Line <N> · [<label>]
  ❯ <quoted code snippet>
  <comment>

── <path/to/another_file.rb> ──────────────────────────────────────
Line <N> · [<label>]
  ❯ <quoted code snippet>
  <comment>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Summary
<2–4 sentences: what the PR does and why, based on the description and diff>

## Verdict
<Approve / Request Changes / Needs Discussion>
<bulleted list of the most important action items, if any>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Comment labels

Use one of these labels for each inline comment:

| Label | Use for |
|---|---|
| `Bug` | Logic errors, incorrect behavior, unhandled edge cases |
| `Security` | Auth bypasses, PHI/PII exposure, injection risks, hardcoded secrets |
| `Suggestion` | Better approaches, design concerns, missing abstractions |
| `Nitpick` | Minor style or convention deviations (low priority) |
| `Question` | Unclear intent where you need the author's reasoning |
| `Praise` | Something done particularly well — good to call out |

### Guidelines

- Only leave a comment when there is something genuinely worth saying. Don't pad.
- Quote the specific line(s) from the diff that prompted the comment.
- Be direct: name the problem, explain why it matters, suggest what to do.
- Skip files with no comments entirely — don't list them with "looks good".
- Inline comments are the primary output. The Summary is a brief closing note, not a repeat of
  every issue — use it to provide overall context or flag cross-cutting concerns not tied to a
  single line.

## Step 5: Add the review to Plannotator

Use Plannotator for a GitHub-style, inline code-review UI. If the user has provided **Plannotator External Review Comments** instructions for a live session, post the review's findings into that session rather than merely opening the PR.

1. Fetch the current session diff from its supplied base URL (`GET /api/diff`) and use its `rawPatch` to verify each file path, line number, and side before posting. The session diff is authoritative because the user may have changed the base or diff type.
2. Delete only prior annotations from this skill's source; never delete annotations from any other source:

   ```bash
   curl -s -X DELETE "<base-url>/api/external-annotations?source=pi-review-pr"
   ```

3. Batch-post the inline findings to `POST <base-url>/api/external-annotations`, using:
   - `source: "pi-review-pr"`
   - `author: "Pi review-pr"`
   - `scope: "line"`, exact diff `filePath`, `lineStart`, `lineEnd`, and `side` for inline comments
   - `scope: "general"` for the overall verdict or cross-cutting feedback
   - `type: "concern"` for Bugs and Security findings; `type: "comment"` for other feedback

   Include only genuine findings, preserving the same comments and labels from the terminal review. Use a suggestion only when a precise replacement is appropriate.

4. Report how many annotations were posted and surface any API validation error. Do not claim success until the API returns `201`.

If no live-session instructions have been provided, open the PR for the user's manual review instead:

```bash
plannotator review <url>
```

Use the PR URL resolved in Step 1. This command opens the browser and blocks until the user approves, annotates, or closes the review. To add agent findings inline on a later pass, ask the user to use Plannotator's **copy agent instructions** action and provide the resulting session instructions.
