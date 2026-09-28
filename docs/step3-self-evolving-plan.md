# Step 3 (self-evolving) — plan across all four components

See `STAGE3.md` / `COORDINATION.md` for cross-session status and why this stage started when it did. This doc is the design; the coordination log is the narrative of what's actually landed.

## Roadmap definition

Per the source doc's roadmap table: "Evolution engine, experiments, swarm calibration loop, competitor feed | Promoted changes hold up after 90 days." Nobody had started design or implementation on any of the four components before this plan (confirmed via a full search of `COORDINATION.md`/`STAGE*.md`/`docs/` and both repos' git history as of 2026-09-27).

## Why now, and what's still honestly gated

Two of the four (experiments at real statistical scale, and the stage's own exit criterion — "promoted changes hold up after 90 days") are blocked on the same thing the retention-lift gate has always been blocked on: real users and real elapsed time. No amount of engineering fixes that. Consistent with how Step 2 was handled (build the real mechanism now — `decideSlotConfig`, the composer, the per-user model — honestly reporting what isn't observable yet, rather than waiting indefinitely for a gate that may never lift on its own), this plan builds real infrastructure for all four components now, and stays explicit everywhere about which parts are "real and working" today versus "real and working, but not yet meaningful at scale."

The user explicitly directed Step 3 to start in one session while a separate session continued hardening Step 1/2 — a deliberate division of work across sessions, not a contradiction of any "keep hardening" note logged elsewhere in this file's history. If you're a session picking this up cold: check the session map in `COORDINATION.md` for who's currently doing what before claiming a piece of this.

## Sequencing and why

