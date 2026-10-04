# Independent implementation audit — 2026-10-03 (evening pass)

**Method:** fresh read of the actual code, git history, and running tests —
not a summary of `COORDINATION.md`'s or `docs/platform-audit-findings.md`'s
own claims. Where this doc confirms something those two already said, it's
because it was independently re-derived, not copied. Every finding below
has a file:line or command-output citation; nothing here is inferred from
memory, chat history, or prior sessions' self-reports.

**A methodology note, because it's relevant to how much to trust parallel
AI-assisted audits generally:** this pass started by fanning out five
parallel sub-agents (one per subsystem). Four of the five, when asked a
*second* time to repeat their findings in full, got confused about their
own identity — each had inherited the coordinating session's full context
(including the fact that it had spawned five agents), and on resumption
each one concluded *it* must be the coordinator, not one of the five
workers, and refused to "fabricate" a report that was, in fact, its own
already-completed work. This is a reasonable safety instinct (don't
impersonate a role you're not sure you're in) but it meant most of the
detailed sub-reports were unrecoverable. Rather than fight that, this doc
is built from direct, first-hand verification of the sub-agents' headline
leads — reading the actual source, running the actual tests, checking the
actual git/PR state. Where a sub-agent's lead turned out to be imprecise or
wrong once checked (see Component 6 note below), it was dropped rather than
repeated. That back-and-forth is its own small data point: a single careful
pass against ground truth caught things a prose summary would have
missed or gotten wrong.

---

## Headline finding: a documentation claim of "resolved" describes code that only exists on an unreviewed, unmerged PR

The most recent commit on `main`, `4846a22` ("Close the experiments.ts vs
entry-paths.ts conflict flagged Sept 30"), touches **exactly one file**:
`docs/closed-loop-spec.md` (431 insertions, 0 other files — confirmed via
`git show 4846a22 --stat`). It rewrites that spec's conflict #4 to say:

> **RESOLVED in M4 (self-healing-hardening follow-up).** ... `experiments.ts`
> now also exports `evaluateProportionExperiment` ... `entry-paths.ts` calls
> it instead of maintaining its own private copy. (`docs/closed-loop-spec.md:14`)

Checked directly against `orchestrator/src` on `main`:

- `grep -rn "evaluateProportionExperiment" orchestrator/src` → **zero matches,
  anywhere.** It doesn't exist in `experiments.ts`, isn't imported by
  `entry-paths.ts`, isn't referenced in any test.
- `orchestrator/src/entry-paths.ts`'s only import is `from "./metrics"`
  (`entry-paths.ts:6-7`) — no relationship to `experiments.ts` at all on `main`.

The code the doc describes is real, but it lives on the `self-healing-hardening`
branch (`orchestrator/src/experiments.ts:236` defines
`evaluateProportionExperiment`; `orchestrator/src/entry-paths.ts:9,250` calls
it there) — confirmed by reading that worktree directly. That branch is
**not merged**: `git merge-base --is-ancestor self-healing-hardening
origin/main` fails, and it's 4 commits ahead of `main` with an **open,
unreviewed PR** (`orchestrator` PR #6, opened 2026-10-02T22:38:38Z, still
open as of this audit — confirmed via `gh pr list --state all`).

So: on `main`, right now, the conflict is **not** resolved in code. The spec
says "RESOLVED" in the past tense with no caveat that the fix is sitting in
review. `COORDINATION.md:1020` (the "2026-10-03 reconciliation pass," written
before `4846a22`) still says this conflict is "still open" — so the two docs
in this repo currently disagree with each other, and neither one's current
wording accurately describes `main`: one is stale-in-the-"open" direction,
the other is premature-in-the-"resolved" direction.

**This generalizes beyond this one conflict.** PR #6 also carries three other
real, tested features that don't exist on `main` yet: cross-source dedup (same
Sentry issue arriving via two paths), a canary→autonomy trust-feedback loop,
and rejection memory for the evolution engine (`git log origin/main..self-healing-hardening
--oneline` on the orchestrator worktree: `f49c3e2`, `4b4980f`, `4c946fc`,
`6ad421c`). None of this is lost — it's sitting in a real, open, reviewable
PR, which is this project's own stated discipline working as designed — but
anyone reading `docs/closed-loop-spec.md` on `main` today would reasonably
believe `evaluateProportionExperiment` already exists there. It doesn't.

**Recommendation:** either merge PR #6, or edit `docs/closed-loop-spec.md`'s
conflict #4 to say "fix implemented, pending review in PR #6" rather than
"RESOLVED." Five-minute fix, meaningfully more honest.

---

## New bug (not previously flagged anywhere): autonomy decision can misattribute which area governs it

