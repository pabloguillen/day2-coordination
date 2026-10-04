# day2 Platform — Independent Implementation Audit (2026-10-04, fresh pass)

**Scope:** entire day2 platform — `orchestrator/` (Steps 1-4 backend), `console/` (owner dashboard), `expense-buddy` (the one onboarded app), and all project documentation (`COORDINATION.md`, `STAGE0-4.md`, `docs/*.md`).

**Method:** Six independent, memory-free agents were launched in parallel, each scoped to a different subsystem. None used any memory/MCP recall tool or trusted a prior session's conclusions — each read full source files directly, ran the real test suites itself (`bun test`, `bun run build`), traced import graphs, and spot-checked live git/GitHub history. This document is the synthesis of their six independent reports. Where two or more agents converged on the same fact from different angles, that is noted — it's the strongest evidence in this audit.

This supersedes nothing by fiat — `docs/implementation-audit-2026-10-03-independent.md` and `docs/platform-audit-findings.md` remain as a historical record — but every claim below was independently re-derived from code today, 2026-10-04, not copied from either.

---

## Executive summary

The platform is **more honestly self-documented than most codebases get credit for**, and the core mechanics of all four Steps are real engineering, not scaffolding dressed up as done — backed by a genuinely large, almost entirely passing test suite (orchestrator: **1021/1021**, console: builds clean, expense-buddy: **144/144** vitest). Nothing audited was found to be fabricated data pretending to be real, and in several places the code's own comments pre-disclose exactly the gap an independent audit would otherwise have to go dig for.

The one pattern that repeats across every Step, though, is **"real infrastructure with no caller."** A large fraction of the newer, more sophisticated modules — entry-path learning, cohort report cards, day2's own system-health KPIs, growth-render, the judge model's real prediction call site, growth-reward, growth-website, growth-winback, growth-cross-channel, growth-trend-campaigns — are fully built, independently unit-tested, and **never invoked by anything else in the codebase**. The system is a well-tested library of capabilities more than it is a running, self-triggering autopilot. Three converging facts anchor this:

- **No automatic trigger exists for almost anything.** The only two real non-human triggers found anywhere are a PR-merge-triggered profile rescan (Step 2) and a 6-hourly health-scout cron added **2026-10-04** — which itself can't file real fixes yet because the CI environment has no `ANTHROPIC_API_KEY` secret.
- **No execution path ever touches the real world.** Every chain that could spend money, post content, or call an external platform terminates in a hardcoded stub (`performLiveAction` in `growth-execution.ts`) that always returns `execution_failed`. This was independently confirmed by three separate agents (Step 1, Step 4a, Step 4b) reading different files.
- **A human still clicks merge on every PR**, confirmed from real GitHub history, even for the one autonomy area (`ui-fixes`) opted into the highest automation level. Autonomy levels L3/L4/L5 are confirmed behaviorally identical in code (independently confirmed by two agents).

