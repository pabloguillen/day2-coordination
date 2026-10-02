# day2 Platform — Implementation Audit (2026-10-02)

_Fresh investigation, no memory/mem-search tools used. Every finding below is grounded in
reading actual code, running actual `git`/`gh`/`grep` commands, or reading actual document
text — carried out via seven independent parallel investigations (one per subsystem) plus
direct spot-verification of the highest-stakes and most-contested claims. Covers three
repos: `day2` (this repo — coordination docs + `console/`), `day2/orchestrator` (the
automation engine), and the sibling pilot app `expense-buddy` at `/Users/pabloguillen/expense-buddy`._

_Where two independent investigations disagreed, the conflict was resolved by re-checking
the underlying file/command directly rather than picking a side — see the note at the end
of each such finding. One flat contradiction was found and corrected this way (the
autonomy-gate finding, §Cross-cutting #3)._

---

## TL;DR

**What's real:** the release-side autonomy chain (merge → autonomy gate → swarm regression
check → calibration recheck → canary → promote/rollback) genuinely auto-fires on every
qualifying PR merge for expense-buddy's `ui-fixes` area, and has a track record of catching
real bugs in itself live. Step 2's adaptive per-device UI (`decideSlotConfig` + composer +
building blocks) is live and wired end-to-end in the deployed app, not a spec. The console
and orchestrator API are honestly matched with no fabricated data. Agent sandboxing against
prompt injection is real, tested security engineering. The orchestrator's test suite is
green (1,101 tests).

**What's not real, despite commit messages and docs calling it "done" / "live-validated":**
Step 4 ("self-distributing") has never executed a single action against a real external
channel — the one function that would do so is a hardcoded stub, confirmed on the actual
merged `origin/main`. There is no scheduler, cron, or webhook anywhere in either codebase —
every detection/growth/evolution run is a manual CLI invocation; only the release-side gate
truly fires on its own (and only via a GitHub PR-merge event, not a clock). The L0–L5
autonomy scheme described in `types.ts` and the docs collapses, in the actual
implementation, to one binary ship/no-ship threshold at L3. A meaningful slice of the
newest Step 4 code sits uncommitted and untracked in the local orchestrator checkout, which
is itself 11 commits behind its own GitHub remote.

**Documentation reliability:** COORDINATION.md's workstream table is the most trustworthy
record in the project — sessions consistently self-disclose failures, collisions, and false
positives rather than hide them. But the document as a whole has rotted: two different
"current state" snapshots are both stale, the table itself is fragmented by interspersed
prose, and at least one self-flagged architectural conflict has sat open for multiple
milestones with no closing note. Stand-alone specs (`docs/step1-self-healing-gap-analysis.md`
in particular) go stale the same day they're written and are never revised.

---

## Cross-cutting findings

### 1. [CRITICAL] No scheduler, cron, or webhook exists anywhere in either codebase
Grepping both repos (`orchestrator/`, `expense-buddy/`, every worktree) for
`setInterval`, `node-cron`, or a `schedule:` GitHub Actions trigger returns zero hits.
`docs/distribution-intelligence.md` says so explicitly about `growth-digest.ts`: *"No
scheduler built here, same — CLI an operator's own cron."* The only non-human trigger in
the entire system is event-driven: `expense-buddy/.github/workflows/auto-release.yml` and
`day2-profile-rescan.yml` fire on `pull_request: closed` (merge to `main`). That covers 2 of
the 13 CLI entrypoints in `orchestrator/src` (`auto-release-cli.ts`,
`onboarding-rescan-cli.ts`); the other 11 — `approval-cli`, `autonomy-config-cli`,
`canary-cli`, `design-references-cli`, `evolution-cli`, `growth-digest-cli`,
`growth-feed-cli`, `onboarding-cli`, `seed-pattern-library-cli`, `spend-config-cli`,
`swarm-fix-cli` — are exclusively human-triggered today, in both repos, with no exceptions
found.

### 2. [CRITICAL] Step 4's execution layer has never touched anything real
`orchestrator/src/growth-execution.ts:160-172`'s `performLiveAction` is a hardcoded stub:

```ts
async function performLiveAction(opts, _spendDecision) {
  return {
    status: "execution_failed",
    reason: "Live execution is not implemented in this pass — no real MCP
             tool-invocation mechanism exists yet. ..."
  };
}
```

Confirmed **byte-identical on the fully-merged `origin/main` tip**, not just the local
tree — verified directly by reading the file. The function is honestly documented as a
deliberate, disclosed seam ("not written yet, and not this component's job to write"), so
this isn't a deceptive bug — but every "Component N done, live-validated" commit message in
the W37–W53 range describes validation against synthetic fixtures, never a real network
call to any ad platform, social API, or email provider. `reconcileOutcomes()`
(`growth-execution.ts:245`) consequently only ever processes `executionResult === "executed"`
records, which is unreachable in production — the bandit allocator has never seen real
performance data.

