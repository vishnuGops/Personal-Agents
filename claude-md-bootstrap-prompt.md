# CLAUDE.md Bootstrap & Improvement Prompt (v2)

Paste everything below this line into Claude Code from the repository root.

---

You are going to produce the single most valuable file in this repository: a `CLAUDE.md` that makes every future AI coding session productive from message one. Work through the phases below in order. Do not write any CLAUDE.md content until Phase 3.

## Mode detection

First check whether a `CLAUDE.md` (or `CLAUDE.local.md`, or nested `CLAUDE.md` files in subdirectories) already exists anywhere in the repo.

- **If none exists** → **CREATE mode**: build one from scratch.
- **If one exists** → **IMPROVE mode**: treat the existing file as a draft written by a previous engineer. Preserve its correct, project-unique knowledge; verify every claim in it against the actual code; delete anything stale, generic, or duplicated; fill gaps. Report what you changed and why at the end.

### IMPROVE mode — structural-stability check (do this before touching structure)

Before restructuring, renumbering, or reordering an existing CLAUDE.md, **grep the repo for references to it** — section numbers ("§4", "CLAUDE.md §11.5", "claude.md step 2"), heading names, and anchors — across `docs/`, `.claude/commands/`, `.claude/agents/`, bug trackers, roadmaps, and design specs.

- **If section anchors are load-bearing** (cited elsewhere): do NOT renumber or restructure. Instead, map the Phase 3 template's _content requirements_ onto the existing sections, verify and fill gaps in place, and note the deviation in your report.
- **If the repo runs its own doc-governance system** (a token-budget doc, a doc-weighting command, an owner-run pruning process, a documented review gate): defer to it. Do not unilaterally prune content that system manages — flag candidates for the owner instead.
- **If a rule cites a real past failure** (a bug ID, incident, postmortem): it is the highest-value content in the file. Never cut it for length. Only remove it if you verify the underlying cause no longer exists — and say so.
- Structure and line budget are means, not ends. A mature, dense, failure-derived CLAUDE.md that exceeds the budget is better than a tidy one that forgets why rules exist.

## Phase 1 — Discovery (read, don't write)

Build a complete mental model of the project. Read, in roughly this order:

