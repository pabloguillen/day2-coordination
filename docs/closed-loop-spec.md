# Closed-Loop Spec: Cross-Domain Data and Optimization

Status: all 5 milestones (M1-M5) built, tested, and pushed — awaiting human review/merge (COORDINATION.md W47-W51) · Owner: @Pablo · Date: 2026-09-30

> **Correction (2026-10-04):** stale — all of M1-M5 are merged. `day2-orchestrator`
> PRs #1-#5 merged 2026-10-02; PRs #6 (self-healing/evolving hardening,
> including the statistical-framework fix in item 5 below) and #7 merged
> 2026-10-04. Confirmed directly via `gh pr list --repo
> pabloguillen/day2-orchestrator --state merged`, not just asserted. Nothing
> in this spec is still "awaiting review" as of this date.

> **Implementation status (2026-09-30):** M1 ([orchestrator PR #1](https://github.com/pabloguillen/day2-orchestrator/pull/1), [expense-buddy PR #41](https://github.com/pabloguillen/expense-buddy/pull/41) — **merged**), M2 ([orchestrator PR #2](https://github.com/pabloguillen/day2-orchestrator/pull/2), stacked on #1), M3 ([orchestrator PR #3](https://github.com/pabloguillen/day2-orchestrator/pull/3), stacked on #2), M4+M5 ([orchestrator PR #4](https://github.com/pabloguillen/day2-orchestrator/pull/4), stacked on #3; [expense-buddy PR #43](https://github.com/pabloguillen/expense-buddy/pull/43), independent). Orchestrator PRs #1-#4 are a sequential stack — merge in order. None force-merged; all await real human review per this project's own "ask before a real production action" discipline. See COORDINATION.md W47-W51 for full per-milestone detail (what was built, real bugs found and fixed by the test suites, live-validation notes).
>
> **Correction (2026-10-04):** all of the above are now merged, not pending.
> Per `gh pr list --repo pabloguillen/day2-orchestrator --state merged`:
> PR #1 merged 2026-10-02 (already noted above), and PR #2 (M2), PR #3 (M3),
> and PR #4 (M4+M5) all also merged 2026-10-02. `expense-buddy` PR #43
> likewise merged. The "stacked on, awaiting review" framing above is
> historical only.

> **For Claude Code:** module names below come from your own review of `orchestrator/src/` and `expense-buddy/src/`. Verify each against the code before changing it. Where this spec conflicts with `docs/step1-4` or `COORDINATION.md`, this spec wins for the closed-loop work; flag conflicts rather than silently resolving them. Put this file at `docs/closed-loop-spec.md` and add a short pointer to it in the roadmap section of `COORDINATION.md`.

> **Verification notes (Claude Code, 2026-09-30) — read before starting M1.** Checked every module/function/type this spec names against the real code in `orchestrator/src/` and `expense-buddy/src/`. Confirmed correct as referenced: `growth-allocator.ts` (`Arm`, `armKey`/`decodeArmKey`), `growth-execution.ts` (`reconcileOutcomesIntoAllocator`), `growth-strategy.ts` (`deriveAppStage`, `AppStage = "launch"|"traction"|"growth"|"scale"`, `GrowthChannel`), `spend-governance.ts` (`SpendCategory`, `BudgetConfig`), `growth-config.ts` (owner-facing `.day2-budget.json` CRUD — distinct from `growth-tools-config.ts`, the platform-level MCP-binding config; both exist, both as this spec implies), `autonomy.ts` (`L0`–`L5`, default `L2`, `L3` = "Act on low risk" — consistent with section 12's L2/L3 usage), `swarm.ts`, `ai-slop-patterns.ts`, `release.ts`, `agent.ts`, `owner-feed.ts`, `proposals.ts`, `growth-feed.ts`, `expense-buddy/src/server.ts::handleConfigPlane` (line 148). One correction and four conflicts, flagged rather than silently resolved:
> 1. **Corrected below:** section 2.2 originally read `expense_add`; the real event type in `expense-buddy/src/lib/day2-events.ts` and `server.ts::EVENT_TYPES` is `expense_added`. Fixed inline in the table.
> 2. **No `server-profile.ts` exists.** The per-user model (`derivePerUserModel`, `PerUserModel`, `decideSlotConfig`, `handleProfile`) lives inline in `expense-buddy/src/server.ts` — only `server-profile.test.ts` is a separate file. Every reference below to "the per-user model" resolves to `server.ts`, not a standalone module.
> 3. **RESOLVED in M1 (COORDINATION.md W47).** `growth-execution.ts`'s existing `AcquisitionEvent = { creativeId: string; armKey: string; deviceId: string; landedAt: string }` was kept as-is, not replaced. `expense-buddy/src/lib/day2-acquisition.ts`'s new `AcquisitionContext` deliberately reuses the exact field names `armKey`/`creativeId` (not this spec's literal `arm_id`/`creative_id`) so a real `acquisition_landing` event's `acquisition` field maps onto `AcquisitionEvent` with zero translation — `growth-execution.ts::acquisitionEventFromStoredEvent` just picks those two fields plus the event's server-assigned `at` (used for `landedAt`, not the client-supplied `firstSeenAt` — server clock is trustworthy, a client timestamp isn't). `reconcileOutcomes`'s pure core was never touched.
> 4. **STALE as of M1 — corrected.** This note originally said `acquisition_landing` was never implemented. Between this spec being written and M1 starting, `expense-buddy` PR #40 (W43) merged to `origin/main` for real, adding `EVENT_TYPES` entries for `acquisition_landing`/`referral_shared`/`referral_redeemed` with the old step4-plan shape (`{source, campaign, creativeId, armKey}` as free-form `metadata`). M1 (PR #41) supersedes that shape with this spec's richer `AcquisitionContext` envelope, per this spec's own precedence rule — and it composes cleanly with the old shape's `creativeId`/`armKey` naming by construction (see #3 above), so nothing built against the old shape breaks. Live proof this file drifts under concurrent multi-session work: re-verify against current `origin/main` before trusting any "not implemented yet" claim in this doc.
> 5. **Fix written, NOT yet on `main` — pending review in [orchestrator PR #6](https://github.com/pabloguillen/day2-orchestrator/pull/6).** `experiments.ts` already implemented a frequentist statistical-significance calculator (`evaluateExperiment`, Welch's-t-test-style, `MIN_SAMPLE_SIZE_PER_ARM = 30`) before M4 landed. M4's `entry-paths.ts::evaluateHoldoutPromotion` needed section 6.2's Bayesian "90% posterior probability" test instead — a t-test answers "is there a difference in a continuous/count outcome," not "how likely is the true retention rate higher," which is what a binary retained/not-retained holdout decision actually asks. The fix, on the `self-healing-hardening` branch: `experiments.ts` also exports `evaluateProportionExperiment` — a real Beta-binomial posterior comparison via Monte Carlo sampling, the Bayesian counterpart to `evaluateExperiment` — and `entry-paths.ts` calls it instead of maintaining its own private copy of the same sampler. The decision, made explicit: **use `evaluateExperiment` (frequentist) for continuous/count outcomes, `evaluateProportionExperiment` (Bayesian) for binary/proportion outcomes** — both live in `experiments.ts`, so "which framework governs this decision" always has one answer, keyed on the outcome's shape, not on which module happened to need it first. **Correction (2026-10-03, independent audit):** an earlier edit here said "RESOLVED," past tense, with no caveat — checked directly against `main` and `evaluateProportionExperiment` doesn't exist there; `entry-paths.ts` on `main` has no relationship to `experiments.ts` at all. The code is real and correct, just not merged yet. Don't trust "RESOLVED" language in this file (or `COORDINATION.md`) over a direct check of `main` — see `docs/implementation-audit-2026-10-03-independent.md` for how this drift happened.
>
> **Correction (2026-10-04):** now actually merged and confirmed live on
> `main` — `orchestrator PR #6` merged 2026-10-04. Direct check:
> `grep -n evaluateProportionExperiment orchestrator/src/entry-paths.ts`
> shows `entry-paths.ts` importing and calling it for real (line 9 and line
> 250, as of this writing). The "RESOLVED" language the 2026-10-03 note
> above was correcting is, as of today, actually correct — the earlier
> correction's own caveat ("not merged yet") no longer applies.

---

## 0. Purpose

Day2 already runs four local loops: healing, adapting, evolving and distributing. This spec turns them into one closed loop:

1. Collect data from every domain (acquisition, activation, engagement, retention, monetization, quality, satisfaction) with one shared context on every event.
2. Compute every KPI from one metric layer, broken down by cohort, segment and variant.
3. Diagnose which part of the chain is weakest for each cohort.
4. Route the fix to the loop that can move it: allocator, creative generation, slot composer, evolution engine or healing pipeline.
5. Feed measured outcomes back as the reward for the next decision.

**The moat:** cross-domain questions no single-category tool can answer, such as "users from arm X hit more crashes", "variant Y lowers refunds", or "channel Z looks cheap on installs but has the worst CAC payback."

### Principles

- **No declared promises.** Intent is learned from behavior per acquisition cohort, not written down per ad. Works for every app and ad type.
- **One context, stamped everywhere.** Every loop gets acquisition and variant context for free, without per-module integration.
- **One definition per metric.** All loops read the same metric layer; no module computes its own "active" or "retained."
- **Averages hide the signal.** Every KPI is available by cohort, segment and variant.
- **One target per stage, the rest are guardrails.** KPIs conflict; the goal hierarchy decides.
- **Deterministic before generative.** Diagnosis and guardrails are rules; LLMs write explanations, creatives and proposals.

---

## 1. Core concepts

| Concept | Definition |
| --- | --- |
| **Acquisition context** | Where a user came from: channel, campaign, arm, creative, referrer. Captured at first touch, stamped on every later event. |
| **Arm** | One allocator option (channel × audience × creative angle), as in `growth-allocator.ts`. |
| **Cohort** | Users grouped by acquisition arm (or channel, when the arm is unknown) and signup week. The unit for acquisition economics. |
| **Segment** | Users grouped by behavior, from the per-user model (skill level, habits, core-action pattern). The unit for adaptation. |
| **Entry path** | The first-session surface: which slots and blocks appear first, and in what order. Served by the config plane. |
| **Learned entry path** | The entry path that best predicts retention for a cohort, learned from data (section 6). |
| **Variant** | Any config-plane assignment: entry path, slot configuration, experiment arm, or holdout. |
| **Diagnosis** | A rule-produced record stating which funnel step is weakest for a cohort and which loop should act (section 8). |
| **App stage** | Launch, Traction, Growth or Scale, from `deriveAppStage`. Sets the target KPI and guardrails. |

---

## 2. Event schema

### 2.1 Envelope (on every event)

```ts
interface EventEnvelope {
  event_id: string;          // uuid
  event_type: EventType;
  ts: string;                // ISO 8601, UTC
  app_id: string;
  device_id: string;
  user_id?: string;          // after signup
  session_id: string;
  app_version: string;
  platform: 'web' | 'pwa' | 'ios' | 'android';
  locale?: string;

  acquisition: AcquisitionContext;   // first touch, stamped on every event (section 3)
  variants: Record<string, string>;  // active config-plane assignments, e.g. { entry_path: 'invoice_first', exp_42: 'B' }
  segment_id?: string;               // current per-user-model segment, if known
  consent: { analytics: boolean; marketing: boolean };

  props: Record<string, unknown>;    // event-specific payload
}
```

### 2.2 Event catalog

Extend `EVENT_TYPES` in `expense-buddy/src/server.ts` (currently `session_start`, `expense_added`, `weekly_report_viewed`, `experiment_exposure`) and the SDK. Per-app custom events are allowed but must be declared in the app's metric config (section 4.2).

| Domain | Event types |
| --- | --- |
| Acquisition | `acquisition_landing`, `install` (mobile), `signup` |
| Virality | `referral_shared`, `referral_redeemed`, `invite_sent`, `invite_accepted` |
| Usage | `session_start`, `session_end`, `screen_view`, `core_action` (with `props.action`), `feature_used` |
| Monetization | `trial_started`, `paywall_viewed`, `subscription_started`, `subscription_renewed`, `subscription_cancelled`, `payment_succeeded`, `payment_failed`, `refund_issued` |
| Quality | `error`, `crash`, `perf_sample` (load time, response time), `rage_click` |
| Satisfaction | `rating_prompt_shown`, `rating_submitted`, `feedback_submitted`, `support_ticket_opened` |
| Experiments | `experiment_exposure`, `variant_served` |

Existing domain events such as `expense_added` map to `core_action` via the app's metric config; they don't need renaming.

### 2.3 External ingests (daily, per arm where possible)

| Source | Fields | Consumer |
| --- | --- | --- |
| Ad platforms (via MCP / official APIs) | spend, impressions, clicks, installs, per campaign / ad set / creative / day | Metric layer, allocator |
| App stores | rating, review count, review text | Metric layer, sentiment job |
| Payments provider | revenue, refunds, chargebacks | Metric layer (source of truth for revenue) |
| Support tool (if connected) | tickets, tags | Metric layer |
| Error monitoring (e.g. Sentry) | issues, affected users | Healing pipeline, metric layer |

Every ingest row is mapped to an `arm_id` where the platform exposes campaign IDs. Unmappable rows go to `arm_id = 'unattributed'`.

---

## 3. Acquisition context

### 3.1 Shape

```ts
interface AcquisitionContext {
  touch: 'first';
  channel: 'paid_social' | 'paid_search' | 'app_store' | 'seo' | 'referral' | 'direct' | 'community' | 'email' | 'unknown';
  source?: string;        // utm_source, e.g. 'meta'
  medium?: string;        // utm_medium
  campaign_id?: string;   // utm_campaign
  creative_id?: string;   // utm_content
  arm_id?: string;        // day2 allocator arm, via ?d2_arm=
  referrer_user_id?: string;
  landing_path: string;
  first_seen_at: string;
}
```

### 3.2 Capture rules

1. On first page load or app open, read URL parameters (`utm_*`, `d2_arm`, `ref`), store referrer and install referrer (Android) or deferred deep-link data (iOS, where available).
2. Persist first touch on the device (first-party cookie or local storage on the app's own domain; secure storage on mobile). Never overwrite it.
3. Emit `acquisition_landing` once, with the full context.
4. On `signup`, bind the device's first touch to `user_id` server-side. If a user signs in on a second device, keep the earliest first touch.
5. Stamp `acquisition` on every later event from the persisted value. The SDK does this; modules never look it up themselves.
6. Every creative launched by `growth-execution.ts` must carry `d2_arm` and `utm_content = creative_id` in its destination URL. Launch is blocked otherwise.

### 3.3 Privacy

- URL-parameter matching needs no tracking consent and works under iOS ATT: it's first-party and doesn't identify the user across apps.
- Device-level ad-platform attribution (click IDs, conversion APIs) is used only with `consent.marketing = true`.
- Ad-platform numbers are reconciled at cohort level, never by joining individual users across platforms.
- No protected attributes in context, segments or rules.

---

## 4. Metric layer

### 4.1 Rules

- One module (new: `orchestrator/src/metrics/`) owns all KPI definitions. Every loop reads from it.
- Every metric is computable at grain `app × day` and broken down by `cohort`, `arm`, `channel`, `segment`, `variant`, `app_version`, `platform`.
- Metrics with small samples return a value **and** a confidence interval and `n`. Consumers must respect `n`.

### 4.2 Per-app metric config

Set at onboarding from the app profile; the owner confirms or edits.

```ts
interface AppMetricConfig {
  core_actions: string[];            // e.g. ['expense_add', 'invoice_sent']
  activation: { event: string; count: number; within_hours: number }; // e.g. 1 core_action within 24h
  active_user: { event: string; min_count: number };                   // what counts as "active" on a day
  retention_windows_days: number[];  // default [1, 7, 30]
  paid_event: string;                // default 'subscription_started'
  currency: string;
}
```

### 4.3 KPI definitions

| Domain | KPI | Definition |
| --- | --- | --- |
| Acquisition | CTR | clicks / impressions |
| | CPC | spend / clicks |
| | CPI | spend / installs (mobile) or landings (web) |
| | Landing-to-signup | signups / `acquisition_landing` |
| | CAC (paid) | paid spend / new users from paid arms |
| | CAC (blended) | total acquisition spend / all new users |
| | Organic share | new users from organic channels / all new users |
| Virality | Referral rate | users with ≥1 `referral_shared` / active users |
| | K-factor | invites per user × invite acceptance rate |
| Activation | Activation rate | users meeting `activation` / signups |
| | Time to value | median time from signup to activation |
| | First-session drop-off | last `screen_view` before session end, for users who never activate |
| Engagement | DAU / WAU / MAU | distinct users meeting `active_user` in 1 / 7 / 30 days |
| | Stickiness | DAU / MAU |
| | Sessions per user | sessions / active users, per week |
| | Feature adoption | users using feature X / active users |
| | Core action frequency | core actions per active user per week |
| Retention | Dn retention | users active on day n (±1) / cohort size |
| | Churn rate | users active last period, not this period / active last period |
| | Resurrection rate | users returning after ≥30 inactive days / inactive pool |
| Monetization | Trial-to-paid | `subscription_started` / `trial_started` |
| | ARPU | revenue / active users |
| | ARPPU | revenue / paying users |
| | MRR | recurring revenue normalized to a month |
| | LTV | predicted revenue per user over 12 months (cohort curve fit; see 4.4) |
| | LTV:CAC | LTV / CAC, per arm and blended |
| | CAC payback | months until cumulative revenue per user ≥ CAC |
| | Refund rate | refunds / payments |
| Quality | Crash-free sessions | sessions without `crash` / sessions |
| | Error rate | `error` events / sessions |
| | p95 latency, load time | from `perf_sample` |
| | Escaped defects | incidents after release not caught by gates |
| | Mean time to fix | incident detection → fix live |
| Satisfaction | Store rating | rolling average, 30 days |
| | Review sentiment | share of negative reviews, 30 days |
| | Tickets per active user | tickets / active users |
| | Rage clicks per session | `rage_click` / sessions |
| Day2 itself | Change success rate | shipped changes still live after 30 days / shipped changes |
| | Rollback rate | rollbacks / releases |
| | Proposal approval rate | approved / proposed |
| | Owner undo rate | undos / auto-applied changes |
| | Compute cost per active user | day2 compute cost / MAU |

### 4.4 LTV method

- Launch/Traction: LTV = ARPPU × paid conversion × expected paid lifetime from the app's own churn; flag as low confidence.
- Growth/Scale: fit a retention curve per cohort (e.g. shifted-beta-geometric) and project revenue over 12 months.
- Until an app has 90 days of data, borrow priors from similar apps on the platform (same category and price band), clearly marked.

---

## 5. Cohorts and segments

- **Cohort key:** `arm_id` (fallback `channel`) × signup ISO week. Used for acquisition economics and allocator rewards.
- **Segment key:** from the per-user model. Used for adaptation and evolution proposals.
- Both dimensions are available on every metric, so the cross-tab ("segment mix of arm X") is free.
- **Minimum sample size:** a metric breakdown is reported as "insufficient data" below `n = 30` users. Decisions require the thresholds in section 8.3.
- **Pooling for small cohorts:** arm → channel × creative angle → channel → app default. Each level up is marked as borrowed.

---

## 6. Learned entry paths

This is the message-match mechanic without declared promises: users from each cohort start where users like them succeeded.

### 6.1 Learning

For each arm (or pooled level) with ≥ 100 signups:

1. Collect first-session sequences: ordered `screen_view` and `core_action` events in session 1.
2. For each early action (first 3 distinct actions), estimate lift in D7 retention for users who took it vs. those who didn't, within the arm. Control for platform.
3. Pick the action with the highest lift that is also reachable from an existing slot configuration. That action defines the candidate entry path: the slot configuration that surfaces it first.
4. Store it as `LearnedEntryPath { arm_id | pool_key, entry_path_id, lift, n, confidence, learned_at }`.

Correlation is not causation here, which is why step 6.2 always tests.

### 6.2 Serving and testing

- The slot composer (config plane in `server.ts`) reads `acquisition` + `LearnedEntryPath` on session 1 and serves the learned entry path if one exists with sufficient confidence.
- **Cold start bridge:** on session 1 the per-user model has no behavior; acquisition context is the prior. From session 2, the per-user model takes over as its confidence grows.
- Every learned entry path runs as a bandit against the app default, with a fixed **10% holdout** per arm that always gets the default.
- An entry path is promoted to permanent for that arm only when it beats the holdout on D7 retention with ≥ 90% posterior probability and doesn't worsen any guardrail.
- Entry paths are composed only from verified building blocks. No new code is generated in this step.

---

## 7. Allocator reward

Change `reconcileOutcomesIntoAllocator` (`growth-execution.ts`) so Thompson sampling in `growth-allocator.ts` learns from value, not clicks.

### 7.1 Staged reward

Rewards arrive over weeks, so each new user contributes in stages:

| Stage | Available at | Signal | Weight (default) |
| --- | --- | --- | --- |
| R0 | Day 1 | Activated | 0.2 |
| R1 | Day 7 | D7 retained | 0.3 |
| R2 | Day 30 | D30 retained + revenue to date | 0.5 |

- Arm reward = Σ(weighted signals) per user ÷ spend on that arm, i.e. value per euro.
- Posteriors update as each stage matures. Early stages act as a proxy; the proxy's weights are recalibrated monthly by regressing R2 on R0 and R1 across the app's history.
- Weights are per stage of the app: in Growth and Scale, R2 uses projected LTV instead of revenue to date.

### 7.2 Guardrails on the allocator

- Arms whose cohorts breach a quality or satisfaction guardrail (section 9) are capped at their current budget, regardless of reward.
- Allocator changes go through `spend-governance.ts`; this spec doesn't loosen any cap.

---

## 8. Diagnosis router

The core of the closed loop. New module: `orchestrator/src/diagnosis/`.

### 8.1 Inputs

Per cohort (and per segment where relevant), for the last complete period: the full KPI set from section 4, the app baseline (app-wide median over the last 4 weeks), and `n`.

### 8.2 Rules

Rules compare a cohort to the app baseline. Thresholds are defaults, overridable per app.

| # | Condition (cohort vs. baseline) | Diagnosis | Route to | Proposed action |
| --- | --- | --- | --- | --- |
| D1 | CTR < 0.7× baseline | Ad doesn't attract | `growth-execution.ts` | New creative angle for this arm |
| D2 | Landing-to-signup < 0.7× | Landing doesn't convert | Config plane | Test a different landing variant |
| D3 | Activation < 0.8× | Entry path doesn't fit this cohort | Slot composer (section 6) | Learn or test a new entry path |
| D4 | Activated, but D7 < 0.8× | Product doesn't hold this cohort | `evolution.ts::proposeFeature` | Feature proposal with cohort and segment attached |
| D5 | Retained, but CAC payback > target | Right users, expensive channel | `growth-allocator.ts` | Shift budget; test cheaper channels or organic |
| D6 | Crash-free or error rate > 1.3× baseline | Quality problem concentrated in this cohort | Healing pipeline (`agent.ts`) | Raise heal priority for issues affecting this cohort |
| D7 | Refund rate > 1.5× | Ad sets expectations the product doesn't meet | `growth-execution.ts` + owner | Review creative claims against app profile |
| D8 | Store rating drop after a release | Release hurt satisfaction | `release.ts` | Check release for rollback; link reviews to version |
| D9 | Trial-to-paid < 0.7× | Paywall doesn't fit this cohort | Config plane | Test paywall timing or offer |
| D10 | All steps ≥ baseline and LTV:CAC > target | Cohort works | `growth-allocator.ts` | Scale within caps |

Rules are evaluated in funnel order; the **first** failing step is the primary diagnosis, later failures are listed as secondary. This prevents fixing retention for users who were never activated.

### 8.3 Decision thresholds

- A diagnosis is emitted only when `n ≥ 100` users in the cohort for rate metrics (≥ 30 for D6/D8, which are severity-driven), or when pooled data reaches that level.
- Each diagnosis carries the evidence: metric values, baseline, `n`, confidence interval, and the rule ID.

### 8.4 Output

```ts
interface Diagnosis {
  id: string;
  app_id: string;
  cohort_key: string;
  segment_id?: string;
  rule_id: 'D1' | 'D2' | /* … */ 'D10';
  primary: boolean;
  evidence: { metric: string; value: number; baseline: number; n: number; ci: [number, number] }[];
  route: 'allocator' | 'creative' | 'config' | 'composer' | 'evolution' | 'healing' | 'release';
  proposal_id?: string;      // created in the target module's own proposal format
  created_at: string;
}
```

Each target module creates its proposal in its existing format (`proposals.ts`, `growth-feed.ts`, owner feed) with the `Diagnosis` linked. The LLM writes the plain-language explanation from the evidence; it doesn't decide the route.

---

## 9. Stage and goal hierarchy

Extend `growth-strategy.ts::deriveAppStage` to read from the metric layer (replaces the planned C3 bridge).

| Stage | Target KPI | Guardrails (must not get worse) |
| --- | --- | --- |
| Launch | Activation rate, D7 retention | Crash-free sessions, error rate |
| Traction | D30 retention, organic share | Quality, store rating, refund rate |
| Growth | LTV:CAC, CAC payback | D30 retention, quality, satisfaction |
| Scale | Net revenue retention, margin | Retention, quality, satisfaction, tickets per user |

- Stage inputs: MAU, D30 retention, MRR, plus per-user-model aggregates (skill distribution, habit prevalence) as secondary signals.
- **Per-cohort spend unlock** in `spend-governance.ts`: paid spend on an arm scales only when that arm's cohort meets the retention threshold for the app's stage. One good cohort can scale while the rest of the app is still in Traction.
- Every proposal is scored as: expected change in the stage's target KPI, rejected if any guardrail is predicted or measured to worsen beyond tolerance (default 5% relative).

---

## 10. Swarm checks for new arms

Reuse `swarm.ts` before any spend on a new arm:

1. A persona matching the arm's intended audience opens the creative's destination URL.
2. It must reach the app's activation event within 10 steps on the entry path it's served.
3. No errors or crashes on the way; accessibility checks pass.
4. The creative's claims are checked against the app profile; unsupported claims block the arm (reuse `ai-slop-patterns.ts` for authenticity checks).

A failed check blocks launch and creates a D2 or D3 diagnosis with the swarm trace as evidence.

---

## 11. Owner feed: cohort report card

The first merged feed item (a small slice of the planned C7). One card per cohort that changed materially this week:

- Where they came from (channel, arm, creative thumbnail)
- Funnel with the weakest step highlighted
- The diagnosis in one sentence
- The proposed action and expected effect on the stage's target KPI
- Buttons: Apply, Undo, Ask

Existing feeds (`owner-feed.ts`, `proposals.ts`, `growth-feed.ts`) keep working; the report card links to their items.

---

## 12. Governance

- All actions route through existing governance: code and config changes via `autonomy.ts`, spend via `spend-governance.ts`. This spec adds no new autonomy surface.
- Defaults: entry-path variants L3 (auto-applied within guardrails, summarized weekly); creative and budget changes L2 (owner approves); feature proposals L2; healing priority changes L3.
- Every diagnosis, proposal, approval and outcome is written to the audit trail with its links.

---

## 13. Milestones

Each milestone ships behind a feature flag, with tests, and is demonstrable end to end in `expense-buddy`.

### M1: Context everywhere
- Envelope (2.1) in SDK and server; extend `EVENT_TYPES`; acquisition capture and stamping (section 3); creative launch blocked without `d2_arm`.
- External ingest for one ad platform + payments.
- **Done when:** every event in expense-buddy carries acquisition and variant context; a synthetic campaign's users are traceable from landing to revenue.

### M2: Metric layer
- `orchestrator/src/metrics/` with per-app config (4.2), all KPIs (4.3), breakdowns, `n` and confidence intervals, LTV v1.
- **Done when:** all KPIs compute for expense-buddy with breakdowns by arm, segment and variant; unit tests cover each definition against fixture data.

### M3: Reward and routing
- Staged allocator reward (section 7) in `reconcileOutcomesIntoAllocator`.
- Diagnosis router (section 8) with rules D1–D10, routes into existing modules.
- `deriveAppStage` on the metric layer; per-cohort spend unlock (section 9).
- **Done when:** seeded scenarios, one per rule, each produce the right diagnosis and a proposal in the right module; allocator shifts budget toward the arm with the best value per euro, not the most installs.

### M4: Learned entry paths
- Learning job (6.1), composer integration and holdouts (6.2), cold-start bridge to the per-user model.
- **Done when:** in a simulation where two arms prefer different first actions, the composer learns and serves different entry paths per arm and the holdout comparison is reported.

### M5: Swarm arm checks and report card
- Section 10 and section 11.
- **Done when:** a creative with an unsupported claim or a broken path is blocked before spend; the owner sees one cohort report card per changed cohort.

### Deferred (after M5)
- Unified pattern registry (C2), single trust dial (C5), fully merged feed (rest of C7), approved proposal → auto-drafted PR (C6).

---

## 14. Open questions for the owner

1. Which ad platform first for M1 ingest: Meta, Google or TikTok?
2. Default activation definition when the owner doesn't set one: first core action, or a count?
3. Which payment provider is the source of truth for revenue?
4. Tolerance for guardrail regressions: 5% relative as default, or stricter?
5. Should cross-app priors (LTV, entry paths) be on by default for new apps, or opt-in?