1. **Swarm calibration loop** — first, because it's fully buildable and safe today (no real users needed, ships with its override defaulting to "off"), and it's grounded in real evidence already collected in this project: three separate times, a live canary release was blocked by a swarm v1 finding that turned out — after manual investigation with real browser tools — to be a false positive. See `COORDINATION.md` W21/W25 for the three specific incidents (CSS-transition timing, shadow-DOM `activeElement`, native `<input type="date">` segment highlighting). Each time, the fix was the same shape: investigate live, confirm it's not real, hand-edit the persona's prompt with a new guidance bullet. This component automates that loop.
2. **Experiments infrastructure** — second, because the swarm-based comparison mechanism (`orchestrator/src/swarm.ts`'s `buildComparisonPrompt`/`runComparisonPersona`/`parseComparisonResult`, used throughout W16/W16b/W16c/W16d) is already a primitive, ad-hoc version of this. Formalizing it is a natural next step and reuses calibration's own "build the mechanism honestly, mark what's not statistically meaningful yet" posture.
3. **Evolution engine** — third, because a *safe* version of it (proposal generation, not autonomous shipping) depends on having a well-audited pattern of "propose → human reviews → build → verify → ship" already proven trustworthy — which components 1 and 2 exercise directly.
4. **Competitor feed** — last and lowest-priority: a real, buildable research capability, but expense-buddy is a demo app with no real competitive position, so its output feeds the evolution engine's proposals rather than standing alone, and it introduces a genuinely new capability (external web research) nothing else in this project has needed yet.

Whoever picks up a component: check this doc's section for it, check `COORDINATION.md` for whether it's already claimed, and update both when you start and when you finish — same discipline as every other workstream in this project.

## Component 1: Swarm calibration loop

**Explicit non-goal:** this does not invent new leniency. The skeptic can only re-apply patterns a human already vetted and added to a shared checklist. A genuinely new false-positive class still blocks the release and still requires a human to investigate and add a new checklist entry — this bounds "self-evolving" to mechanizing already-approved judgment, not creating new judgment.

**Collision note (check freshness before touching):** as of this doc's writing, Session C's W28 (installing `bubblewrap`/`socat` in `expense-buddy/.github/workflows/auto-release.yml` so swarm's sandbox works on GitHub Actions) was claimed but not yet landed, and its own stated scope explicitly excludes `swarm.ts`/`release.ts`. This component avoids `auto-release.yml` and `swarm.ts`'s sandbox config (`failIfUnavailable`, `autoAllowBashIfSandboxed`, the `sandbox` block in `runPersona`) entirely — `calibration.ts` defines its own small, disclosed-duplicate copy of the sandbox/denylist constants rather than editing near that block. Re-check `COORDINATION.md`'s W28 row before touching `swarm.ts` — if it's landed by the time you read this, the sandbox-duplication tradeoff below is worth revisiting (dedupe into a shared file).

### Implementation

#### 1. New file: `orchestrator/src/false-positive-patterns.ts` — single source of truth

```ts
export type FalsePositivePattern = {
  id: string;                 // stable slug, never reused once shipped
  personas: string[];         // base persona names this applies to, e.g. ["accessibility-auditor"]
  description: string;        // the pitfall + concrete re-verification steps, one paragraph
  discovered: string;         // "W21", "W25" — matches this project's citation style
};

export const FALSE_POSITIVE_PATTERNS: FalsePositivePattern[] = [
  { id: "css-transition-timing", personas: ["accessibility-auditor"], description: /* today's bullet 1, verbatim */, discovered: "W21" },
  { id: "shadow-dom-active-element", personas: ["accessibility-auditor"], description: /* bullet 2, verbatim */, discovered: "W21" },
  { id: "native-control-internal-segment", personas: ["accessibility-auditor"], description: /* bullet 3, verbatim */, discovered: "W25" },
];

export function hasApplicablePatterns(basePersonaName: string): boolean;
export function buildPersonaGuidance(basePersonaName: string): string;   // preventive framing, no ids — rendered into the persona's own task text
export function buildSkepticChecklist(basePersonaName: string): string; // diagnostic framing, WITH ids — rendered into the skeptic's prompt
```

Keep each `description` byte-for-byte identical to the three bullets already in `swarm.ts`'s `accessibility-auditor` task text. This is what makes `swarm.test.ts`'s existing content-check tests keep passing **unmodified** — they become an indirect proof the refactor didn't lose content, without needing to touch that test file.

#### 2. Edit `swarm.ts` — one narrow spot only

In `BASE_PERSONAS`'s `accessibility-auditor` entry, replace the three inline bullets with `buildPersonaGuidance("accessibility-auditor")`. Nothing else in the file changes.

#### 3. New file: `orchestrator/src/calibration.ts` — the skeptic

```ts
export type CalibrationVerdict = {
  persona: string;                 // e.g. "accessibility-auditor-desktop"
  matchedPatternId: string | null;
  clearedAsFalsePositive: boolean;
  summary: string;
  isError: boolean;
  costUsd: number;
};

// Pure, unit-tested — the fail-closed core.
export function parseCalibrationVerdict(
  finalText: string,
  isError: boolean,
  validPatternIds: string[],
): { matchedPatternId: string | null; clearedAsFalsePositive: boolean; summary: string };

// Thin agent-invoking wrapper — zero unit coverage, validated live only (like runPersona).
// Short-circuits to "not cleared", no query() call, if no pattern applies to this persona.
export async function runSkepticCheck(
  previewUrl: string,
  failedResult: PersonaResult,
): Promise<CalibrationVerdict>;

// Batches one runSkepticCheck per failing persona (mirrors runSwarm's shape). Wrapper, no unit coverage.
export async function calibrateSwarmFailures(
  previewUrl: string,
  results: PersonaResult[],
): Promise<{ allClearedAsFalsePositive: boolean; verdicts: CalibrationVerdict[] }>;

// Append-only JSONL audit trail, same idiom as autonomy.ts's recordAutonomyAudit.
export function recordCalibrationAudit(
  auditFile: string,
  sha: string,
  previewUrl: string,
  verdicts: CalibrationVerdict[],
): void;
```

**Fail-closed rule (the load-bearing safety property of the pure parser):** `clearedAsFalsePositive` is `true` only when all of the following hold:
- the skeptic's final line is exactly `CALIBRATION_VERDICT: FALSE_POSITIVE — pattern: <id> — <evidence>`,
- `isError` is `false`,
- `<id>` is a member of `validPatternIds` for that persona,
- the `<evidence>` clause is non-empty (rejects a bare, unsubstantiated clear).

`CONFIRMED_REAL`, `INCONCLUSIVE`, a missing/malformed line, a hallucinated/typo'd pattern id, an empty evidence clause, or any SDK error all resolve to `false`. The skeptic can only re-apply a pattern a human already vetted — never invent a new one.

#### 4. Edit `release.ts` — additive only, no new status literals

New optional options on `CanaryReleaseOptions`:
```ts
skipCalibration?: boolean;          // same rationale as skipSwarmCheck
allowCalibrationOverride?: boolean; // default false — see "safety valve" below
calibrationAuditFile?: string;      // default "day2-calibration-audit.jsonl"
```

Enrich the existing `CanaryReleaseResult` union with an optional `calibration?: CalibrationVerdict[]` (on `swarm_check_failed`) and optional `calibrationOverride?: CalibrationVerdict[]` (on the three later statuses) — no new status values, so every existing consumer (`canary-cli.ts`'s `JSON.stringify`, `auto-release-cli.ts`) keeps working unchanged.

In `runCanaryRelease`, where it currently returns `swarm_check_failed` immediately on `!swarm.allPassed`: unless `skipCalibration`, run `calibrateSwarmFailures`, log each verdict, record the audit entry. If not all verdicts cleared, or `allowCalibrationOverride` is off, still return `swarm_check_failed` (now carrying the `calibration` array for visibility). Only if every failure cleared **and** `allowCalibrationOverride` is explicitly `true` does the pipeline proceed past the swarm gate, carrying `calibrationOverride` through to whichever later status it reaches.

**Safety valve — ships with `allowCalibrationOverride` defaulting to `false`.** With it off, a fully-cleared calibration still blocks the release, byte-identical to today's behavior — but the result now visibly shows "all N failures matched a known pattern and were confirmed live; override available but not applied." This lets the mechanism run for real on every real block, building a visible, auditable track record, before it's ever trusted to actually skip the gate. Flip it on later — a per-run flag at first, a persistent `.day2-autonomy.json`-style config as a fast-follow, not built now — only after watching it correctly clear known false positives across several real runs without ever wrongly clearing a real bug.

#### 5. New test file: `orchestrator/src/calibration.test.ts`

Covers only the pure/testable surface (matches `swarm.test.ts`'s own boundary — zero coverage of the SDK-calling wrappers):
- `parseCalibrationVerdict`: well-formed clear with a valid id; a hallucinated/typo'd id (**the single most important test**); `CONFIRMED_REAL` never clears; `INCONCLUSIVE` never clears; `isError: true` never clears even over an otherwise-valid line; missing verdict line fails closed; empty transcript fails closed; empty evidence clause fails closed; only the first verdict line is used.
- `false-positive-patterns.ts`: every pattern's `personas` reference a real base persona name; no duplicate ids; `buildPersonaGuidance("accessibility-auditor")` contains the required substrings (re-homing the intent of `swarm.test.ts`'s existing checks as content tests, without touching that file); `buildSkepticChecklist` includes every applicable id verbatim; `hasApplicablePatterns` is `false` for personas with no patterns defined yet (locks in the cost short-circuit).
- `recordCalibrationAudit`: appends one correct JSON line per call to a temp file (same pattern as `autonomy.test.ts`'s audit test).

#### 6. Live-validation plan (real infrastructure, not mocks — this project's own standing discipline)

1. **Positive control**: deploy a tiny disposable fixture (a focusable, visible, labeled button inside `attachShadow({mode:"open"})`) as a real Cloudflare Worker version via the same `wrangler versions upload` path `release.ts` already uses. Feed `runSkepticCheck` a synthetic `PersonaResult` reproducing the exact original false-positive report. Confirm live: it drills into `shadowRoot.activeElement` and correctly emits `FALSE_POSITIVE — pattern: shadow-dom-active-element`.
2. **Negative control on the same fixture (non-negotiable)**: a second fixture where the shadow-root button genuinely has no focus indicator — confirm the skeptic emits `CONFIRMED_REAL`, not a false clear. Without this, the positive control alone proves nothing about safety.
3. **End-to-end via `runCanaryRelease --dry-run`** (zero traffic risk): in a throwaway branch never merged, temporarily reintroduce one of the already-fixed false-positive-triggering conditions into `expense-buddy` so the real 6-persona swarm organically fails on a known pattern. Run with `allowCalibrationOverride: true`, confirm: swarm fails → calibration runs live → clears it → proceeds to `dry_run_stopped_before_traffic_shift` with `calibrationOverride` populated and a real, readable audit-file entry.
4. **Negative control at the release level**: same dry-run against a preview carrying a genuine, uncatalogued failure — confirm it still returns `swarm_check_failed`.
5. Only after all four check out should a real (non-dry-run) release ever run with `allowCalibrationOverride: true` — and even then, a human should review the first several real overrides via the audit log before trusting it unattended.

### Open items disclosed, not silently resolved

- `calibration.ts` duplicates ~15 lines of sandbox/denylist config rather than touching `swarm.ts` near the flagged W28 area — worth deduping into a shared file once W28 lands.
- One skeptic check per failing persona, no cross-viewport deduping — simplest, and avoids incorrectly clearing a real mobile-only bug via a textually-similar desktop false positive, at the cost of occasionally running two checks for one root cause.
- Found, out of scope to fix here: `auto-release-cli.ts` doesn't set a failing exit code on `swarm_check_failed` (only on `smoke_check_failed`/`rolled_back`), unlike `canary-cli.ts`. Worth a separate, later fix.

## Component 2: Experiments infrastructure

### What exists today, informally

`orchestrator/src/swarm.ts`'s `buildComparisonPrompt`/`runComparisonPersona`/`parseComparisonResult` already run personas under two named conditions (control/treatment) and compare outcomes — this is what powered W16/W16b/W16c/W16d. It's ad-hoc in three ways this component formalizes: (a) variant assignment is manual (a human seeds a specific KV config for a specific test device), not a real, repeatable assignment rule; (b) "significance" is eyeballed from a handful of swarm-persona runs (W16d: "47.0 control vs. 48.0 treatment... plausibly reverses at larger N, untested"), not computed; (c) there's no way to run this against real device cohorts once they exist, only synthetic swarm personas.

### What's buildable now, honestly labeled

1. **Real, deterministic variant assignment** — a pure function `assignVariant(deviceId: string, experiment: ExperimentConfig): string`, hashing `deviceId` + experiment name into a stable bucket (same device always gets the same variant, no storage needed to remember it). New file `orchestrator/src/experiments.ts`. `ExperimentConfig = { name: string; variants: { name: string; weight: number }[] }`.
2. **Wire it into `handleConfigPlane`** (`expense-buddy/src/server.ts`) as a new possible source of a slot override, layered *under* the existing explicit-KV-override (still wins unconditionally — real test seeding, per W14/W16's pattern, must keep working) and *above* `decideSlotConfig`'s rule-based decision. An active experiment's assignment picks which of two `SlotConfig` variants a device gets, deterministically.
3. **A real statistical-significance calculator** — pure function `evaluateExperiment(controlOutcomes: number[], treatmentOutcomes: number[]): { pValue: number; significant: boolean }` (two-proportion or two-sample test, whichever fits the outcome type actually being measured — action counts, like W16d's, are continuous, not proportions, so likely a Welch's t-test analog). Fully unit-testable with synthetic data — this is genuinely real math, not gated on anything.
4. **Event pipeline addition**: an `experiment_exposure` event type (which experiment + variant a device was assigned, recorded once per device per experiment) so `evaluateExperiment` has something real to compute over, from either swarm-persona runs (today) or real device traffic (once it exists).

### What's honestly still gated, and how this stays truthful about it

The calculator will report a real p-value on real (or swarm-synthetic) data — but a handful of swarm-persona runs, as W16d itself noted, has essentially no statistical power. This component's job is to make that limitation *visible* (report sample size and power alongside significance, refuse to label anything "significant" below a minimum N) rather than to manufacture confidence that isn't there. Matches the same honesty `primaryGoal`/`habits`/`statedPreferences` already apply — report what's genuinely computed, flag plainly what it doesn't yet prove.

### First concrete deliverable

`experiments.ts` (assignment + significance calculator, fully unit-tested) and the config-plane wiring, live-validated the same way W16's comparison tests were: seed a real experiment via KV, run a handful of swarm personas under each variant against a real deployed preview, feed the real outcome counts into `evaluateExperiment`, confirm the reported p-value/sample-size framing is honest about what a run of this size can and can't establish.

## Component 3: Evolution engine (proposal generation, not autonomous shipping)

### Scope decision, made explicit rather than assumed

"Generating genuinely new features/flows" is the most consequential of the four components — a categorically bigger leap in autonomy than anything shipped in this project so far, which has only ever fixed real bugs or varied among already-human-built, already-verified UI blocks (Step 2's composer). This plan scopes the evolution engine's *first* version to **proposal generation only**: an agent that reads the real per-user model and event history and produces a written proposal (rationale + a concrete building-block contract sketch, in the same shape as `docs/step2-self-adapting-spec.md` §3's typed contracts) for a human to evaluate — it does not write, merge, or ship code on its own. This mirrors exactly how `WeeklyReportSlot` actually got built: a novel-feature idea, checked with the user before any code was written, then hand-built and verified through the existing pipeline. The evolution engine's job is to make the *first half* of that (noticing a real, repeated, unserved pattern and proposing something for it) something the system itself can surface, not to skip the human-review half.

### What's buildable now

1. New file `orchestrator/src/evolution.ts`: `proposeFeature(model: PerUserModel, eventHistory: StoredEvent[]): FeatureProposal | null` — an agent-invoking function (same idiom as `runPersona`, not a pure function, since this genuinely requires generative reasoning over open-ended data) that looks for a repeated, currently-unserved pattern (the same kind of signal `habits`/`WeeklyReportSlot` already formalizes for one specific case: 3-consecutive-weeks) and either proposes a concrete new building block or returns `null` ("nothing worth proposing yet" is a legitimate, expected outcome, not a failure).
2. `FeatureProposal = { title: string; rationale: string; observedEvidence: string; proposedContract: string; openQuestions: string[] }` — deliberately a *document*, not code, matching the "propose, not ship" scope.
3. Land proposals into the exact review surface Session C already built for the app-owner side: `orchestrator/src/approvals.ts`'s Apply/Undo/Ask pattern, or a clearly-separate new "proposed features" list alongside it — a human reads and decides, same as every other consequential decision in this project's history.

### What's explicitly out of scope for this first version

Auto-generating and merging code for a proposal; auto-shipping a proposal even at L3 (a new autonomy consideration — genuinely new features should very likely never share the `ui-fixes` L3 area's risk classification, since inventing something is categorically different from fixing/tweaking something that already exists and was already reviewed once).

### First concrete deliverable

`proposeFeature` running against the real, current per-user-model/event data (today mostly synthetic test-device data, honestly labeled as such the same way Component 2 labels its statistical power) producing at least one real, reviewable proposal end to end, surfaced through a real review mechanism — no code generation yet.

## Component 4: Competitor feed

### Scope and honest framing

Expense-buddy is a demo/test app with no real competitive position, real customers, or real market — a "competitor feed" in the source doc's sense (informing feature proposals with what real competing products do) is genuinely buildable as a research capability, but its *output* only has somewhere useful to go once Component 3 exists to consume it. This is why it's sequenced last.

### What's buildable now

A new agent-invoking function `researchCompetitorFeatures(category: string): CompetitorInsight[]` using web search/fetch tools (the first Step 3 piece to need external web research — nothing else in this project has needed it) to summarize what real, named competing apps in a given category (e.g., "personal expense trackers") do, structured the same shape as a `FeatureProposal`'s `observedEvidence` field so Component 3 can cite it directly. This is a real, working capability regardless of expense-buddy's own real-world status — it just currently has a thin, demo-app audience for its output.

### First concrete deliverable

One real research pass for expense-buddy's actual category, producing a small set of structured, cited insights, manually reviewed for usefulness before wiring it into Component 3's proposal generation as an additional input.