1. **Manifests & lockfiles**: `package.json` / `pyproject.toml` / `Cargo.toml` / `go.mod` etc. — note the real scripts (ALL of them, including test/eval/db utility scripts), dependencies, engines, workspaces/monorepo layout, and `postinstall`-style hooks that affect deploys.
2. **The `.claude/` ecosystem**: `settings.json` (hooks, permissions), `commands/`, `agents/`, `skills/`, MCP config. These are both context (they shape how sessions run) and claims to verify (a CLAUDE.md that references a hook or agent must match what's actually configured). Also check for repo-level agent docs like `AGENTS.md`.
3. **Docs**: `README.md`, everything in `docs/` or `documents/`, ADRs, design specs, API specs, CONTRIBUTING, **bug trackers / postmortem logs** (in CREATE mode, past failures are your best source of gotcha rules). Note which docs are authoritative and current vs. aspirational or stale (cross-check dates and whether the code matches).
4. **Configuration**: framework config, `tsconfig`, linter/formatter configs, `.env.example`, CI workflows, deployment config, database config (schemas, migrations, RLS policies, edge functions).
5. **Entry points & structure**: the main app entry, routing, request-gating layer, and the top 2 levels of the source tree. **Verify framework-level filenames against the actual code, not memory** — frameworks rename things across major versions (e.g., a "middleware" file may now live elsewhere under a different name). List directories and infer each one's role from its _contents_, not its name — a folder labeled "migrations only" may hold functions and tests.
6. **The code itself**: skim enough real source files (10–25, spread across layers) to infer the _actual_ conventions in use: naming, state management, styling, error handling, validation, auth flow, data-fetching, test patterns. Conventions come from observed code, never from the framework's defaults.
7. **Git signal** (if available): `git log --oneline -30` and recently-changed files to see where active development is happening.

While reading, maintain a scratch list of:

- **Invariants** — facts true everywhere (e.g., "all shared domain logic enters via the `@pkg/core` barrel").
- **Gotchas** — anything a competent new engineer would get wrong without being told (non-obvious working directory, env var pairs, fail-open behavior, where enforcement _really_ happens vs. where the UI pretends it does, ports, deploy hooks).
- **Volatile facts** — true today, likely to change (feature flags, commented-out guards, placeholder tabs, "Phase 1 (now)" markers). These get flagged as volatile in the output.
- **Deep-doc pointers** — long reference material that should be _linked_, not inlined.

## Phase 2 — Architecture synthesis

Before writing, answer these for yourself (briefly, in your reply, so the human can correct you):

1. What is this project, in one sentence — and what is its _hard core_, the one problem everything else orbits?
2. What is the request/data lifecycle, end to end, naming the actual files?
3. Where do auth, authorization, and enforcement actually happen — and where do they _not_? (UI gates that are convenience-only while the DB/RLS layer is the real enforcement is exactly the kind of gap CLAUDE.md must capture.)
4. What are the 3–5 architectural decisions someone must respect to not break the project?
5. What would a new senior engineer ask on day one? Those answers are the CLAUDE.md.

If anything critical is ambiguous (two competing patterns, docs contradicting code), **ask the human** before writing rather than guessing.

## Phase 3 — Write the CLAUDE.md

### Hard rules

- **Budget: aim for 150–300 lines for a new file.** Every line costs context in every future session. For an existing mature file, the budget is advisory — the content-quality tests below govern, and failure-derived rules are never cut for length.
- **Only project-unique content.** No generic advice ("write clean code"). No framework defaults.
- **Every command must be real and complete.** Copy commands from the manifest scripts / CI — enumerate the whole script surface (test, e2e, eval, db utilities), don't just list dev/build/lint. For non-obvious scripts, read the script file's header to describe it accurately instead of guessing from its name.
- **Every path must exist.** Verify each referenced file/directory before writing it.
- **Anchor rules to failures where possible.** "Sort by `utcEpochMs` (bug 114)" teaches more than the rule alone; it also protects the rule from future pruning.
- **Link deep docs, don't inline them.** Only `@import` a doc if it is small and needed in _every_ session.
- **Mark volatile facts explicitly**, e.g. "guard currently commented out (**verify before relying on this**)".
- **Prefer tables for role/route/env mappings**, prose for flow, code fences for commands and layout trees.
- **Write in imperative, factual voice.**

### Structure

For CREATE mode, use this skeleton (adapt/omit sections that don't apply). For IMPROVE mode with load-bearing anchors, treat it as a _content checklist_ to map onto the existing layout instead:

```markdown
# CLAUDE.md

One-line project description + pointer to deep design docs.

## Repository Layout ← annotated tree, 2 levels, working-directory note if app is nested

## Commands ← full script surface, verified against manifest

## Required Environment ← every var, one-line purpose, which file it lives in

## Architecture ← auth flow, real vs. cosmetic enforcement, request/data lifecycle with filenames

## Data Model ← models + one-line purpose; where the client/singleton lives

## Feature Notes ← per-feature: what it does, its data flow, its incomplete parts

## Conventions ← observed conventions: styling, state, validation, naming, co-location

## Gotchas & Invariants ← the "you will get this wrong without being told" list, with bug IDs where they exist

## Key Libraries ← only libraries whose role isn't obvious from the name

## Deployment ← platform, cron/hooks, build requirements
```

### Content-quality tests (apply to every candidate line)

1. **The re-explain test**: Would the human have to re-explain this to a fresh session? If no → cut.
2. **The wrongness test**: Would an agent produce wrong code without this line? If no → probably cut. (A cited past failure passes this test automatically.)
3. **The staleness test**: Will this line be false in 3 months? If yes → mark volatile or move to docs/.
4. **The duplication test**: Trivially discoverable in one obvious file? Cut or compress to a pointer — except commands, which agents run constantly.

## Phase 4 — Self-audit before delivering

Run this checklist against your draft and fix failures before showing it:

- [ ] Line budget respected (new files) or deviation justified (mature files)
- [ ] Every command copy-pasteable, correct from the stated working directory, and the script surface complete
- [ ] Every file path verified to exist
- [ ] **Internal-consistency sweep**: every count in a header or sentence matches the list/table it describes ("five test kinds" vs. six rows is exactly the drift this catches); framework file names match the code
- [ ] Claims about `.claude/` hooks, commands, and agents match `settings.json` and the actual files
- [ ] Zero generic advice
- [ ] Real-vs-cosmetic enforcement gaps and fail-open behaviors documented (top-priority content)
- [ ] Volatile facts flagged
- [ ] Deep docs linked, not inlined
- [ ] A brand-new agent reading only this file could: run the app, find any feature's code, and know the 5 rules it must not break
- [ ] (IMPROVE mode) Change report written: **Fixed / Added / Kept / Removed**, each with a one-line reason, and stale facts distinguished from gaps
- [ ] If the repo has a documented doc-change process (changelog, roadmap entries, review gate), follow it for this change too

Then deliver:

1. The final `CLAUDE.md` written to the repo root (or updated in place).
2. Your Phase 2 answers (so the human can correct your understanding).
3. (IMPROVE mode) The change report, plus any deliberate deviations from this prompt and why.
4. A short list of open questions or ambiguities — candidates for the next revision.

Note on verification: if the diff is docs-only, say so — the audit itself is the verification; do not fabricate a test run.

Finally, remind the human of the maintenance rule: **if you correct the agent twice about the same project fact, add it to CLAUDE.md — citing the failure if there is one; when a rule stops being true, delete it the same day.**