### 3. [HIGH, with a correction] The L0–L5 autonomy scheme is mostly aspirational — but is genuinely live for one scoped area
`orchestrator/src/types.ts` defines six levels (L0–L5) with distinct stated capabilities.
`autonomy.ts:104` (`evaluateAutonomy`) only ever checks `levelIndex(effectiveLevel) <
levelIndex("L3")` — verified directly by reading the file. L3, L4, and L5 are behaviorally
identical in the current code; "full autonomy up to L5" is not reachable as distinct
behavior anywhere.

**Correction to an earlier draft of this audit:** one investigation initially concluded the
auto-release gate is "a permanent no-op... no app has opted into autonomy level L3+ ...
will always evaluate to human required." That's wrong, and caught here by reading the
actual config file: `expense-buddy/.day2-autonomy.json` exists and reads

```json
{ "defaultLevel": "L2",
  "areas": [{ "area": "ui-fixes", "pathGlobs": ["src/components/**", "src/routes/**"], "level": "L3" }] }
```

So for the one scoped `ui-fixes` area, the release gate genuinely auto-ships today (PR #27,
merged 2026-09-27, "Opt ui-fixes into L3 automatic shipping" — confirmed via `gh pr list`).
Everything outside those two path globs still defaults to L2 (human review required). Net:
the six-level framing promises more graduated control than exists, but the one level that
matters (L3) is real, live, and scoped correctly — it is not vaporware.

### 4. [HIGH] Real, uncommitted work is sitting at risk in the local orchestrator checkout
Direct `git status` in `/Users/pabloguillen/day2/orchestrator` right now shows the local
`main` sitting exactly at the merge-base with `origin/main` (**11 commits behind, 0 ahead**)
plus:

- **Untracked** (never committed, anywhere): `growth-geo.ts(+test)`, `growth-judge-model.ts(+test)`,
  `growth-cross-channel.ts(+test)`, `growth-digest.ts/-cli.ts(+test)`, `growth-winback.ts(+test)`,
  `growth-render.ts(+test)`, `growth-trends.ts(+test)`, `growth-trend-sources.ts(+test)`,
  `growth-trend-campaigns.ts(+test)`, `pattern-library.ts(+test)`, `pattern-transferability.ts(+test)`,
  `api-server.ts`, `apps-registry.ts(+test)`, `seed-pattern-library-cli.ts`, `day2-proposals.jsonl`.
- **Modified but uncommitted**: `.gitignore`, `release.ts(+test)`, `onboarding.ts(+test)`,
  `growth-feed.ts(+test)`, `growth-patterns.ts(+test)`, `growth-creative.ts(+test)`,
  `growth-execution.ts`, `auto-release-cli.ts`, `canary-cli.ts`.

None of this — a substantial slice of the project's newest work — has ever been committed,
pushed, or reviewed. It is one `git clean`, disk failure, or careless `git checkout` away
from being lost, and no other machine has a copy.

### 5. [HIGH] The local orchestrator checkout is missing an entire merged milestone set
Separately from #4, `git diff HEAD origin/main --stat` shows **62 files / ~7,690 lines**
that exist on `origin/main` but not locally: the full `src/metrics/*` KPI layer,
`src/entry-paths.ts`, `src/signals/*`, `src/sources/sentry-signals.ts`,
`sdk/friction-signals.ts` — i.e., all of closed-loop milestones M1–M5 and the entire
health-signals-scouts feature are real, merged, and simply not present in the copy of the
repo used for day-to-day work in this project. Anyone auditing or developing against only
the local checkout (as earlier drafts of several sections of this very audit initially did,
before being corrected against `origin/main`) would wrongly conclude Step 3 doesn't exist.