No "Critical" severity findings surfaced. The most serious items are a **High**-severity documentation/code mismatch in the growth allocator (a comment claims a wiring that doesn't exist) and a cluster of **Medium** findings — mostly stale docs, unwired modules, and one real latent multi-tenancy bug waiting for a second app to exist.

---

## Platform-wide cross-cutting findings (highest confidence — multi-agent convergence)

| # | Finding | Confirmed by | Severity |
|---|---|---|---|
| 1 | No execution path anywhere ever performs a real external action (ad spend, social post, API call to a growth/ad platform). `growth-execution.ts`'s `performLiveAction` is a permanent, disclosed stub. | Step 1, Step 4a, Step 4b agents, independently | High (by design, but easy to mis-state in sales/positioning material) |
| 2 | Autonomy levels L3/L4/L5 are behaviorally identical — only `< L3` is checked anywhere in code. | Step 1 agent + Console/cross-cutting agent, independently | Medium (disclosed in `types.ts`/`autonomy.ts` comments and in COORDINATION.md's 2026-10-03 decision log — matches code exactly) |
| 3 | No auth, no session, no multi-tenancy at the data-model level (`apps-registry.ts` has no `tenantId`/`ownerId` field) — confirmed to match the project's own "documented, deliberately not built" decision log. | Console/cross-cutting agent, Step 4a agent | Medium (disclosed; becomes a real migration cost the moment a 2nd operator or 2nd customer shows up) |
| 4 | A real scheduler (GitHub Actions cron) was added for health-scout on **2026-10-04**, one day after COORDINATION.md's 2026-10-03 section stated flatly "no scheduler, cron, or webhook exists anywhere." That section was never corrected even though a later same-day entry mentions the new cron. | Step 1 agent + Step 4a agent, independently | Low/Medium (stale doc, not a code bug) |
| 5 | The orchestrator test count changed from a COORDINATION.md-claimed 1101 (2026-10-02) to an independently-measured 1021 (today) with no explanation anywhere in the log for the ~80-test delta. | Step 1 agent (ran `bun test` fresh: 1021/1021) + Console/cross-cutting agent, independently, same number | Medium |
| 6 | Real evidence day2 has acted on a real app, not just fixtures: genuine merged PRs, `day2-fix-*` branches, and a scheduled workflow all exist in expense-buddy's real git/GitHub history. | Console/cross-cutting agent (GitHub history) + Step 1 agent (`gh run list`/`gh run view` on 35 real workflow runs) | Positive finding, not a defect |

---

## Step 1 — Self-Healing

**What's real:** signal ingestion (Sentry, manual reports, interaction-friction polling, swarm-persona failures) → clustering/prioritization → fix-agent (Claude Agent SDK, sandboxed) → independent adversarial verifier-agent → isolated git branch → swarm v1 pre-release persona testing (real Playwright) → canary rollout with Sentry-driven rollback → autonomy-gated release decision → PR (never auto-merged). This is genuine, not stubbed, and `release.ts`/`autonomy.ts`/`signals/*` all carry thorough, substantive unit tests (25, 8, 11+9+7 tests respectively).

**Test health:** `bun test` (run fresh) → **1021 pass, 0 fail, 3555 expect() calls, 70 files.**

**Verified / contradicted claims:**
- "Never auto-merges — a human always reviews and clicks merge" — **confirmed** against real merge history on 8 real PRs (#21-#33), including ones inside the L3-opted-in `ui-fixes` area; all merged by a human, `is_bot: false`.
- "L3/L4/L5 behaviorally identical" — **confirmed** (`autonomy.ts:112` only checks `< L3`).
- `docs/step1-self-healing-gap-analysis.md` says "release pipeline with canary+rollback: Not started," "swarm as regression tester: Not started," "autonomy levels: Not started as explicit model" — **contradicted by current code**; all three are fully built. The doc is dated W2 (2026-09-25) and was never updated or marked superseded even though later COORDINATION.md entries from the same week describe building exactly these.
- "Auto-release fires for real on every PR merge for the L3 area" — **true but weaker than it sounds**: of 35 real `auto-release.yml` GitHub Actions runs, only 2 ever reached an AUTO-SHIP decision, and both were stopped by the swarm gate before any traffic shift. **Zero fully unattended releases have ever completed end to end.** The one real "promoted to 100%" success in the log was a human manually running `bun run canary` from a terminal after merge, not the automated workflow completing on its own.

**New findings:**
- **[Medium]** The diagnosis router (`diagnosis/rules.ts`) computes a `route: "healing"` label on crash/error-rate spikes, but **nothing in the codebase ever reads `.route` to dispatch anywhere** — its only two consumers (`cohort-report-card.ts`, `growth-arm-check.ts`) use it purely as a human-readable label. A cohort error-rate spike today produces a label on a report card, not an automatically-filed bug report.
- **[Medium]** `pipeline.ts::runPipeline` — the single most central function in Step 1 — has **zero automated test coverage** (only its pure dedup helper `isAlreadyProcessed` is tested). Same gap in `health-scout-cli.ts`'s actual filing logic and `swarm-fix-cli.ts` (no test file at all).
- **[Medium]** "Reproduce-first" discipline (write a failing test before fixing) is enforced only by LLM self-instruction in the prompt — the only mechanical gate in `pipeline.ts` is "did any file change," which would pass even if the fix-agent skipped writing a test.
- **[Low]** The new health-scout cron (every 6h) can currently only run `--dry-run` in production — `ANTHROPIC_API_KEY` is not among expense-buddy's configured GitHub secrets, so the scheduler exists but can't yet trigger a real fix.
- **[Low]** Trust-based level-up (`trust.ts`) is correctly disconnected from `autonomy-config.ts` by design (suggestion only, human must separately apply it) — and in practice has likely never been exercised, since only 2 auto-ship attempts have ever occurred for any area.

**Overall:** a well-verified, safety-gated PR/release *mechanism*, not yet a system that runs unattended day to day.

---

## Step 2 — Self-Adapting

**What's real:** agent-driven app-profile onboarding scan + drift re-scan (the latter wired to a real CI trigger on PR-merge), a full statistical layer (Welch's t-test + Bayesian Beta-posterior), ~45 domain KPI metrics with real confidence intervals, and a live-validated rule-based per-user adaptation loop in expense-buddy itself (`decideSlotConfig`, `WeeklyReportSlot`).

**Test health:** targeted suite → 202 pass; full orchestrator suite → 1021 pass, 0 fail (matches Step 1's independent count exactly).

**The experiments.ts vs entry-paths.ts conflict — independently re-verified as genuinely resolved, not cosmetic.** `entry-paths.ts` used to carry a private, duplicate Beta/Gamma sampler; the fix (commit `4c946fc`) deleted it and moved the shared math into `experiments.ts` as `evaluateProportionExperiment`, which `entry-paths.ts:9,250` now calls directly. Both are independently unit-tested, and `docs/closed-loop-spec.md` itself contains an honest, dated self-correction of an earlier false "RESOLVED" claim — a real instance of the project catching its own mistake.

**New findings:**
- **[Medium]** `entry-paths.ts`'s learning job (`learnEntryPaths`) and holdout-promotion logic are real, tested, and **have zero callers anywhere** — no CLI, no CI, no cron. expense-buddy's `LEARNED_ENTRY_PATHS` array is permanently `[]`.
- **[Medium]** `cohort-report-card.ts` is fully dead in production — no caller outside its own test; its `linkedItems` field is hardcoded `[]` forever, so the spec's claim that it "links to the underlying proposal/growth item" is typed but never implemented.
- **[Medium]** `metrics/day2-kpis.ts` (the system's own health KPIs — change-success rate, rollback rate, undo rate) is real math with **no loader anywhere** mapping real audit-log data into it.
- **[Low]** `STAGE2.md` is stale — its log stops at W26 even though substantial later work (closed-loop M1-M5) landed under different docs.
- **[Low]** `calibration.ts`, `ai-slop-patterns.ts`, and `design-references.ts` all self-identify in their own file headers as **Step 3 or Step 4** modules, not Step 2 — worth noting since an externally-assumed file list would misattribute them.
- The project's own stated Step 2 exit criterion — a measured retention lift against a holdout — **has never run**, because there are no real users yet. This is disclosed, not hidden, in COORDINATION.md.

**Overall:** the adaptive loop that exists is real and was live-validated once against a running Workers deployment; the more sophisticated learning/reporting layer built on top of it is well-engineered but entirely unreachable in production today.

---

## Step 3 — Self-Evolving

**What's real:** feature-proposal generation (`evolution.ts`/`proposals.ts`) — a genuinely fail-closed agent wrapper that never writes code itself, plus a complete rejection-memory system added 2026-10-03.

**Test health:** targeted suite → 133 pass, 0 fail.

**Rejection-memory system — independently traced end to end and confirmed genuinely wired**, not just defined-and-orphaned: record (`proposals.ts:40-43`) → list (`:46-50`) → check (`evolution.ts:76-82`) → CLI flag (`evolution-cli.ts:60-68`) → prompt injection (`evolution.ts:131`, a hard "don't propose these again" block) → deterministic backstop re-check after the agent responds (`evolution.ts:283-288`). Every piece is actually called in the real path.

**Scope-boundary check:** `pattern-library.ts`/`pattern-transferability.ts` were suspected to possibly belong to Step 3 — **confirmed they belong to Step 4**: zero imports from `evolution.ts`/`proposals.ts`; all real importers are growth/distribution modules; the file headers and the original commit message both say "Step 4" explicitly. `swarm.ts`'s comparison-persona mode is Step 1-built infrastructure reused for a Step 2 experiment (W16), not a Step 3 mechanism — correcting an initial task-framing guess.

**New findings:**
- **[Medium]** The rejection-memory feature has **no COORDINATION.md/STAGE3.md entry at all**, breaking the project's own documentation discipline for every other Step 3 change.
- **[Medium]** The feature has **never been exercised against real data** — the rejections JSONL file doesn't exist on disk, meaning `--reject` has never actually been run for real.
- **[Low]** The evolution engine has produced exactly **one** proposal in its entire history (Sep 27) — real, not fixture data, but an n=1 track record.
- **[Low]** No `evolution-cli.test.ts` exists — the CLI argument wiring itself is unverified except by reading.
- No scheduler exists for proposal generation; every run is a manual CLI invocation.

**Overall:** correctly engineered, cleanly bounded, good unit coverage of pure logic — but minimal real-world mileage.

---

## Step 4 — Self-Distributing (split across two audits: strategy/governance/execution, and creative/channels/intelligence)

**What's real (strategy/governance half):** app-stage detection and channel allocation (`growth-strategy.ts`), a genuine Thompson-sampling bandit allocator (`growth-allocator.ts`), a hard, fuzz-tested budget governance gate (`spend-governance.ts` — 200+ randomized scenarios proving the cap is never exceeded), a multi-stage execution gate pipeline (`growth-execution.ts`), a real CSV ingest path for ad-spend/payment data, and a real multi-app registry.

**What's real (creative/channel half):** real LLM-driven copywriting with two independent agent-based safety checks (truthful-claims, authenticity), real competitor/trend research via genuine web search and official YouTube/Reddit APIs (including an honestly-disclosed live failure — TikTok returning a real HTTP 403 bot-block), real HTML-to-image template rendering, and real Playwright screen-recording of the live app.

**Test health:** strategy/governance half → 236 pass, 0 fail, 2121 expect() calls; creative/channel half → 287 pass, 0 fail, 487 assertions. Combined with Steps 1-3, the full orchestrator suite is the single 1021/1021 figure above.

**Core verdict, confirmed independently by both Step 4 agents and the Step 1 agent: everything terminates in simulation.** `spend-governance.ts` enforces a real cap but on a **paper ledger** — no real ad account or payment processor is ever debited. `growth-execution.ts::performLiveAction` is a hardcoded stub: `{status: "execution_failed", reason: "Live execution is not implemented in this pass — no real MCP tool-invocation mechanism exists yet."}`. This matches the project's own repeated "stopping honestly one step before anything real happens" framing in STAGE4.md.

**Multi-tenancy reality:** `apps-registry.ts` currently holds exactly one app (expense-buddy). More importantly, `growth-tools-config.ts::resolveBindings(config, capability, appId)` **receives `appId` and discards it** (`void appId;`) — a real latent bug, not just an absent feature: the moment a second app is onboarded, any connected-account binding would resolve as "connected" for every app, since nothing is keyed per-app. This is self-disclosed in the file as an open question.

**New findings:**
- **[High]** `growth-allocator.ts`'s own comment claims staged reward recalibration "feeds" `recordWeightedOutcome`/`selectArmWeighted` — but it **never imports `growth-reward.ts`**. Only the reward module's own test and an integration test exercise it. An operator reading that comment would believe rewards already flow into arm selection; they don't.
- **[Medium]** A large set of fully-built, fully-tested modules have **zero production callers anywhere**: `growth-render.ts` (the only code that produces real pixel/video assets — its own header admits it isn't wired in), `growth-judge-model.ts`'s real prediction call site (trained/evaluated only on synthetic data; `judgePrediction` field exists on feed records but nothing ever populates it), `growth-website.ts` (no CLI even exists for it, unlike its siblings), `growth-winback.ts` (also assumes a `atRiskDeviceIds` input that nothing in the codebase ever computes), `growth-cross-channel.ts`, `growth-trend-campaigns.ts`.
- **[Medium]** Pricing-tier claims in `docs/offering-logic.md` ("Starter: 1 app," "Growth: 5 apps") have **zero enforcement anywhere** — `apps-registry.ts::addApp()` has no plan or app-count ceiling check at all.
- **[Low/Medium]** `external-ingest.ts`'s named ad-platform/payment adapters (Meta, Google, TikTok, Stripe, Apple, Google Play) return `parse_failed` / "not implemented" **even when the relevant credential env var is present** — disclosed in-file, but worth flagging explicitly since setting the credential buys nothing today.
- **[Low]** `docs/closed-loop-spec.md`'s status banner and one inline note are **stale/false**: it says orchestrator PRs are "awaiting human review/merge" and that the experiments/entry-paths fix is "not yet on main" — both were merged days ago. The doc itself warns future readers not to trust "RESOLVED" language blindly; this is the mirror-image failure (says "pending," is actually done).
- **[Low]** Three "trend" files (`growth-trends.ts`, `growth-trend-sources.ts`, `growth-trend-campaigns.ts`) were checked for redundancy and found to be **genuinely distinct layers** (fast disposable trend detection → durable pattern promotion → ad-hoc trend-jacking decision), not duplicated code.
- **[Low]** No single Step 4 orchestrator file exists anywhere — the full creative→safety-check→execution→feed chain has never been wired together in one place; every such run in the project's history was a one-off manual script, never committed.

**Overall:** both halves of Step 4 are unusually honest about their own limits — nothing claimed "done" in the docs was found to be fabricated — but the system today is a well-tested *library* of growth-decision capabilities, not a running distribution pipeline. Nothing in Step 4 has ever posted, published, or spent anything in the real world.

---

## Console & cross-cutting integration

**Console ↔ API wiring:** all 17 routes traced against `api-server.ts`'s real endpoint registrations — **every route is genuinely wired to a real backend call; zero mock or hardcoded data found anywhere in the console.** `bun run build` succeeds clean (client + SSR).

**Auth/multi-tenancy:** confirmed absent at both the server (`api-server.ts` binds to `localhost` only, no auth middleware) and schema level (`apps-registry.ts` has no tenant field) — and this **matches the project's own documented decision** to defer it, not an undisclosed gap.

**Git/worktree hygiene:**
- `day2` (root) and `orchestrator` repos: clean, up to date with origin.
- **`console` has no git remote configured at all** — the entire operator-dashboard codebase exists on one machine with no off-box backup. Flagged once in COORDINATION.md on 2026-10-03 as "a decision for whoever wants one, not made here" and still unresolved.
- `expense-buddy` has uncommitted local drift right now: a modified CI workflow file and an untracked `.day2-app-profile.pending.json` (a genuine, real re-scan output — positive evidence the rescan CLI works, but currently un-promoted/un-committed).
- `orchestrator` has one stale local branch (`step4-component2-growth-strategy`, already merged) left over.

**Config-plane storage:** confirmed still not configured — `expense-buddy/src/server.ts:202` correctly fails closed with a 503 ("config plane storage not configured") rather than silently no-op'ing; no KV binding exists in this environment.

**Real-world evidence:** expense-buddy's actual GitHub history shows genuine day2-originated branches and merged PRs (self-healing-hardening #45, health-signals-scouts #44, closed-loop M1/M4 wiring, interaction-friction telemetry rollout, several real `day2-fix-*` auto-generated branches) — the loop has demonstrably run against a real app, not only fixtures.

---

## Consolidated findings by severity

**High**
1. `growth-allocator.ts` claims (in its own comment) to consume staged reward recalibration from `growth-reward.ts`; it does not import it at all. (Step 4a/4b)

**Medium**
2. No execution path anywhere performs a real external action — `performLiveAction` is a permanent stub. (Disclosed by design, but a live risk for positioning/sales claims.)
3. `growth-tools-config.ts::resolveBindings` discards its `appId` parameter — a real multi-tenancy correctness bug waiting for a second app. (Step 4a)
4. Diagnosis router (`diagnosis/rules.ts`) computes a `route` label nothing ever dispatches on. (Step 1)
5. `pipeline.ts::runPipeline` — Step 1's central orchestration function — has zero automated test coverage. (Step 1)
6. Entry-path learning loop (`learnEntryPaths`), `cohort-report-card.ts`, and `metrics/day2-kpis.ts` are fully built and tested with zero production callers. (Step 2)
7. Rejection-memory system (Step 3) has no COORDINATION.md/STAGE3.md entry and has never been exercised against real data.
8. Pricing tiers in `docs/offering-logic.md` ("1 app"/"5 apps") have zero enforcement in code. (Step 4a)
9. `growth-render.ts`, `growth-judge-model.ts`'s real call site, `growth-website.ts`, `growth-winback.ts`, `growth-cross-channel.ts`, `growth-trend-campaigns.ts` all have zero production callers. (Step 4b)
10. Orchestrator test count dropped from a COORDINATION.md-claimed 1101 to an independently-measured 1021 with no documented explanation.
11. `console` repo has no git remote — single point of failure.
12. COORDINATION.md's 2026-10-03 "no scheduler exists anywhere" section is stale as of 2026-10-04's health-scout cron addition.

**Low**
13. `docs/step1-self-healing-gap-analysis.md` claims canary/rollback, swarm regression testing, and autonomy levels are "Not started" — all are fully built; doc never updated.
14. `docs/closed-loop-spec.md` status banner and one inline note are stale (claims unmerged work that's actually been on `main` for days).
15. `STAGE2.md`'s log stops at W26, abandoned in favor of other docs for later Step 2 work.
16. Health-scout's new cron can only run `--dry-run` — no `ANTHROPIC_API_KEY` secret configured in CI.
17. "Reproduce-first" fix discipline is enforced by LLM self-instruction only, with no mechanical diff-level check.
18. `external-ingest.ts`'s named ad/payment-platform adapters return "not implemented" even with a credential present.
19. `evolution-cli.ts`, `swarm-fix-cli.ts`, and several other thin CLI wrappers have no dedicated tests (consistent project-wide pattern, not a one-off).
20. Uncommitted drift currently sitting in expense-buddy's working tree (CI workflow diff + untracked pending profile file).
21. `offering-logic.md`'s "multi-tenant" business-pitch language could be misread as a present-tense architecture claim.
22. One stale, already-merged local branch in `orchestrator` (`step4-component2-growth-strategy`).

---

## Recommendations (priority order)

1. **Fix the `growth-reward.ts` ↔ `growth-allocator.ts` comment mismatch** — either wire it in or correct the comment. This is the one place a reader would be actively misled about current behavior.
2. **Fix `resolveBindings`'s discarded `appId`** before onboarding a second app — otherwise the first multi-app customer silently gets cross-account binding leakage.
3. **Reconcile the stale docs** (`closed-loop-spec.md`'s status banner, `step1-self-healing-gap-analysis.md`'s "not started" items, the COORDINATION.md scheduler section, the 1101→1021 test-count gap) — cheap, high-signal fixes that restore the project's own stated documentation discipline.
4. **Back up `console`** — push to a remote; it's the one codebase in the platform with zero off-box copy.
5. **Decide deliberately** whether to wire any of the fully-built-but-orphaned modules (entry-path learning, cohort report cards, growth-render, judge-model real call site, growth-website/winback/cross-channel/trend-campaigns) into a real caller, or explicitly mark them as "built ahead of need" in the docs so future sessions don't assume they're live.
6. **Either enforce or remove** the pricing-tier app-count claims in `offering-logic.md` before it reaches anything resembling a real customer.

---

## Remediation status (2026-10-04, same day)

Every finding above was acted on the same day, via 7 parallel fix agents (each scoped to a non-overlapping file set, verified independently with `bun test`) plus direct action for the items that were genuinely the operator's call rather than a code fix. Final state: **orchestrator test suite — 1204 pass, 0 fail, across 85 files** (up from 1021 at audit time; net new tests from this remediation pass, not regressions — re-verified fresh after all agents landed). All code changes are currently unstaged in `orchestrator/` and `day2` root, pending a review/commit decision.

| # | Finding | Resolution |
|---|---|---|
| 1 | `growth-allocator.ts` claims to consume `growth-reward.ts`; doesn't | **Fixed** — new `recordStagedOutcome()` in `growth-allocator.ts` actually calls `computeStagedReward()` and feeds the result into `recordWeightedOutcome`. 14 new tests. |
| 2 | No execution path ever performs a real external action | **Left as a disclosed stub, by explicit decision** — building real ad-platform/payment integrations needs real credentials the operator doesn't have; this remains the platform's intentional safety boundary. |
| 3 | `resolveBindings` discards `appId` (latent multi-tenancy bug) | **Fixed** — `ToolBinding.connectedAccountRef` → `connectedAccountRefs: Record<appId, string>`; resolution now genuinely scoped per app. |
| 4 | Diagnosis `route` label never dispatched anywhere | **Fixed** — new `diagnosisToSignal()`/`diagnosesToSignals()` convert healing-routed diagnoses into real `Signal`s; wired into `health-scout-cli.ts`'s existing signal-gathering (human/CLI-triggered flow preserved, no new auto-invocation). |
| 5 | `pipeline.ts::runPipeline` had zero test coverage | **Fixed** — minimal dependency-injection refactor (additive, existing call sites unaffected) + 9 new tests covering ordering, dedup, and failure paths. |
| 6 | Entry-path learning, cohort report cards, day2-kpis unwired | **Fixed** — `entry-paths-cli.ts`, `cohort-report-card-cli.ts` (now genuinely populates `linkedItems` instead of hardcoded `[]`), `day2-kpis-cli.ts`, each built against real on-disk record shapes. Surfaced a new honest finding in the process: `owner_undo_rate` has no real data source anywhere in this codebase (`approvals.ts::undoChange` persists no audit trail), so it's correctly left unmeasured rather than faked as 0%. |
| 7 | Rejection-memory undocumented and never run live | **Partially fixed** — `STAGE3.md` now has a dated entry; `evolution-cli.test.ts` now proves `--reject`'s wiring end-to-end (mocked agent calls). Still true, and left true: the feature has never been exercised against real production data — that requires a real run, not a doc or test fix. |
| 8 | Pricing tiers unenforced | **Fixed, honestly bounded** — `addApp()` gained a caller-supplied `maxApps` cap (tested, opt-in, defaults to unlimited). Deliberately NOT wired into `api-server.ts`'s two real call sites, because there is no plan/billing system anywhere in this codebase to supply a real value from — doing so would have faked enforcement against a plan concept that doesn't exist. `offering-logic.md` now discloses this precisely. |
| 9 | growth-render/judge-model/website/winback/cross-channel/trend-campaigns orphaned | **Fixed** — `predictForCandidate` now wired into `growth-feed.ts`'s sole recording function (every new feed record gets a real, even if fallback, prediction); `growth-render-cli.ts`, `growth-website-cli.ts`, `growth-winback-cli.ts`, `growth-cross-channel-cli.ts`, `growth-trend-campaigns-cli.ts` all added, each sourcing real on-disk state rather than inventing new telemetry. |
| 10 | Undocumented test-count drop (1101 → 1021) | **Investigated and documented** — real cause found via git archaeology: the 1101 figure never corresponded to any single committed tree (likely the same shared-checkout concurrency artifact this doc discloses elsewhere), and a separate real anomaly (a branch-base mismatch that transiently deleted 47 files, self-healed by a later merge) was found and documented in `COORDINATION.md`. |
| 11 | `console` has no git remote | **Fixed** — new private repo `github.com/pabloguillen/day2-console` created and pushed. |
| 12 | COORDINATION.md's "no scheduler exists" section stale | **Fixed** — dated correction appended noting the 2026-10-04 health-scout cron, with its dry-run-only status confirmed live via `gh secret list`. |
| 13 | `step1-self-healing-gap-analysis.md` claims things are "not started" that are built | **Fixed** — SUPERSEDED annotation added at the top, pointing to `release.ts`/`swarm.ts`/`autonomy.ts`. |
| 14 | `closed-loop-spec.md` stale banner/note | **Fixed** — both corrected with dated notes citing real merged-PR data. |
| 15 | `STAGE2.md`'s log abandoned at W26 | **Fixed** — pointer note added directing readers to where Step 2 work continued. |
| 16 | health-scout cron is dry-run only (no CI secret) | **Not actionable by an agent** — requires the operator's own metered API key; left as-is, status reconfirmed and documented in COORDINATION.md. |
| 17 | "Reproduce-first" enforced only by LLM self-report | **Fixed** — `pipeline.ts` now mechanically checks the fix-agent's diff for a touched test file before proceeding, failing closed with a new `reproduction_failed` result if none is found. |
| 18 | `external-ingest.ts` named adapters are stubs even with a credential present | **Left as-is, out of scope** — real Meta/Google/TikTok/Stripe integration needs real platform credentials and OAuth app registrations the operator doesn't have; already honestly disclosed in-code. |
| 19 | Thin CLI wrappers (`pr.ts`, `git.ts`, etc.) untested | **Fixed** — 8 new test files (including `git.test.ts`/`pr.test.ts` covering realistic shell-command failure paths via a real subprocess + fake-PATH-script pattern), plus the one named gap (`evolution-cli.ts`'s `--reject` wiring) explicitly proven correct. |
| 20 | Uncommitted real work sitting in expense-buddy's working tree | **Fixed** — committed and pushed (`9a190cb`). |
| 21 | `offering-logic.md`'s "multi-tenant" language reads as present-tense | **Fixed** — disambiguating paragraph added, citing the single-tenant data model and no-auth reality. |
| 22 | Stale already-merged local branch in `orchestrator` | **Fixed** — deleted. |

**What's still open, by design:** two items (#2 real external execution, #18 real ad/payment platform adapters) require real third-party credentials only the operator can supply, and were deliberately left as the disclosed stubs they already were rather than faked. One item (#16) is an operational step (adding a secret to GitHub Actions) that only the operator should do. One item (#7's "never run live") can only be closed by an actual production run, not by further code or doc changes.
