# Review-Checklist Bootstrap Prompt (v1)

Paste everything below this line into Claude Code from the repository root. Prerequisite: the repo should already have a good `CLAUDE.md` (run the CLAUDE.md bootstrap prompt first if not — this prompt builds on it and must not duplicate it).

---

You are going to produce this repository's **review checklist**: a project-specific skill at `.claude/skills/review-checklist/SKILL.md` that encodes the failure modes this codebase _actually has_, for use by the shared `code-review` skill. Do not write any checklist content until Phase 3.

## Mode detection

Check for an existing review-criteria file: `.claude/skills/review-checklist/SKILL.md`, `.claude/commands/review-changes.md`, or similar.

- **None exists** → **CREATE mode.**
- **One exists** → **IMPROVE mode**: verify every claim in it against the current code (dead guards die, line references move, "known-live bugs" get fixed); preserve verified rules; fill gaps found in Phase 1; report Fixed / Added / Kept / Removed with file:line evidence. Before restructuring, grep the repo for references to its section numbers — if load-bearing, map content onto the existing structure. If the existing file mixes procedure (output format, scope rules) with criteria, note that the procedure now lives in the shared `code-review` skill and propose (don't silently perform) extracting it, keeping only project-specific overrides.

## Phase 1 — Mine the failure modes (read, don't write)

A review checklist is only as good as the failures it encodes. Hunt them in this order — highest-yield sources first:

1. **The bug tracker / postmortems** (`docs/bugs/`, `BUG-TRACKER.md`, issue history): every recorded bug with a root cause is a candidate rule. The "why not caught" column is gold — it tells you what a reviewer must look for.
2. **Git history**: `git log --oneline --grep="fix" -40` (and "revert", "hotfix"). Read the fix commits — each one shows a failure mode and its shape in a diff.
3. **CLAUDE.md invariants and gotchas**: these are your criteria _index_, not content to restate. For each invariant, your job is to derive the **diff-level predicate**: what does a violating change look like in a code review? (CLAUDE.md says "store UTC, render local"; the checklist says "flag any new date comparison mixing an aware and a naive value, or assuming the machine clock is X.")
4. **The danger inventory** — read the code hunting for these structural risk classes, and verify each suspicion by reading the actual implementation:
   - **Concurrency boundaries**: threads/workers touching UI or shared state; missing guards allowing double-start; async races.
   - **Time semantics**: aware/naive mixing, wall-clock _equality_ checks (sleep overshoot loses the whole window), machine-local assumptions, DST/date-line exposure.
   - **Secrets and their blast radius**: where credentials live (plaintext files, env), and — critically — **every sink that publishes** (loggers that fan out to files/UI, error messages, commit messages, third-party calls). The rule shape: "treat everything passed to `<logger>` as published."
   - **Boundary parsing**: unchecked indexing into user/file input, `int()` on free text, truthiness checks that never fire on the actual type (a paginated/lazy collection that's never falsy — a **dead guard** is a checklist entry, verified against the library's real behavior).
   - **Packaging/build quirks**: frozen builds (`__file__` assumptions, hidden imports, windowed-mode invisible tracebacks), monorepo alias rules, dynamic imports.
   - **CI/workflow blast radius**: steps that delete releases/tags, auto-bump versions (hand edits collide), rewrite history, or echo env into logs — anything where a small diff has destructive reach.
   - **Enforcement geography**: where authz is _really_ enforced (RLS, data layer, CI) vs. cosmetically (UI gates) — reviews must check the real layer.
5. **The doc-governance system**, if any (docs-ship-with-code rules, SDS section maps, test READMEs, roadmap conventions): derive the **mechanical obligation table** — "changed path X ⇒ doc Y must also appear in the diff." Only include obligations the project's own rules actually state.
6. **Companion tooling**: existing test/eval/coverage commands or agents the review should conditionally hand off to, with skip conditions (token discipline — never run a coverage companion on a docs-only diff).

## Phase 2 — Synthesis check (answer briefly in your reply)

1. What are this codebase's 3–6 _recurring_ failure classes, each backed by at least one real instance (bug ID, fix commit, or live code you can cite)?
2. What is the single most dangerous thing a plausible-looking diff could do here (the money path, the release-deletion step, the paper/live flag)?
3. Which CLAUDE.md invariants translate into diff-level predicates, and what does each violation _look like_ in a diff?
4. Does the project define an integration target / base-branch rule the shared skill must be told about?

If a suspected failure mode can't be verified in code, ask the human rather than encoding folklore.

## Phase 3 — Write the checklist

### Hard rules

- **Every rule passes the concrete-mechanism test**: it names the concrete input, timing, or state that produces wrong behavior. "Be careful with threads" fails; "Tkinter widgets may only be mutated from the creating thread; flag worker-thread calls into `AppUI.log_message`" passes.
- **Rule anatomy** (use for each): _the risk and why it's live here_ (cite bug ID / file:line / commit) → _what to flag in a diff_ (predicates: "flag when a diff adds/changes/removes…") → _accepted fix shape_ when one is established (e.g., "worker pushes onto a queue; main thread drains via `root.after`").
- **Reference CLAUDE.md, don't restate it.** Cite invariant/§ numbers; your added value is the diff-level predicate and fix shape, not the fact.
- **Verified, not remembered**: every file path, line behavior, dead guard, and CI step claim checked against current code this session. Line numbers drift — prefer symbol names (`start_activity`, `_load_login_state`) over bare line numbers where possible.
- **Severity guidance where it's non-obvious**: mark which rule classes are Critical/High by default (secret publication, destructive CI edits, assertion-weakening) so the shared skill grades consistently.
- **Include only sections that apply.** A web app with no frozen build gets no freeze-safety section. Padding with inapplicable categories teaches reviewers to skim.
- **Budget**: aim for 60–150 lines. This loads on every review.

### Skeleton (adapt; ordering = danger order for this repo)

```markdown
---
name: review-checklist
description: <repo>-specific review criteria — <the 4–6 danger areas, named concretely>. Use when reviewing a diff, PR, or proposed change in this repository, alongside the shared code-review skill.
---

# <repo> review checklist

Apply on top of ordinary correctness review. These encode the failure modes this
codebase actually has. Report a finding only when you can name a concrete input
or timing that produces the wrong behavior.

## <Danger area 1 — most dangerous first> ← risk + evidence, flag-when predicates, fix shape

## <Danger area 2> …

## Project review settings ← integration target/base-branch rule; severity defaults

## Doc-sync obligations ← the mechanical path⇒doc table (only if the project has the rule)

## Companion handoffs ← conditional gates (test/eval commands) + skip conditions
```

## Phase 4 — Self-audit before delivering

- [ ] Every rule names a concrete mechanism; zero generic advice
- [ ] Every rule cites evidence: bug ID, fix commit, or file/symbol verified this session
- [ ] Dead guards / known-live bugs re-verified against current code (IMPROVE mode: the bug may have been fixed since — a stale "known bug" entry is worse than none)
- [ ] No restated CLAUDE.md facts — references only, plus the diff-level predicate
- [ ] Doc-sync table derived only from rules the project actually states
- [ ] Inapplicable risk classes omitted entirely
- [ ] Description frontmatter names the danger areas concretely (it's what triggers the skill)
- [ ] (IMPROVE mode) Change report with file:line evidence for every Fixed/Added; failure-cited rule removals justified by a verified-dead cause

Deliver: the SKILL.md written to `.claude/skills/review-checklist/SKILL.md`, your Phase 2 answers, the change report (IMPROVE mode), and open questions.

Maintenance rule to leave with the human: **every new row in the bug tracker is a candidate checklist rule — add it while the root cause is fresh; when a failure mode is structurally eliminated (not just fixed once), delete its rule the same day.**