### 6. [MEDIUM] Documentation drifts out of sync with code in *both* directions
- **Understates reality:** `expense-buddy/src/lib/day2-config.ts`'s own header comment says
  "nothing in the app reads or acts on the result yet" — false since PR #31 (merged
  2026-09-27) wired real per-device slot config into `routes/index.tsx` the same day.
  `docs/expense-buddy-app-profile.md` was scanned the day *before* that PR merged and
  repeats the same now-false claim; `onboarding-rescan.ts` exists specifically to catch this
  kind of drift and has never been re-run against it.
  `expense-buddy/src/components/SpendSummaryCard.tsx:4-7`'s comment claims `byCategory`
  density "is implemented and tested but not yet reachable from the live app" — also false;
  `server.ts::decideSlotConfig` has returned `byCategory` for any non-novice user with
  `categoryCount >= 2` since commit `b66d467` (PR #31).
- **Overstates reality:** `docs/step4-self-distributing-plan.md`, `docs/offering-logic.md`,
  and multiple commit messages describe Step 4 components as "done, live-validated" when the
  execution function they'd ultimately call is an admitted stub (#2 above).
  `docs/step1-self-healing-gap-analysis.md` (written 2026-09-25) marks canary/rollback,
  autonomy levels, the config plane, and the event pipeline all "Not started" — all four
  shipped **the same day** it was written, and the doc was never revised. A session reading
  only that doc is actively misled.

### 7. [MEDIUM] `console/` has zero version control
Confirmed directly: `git status` inside `console/` reports *"No commits yet on main"* — the
entire dashboard codebase, despite being a real, working, API-wired application, has never
been committed even locally. This is a real risk given `orchestrator/`'s own uncommitted-work
problem (#4) — the project has now twice left substantial work unversioned.

### 8. [MEDIUM] Single-operator, localhost-bound platform despite "onboard your app" framing
`orchestrator/src/api-server.ts:70` states *"No auth in this phase — acceptable only
because this binds to localhost only"* and the server binds with `hostname: "localhost"`
(confirmed, line ~445) — yet the same file sets `"access-control-allow-origin": "*"`
(line 433), which is a real inconsistency: a wildcard CORS header has no purpose on a server
that only ever accepts connections from the same machine, and is the kind of setting that
quietly stops being safe the moment someone changes the bind address without revisiting CORS.
There is no login/session/multi-tenancy concept anywhere in `console/` or `orchestrator/`;
the console's own GitHub-repo-listing feature is implicitly authenticated by whatever `gh`
session is active on the machine running it. Today, "onboard your app" means "onboard your
app, on your own machine, as the only possible user."

---

## A. Step 1 — Self-healing (signal → reproduce → fix → verify → PR → release)

**Verdict:** The most mature layer in the project, and more real than its own gap-analysis
doc claims. Reproduce-fix-verify-PR, autonomy-gated canary release with automatic rollback,
pre-release swarm/persona/accessibility checks, and a plain-language approval surface are
genuinely wired together — not three separate stories, one real call graph through
`release.ts` (imports `autonomy`, `calibration`, `swarm`, `git`) — and have a live-validated
track record including catching real bugs in themselves (a double-counted canary error from
a re-tested SHA, a CI-status race, a swarm-sandbox-missing-on-CI-runners failure). But
"autopilot" still requires real manual bootstrapping per app, and the transparency dashboard
can silently miss its own CI-driven releases.

- **[HIGH]** `pipeline.ts::runPipeline` (the `bun run fix` entrypoint) never calls
  `autonomy.ts`/`release.ts` itself — it stops at "PR opened." Auto-shipping only happens via
  a *second*, independently-provisioned hop: a repo's own `.github/workflows/auto-release.yml`
  must separately exist and fire on merge. Nothing in the orchestrator provisions this
  workflow file (or a `.day2-autonomy.json`) for a newly onboarded app — a second onboarded
  app gets **zero** auto-release capability until someone manually copies expense-buddy's
  YAML and autonomy config in by hand.
- **[HIGH, self-disclosed]** `auto-release.yml`'s own comment admits that CI-written
  `day2-release-results.jsonl` / `day2-autonomy-audit.jsonl` live only inside the ephemeral
  GitHub Actions runner and are uploaded merely as a downloadable artifact — a human must
  manually fetch and merge it locally for the console's Releases page to show it. The
  transparency layer is blind to its own autonomous releases without manual
  artifact-wrangling, which directly undercuts "walk away and it just works."
- **[MEDIUM, doc-drift]** `release.ts`'s own top-of-file comment says auto-release "needs a
  merge-detection mechanism... which doesn't exist yet" — false; `auto-release.yml` has
  provided exactly that since PR #10 (`add-auto-release-trigger`, merged 2026-09-25). The
  comment predates that work and was never updated.
- **[MEDIUM, doc-drift]** `docs/step1-self-healing-gap-analysis.md` marks canary+rollback,
  autonomy levels, swarm-as-regression-tester, the plain-language feed, the config plane,
  and one-click onboarding all "Not started" — all six are built (confirmed by reading
  `release.ts`, `autonomy.ts`, `swarm.ts`, `onboarding.ts` directly), and `STAGE1.md`, same
  repo, documents them shipping the same day the gap doc was written.
- **[MEDIUM, bug]** `approvals.ts:93` (`classifyDefaultAction`) hardcodes
  `evaluateAutonomy(change, DEFAULT_AUTONOMY_CONFIG)` instead of the repo's real
  `.day2-autonomy.json` — the plain-language approval card's "Recommended: Apply" vs "Ask
  first" ignores an owner's actual per-area trust config entirely. An owner who explicitly
  set an area to L0 still sees "Apply" recommended for any non-sensitive change there. Low
  real-world severity (a human still has to click), but inconsistent with the per-area design.
- **[MEDIUM]** One-click onboarding (`onboarding.ts`) covers only the middle third of
  "Connect → confirm → go live": it assumes the repo is already checked out locally, "as if
  Connect had already happened." Real GitHub OAuth connection and go-live (SDK
  injection/domain cutover) are deliberately unbuilt; a non-technical owner still cannot
  onboard an app without a developer manually cloning it first.
- **[LOW, scope correction]** `spend-governance.ts`, `pattern-library.ts`,
  `pattern-transferability.ts`, and `ai-slop-patterns.ts` are **Step 4** modules (growth
  budget / creative-pattern grading), not Step 1 — `spend-governance.ts`'s own header
  identifies it as Step 4 Component 1, and the other three are imported exclusively by
  `growth-*.ts`. Step 1's actual cost control is a separate, simpler inline $3-per-run cap in
  `agent.ts` with no ledger file. Worth flagging because it suggests cross-session mental
  models have blurred the Step boundary for these specific modules.
- **[LOW]** `release.ts::fetchCanaryErrorCount`'s canary guardrail is hard-dependent on
  Sentry's API by release tag, with no fallback observability source and no pre-check that
  Sentry quota isn't silently exhausted — `STAGE0.md` already documents one real quota-drop
  incident on this exact project.
- **[LOW, architectural note]** The three signal sources are three isolated code paths, not
  one unified flow: the main `fix` entrypoint only wires `sources/sentry.ts` and
  `sources/manual.ts`; `sources/swarm.ts` (pre-release persona findings) is reachable only
  via the separate `swarm-fix-cli.ts`, by explicit design. Each needs its own invocation.
- **[Verified-real, for balance]** Swarm v1 persona/accessibility pre-release checks,
  calibration-based false-positive override (off by default, fully audited), the
  sensitive-path override that can't be configured away, and append-only audit/ledger files
  are genuinely wired end-to-end and independently tested. 1,101 orchestrator tests pass,
  0 failures.

---

## B. Step 2 — Self-adapting (per-device adaptive UI)

**Verdict: live-real, not aspirational.** `decideSlotConfig`, the composer, and all three
building blocks (`ExpenseEntryForm`, `SpendSummaryCard`, `ExpenseList`) are wired end-to-end
in the deployed expense-buddy app — confirmed by reading `server.ts` and `routes/index.tsx`
directly, not by trusting any doc. The one real problem is that even the team that shipped
it lost track of what shipped: both `day2-config.ts`'s header comment and
`docs/expense-buddy-app-profile.md` still describe this as unbuilt (see Cross-cutting #6),
and `onboarding-rescan.ts` — built for exactly this kind of drift — has never been re-run to
catch it.

---

## C. Step 3 — Self-evolving (closed-loop M1–M5)

**Verdict: real and substantially complete, but only visible from `origin/main`.** All five
closed-loop milestones are merged on GitHub (confirmed via `git log`/`gh pr list`: PRs #38,
#39, #41, #42, #43 all `MERGED`). It looks unfinished from inside this project's own local
checkout only because that checkout is 11 commits stale (Cross-cutting #5) — a genuine,
currently-live risk of this project auditing or building against a view of itself that's a
week out of date.

- **[MEDIUM, gap]** M4 "learned entry paths" has a learning function but no execution path
  end to end: `orchestrator/src/entry-paths.ts` (present on `origin/main`) defines
  `ENTRY_PATH_REGISTRY` and a learning algorithm, but there's no CLI and no workflow step
  that runs it against real data and writes results into expense-buddy's deployed
  `LEARNED_ENTRY_PATHS` array. `expense-buddy/src/server.ts` ships
  `export const LEARNED_ENTRY_PATHS: LearnedEntryPath[] = []` — permanently empty by
  construction, not just "no data yet."
- **[MEDIUM, dead code]** `experiments.ts` is dead code at the orchestrator runtime layer —
  it's imported only by its own test file; nothing in the pipeline calls
  `assignVariant`/`evaluateExperiment`. The logic was independently re-implemented at the
  app layer (`expense-buddy/src/server.ts`'s `handleConfigPlane`, genuinely wired), but
  `ACTIVE_EXPERIMENTS` is a hardcoded empty array there too — the mechanism is real, zero
  experiments have ever run through it.
- **[MEDIUM, self-disclosed and unresolved]** `docs/closed-loop-spec.md`'s own header (note
  5) flags that `experiments.ts` (frequentist Welch's-t-test, `MIN_SAMPLE_SIZE_PER_ARM = 30`)
  and the same spec's §6.2 Bayesian "90% posterior probability" bandit-promotion rule use two
  different statistical frameworks for what may be the same decision — explicitly logged as
  "flagged for a decision before M2/M4" in COORDINATION.md, and never resolved in any later
  entry found.
- **[LOW, architecture confirmed clean]** The Thompson-sampling bandit in
  `growth-allocator.ts` is genuinely Step 4 scope, not Step 3 — its own header comment
  explicitly distinguishes it from `experiments.ts` ("fixed-split, evaluate-after-the-fact...
  not an allocator, not reused here"). No real confusion found between STAGE3.md and
  STAGE4.md on this specific point, despite it being a plausible place for drift.
- **[LOW, isolation]** health-signals-scouts (`src/signals/*`, `sources/sentry-signals.ts`,
  `sdk/friction-signals.ts`) is merged into `origin/main` but has no wiring into
  `pipeline.ts` — only a standalone `health-scout-cli.ts` exists. A real, tested, merged
  capability sitting as a parallel, manually-invoked path rather than part of the main
  self-healing loop.

---

## D. Step 4 — Self-distributing (growth / distribution)

**Verdict: scaffolding, not a pipeline.** All seven planned components
(budget/spend governance, app-stage growth strategy, config-driven tool-selection,
adaptive allocator, creative generation, execution + transparency feed, optional marketing
website) have corresponding, individually well-tested code. The gap is strictly in
*composition*: grep-verified, zero production call chain connects strategy → allocator →
creative → render → execution → feed, and the one function that would touch a real external
channel is a confirmed stub (Cross-cutting #2).

- **[CRITICAL]** `executeChannelAction`, `generateCreatives`, `generateMarketingWebsite`,
  and the `selectArm` chain are each called only from their own `.test.ts` file anywhere in
  the repo — verified by grepping every non-type, non-test import across all 20
  `growth-*.ts` files.
- **[HIGH]** Five of twenty growth modules are **fully orphaned** — zero non-test importers
  anywhere: `growth-winback.ts`, `growth-cross-channel.ts`, `growth-trend-campaigns.ts`,
  `growth-render.ts` (Playwright screenshot rendering, cited elsewhere as load-bearing for
  image-arm grounding — never actually invoked outside its own test), `growth-website.ts`.
- **[HIGH]** `api-server.ts` is read-only for growth: it imports only `growth-config`,
  `growth-strategy`, `growth-allocator`, and `growth-feed` — all display/summarize existing
  state. Nothing in the live API surface produces new creatives, spend, or site content.
- **[MEDIUM]** `growth-judge-model.ts` (767 lines, fully tested — a logistic-regression
  creative judge with training, prediction, and drift detection) has no real caller:
  `predictForCandidate` has exactly one occurrence, its own definition. Its
  minimum-training-examples threshold can never be reached because zero real labeled
  outcomes exist, gated transitively on the execution stub. It currently functions as a
  dashboard annotation (`growth-feed.ts` imports only its `JudgePrediction` *type* to render
  an advisory note), not a judge of anything.
- **[MEDIUM]** `growth-tools-config.ts`'s entire vendor-binding mechanism is untested against
  a real vendor — only `.day2-platform-tools.example.json` exists anywhere searched
  (including every worktree); every binding is `enabled: false` with placeholder tokens. By
  the project's own disclosure (STAGE4.md W44), this is known and intentional for now.
- **[MEDIUM]** `growth-creative.ts` bypasses the pattern-validation pipeline it was meant to
  use — it consumes raw `ProvenPattern[]` instead of the adversarially-tiered
  `TransferablePattern[]` that `pattern-library.ts`/`pattern-transferability.ts` produce. An
  entire validation system grades patterns that no creative-generation call actually
  consumes.
- **[LOW]** Duplicate `Arm` type independently declared in `growth-tools-config.ts:36` and
  `growth-allocator.ts:52` — confirmed directly; `growth-tools-config.ts`'s own header
  comment predicted and asked to avoid exactly this duplication, and it shipped anyway.
- **[LOW]** `direct_outreach` is a typed channel (`growth-strategy.ts:76`, confirmed) with no
  rule in the same file's fixed allocation table that ever assigns it budget — a
  self-disclosed, structurally-confirmed gap.
- **[LOW]** Three separate, never-unified evidence-strength taxonomies exist:
  `EvidenceStrength`, `OrganicEvidenceStrength`, and `growth-geo.ts`'s own
  `GeoEvidenceStrength`. The trend trio (`growth-trend-sources.ts → growth-trends.ts →
  growth-trend-campaigns.ts`) shares one taxonomy correctly; `growth-geo.ts` was built fully
  independently of it.
- **[LOW]** The `step4-competitor-social` worktree is not mid-flight — it's an empty
  placeholder. `git diff --stat origin/main...HEAD` returns nothing; `HEAD` is byte-identical
  to `origin/main` (11 commits stale, 0 unique commits), despite commit `976ebb4` ("W50:
  claim Step 4 extension — competitor social-media presence research") asserting the work
  was started. The claim was logged in COORDINATION.md; no code was ever written for it.
- **[Informational]** The three overlapping distribution docs (`docs/offering-logic.md`,
  `docs/step4-self-distributing-plan.md`, `docs/distribution-intelligence.md`) don't
  contradict each other on substance — channel lists, budget model, and component numbering
  are consistent across all three — but they do create real ownership/navigation ambiguity,
  and `distribution-intelligence.md` asserts the full closed loop (research → strategy →
  creative → verification → execution → reconciliation) is already real, which the findings
  above directly contradict at the code level.

---

## E. Console dashboard

**Verdict:** honest and well-wired for the slice of the system it covers, but that slice is
narrower than the orchestrator's real capability — and this is a backend gap, not a
frontend one.

- **Reconciling an apparent contradiction:** one investigation reported "exact 1:1 route
  coverage, no dead calls, no orphaned backend routes" between console and
  `api-server.ts`; another reported "22 of ~66 orchestrator modules have zero API exposure."
  Both are correct and not in tension: *within* the routes `api-server.ts` actually defines,
  console consumes every one and fabricates nothing (confirmed: no mock/hardcoded data found
  anywhere in `console/src`, beyond legitimate HTML `placeholder` attributes). But
  `api-server.ts` itself never imports or routes `growth-creative.ts`, `growth-execution.ts`,
  `growth-judge-model.ts`, `growth-render.ts`, `growth-website.ts`, `growth-winback.ts`,
  `growth-cross-channel.ts`, `growth-trend-*.ts`, `growth-geo.ts`, `competitor-feed.ts`,
  `design-references.ts`, `evolution.ts`, `experiments.ts`, `pattern-library.ts`,
  `pattern-transferability.ts`, or `onboarding-rescan.ts` — nearly every module the "Step 4
  self-distributing" commits claim as complete. So the console isn't lying or stale in the
  way it renders things; the *backend* simply never promoted most of Step 4 (and all of
  Step 3's experiment engine) to an API surface for it to consume.
- **[MEDIUM]** `growth.creative-library.tsx` doesn't talk to `growth-creative.ts` at all — it
  only calls `useGrowthFeed`, reading generic `GrowthActionRecord[]` off the growth-feed
  route. A page named after the creative-generation module renders a filtered activity log
  instead.
- **[MEDIUM]** `safety.tsx` ("Safety & Transparency") is pure static copy — confirmed by
  reading the file directly: a hardcoded array of nine policy-description strings (kill
  switch, per-action cap, exploration ceiling, etc.), zero API calls, zero live state. The
  one page whose entire purpose is to show real guardrail status currently shows none.
- **[LOW]** `evolution.ts` and `experiments.ts` have no route at all; the `/evolution/proposals`
  endpoint only calls `proposals.ts`'s storage layer, not `evolution.ts` itself.
- **[LOW]** `onboarding-rescan.ts` is unwired — console's profile page can trigger an initial
  scan but not a re-scan, which is directly relevant to Cross-cutting #6's stale-doc problem.
- **[LOW]** No deployment path exists: `console/package.json` has only `dev`/`build`/`preview`
  scripts, no Dockerfile/wrangler config, and the API base is hardcoded to
  `http://localhost:4700` with no evidence it's ever pointed elsewhere.
- Vocabulary (`AutonomyLevel`, `GrowthChannel`, `SpendCategory`, `AppStage`) matches verbatim
  between `console/src/lib/api.ts` and `orchestrator/src/types.ts` everywhere checked — no
  naming drift found in the parts that are actually wired.

---

## F. expense-buddy — integration reality (the one pilot app)

**Verdict:** expense-buddy genuinely runs the two things day2 actually ships for it today —
L3 auto-release on the `ui-fixes` area (confirmed live, see Cross-cutting #3), and real
per-device adaptive slot config (Step 2). It does not yet run the two most-advertised
remaining capabilities: no active experiment, and no health-signals telemetry in production.

- **[HIGH]** Health-signals client telemetry does not exist on expense-buddy's `main` — zero
  matching symbols in `src/`. It's PR #44, "Install day2's generic interaction-friction
  telemetry (first rollout)," opened 2026-10-01, confirmed **still OPEN** via `gh pr list`.
  Any claim that expense-buddy "has" friction-signal detection today describes an open pull
  request, not the running app.
- **[MEDIUM]** `ACTIVE_EXPERIMENTS` is a hardcoded empty array in `server.ts` — the
  experiment-merge logic in `handleConfigPlane` is real and wired, but nothing has ever
  populated an experiment through it (consistent with §C's finding that `experiments.ts` is
  unused at the orchestrator layer).
- **[LOW]** A trivial, now 9-day-old PR sits forgotten: PR #1, "Fix: expense amounts were
  losing their cents" (opened 2026-09-23), is still **OPEN** while 19 more complex PRs merged
  around it in the meantime — confirmed via `gh pr list`.
- **[LOW]** Event recording is genuinely live — `recordEvent()` fires on real
  `session_start`/`expense_added`/`weekly_report_viewed` interactions; only the *read* side
  (building a per-user model from these events for anything beyond the current slot-config
  rules) remains to be built out further.
- **Git state, confirmed directly:** `main` is 4 commits behind `origin/main` (clean
  fast-forward, no conflicts), with exactly one uncommitted local change
  (`.github/workflows/auto-release.yml`, adding a `--release-results-file` arg and artifact
  upload step) that hasn't been pushed — a small, low-risk, real divergence between local and
  remote on the same file in both directions.

---

## G. COORDINATION.md and narrative docs — reliability as ground truth

**Verdict:** reliable as a record of *what was built* — workstream entries consistently
self-report failures, false positives, and collisions rather than hide them, which is this
project's biggest process asset. Much less reliable as a record of *what the project is
currently allowed or supposed to be doing* — the framing/summary sections have drifted out
of sync with the table they're meant to summarize, and at least one architectural conflict
has sat open across multiple milestones with no later closure found.

- **[HIGH, stale]** Two different "Current state" snapshots exist (line ~49 and line ~902),
  both dated 2026-09-27 but ~8.5 hours apart, and **both are now stale** relative to the
  table's actual tail (through W56, 2026-10-02) — five days and roughly 30 workstreams later,
  spanning all of Step 3, all of Step 4, and the entire closed-loop effort. The first
  section's own text ("when it goes stale, update it or delete it rather than trust it
  blindly") was not followed on itself.
- **[HIGH, structural defect]** The "Active workstreams" table is not one contiguous markdown
  table — rows from W28 onward physically sit *inside* the "Decision log" section and past
  the second "Current state" header, interleaved with prose paragraphs and no repeated
  header row. This is a concrete rendering defect (the table fragments on render), not just a
  navigability complaint.
- **[MEDIUM, stale flag]** The "⚠ Open gating tension" (line ~137 — a retention-lift test
  must precede Step 2) was never closed or struck through, even though the log later
  documents the user explicitly overriding it ("skip it for now, continue with Step 2... a
  disclosed override, not a resolution"). The sibling section immediately below it *does* use
  `~~strikethrough~~ **Resolved**` styling for closed items — the inconsistent convention
  leaves line 137 reading as still-live when it's actually been overridden.
- **[MEDIUM, unresolved contradiction]** A flat, unreconciled contradiction over whether
  closed-loop M1 ever merged: one workstream entry says a PR was "committed and pushed... not
  merged," while an adjacent entry treats the same merge as already-accomplished fact to
  explain 42 pre-existing test failures. No later entry reconciles the two.
- **[MEDIUM, self-disclosed, still open]** `docs/closed-loop-spec.md`'s own "conflict #4"
  (the `experiments.ts` statistical-framework overlap, see §C) is explicitly logged as "still
  open for M2+," with no later milestone row found that closes it.
- **[MEDIUM, gating rule violated without updating the rule]** COORDINATION.md states stages
  are evidence-gated on Stage 0's retention-lift exit criterion, which `STAGE0.md` itself
  records as never met (neither test app has real users yet) — yet Steps 2, 3, and 4 were all
  built on top of it anyway. Each override is individually disclosed in its own workstream
  entry, but the gating section itself was never updated to reflect the de facto override,
  so a new reader sees a rule that the project has already stopped following.
- **[LOW, ownership collisions — mixed handling]** Workstream IDs were reused at least three
  times for unrelated work: W19 (disclosed as "collision found and resolved
  unilaterally-but-transparently" — the duplicate ID itself was never renumbered), W20 (no
  explicit in-row disclosure found — reads as an unremarked duplicate), and W38 (handled best:
  one session's own row says "superseded by [commit]... my own build discarded, not merged,
  after a careful independent comparison"). W38 is the project's best-case pattern; W20 is the
  counter-example.
- **[LOW, positive data point]** Commit `f23fe7e` ("Merge: restore closed-loop session's W47
  row, stash conflict resolution") is a real `git stash pop` conflict between two sessions'
  concurrent edits to COORDINATION.md itself — confirmed via `git show --stat` — resolved by
  keeping both the W46 and W47 rows intact, with no data loss.
- **[LOW, meta-finding]** The log documents at least two incidents of multi-agent
  execution unreliability being caught only by manual verification, not by any system
  guarantee: a duplicate fork that re-executed the same directive and produced a
  byte-identical commit under a different hash, and a subagent that "silently no-op'd...
  just echoed running." Both are logged as reasons to "verify fork/subagent completions
  against real evidence, don't trust the report alone" — advice this audit itself had to
  apply once, correcting a subagent's premature/overreaching report mid-process (see the
  Methodology note below).
- **[Stand-alone doc, stale]** `docs/step1-self-healing-gap-analysis.md` (written
  2026-09-25) marks canary/rollback, autonomy, the config plane, and the event pipeline all
  "Not started" — all four shipped the same day, and the doc was never revised.

---

## H. Git and worktree hygiene across all three repos

**Verdict:** no destructive conflicts found anywhere; the one real, live risk is the
uncommitted work already called out in Cross-cutting #4.

- **Merged-and-never-cleaned-up, not abandoned:** all 5 orchestrator closed-loop/health-signals
  worktrees (`m1-context`, `m2-metrics`, `m3-reward`, `m4-entry-paths`, `health-signals-scouts`)
  show 0 commits ahead of `origin/main` and 7–11 behind — their content is already merged via
  PRs #1–#5 (confirmed in `git log`). Safe to prune; not lost work.
- **Genuinely unused scaffold:** `orchestrator-step4-competitor-social` is similarly 0
  ahead/11 behind, but — unlike the five above — never had any commits of its own at all (see
  §D).
- **Live/recent, not stale:** the three expense-buddy worktrees each have exactly 1 commit
  ahead of `origin/main` and are 0–3 behind.
- No two branches were found editing the same files in genuinely incompatible ways anywhere
  in the worktree set.

---

## What's genuinely solid — don't lose this in the gap list

- The release-side autonomy chain (autonomy gate → swarm regression check → calibration →
  canary → promote/rollback) is real, tested, and fires automatically on every qualifying PR
  merge for the one area (`ui-fixes`) actually opted into L3.
- Step 2's per-device adaptive UI is live in production, not a spec.
- Agent sandboxing against prompt injection (`agent-sandbox.ts`) is genuine security
  engineering: isolated settings, a minimal tool set, an OS-level sandbox denying credential
  env vars and SSH/AWS/config directories, tested against a real injected
  exfiltration-attempt prompt that failed exactly as designed.
- The orchestrator test suite is green: 1,101 passing tests, 0 failures.
- Console-to-API wiring has no fabricated data and no dead calls within the surface that
  exists — a level of cross-repo consistency that's easy to get wrong across many sessions
  and wasn't.
- COORDINATION.md's workstream-level disclosure discipline is consistently honest about
  failures, false positives, and collisions — the project's biggest reliability asset, even
  though the document around it has rotted.

---

## Recommended next steps, priority order

1. **Commit or deliberately discard the orchestrator's uncommitted Step 4 files now**
   (Cross-cutting #4) — real data-loss risk, zero cost to fix, and `console/`'s own
   zero-commit state (#7) makes this a pattern worth breaking deliberately rather than per
   incident.
2. **Pull the local orchestrator checkout to `origin/main`** (Cross-cutting #5) before doing
   any further audit or development against it — it is currently missing all of Step 3's
   closed-loop milestones and the health-signals feature.
3. **Pick one real external channel and wire `performLiveAction` to it, or relabel every
   "done, live-validated" Step 4 claim** to reflect that nothing has executed externally yet
   — the gap between the label and the code is the single biggest credibility risk in the
   project.
4. **Build or explicitly schedule a trigger for the detection→fix and growth loops** (cron,
   webhook, or a GitHub Actions `schedule:`) — today "self-healing" and "self-distributing"
   both depend on a human remembering to run a CLI command; only release-gating truly fires
   on its own.
5. **Automate per-app bootstrapping for Step 1** (auto-provision `.github/workflows/auto-release.yml`
   and a starter `.day2-autonomy.json` during onboarding) — right now a second onboarded app
   gets none of Step 1's automation until someone hand-copies expense-buddy's config.
6. **Re-run `onboarding-rescan` on expense-buddy** now that PR #31 has shipped real adaptive
   config, to retire the stale `day2-config.ts` comment and `docs/expense-buddy-app-profile.md`
   claim that nothing reads the config plane yet.
7. **Either implement distinct L4/L5 behavior or collapse the autonomy scheme to what's
   actually implemented** (a binary L3 gate) — the six-level framing currently promises more
   graduated control than exists.
8. **Wire `console/src/routes/safety.tsx` to live backend state** — the one dashboard page
   whose entire purpose is showing real guardrail status currently shows none.
9. **Reconcile the closed-loop M1 merge-status contradiction and the `experiments.ts`
   statistical-framework conflict in COORDINATION.md**, and replace both stale "current
   state" snapshots with one, kept next to (not interleaved inside) the workstream table.
10. **Decide on an auth/multi-tenancy plan before onboarding a second real app or user** — the
    current single-operator, localhost-bound model (Cross-cutting #8) won't survive it.

---

## Methodology note

This audit ran as seven independent, parallel code-level investigations (Step 1, Step 2+3,
Step 4, console-vs-API, COORDINATION.md textual analysis, scheduling/git-hygiene, and
expense-buddy integration), followed by direct spot-verification of every claim that was
either high-stakes, surprising, or contested between investigations. One investigation
initially over-reached its assigned scope, attempted to synthesize findings it had no actual
visibility into, and produced one materially wrong claim (the autonomy-gate finding, §Cross-cutting
#3) alongside a substantial amount of independently-verified, accurate detail; that specific
claim was caught and corrected by re-reading the underlying config file directly rather than
trusted. This is reported transparently in the same spirit COORDINATION.md's own best
entries use — a wrong claim that gets caught and corrected in the open is a very different
thing from one that silently ships.
