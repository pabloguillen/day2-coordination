# Day2 — Step 3 (self-evolving) working log

Companion to `STAGE0.md`/`STAGE1.md`/`STAGE2.md` and the control room in `COORDINATION.md` — read that first for cross-session context and current session assignments. Design doc: `docs/step3-self-evolving-plan.md` (all four components, sequencing, and why).

**Scope note:** per the roadmap, Step 3 doesn't formally start until Step 2's exit criterion (adapted users retain measurably better than a holdout) is met — blocked on the same "no real users" wall as every earlier gate in this project. **2026-09-27:** the user explicitly directed this session to start Step 3 anyway, while a separate session continued hardening Step 1/2 — a deliberate division of work across sessions, not a silent gate-skip. Noted here plainly, same as every prior gate-override in this project's history (composer/building-blocks in Step 2, `decideSlotConfig`'s own W25 entry).

Two of the four named components (experiments at real statistical scale, and this stage's own exit criterion — "promoted changes hold up after 90 days") stay honestly gated on real users/real elapsed time regardless of what gets built. See `docs/step3-self-evolving-plan.md`'s "Why now, and what's still honestly gated" section for the full reasoning — the short version: build the real mechanism now, same as Step 2 did, and stay explicit about what it can and can't prove yet.

## Log

### 2026-09-27 — Plan written and approved (W30 claimed, Session A-Swarm)

Full plan: `docs/step3-self-evolving-plan.md`. Covers all four roadmap components (swarm calibration loop, experiments infrastructure, evolution engine, competitor feed) with a recommended build order and, for the component being built first, an implementation-ready design (file list, function signatures, fail-closed safety rule, test list, live-validation plan). The other three are specified to the level needed to start and get sign-off on direction, not implementation-ready yet — a session picking one up should expand that section into the same level of detail component 1 has before writing code, and update this log when doing so.

Component 1 (swarm calibration loop) claimed as **W30** in `COORDINATION.md` — see that row for live status. Grounded in three real false positives swarm v1 hit this project (documented in `COORDINATION.md` W21/W25): a CSS-transition read mid-animation, `document.activeElement` reporting a shadow host instead of the real focused node, and native `<input type="date">` segment highlighting invisible to `getComputedStyle()`. Each was manually investigated and hand-fixed into the persona's prompt; W30 automates that loop going forward via a "skeptic" re-check against the same catalogued patterns, shipping with its override defaulting off (visibility-only until proven trustworthy on real runs).

### 2026-09-27 — Component 2 (experiments infrastructure) built, W31, Session C

Full detail: `COORDINATION.md` W31. Picked as the next unclaimed piece in the plan's own sequencing — Component 1 was Session A-Swarm's active, dirty W30 (`release.ts`/`swarm.ts`/new `calibration.ts`), zero file overlap with this component.

**Part 1** (`orchestrator/src/experiments.ts`): the pure, fully-testable core — `assignVariant` (deterministic, SHA-256-hashed, weighted variant assignment, no storage needed) and `evaluateExperiment` (a real Welch's t-test, implemented via the standard incomplete-beta-function method rather than a stats dependency). Validated against real, published t-table critical values, not just internal self-consistency — this matters, since a subtly wrong p-value implementation would be the kind of bug that looks fine in isolation and quietly produces false confidence later. Honest about power: `significant` is only ever `true` above a disclosed minimum per-arm sample size (30), regardless of how small the raw p-value is — directly answers W16d's own unresolved question ("47.0 control vs. 48.0 treatment... plausibly reverses at larger N, untested") by naming the problem explicitly instead of leaving it as a caveat nobody enforces.

**Part 2** (`expense-buddy/src/server.ts`): wires real variant assignment into `handleConfigPlane`, layered above `decideSlotConfig`, below the explicit-KV-override (W14/W16's live A/B seeding keeps working unchanged). Ships with an empty `ACTIVE_EXPERIMENTS` registry — real infra, zero real behavior change, live-validated both ways (empty registry byte-identical to before; a temporary synthetic experiment proven to genuinely vary assignment across real devices, stay stable per-device, and record a real `experiment_exposure` event in production KV, then reverted before committing).

**Cross-repo architecture note, worth flagging for whoever builds Components 3/4 next:** `orchestrator/` and `expense-buddy/` are separate deployable units — orchestrator's Bun CLI never runs inside expense-buddy's Cloudflare Worker, so anything needed at real request-time (like variant assignment) has to be a disclosed, deliberate duplicate in `server.ts`, not an import. This project already established the precedent (W30's `calibration.ts` sandbox-config duplication); this component is the second instance of it, and it's likely to come up again for Component 3 (evolution engine) if any of its output needs to affect what a real request sees, rather than staying purely offline/analysis-time.

**What's still honestly gated:** the calculator reports real p-values on real (today, still-synthetic swarm-persona) data — Component 2's own plan section already named this limitation; nothing here pretends otherwise. No real experiment is actually running (`ACTIVE_EXPERIMENTS` is empty) — that's a product decision for whoever has a real hypothesis worth testing, not something to invent to exercise the mechanism.

### 2026-09-27 — Component 3 (evolution engine) built, W32, Session C

Full detail: `COORDINATION.md` W32. User explicitly directed continuing to this component after Component 2 landed.

`orchestrator/src/evolution.ts`'s `proposeFeature` gives an agent real, live HTTP access to the deployed app's own `/api/day2-profile` endpoint for a list of device IDs, along with an explicit list of the 3 adaptive variants already served (bulk-actions, category-breakdown, weekly-report-auto-show) so it doesn't waste a run re-discovering something that already exists. `parseFeatureProposal` is pure and fail-closed, but deliberately richer than the plan's own `FeatureProposal | null` sketch: a 3-way `ProposalResult` (`proposed` / `no_proposal` / `parse_failed`) so "the agent genuinely found nothing" and "the agent's output was unusable" — which need different handling — don't collapse into the same outcome.

**Live-validated twice, and the first run's honest "no" was worth keeping, not just retrying past:**

1. Seeded 3 synthetic devices, each identically shaped (2 sessions, 6 same-category `expense_added` events). Ran `proposeFeature` for real against the live production endpoint. **Result: `no_proposal`.** Read as-is rather than treated as a bug to route around — three byte-identical synthetic profiles is a reasonable thing for an honest agent to distrust, and the plan's own text anticipated exactly this ("if the data is too thin, too synthetic... say so and propose nothing — a null result is a legitimate, expected outcome").
2. Re-seeded with more realistic, *varied* data instead of just re-running the same prompt hoping for a different answer: two devices with a genuine dominant-single-category pattern in different categories (Coffee ×6 on one device, Transit ×5 on another — proving the pattern isn't category-specific), plus a real negative-control device with deliberately diverse spending across 6 categories. Ran again. **Result: a real, well-reasoned proposal:**

> **Proposed: Quick re-add for dominant category**
>
> **Why:** Two of three real profiles show a user whose logged expenses are 100% concentrated in a single category across multiple sessions (not just a single day), yet the app still shows them the full category-picker form every time, identical to what a brand-new user sees. This is a distinct pattern from the 'diversified spender' case already served by category-breakdown (2+ categories) — it's the opposite end of the spectrum, and it's currently unserved.
>
> **What we observed:** deviceId w32evoa...: established, categoryDistribution={"Coffee":6}. deviceId w32evod...: established, categoryDistribution={"Transit":5}. Contrast: deviceId w32evoe... has categoryDistribution spread evenly across 6 categories — the case already served by category-breakdown, confirming these two profiles represent a genuinely different, unserved shape of usage.
>
> **Proposed contract:** a `DominantCategorySignal` (share/basis/eligibility fields) and a `QuickAddShortcut` variant, threshold-gated (share ≥ 0.9, sessions ≥ 2).
>
> **Open questions:** is the threshold validated against a real population; should it pre-fill an amount; what happens when a single-category user diversifies; does it coexist cleanly with the bulk-actions variant.

The agent explicitly cited the negative-control device by ID to justify why the pattern is real and distinct from what's already served — using the contrast, not just the two positive examples, which is exactly the kind of reasoning this component exists to check for before trusting a proposal. Recorded to a real local `day2-proposals.jsonl`, re-read correctly via `evolution-cli.ts --list`.

`orchestrator/src/proposals.ts` is the review surface, deliberately kept separate from `approvals.ts` (a proposal has no PR/branch/diff to review — just a document) — same underlying "human makes the call" idea as `approvals.ts`'s cards, genuinely different review object. 18 new tests (11 parser, 7 review-surface), 153/153 project tests passing.

**Disclosed, not silently absorbed:** another session's Component 4 commit picked up all 5 of this component's already-staged files via a broad `git add` in the shared checkout, and pushed before the mixup was noticed. Content is intact and correct — nothing lost — but the commit message/attribution doesn't mention Component 3 at all. Not rewriting history to fix it (would need a force-push on an already-pushed commit); noted here and in `COORDINATION.md` instead.

**What's still explicitly out of scope, same as the plan's own decision:** this proposal is a document, nothing more — no code was generated, nothing was merged or shipped. Whether "Quick re-add for dominant category" is worth building is a human call, not this component's to make.

All 5 seeded test devices were real writes against the live production `DAY2_EVENTS` KV namespace (this component's live-validation hits the deployed app directly, unlike W31's local-`wrangler dev` validation) — deleted via `wrangler kv key delete --remote` afterward, confirmed via a follow-up profile check showing a fresh/empty device again.