`orchestrator/src/autonomy.ts:98-108`:

```ts
const effectiveLevel =
  change.filesChanged.length === 0
    ? config.defaultLevel
    : change.filesChanged
        .map((f) => resolveFileLevel(f, config))   // correct: most-restrictive area per file, then across files
        .reduce((acc, l) => minLevel(acc, l));

const matchedArea =
  config.areas.find((area) =>                       // bug: FIRST matching area, independent of the above
    change.filesChanged.some((f) => area.pathGlobs.some((glob) => matchesGlob(f, glob))),
  )?.area ?? "default";
```

`effectiveLevel` is computed correctly: for a change touching files in
multiple configured areas, it takes the most restrictive level across all of
them (via `resolveFileLevel` + `minLevel`, `autonomy.ts:65-74`). But
`matchedArea` is computed **independently**, via `Array.find()` — it returns
whichever area happens to appear **first** in `config.areas`, with no
connection to which area's configured level actually produced
`effectiveLevel`.

**Concrete failure scenario:** an app has two configured areas — `ui-fixes`
at L3, `backend-core` at L1 — listed in that order in `.day2-autonomy.json`.
A change touches one file matching each. `effectiveLevel` correctly comes
out L1 (blocked, needs a human). But `matchedArea` returns `"ui-fixes"`
(it's first in the array) — so the decision object, the UI-facing `reason`
string, and the **persisted audit-log entry**
(`recordAutonomyAudit`, `autonomy.ts:158-175`, written to
`day2-autonomy-audit.jsonl` and rendered on the console's Autonomy Activity
page) all say the block came from `ui-fixes` at L3, when it was actually
`backend-core` at L1 that did it. The audit trail — which this project's own
`autonomy.ts:153` comment says is meant to satisfy "SOC 2 and ISO
change-management requirements" — can name the wrong control as the one that
fired.

Not covered by any test: `grep -n "matchedArea" orchestrator/src/autonomy.test.ts`
returns nothing, and there's no multi-area test case in that file.

**Recommendation:** derive `matchedArea` from whichever area actually
produced the minimum in the `effectiveLevel` reduction (or, simpler, track
`{area, level}` pairs through the same `reduce` instead of two independent
passes over `filesChanged`).

---

## Security gap: the agent sandbox's credential denylist doesn't cover this project's own deploy credentials

`orchestrator/src/agent-sandbox.ts:25` — the shared sandbox config used by
every untrusted-input-facing agent call (`agent.ts`'s fix/verifier agents,
`swarm.ts`, `calibration.ts`, `evolution.ts`):

```ts
export const DENIED_ENV_VARS = ["SENTRY_AUTH_TOKEN", "SENTRY_REGION_URL", "ANTHROPIC_API_KEY"];
```

and `agent-sandbox.ts:28-37`'s `DENIED_READ_PATHS` covers `~/.ssh`, `~/.aws`,
`~/.claude`, `~/.config/gh`, `~/.netrc`, `~/.npmrc`, `~/.docker`, `~/.gnupg`.

But `orchestrator/src/release.ts:192,206,236` runs real, production-affecting
Cloudflare Workers deploys as part of this project's own self-healing release
gate — `bunx wrangler versions upload`, `wrangler deployments list`,
`wrangler versions deploy`. Those commands need either a `CLOUDFLARE_API_TOKEN`
env var or a `~/.wrangler` OAuth session present in the same operator shell
that spawns the sandboxed agents. Neither is in `DENIED_ENV_VARS` nor
`DENIED_READ_PATHS`. The orchestrator's own README documents, in detail, why
this exact class of exposure matters (a bug report's text is "effectively
user-controlled... a real prompt-injection-to-secret-exfiltration path, not
theoretical") and lists the threat model the sandbox was built to close — but
the hardening pass that produced `agent-sandbox.ts` evidently didn't audit
for *every* credential the surrounding orchestrator process itself needs, only
the ones already named (Sentry, Anthropic). If `CLOUDFLARE_API_TOKEN` is set
in the same shell (needed for `release.ts` to function at all in a real
deployment), a hostile bug report could exfiltrate it via the sandboxed
agent's Bash tool today.

**Recommendation:** add `CLOUDFLARE_API_TOKEN` (and any other deploy-time
credential this project's own tooling uses — check for `GH_TOKEN`/`GITHUB_TOKEN`
too, since `gh pr create` also runs outside the sandbox but near it) to
`DENIED_ENV_VARS`, and `~/.wrangler` to `DENIED_READ_PATHS`.

---

## Self-distributing (Step 4): confirmed — most of it has no path to production, and this is honestly disclosed in-code, just worth stating precisely

Independently confirmed, with exact figures:

- `orchestrator/src/api-server.ts:18-56` imports exactly **5** of the ~26
  growth/pattern/evolution modules in `orchestrator/src`: `growth-config.ts`,
  `spend-governance.ts`, `growth-strategy.ts`, `growth-allocator.ts`,
  `growth-feed.ts`. Everything else — `growth-execution.ts`,
  `growth-creative.ts`, `growth-render.ts`, `growth-judge-model.ts`,
  `growth-reward.ts`, `growth-cross-channel.ts`, `growth-geo.ts`,
  `growth-winback.ts`, `growth-trend-{campaigns,sources}.ts`,
  `growth-trends.ts`, `growth-arm-check.ts`, `growth-tools-config.ts`,
  `growth-website.ts`, `design-references.ts`, `competitor-feed.ts`,
  `external-ingest.ts`, `pattern-library.ts`, `pattern-transferability.ts`,
  `ai-slop-patterns.ts`, `false-positive-patterns.ts`, `evolution.ts`,
  `experiments.ts`, `entry-paths.ts`, `cohort-report-card.ts`,
  `calibration.ts`, `swarm.ts` — is reachable only via a handful of
  human-invoked CLIs (`growth-digest-cli.ts`, `growth-feed-cli.ts`,
  `design-references-cli.ts`, `seed-pattern-library-cli.ts`,
  `spend-config-cli.ts`, `evolution-cli.ts`, `health-scout-cli.ts`,
  `onboarding{,-rescan}-cli.ts`) or not reachable from any entrypoint at all.
  (The console, confirmed below, only ever calls the same 5 modules'
  worth of API routes — so none of this surfaces in the UI either.)
- `performLiveAction` (`growth-execution.ts:175-187`) has zero callers
  outside its own file. `grep -rn "performLiveAction"` across the whole repo
  turns up only its definition, its one internal call site, and five
  separate comments *in other files* explicitly stating no orchestration
  script calls it (`growth-render.ts:54`, `growth-judge-model.ts:16`,
  `growth-trend-campaigns.ts:27`, `external-ingest.ts:216`,
  `growth-execution.ts:254`) — this is unusually well self-documented in-code,
  not a hidden gap.
- No scheduler/cron/webhook exists anywhere in either repo on `main`:
  `grep -rln "setInterval\|cron\|webhook\|node-cron" orchestrator/src` turns
  up only comments (`growth-digest.ts`, `auto-release-cli.ts`, `release.ts`)
  recommending the operator run things via their own cron, never an actual
  scheduling mechanism. **Correction to an earlier lead from one of the
  sub-agent audits:** a real GitHub Actions cron workflow
  (`.github/workflows/day2-health-scout-schedule.yml`) *does* exist for
  health-scout — but on `expense-buddy`'s `self-healing-hardening` branch,
  open PR #45, not merged. So "no scheduler exists" is accurate for `main`
  today, but inaccurate as a durable architectural claim — the fix is
  written and sitting in review, same pattern as the orchestrator PR #6 case
  above.
- A `false lead worth recording so it isn't re-litigated`: one audit angle
  initially read STAGE4.md's "Component 6 (execution layer) done" claim as
  contradicting the stub finding above. It doesn't — `STAGE4.md:107` and
  `docs/step4-self-distributing-plan.md:241` both explicitly and repeatedly
  disclose, in the same breath as claiming the milestone "done," that live
  execution stops one step short on purpose ("stopping honestly one step
  before any real money is spent or anything real is published... no real
  MCP/tool vendor credential exists anywhere"). This is consistent, honest
  documentation, not an overclaim — worth not flagging as a contradiction
  just because it pattern-matches one.

**Net:** the Step 4 build is real, individually well-tested engineering
(confirmed: `bun test` passes 1396/1396 including every growth-*.test.ts),
but as a connected pipeline it's closer to a library than a running system.
This matches what `COORDINATION.md`'s own reconciliation section already
said in prose; this section adds the precise module-by-module citation.

---

## Console ↔ API integration: genuinely wired, no mocking found

Read the console's entire `lib/api.ts` (typed fetch client, 309 lines) and
`lib/queries.ts` against `orchestrator/src/api-server.ts`'s actual route table
(`api-server.ts:150-470`). Every exported client function maps 1:1 to a real
server route; no hardcoded/mock data found in any route file read in full
(`routes/index.tsx`, `routes/safety.tsx`, `routes/apps.$appId.growth.creative-library.tsx`).

- **`safety.tsx`** (claimed by `COORDINATION.md` to now show "real per-app
  kill-switch/cap/autonomy-level/claims-check state") — confirmed:
  `AppSafetyStatus` (`safety.tsx:53-108`) calls `useGrowthConfig`,
  `useAutonomyConfig`, `useGrowthFeed` — all real hooks hitting real
  endpoints, deriving `flaggedGeneric`/`untruthful`/`autoShipAreas` from
  live response data, not static copy. Confirmed true.
- **CORS**: `api-server.ts:474-487` scopes `access-control-allow-origin` to
  `DAY2_CONSOLE_ORIGIN` (default `http://localhost:3000`), matching
  `console/src`'s Vite dev port (`package.json`: `vite dev --port 3000`).
  Confirmed consistent, not a wildcard.
- **Build**: `cd console && bun run build` succeeds cleanly (client + SSR
  bundles both built, no errors).
- One real gap, structural rather than a bug: `routes/apps.$appId.growth.creative-library.tsx`
  derives its entire view by deduping `useGrowthFeed`'s records
  (`creative-library.tsx:12-22`) — correctly wired, no mock — but since
  nothing ever calls `performLiveAction` (see above), `day2-growth-actions.jsonl`
  never gets a real `executed` record in production, so this page will show
  "No creatives produced yet" indefinitely until Step 4's execution gap
  closes. Not a frontend bug; a downstream consequence of the backend gap
  above, worth knowing so it isn't independently "discovered" and
  mis-diagnosed as a console issue later.

---

## Test suite & build health (run directly, not reported secondhand)

```
bun test v1.3.14
 1396 pass
 0 fail
 6022 expect() calls
Ran 1396 tests across 96 files. [7.73s]
```

One oddity in that output: it includes a duplicate run of `release.test.ts`
from `orchestrator/worktrees-tmp-check/src/release.test.ts` — see hygiene
section below. Doesn't affect the pass/fail count, just doubles some log
lines.

`console`: `bun run build` succeeds, client + SSR, no type errors surfaced.

---

## Git/worktree hygiene

- **`orchestrator/worktrees-tmp-check/`** is an untracked (`git ls-files`
  returns nothing for it), undocumented directory containing a full second
  checkout (own `.git` gitlink, `src/`, `package.json`, dated 30 Sep 18:24 —
  stale for 3+ days as of this audit) sitting *inside* the real
  `orchestrator/` repo instead of under `day2/worktrees/` per this project's
  own worktree convention (`COORDINATION.md`'s W34 section). Harmless
  (causes the test-output duplication above, nothing else) but exactly the
  kind of leftover that convention exists to prevent.
- **Day2 coordination repo**: `main` is 1 commit ahead of `origin/main`
  (unpushed), plus an uncommitted `.gitignore` change (adds `/console/` —
  correct, since console is confirmed to be its own git repo now, just not
  yet committed) and three untracked files: `.DS_Store` (should be
  gitignored, isn't), and two substantial, dated documents —
  `docs/distribution-intelligence.md` (42KB, dated 2 Oct) and
  `docs/offering-logic.md` (18KB, dated 30 Sep) — real content, zero version
  history, real data-loss risk. This is the same class of risk
  `COORDINATION.md`'s own reconciliation pass already caught and fixed once
  for a different set of files (Step 4's growth modules were found
  uncommitted in that pass); these two were missed.
- **Stale worktree tracking** (local, not data-loss, just confusing if
  revisited): `worktrees/orchestrator-closed-loop-m2-metrics` reports 5
  commits behind its remote tracking branch, `m3-reward` 3 behind,
  `step4-competitor-social` 18 behind `main` — all of these branches are, per
  `gh pr list`, actually long since merged; the local worktree checkouts
  were just never refreshed or removed after merge. Not a risk, just
  clutter — `git worktree remove` candidates.
- **Open PRs, for context on what's "done" vs "shipped":**

  | Repo | PR | Age (as of this audit) | Contents | Status |
  |---|---|---|---|---|
  | orchestrator | #6 | ~1 day | cross-source dedup, trust-feedback loop, rejection memory, the experiments.ts/entry-paths.ts fix described above as already "resolved" in docs | **Merged 2026-10-04** |
  | orchestrator | #7 | new | this audit's own two fixes (autonomy misattribution, sandbox denylist) | **Merged 2026-10-04** |
  | expense-buddy | #45 | ~1 day | health-scout GH Actions cron schedule, bulkActions density fix | **Merged 2026-10-04** |
  | expense-buddy | #44 | ~2 days | interaction-friction telemetry first rollout | **Merged 2026-10-04** |
  | expense-buddy | #34 | **~6 days** | "Ask a question" UI so `statedPreferences` stops being null — open since 2026-09-27, no mention found in `COORDINATION.md`'s later entries explaining why it's still unreviewed | **Merged 2026-10-04**, conflict resolved by hand (see Update below) |
  | expense-buddy | #1 | ~10 days | the original Stage 0 seed-bug fixture — `COORDINATION.md` already explicitly notes this one is intentionally left open as a reference artifact, not a stuck item | Left open, by design |

  #34 is the one genuinely unexplained stale item in this list — worth a
  quick human look, if only to decide "still wanted" vs. "close it."

---

## What's confirmed solid (worth stating, so this doc isn't read as all-negative)

- The release gate (merge → autonomy check → swarm regression → calibration
  → canary → promote/rollback) is real, wrangler-backed, and does fire on
  real PR merges for the one area opted into L3 — this is genuine, tested
  machinery, not a mock.
- Agent sandboxing (isolation mode, minimal tool set, OS-level sandbox,
  prompt-injection framing) is present in `agent.ts`/`agent-sandbox.ts`
  exactly as the README describes, and was tested against a real injected
  attack per the README's own account — confirmed the mechanism exists;
  didn't re-run the attack test itself.
- Zip-slip protection on the console's app-upload path
  (`api-server.ts:213-231`, `assertZipEntriesAreContained`) is real,
  defense-in-depth, and runs before extraction.
- Console↔API wiring, as detailed above, has no mocking anywhere checked.
- 1396/1396 tests passing, clean builds on both `orchestrator` and `console`.
- `docs/closed-loop-spec.md` conflict #4 aside, the project's documentation
  culture of disclosing gaps in the same breath as claiming milestones
  (Step 4's execution-layer stub, the autonomy L4/L5 collapse, auth/multi-
  tenancy deferral) is unusually good — most "done" claims checked here
  turned out to be accurately scoped, not inflated.

---

## Priority recommendations

1. ~~Fix `docs/closed-loop-spec.md`'s conflict #4 wording~~ — **done**, see
   `docs/closed-loop-spec.md`'s conflict #5 note and `COORDINATION.md:1020`.
2. ~~Fix the `autonomy.ts` area-misattribution bug~~ — **done**, orchestrator
   PR #7 (merged).
3. ~~Add `CLOUDFLARE_API_TOKEN` / `~/.wrangler` to the agent sandbox
   denylist~~ — **done**, same PR #7.
4. ~~Decide on PR #6 and #45~~ — **done, both merged** (2026-10-04), along
   with expense-buddy #44 and #34 (see Update below).
5. ~~Commit `docs/distribution-intelligence.md`, `docs/offering-logic.md`,
   and `.DS_Store`'s gitignore exclusion~~ — **done**, pushed to `origin/main`.
6. ~~Clean up `orchestrator/worktrees-tmp-check/` and the three
   merged-but-stale worktree directories~~ — **done**.
7. ~~Take a look at expense-buddy PR #34~~ — **done, merged** (see Update
   below).

## Update (2026-10-04): all open PRs from this audit merged

All five items above closed the same day. Orchestrator PR #6 and #7 merged
cleanly (no file overlap, 1021/1021 tests passing on `main` afterward).
Expense-buddy #45 and #44 merged cleanly (#44's CI failure was the
pre-existing composer/density bug #45 fixes — confirmed gone by running the
correct `bun run test` — i.e. `vitest` — command locally after a trial merge,
before merging for real; running `bun test` directly on this repo instead
of `vitest` reproduces a known, already-disclosed 42-failure false alarm,
see `STAGE4.md:135` — not a real regression, just the wrong runner).

Expense-buddy #34 (the 6-day-stale one) had a real merge conflict in
`src/lib/day2-events.ts` — its branch predated the M1 closed-loop work that
expanded `EventType` into the full spec catalog, and both sides had grown
the same union independently (#34 added `preference_answered`; `main` added
~20 other types). Resolved by hand: kept `main`'s full catalog, added
`preference_answered` to it (not a pick-one-side resolution — verified the
server-side `EVENT_TYPES` allow-list in `server.ts` still carries it
post-merge too, same "both sides of the client/server catalog must agree"
trap this spec already warns about elsewhere). CI's visual-diff check then
failed (homepage height 900px → 1175px, couldn't pixel-diff) — downloaded
and viewed both screenshots directly rather than overriding the check on
assumption: confirmed the only difference is the new "One quick question"
card PR #34 intentionally adds, not a broken layout. 144/144 tests, clean
build, then merged.

`origin/main` on both repos confirmed green after all five merges: 1021/1021
(orchestrator), 144/144 (expense-buddy). All now-merged worktrees/branches
cleaned up (local + remote).
