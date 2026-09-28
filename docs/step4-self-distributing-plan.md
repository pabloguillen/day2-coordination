# Step 4 (self-distributing) — full plan across all seven components

See `STAGE4.md` / `COORDINATION.md` for cross-session status. This doc is the design; the coordination log is the narrative of what's actually landed. Written in `worktrees/orchestrator-step4-self-distributing/` (see `day2/scripts/new-worktree.sh`) — the shared checkout was left untouched while this was written.

## Roadmap definition

Per the source doc's roadmap table, Step 4 ("self-distributing") is the last stage: the app grows itself — SEO, social, direct outreach, paid acquisition — driven by an owner-configured budget and KPI/goals, with full transparency and no per-action approval as long as spend stays in budget. Nobody had started design or implementation on this stage before this plan (confirmed via a full search of `COORDINATION.md`/`STAGE*.md`/`docs/` and both repos' git history as of 2026-09-28).

## Design principle: orchestrate domain experts, don't reimplement them

Stated explicitly by the user and load-bearing for the whole design: **day2 does not need to be the expert in SEO, ad creative, UGC video, social scheduling, or website building.** For each distribution/marketing *domain*, day2's job is to (1) recognize the domain matters for this app's current stage/strategy, (2) find real, state-of-the-art tools already built for that domain, (3) operate that binding itself, and (4) orchestrate it via MCP inside day2's own budget/safety-rail/transparency machinery — never re-inventing what a dedicated tool already does well.

**Corrected mid-planning, load-bearing:** the app owner does not source, configure, or pay for these tools themselves, and never touches an MCP server config or API key. **Day2 itself already provides these MCPs** — the tool integrations (Foreplay, tryholo.ai, Arcads.ai, Semrush, raylight/autoAE/hyperframes, PostEveryWhere-style social operation, Juno, Framer, ad-platform access) are day2's own platform infrastructure, operated once and reused across every app day2 powers, not something an individual app owner brings, subscribes to, or wires up per-app. This is a direct consequence of the standing design goal ("the user don't need to care about their app after launch... they configure a monthly budget and day2 makes the rest") applied one level deeper: the owner's only inputs anywhere in this system remain **budget, KPI goals, and the optional website opt-in** — never a vendor account, an API key, or an MCP connection string. See Component 4 below for exactly what this changes (config location, who runs `researchToolCandidates`, and what "connected" means for the handful of domains that still need a real, app-specific identity resource).

This is why `growth-tools-config.ts` (Component 4) is a first-class component, not plumbing: it's the seam where "day2's own judgment" (strategy, budget, safety, sequencing, honesty) meets "a domain expert's judgment" (how to actually write ad copy, generate UGC video, or run SEO) — and now also the seam between "day2 the platform operator" and "day2 acting on behalf of one specific app," since the platform holds the tool relationships and each app only draws on them through its own budget. Concretely this means two things: a config-driven, swappable, **platform-operated** binding per domain (designed below), **and** a real, repeatable research mechanism for *finding* those tools in the first place, run by day2's own maintainers — domains and their best-fit tools are expected to change over time, not be hardcoded once at ship time (Component 4's `researchToolCandidates`).

**Domains identified so far, and the real, illustrative tools that fit them** (illustrative only — swappable via config, never hardcoded into agent logic; a domain can have more than one bound tool, see "mixing" below):

| Domain (`GrowthCapability`) | What day2 needs from it | Illustrative real tool(s) | Verified how | Who provisions the connection |
|---|---|---|---|---|
| `creative_generation` | Text/image/social/ad assets, grounded in real brand voice | higgsfield, KiveAI (social-media asset generation); **tryholo.ai** | Live-researched: tryholo.ai's own "Brand DNA" mechanism (extracts tone/colors/audience from the app's real website) independently validates this plan's own Component 5 grounding design (a) — same idea, already a real product | **Day2 platform** — pure tool access, no per-app identity needed |
| `motion_video_generation` | Motion-graphics-style product/demo video | raylight, autoAE, hyperframes | User-supplied, illustrative | **Day2 platform** |
| `ugc_video_generation` | AI-presented, testimonial-style video | **Arcads.ai** | User-supplied, illustrative | **Day2 platform** |
| `social_trend_research` | What's trending on TikTok/Instagram right now | none required — `WebSearch`/`WebFetch` only, same as `competitor-feed.ts`'s existing pattern; an MCP is an optional upgrade | N/A — deliberately zero-dependency by default | **Day2 platform** (or nothing at all — WebSearch needs no account) |
| `competitor_research` (ad-angle intelligence) | Real competitor ad creative/angles, not just feature lists | **Foreplay.co** | Live-researched: real product — "Spyder" competitor ad tracking across Meta/TikTok with real-time alerts, swipe files, briefing tools; explicitly does *not* generate or launch ads itself, which is exactly the research-only role this domain needs | **Day2 platform** |
| `social_account_operation` | Post/schedule to an already-connected account | PostEveryWhere MCP, PostMCP AI | User-supplied, illustrative | **Day2 platform provisions the tool; the underlying social account is still a real, app-specific identity resource** — see note below the table |
| `ad_platform` | Launch/manage paid campaigns on a real ad platform | (unnamed — a Meta/Google/TikTok Ads-shaped MCP) | Not yet researched | **Day2 platform provisions the tool; the underlying ad account is still a real, app-specific identity resource** — see note below the table |
| `seo_content` | Keyword research, on-page SEO, site audit | Semrush (or similar) | Well-established category leader; illustrative | **Day2 platform** |
| `website_generation` | Owner-opt-in marketing site, template-based | Framer | User-supplied, illustrative | **Day2 platform provisions the tool; the site/domain itself is app-specific** — see note below the table |
| `app_store_release` | N/A today (expense-buddy has no native shell) | fastlane | User-supplied, illustrative — dormant until a native wrapper exists | **Day2 platform** (dormant) |
| *(cross-cutting)* | Autonomous GTM "coworker": browser automation, hosted-site publishing, own schedule/mailbox | **Juno AI (getjuno.com)** | Live-researched: real product, genuinely spans several domains at once (see below) rather than fitting one row | **Day2 platform** |

**"Day2 platform" means:** the credentials, MCP server connections, and vendor subscriptions for every row above live in day2's own operator-level configuration (Component 4, below) — never in the app owner's repo, never something the owner signs up for or pastes an API key into. The owner's only inputs anywhere in this entire system are budget, KPI goals, and the optional website opt-in.

**The three rows flagged "still a real, app-specific identity resource" are a genuinely different problem, not a loophole in the rule above.** Day2 can hold one platform-level Foreplay/tryholo.ai/Arcads.ai/Semrush subscription and use it for every app it powers, because those tools don't need to *know* which brand they're serving beyond the prompt/context day2 gives them per call. Posting to a real Instagram/TikTok account, spending from a real ad account, or hosting a real website all require a real, specific, identity-bearing endpoint *for this one app* to exist before day2 can operate it — that endpoint can't be conjured by code alone. The realistic path, matching how marketing agencies already operate multiple clients' accounts today, is day2 holding its own **agency/multi-tenant-style relationship** with each of these platforms (Meta Business Manager's agency access, an ad platform's official multi-client API product, a hosting provider's reseller/team-account model) and provisioning a dedicated resource per app under that umbrella — still zero owner involvement, but a real business/API relationship day2 itself has to hold, not just a code change. Flagged honestly in Open Questions rather than assumed solved.

**Juno AI is architecturally different from every other tool above and needs its own note.** Verified live (docs.getjuno.com / getjuno.com): Juno is an "AI coworker" that connects to a team's existing tools, uses its own browser to log in and automate work, manages its own filesystem, writes code, publishes hosted sites, and — critically — **manages its own work schedule and has its own mailbox**, i.e. it's built to act autonomously and asynchronously, not just respond to a single call. Two consequences for this design:

1. **One real vendor can back multiple domains at once.** Nothing in `ToolBinding`'s shape needs to change for this — the same `mcpServerName`/`serverConfig` can simply appear in more than one `ToolBinding` entry (e.g. one binding with `capability: "website_generation"`, another with `capability: "seo_content"`, both pointing at the same Juno connection). `growth-tools-config.ts`'s job is unchanged; this is a usage pattern, not a type change.
2. **A tool whose own selling point is autonomous scheduling is exactly the kind of integration that could accidentally bypass this whole plan's governance if wired naively.** Explicit safety note, alongside the non-negotiable rails below: **any MCP-bound tool's own autonomous/scheduling features must never be the thing that triggers a real spend or publish action.** day2 calls a Juno-style binding on *day2's own* schedule (the existing on-demand CLI pattern, or whatever Open Question 3's scheduler decision lands on) and every result still passes through `growth-execution.ts`'s claims-check → authenticity-check → `evaluateSpend` → `allowLiveAction` gate like anything else. Juno "managing its own schedule" is fine for *how it does its internal work*; it must never mean "and therefore decides on its own when to spend the owner's budget."

**"The UI shall use a mix of all tools which are available and fit the strategy" — `growth-tools-config.ts` is extended to support this directly, not left as a single-binding-per-capability model:**

```ts
// Was: resolveBinding(config, capability): ToolBinding | undefined  (single binding)
// Now: a capability can have more than one real, enabled, connected binding —
// e.g. both higgsfield AND tryholo.ai bound for creative_generation — and execution
// picks (or, over time, the allocator's own arms — see below — reinforces) whichever
// fits a given arm best, rather than being locked to one vendor per domain.
export function resolveBindings(config: GrowthToolsConfig, capability: GrowthCapability, appId: string): ToolBinding[];  // appId matters for identity-bearing capabilities — see Component 4's platform-registry note; today there's exactly one app (expense-buddy), so this is a constant, not real multi-tenancy yet

// Picks the best-fit binding among the resolved set for a specific arm/strategy context
// — e.g. prefer a brand-DNA tool like tryholo.ai for on-brand static/carousel ads, prefer
// a UGC-specialized tool for arm.videoFormat === "ugc". v1 is a simple, disclosed rule
// (match on assetType/videoFormat/channel, then fall back to the first enabled binding);
// not a bandit over tools in this pass — see the natural extension noted under Component 3.
export function selectBestFitBinding(
  bindings: ToolBinding[], context: { arm: Arm; strategy: GrowthStrategy },
): ToolBinding | undefined;
```

**Domain/tool discovery is itself a real, repeatable capability, not a one-time list baked into this doc — new function in `growth-tools-config.ts`:**

```ts
export type ToolCandidateInsight = {
  domain: GrowthCapability;
  toolName: string;
  whatItDoes: string;
  fitReason: string;                                          // why it fits day2's specific need for this domain
  mcpAvailability: "confirmed_mcp" | "api_only_needs_wrapper" | "unknown";
  source: string;
};

// Same simplest-agent pattern as competitor-feed.ts's researchCompetitorFeatures —
// WebSearch/WebFetch only, no sandbox/Bash/filesystem. Produces real, cited candidates
// for a day2 platform operator/maintainer to review before a ToolBinding is ever actually
// configured — never owner-facing, since the owner never sees or manages individual tool
// bindings at all (see the platform-operated note above). This is the mechanism that keeps
// the table above from going stale: rerun per domain whenever "state of the art" is worth
// rechecking, not just once at ship time.
export function researchToolCandidates(domain: GrowthCapability): Promise<ToolCandidateInsight[]>;
```

**Natural extension, explicitly not built in this pass (flagged, not silently scoped in):** Component 3's allocator (`Arm`) currently varies channel/assetType/videoFormat/formatTag. Once multiple real tools are bound to the same capability, "which tool produced the best-performing creative for this format" is itself something the same Thompson-sampling mechanism could reinforce — e.g. `Arm.toolHint?: string`. Not added to the `Arm` type in this pass, to avoid widening the bandit's arm-space before the simpler dimension (format/content-type) is proven live; noted here so whoever revisits Component 3 later sees the natural next step spelled out rather than rediscovering it.

## Why now, and what's still honestly gated

Step 3 (self-evolving) is done — all four components live-validated. Two structural facts stay honestly gated regardless of what gets built here, same as every prior stage: (1) real ad spend, real publishing, and real account operation are explicitly withheld per the user's own instruction ("no real money, no real public-facing action yet") — everything ships in default-simulate mode; (2) `paidAcquisitionUnlocked` for `growth`/`scale` stages depends on LTV > CAC, which is structurally unverifiable for expense-buddy specifically (confirmed: no payment/billing/pricing code exists in the real app profile) — handled honestly (a plain `unlockBasis` string saying so), not papered over with an invented proxy.

Research (governance/autonomy infra, per-user data/experiments/competitor-feed reuse, dry-run/MCP conventions, plus live web research on Foreplay/tryholo.ai/Juno AI/Arcads.ai) is complete and independently re-verified against the current codebase — confirmed by reading `autonomy.ts`, `release.ts`, `calibration.ts`, `evolution.ts`, `agent-sandbox.ts`, `owner-feed.ts`, `server.ts`, `onboarding.ts`, `docs/expense-buddy-app-profile.md`, and the SDK's `sdk.d.ts` directly. Key confirmed facts this plan relies on:

- `evaluateAutonomy` (`autonomy.ts`) has **zero spend dimension** — purely code-risk-shaped. A new, parallel governance primitive is required (Component 1); must not extend or reuse `autonomy.ts`.
- Every agent-invoking file (`agent.ts`, `swarm.ts`, `calibration.ts`, `evolution.ts`) shares `agent-sandbox.ts`'s `sandboxConfig()` — new growth agents must use it too.
- `release.ts`'s `dryRun` is `undefined`-falsy → real action is the default there, correctly, because everything upstream is reversible with an earned track record. **Wrong to copy verbatim here** — every real-world-facing flag in Step 4 must default `false`, opt-in required, checked late right before the one consequential call.
- `experiments.ts`'s `evaluateExperiment`/`assignVariant` are real, reusable building blocks, but confirmed **not** a bandit — fixed-split, evaluate-after-the-fact only. The user explicitly asked for real adaptive reinforcement ("reinforced as soon as possible"), so Component 3 designs a genuinely new Thompson-sampling allocator, not a reuse of `experiments.ts`.
- expense-buddy's real, already-scanned `AppProfile.toneOfVoice` and CSS-sourced style guide (`docs/expense-buddy-app-profile.md`) are required grounding inputs for every creative-generation call (Component 5) — independently validated by tryholo.ai's own real "Brand DNA" product mechanism, see above.
- The local expense-buddy checkout was 1 commit behind `origin/main`; **pulled** (`git pull --ff-only`, fast-forwarded `bcd4404..4883589`) before starting this doc — current `EVENT_TYPES`: `session_start`, `expense_added`, `weekly_report_viewed`, `experiment_exposure`.
- The SDK supports config-driven MCP wiring (`Options.mcpServers: Record<string, McpServerConfig>`) — nothing forces hardcoded vendor literals.

## Sequencing and why

Pure/deterministic core first, then agent-invoking pieces, composing last — same discipline as Step 3's own sequencing:

1. **Budget/spend governance** — pure math, zero agent/MCP dependency, highest consequence. Everything else depends on it.
2. **App-stage detection + macro strategy** — depends on (1) and the real `AppProfile`; decides *how much* budget per channel.
3. **Adaptive format/content allocator** — depends on (2)'s channel budgets; decides *what specific format* gets tried next within a channel, and reinforces what works. The genuinely new primitive (no bandit exists anywhere in this codebase today).
4. **Config-driven MCP/tool-selection layer** — depends on nothing functionally, but is positioned here because (5)'s creative generation and (3)'s `buildCandidateArms` both need to know what's actually resolvable before proposing arms/generating content for them.
5. **Creative generation** (text/image/motion-video/UGC-video) — depends on (3)'s selected arm and (4)'s tool bindings.
6. **Execution layer + transparency feed** — composes 1–5, necessarily last; closes (3)'s feedback loop.
7. **Optional marketing website** — owner opt-in, lowest priority/most separable; depends on (4)'s `website_generation` binding.

Whoever picks up a component: check this doc's section for it, check `COORDINATION.md` for whether it's already claimed, and update both when starting and finishing — same discipline as every other workstream in this project. Use `day2/scripts/new-worktree.sh orchestrator <branch>` for whichever component you pick up — this plan itself was written from an isolated worktree for exactly this reason.

## Non-negotiable safety rails (replace per-action approval, since the user explicitly removed it)

Hardcoded, not configurable — mirrors `autonomy.ts`'s own `SENSITIVE_PATH_PATTERNS` precedent:

1. **No `paid_ads` spend while in `launch` stage**, regardless of remaining budget — enforced in both Component 2's allocator output and re-checked in Component 6 (defense in depth).
2. **Per-action spend cap**: no single action may exceed the lesser of $50 or 20% of remaining monthly budget.
3. **Kill switch**: config flag, checked first in `evaluateSpend`, unconditionally, before any other math.
4. **Independent truthful-claims check on every creative**, run by a second agent that never also wrote it.
5. **Tool/MCP connections (credentials, subscriptions) are day2-platform infrastructure, never owner-supplied — but the real, app-specific identity resources a handful of domains still require (a social account, an ad account, a website/domain) are always established as a manual, one-time day2-operator action, never automated, regardless of budget.** Agents may only *operate* what's already connected; neither an agent nor the budget can create the underlying identity resource itself.
6. **An independent "does this read as generic AI content" check runs on every creative.** Not a hard block by default; surfaced in the transparency feed; blocks after repeated consecutive flags for the same segment/channel.
7. **Exploration spend ceiling**: no more than 30% of a channel's monthly budget may go to under-observed arms at once.
8. **UGC-style content may adopt an authentic aesthetic but may never fabricate a specific real person's identity or a genuine-unsolicited-testimonial claim.**
9. **An MCP-bound tool's own autonomous/scheduling features (Juno-class tools specifically) may never independently trigger a real spend or publish action** — every real action from any bound tool routes through Component 6's gate on day2's own schedule, full stop.

## Component 1: Budget/spend governance

New file `orchestrator/src/spend-governance.ts` (+ `spend-config-cli.ts`). Pure math, zero agent/MCP dependency — build and prove first.

```ts
export type SpendCategory = "creative_generation" | "seo_content" | "aso" | "paid_ads" | "social_content" | "direct_outreach" | "website";

export type BudgetConfig = {
  monthlyBudgetUsd: number;
  periodStart: string;                // ISO date, first-of-month boundary
  dailyCapUsd?: number;
  perCategoryCapUsd?: Partial<Record<SpendCategory, number>>;
  perActionCapUsd?: number;           // default: min(50, 20% of remaining monthly) — safety rail 2
  explorationCapFraction?: number;    // default 0.3 — safety rail 7
  killSwitch: boolean;
};

export type SpendRequest = { id: string; category: SpendCategory; amountUsd: number; description: string; requestedAt: string; isExploration?: boolean };

export type SpendDecision =
  | { allowed: true;  reason: string; remainingMonthlyUsd: number; remainingDailyUsd: number | null }
  | { allowed: false; reason: string; remainingMonthlyUsd: number; remainingDailyUsd: number | null };

// Pure. Order: killSwitch (hard no) -> idempotency (replay if request.id already ledgered) ->
// per-action cap -> exploration ceiling (if isExploration) -> daily cap -> per-category cap -> monthly total.
export function evaluateSpend(request: SpendRequest, config: BudgetConfig, ledger: SpendLedgerEntry[]): SpendDecision;
export function recordSpend(ledgerFile: string, request: SpendRequest, decision: SpendDecision): void;  // unconditional
export function loadSpendLedger(ledgerFile: string): SpendLedgerEntry[];
export function renderBudgetSummary(config: BudgetConfig, ledger: SpendLedgerEntry[]): string;

export type KpiGoal = { metric: string; target: number; byDate?: string };
export type WebsiteConfig = { enabled: boolean; templatePreference?: string };
export type GrowthConfig = { budget: BudgetConfig; kpiGoals: KpiGoal[]; website: WebsiteConfig };
```

Config at `.day2-budget.json` in expense-buddy, same idiom as `.day2-autonomy.json`.

**Required test bar, cited from the source spec's own red-team section:** property-based/fuzz suite asserting `sum(allowed requests) <= monthlyBudgetUsd` always, zero breaches — plus explicit tests for the per-action cap, exploration ceiling, and kill switch.

**Live-validation:** synthetic budgets/requests, the fuzz suite, hand-run scenarios proving the per-action cap, exploration ceiling, and kill switch each fire correctly. Zero real money.

## Component 2: App-stage detection + macro strategy

New file `orchestrator/src/growth-strategy.ts`. Depends on Component 1's `BudgetConfig`, the real `AppProfile`, real per-device profiles (`GET /api/day2-profile`), and real competitor/trend insights.

```ts
export type AppStage = "launch" | "traction" | "growth" | "scale";
export type StageSignals = { activeUsers: number; retentionSignal: number | null };
export function deriveAppStage(signals: StageSignals): { stage: AppStage; basis: string };

export type ChannelAllocation = {
  channel: "aso" | "seo_content" | "referral_loops" | "social_content" | "paid_ads" | "direct_outreach" | "website";
  budgetUsd: number; rationale: string; frequencyPerWeek: number;
};

export type GrowthStrategy = {
  stage: AppStage; stageBasis: string; totalBudgetUsd: number;
  allocations: ChannelAllocation[];
  paidAcquisitionUnlocked: boolean; unlockBasis: string;
  kpiGoals: KpiGoal[];
  competitorSignal?: string;          // supporting evidence only, never sole justification — same discipline as evolution.ts's competitorContext
  derivedAt: string;
};

export function deriveGrowthStrategy(
  budget: BudgetConfig, appProfile: AppProfile, stageSignals: StageSignals, kpiGoals: KpiGoal[],
  competitorAngles: CompetitorAngleInsight[] = [], trendInsights: SocialTrendInsight[] = [],
): GrowthStrategy;
```

**v1 macro layer is a fixed rule table**, same honesty discipline as `decideSlotConfig`: `launch` (<100 users) → 100% free channels, `paidAcquisitionUnlocked` hard-false regardless of retention (safety rail 1); `traction` (100–5,000) → referral_loops + social_content, small `paid_ads` slice only past a retention threshold, with competitor/trend insight informing which social *format* gets weight; `growth`/`scale` → paid scaling "while LTV > CAC," honestly flagged unverifiable for expense-buddy.

**Real infra gap to build:** `deriveAppStage` needs an aggregate active-user count; today's KV has no cheap "list all devices" primitive. Needs a small `server.ts` addition (`/api/day2-stats`) — through the normal PR/autonomy pipeline, not written by a growth agent itself.

**Live-validation:** real (small) device population → honest "Launch stage, 100% free-channel" result; synthetic competitor/trend fixtures → rationale cites them without overriding stage-based hard rules.

## Component 3: Adaptive format/content allocator

New file `orchestrator/src/growth-allocator.ts` — the genuinely new primitive (confirmed: zero bandit/Thompson-sampling code exists anywhere today). Directly answers the user's "try different things, reinforce what works, as fast as possible."

```ts
export type Arm = {
  channel: SpendCategory;
  assetType: "text" | "image" | "video";
  videoFormat?: "motion_graphics" | "ugc";   // motion-graphics (raylight/autoAE/hyperframes-style) vs. UGC (Arcads.ai-style)
  formatTag: string;
};
export type ArmStats = { arm: Arm; attempts: number; successes: number; spendUsd: number };
export type AllocatorState = { arms: ArmStats[]; updatedAt: string };

// Only proposes arms whose required capability actually resolves via Component 4's config
// (never propose something nothing can execute).
export function buildCandidateArms(channel: SpendCategory, toolsConfig: GrowthToolsConfig, appId: string): Arm[];

// Beta-Bernoulli Thompson sampling: each arm's success rate is a Beta(1+successes, 1+failures)
// posterior; selection draws one sample per candidate arm, picks the max. Untried arms have wide
// posteriors so they still get picked ("try different things"); proven arms win more often as
// evidence accumulates ("reinforced ASAP" — no fixed minimum sample size required before
// reinforcement starts, unlike experiments.ts's MIN_SAMPLE_SIZE_PER_ARM=30 t-test gate, which
// answers a different question). Pure given an injected RNG — never Math.random() directly.
export function selectArm(state: AllocatorState, candidateArms: Arm[], rng: () => number): Arm;
export function recordOutcome(state: AllocatorState, arm: Arm, success: boolean, spendUsd: number): AllocatorState;

// Enforces safety rail 7.
export function applyExplorationCeiling(candidateArms: Arm[], state: AllocatorState, channelBudget: BudgetConfig): Arm[];

export function loadAllocatorState(path: string): AllocatorState;
export function saveAllocatorState(path: string, state: AllocatorState): void;
export function renderAllocatorSummary(state: AllocatorState): string;
```

**What "success" means:** a device landing via `acquisition_landing` (tagged with the originating `armKey`) counts as a success for that arm if it records a second real signal (e.g. `expense_added`) within a configurable window — same "2+ sessions" activation bar the per-user model already uses. Thin/early data is honestly thin — `renderAllocatorSummary` states sample sizes plainly alongside win rates.

**Closing the loop, flagged not resolved:** every feed/CLI in this codebase is deliberately on-demand, no scheduler anywhere. Driving `AllocatorState` from real events needs either (a) an on-demand `growth-allocator-cli.ts`/`reconcileOutcomesIntoAllocator` (Component 6) — this plan's default — or (b) this project's first real scheduled job, possibly satisfied by a Juno-class tool's own scheduling *called by day2*, never the reverse (see safety rail 9). Flagged in Open Questions.

**Natural extension, not built now:** once multiple real tools are bound per capability (see "mix of tools" above), `Arm` could grow a `toolHint` dimension so the same reinforcement mechanism also learns which *tool* wins, not just which format. Deliberately deferred.

**Live-validation:** seeded-RNG convergence test — a rigged synthetic environment where one arm has a genuinely higher success probability; confirm the better arm's selection share rises over rounds AND the worse arm is never selected zero times (exploration never collapses). Confirm `applyExplorationCeiling` caps low-observation-arm spend at the configured fraction. Zero real money.

## Component 4: Config-driven MCP/tool-selection layer

New file `orchestrator/src/growth-tools-config.ts` — the domain-orchestration seam described above. **Platform-level, not per-app**: this is the one piece of Step 4 config that does *not* live in the governed app's own repo, and is not read via the `--repo <path>` targeting every other per-app config (`.day2-autonomy.json`, `.day2-budget.json`) uses. Reflects the corrected design above — the app owner never sees, edits, or authors a `ToolBinding`.

```ts
export type GrowthCapability =
  | "creative_generation" | "motion_video_generation" | "ugc_video_generation" | "social_trend_research"
  | "social_account_operation" | "ad_platform" | "app_store_release"
  | "seo_content" | "competitor_research" | "website_generation";

export type ToolBinding = {
  capability: GrowthCapability;
  mcpServerName: string;                // e.g. "higgsfield"/"kiveai"/"tryholo" (creative), "raylight" (motion video), "arcads" (UGC), "foreplay" (competitor ad research), "semrush" (SEO), "posteverywhere" (social ops), "fastlane" (app-store), "framer" (website), "juno" (cross-cutting — see multi-capability note) — illustrative, swappable, never hardcoded into agent logic. Held and paid for by day2 as the platform operator, not the app owner
  serverConfig: McpServerConfig;        // SDK's own union type — stdio/SSE/HTTP/in-process; real credentials, day2-operator-owned
  allowedTools: string[];
  toolPolicy?: McpServerToolPolicy[];   // default: always_ask for anything spending money, publishing, or operating an account
  enabled: boolean;
  connectedAccountRef?: string;         // social_account_operation/ad_platform/website_generation only — points at the real, app-specific identity resource (a social account, ad account, or site/domain) day2 has provisioned for THIS app under its own agency/multi-tenant relationship with that platform; fails closed unset (safety rail 5). Never owner-supplied — see the table note above
};

export type GrowthToolsConfig = { bindings: ToolBinding[] };  // one registry, shared across every app day2 powers today just expense-buddy, designed to scale to more without a shape change

// Reads from day2's own platform-level location (e.g. orchestrator/.day2-platform-tools.json,
// gitignored — real credentials live here, a checked-in .example documents the shape), NOT
// from the governed app's repo and NOT passed a --repo flag. A given app's identity is supplied
// separately, only for resolving which connectedAccountRef applies (see resolveBindings below).
export function loadGrowthToolsConfig(path: string): GrowthToolsConfig;
export function resolveBindings(config: GrowthToolsConfig, capability: GrowthCapability, appId: string): ToolBinding[];  // plural — every enabled binding usable for this specific app (identity-bearing bindings additionally require a connectedAccountRef provisioned for this appId)
export function selectBestFitBinding(bindings: ToolBinding[], context: { arm: Arm; strategy: GrowthStrategy }): ToolBinding | undefined;
export function buildMcpServersOption(config: GrowthToolsConfig, capabilities: GrowthCapability[]): Record<string, McpServerConfig>;
export function researchToolCandidates(domain: GrowthCapability): Promise<ToolCandidateInsight[]>;  // day2-operator-run, see domain-discovery mechanism above
```

Platform registry at `orchestrator/.day2-platform-tools.json` (new addition to `orchestrator/.gitignore` — real vendor credentials never get committed; a `.day2-platform-tools.example.json` documents the shape with placeholder values). **Ships with `bindings: []` by default** — matches `ACTIVE_EXPERIMENTS: []`'s "real infra, zero real behavior change" precedent. An unresolved capability fails closed to "no tool available." `social_account_operation`/`ad_platform`/`website_generation` additionally fail closed for a given app whenever that app has no provisioned `connectedAccountRef`, even if the binding itself is `enabled: true` platform-wide — day2 having a Foreplay subscription doesn't mean every app automatically has a live Instagram account to post through.

**Live-validation:** config round-trips; `resolveBindings` returns `[]` against the empty default; `selectBestFitBinding` picks correctly among ≥2 synthetic bindings for the same capability by matching arm context; an identity-bearing binding (`social_account_operation`/`ad_platform`/`website_generation`) with `enabled: true` platform-wide but no `connectedAccountRef` for expense-buddy's `appId` still resolves unavailable for expense-buddy specifically, proving the per-app fail-closed check works independently of the platform-wide `enabled` flag; `researchToolCandidates` run for real against one domain (e.g. `competitor_research`) and cross-checked against Foreplay's real, verified feature set above.

## Component 5: Creative generation — text, image, motion video, UGC video

New file `orchestrator/src/growth-creative.ts`. Three concrete, checkable authenticity mechanisms — not just "prompt it to sound natural":

**(a) Mandatory grounding in the app's own real, already-scanned voice and visuals.** `AppProfile.toneOfVoice` and the real CSS-sourced style guide are **required** inputs to every generation call — the same mechanism tryholo.ai's real "Brand DNA" product independently validates. Visual assets are grounded in a real Playwright screenshot of the live app (same Playwright dependency `swarm.ts`/`calibration.ts` already use).

**(b) New file `orchestrator/src/ai-slop-patterns.ts`**, same idiom as `false-positive-patterns.ts`:

```ts
export type GenericContentPattern = { id: string; description: string; examples: string[] };
export const GENERIC_CONTENT_PATTERNS: GenericContentPattern[];
export function buildAuthenticityChecklist(): string;
```

**(c) Independent authenticity-check agent, never the same agent/call that wrote the creative:**

```ts
export type AuthenticityVerdict = { creative: Creative; readsAsGeneric: boolean; matchedPatterns: string[]; suggestion: string };
export function checkAuthenticity(creative: Creative, appProfile: AppProfile): Promise<AuthenticityVerdict>;
```

Per safety rail 6: not a hard block by default, but surfaced prominently and blocks repeated-consecutive generic flags per segment/channel. UGC-format creatives go through the same check at higher stakes — a UGC creative that still reads as generic has failed at its one job.

```ts
export type Creative = {
  arm: Arm;
  segment: string; headline: string; body: string;
  imageDescription?: string;           // grounded in a real screenshot when arm.assetType === "image"
  videoAssetRef?: string;              // real asset URL once a motion-video/UGC MCP is bound; else a storyboard/script/shot-list
  videoStyle?: string;
  claimsCheckedAgainst: string[];
  costUsd: number;
};

export type CreativeGenerationResult =
  | { status: "generated"; creatives: Creative[] }
  | { status: "no_creative_worth_generating"; reason: string }
  | { status: "parse_failed"; reason: string };

export function generateCreatives(
  appProfile: AppProfile, arm: Arm, segment: string,
  competitorAngles: CompetitorAngleInsight[], trendInsights: SocialTrendInsight[],
): Promise<CreativeGenerationResult>;

// For arm.videoFormat === "ugc", also checks the creative doesn't fabricate a real person's
// identity or a "genuine unsolicited customer" claim (safety rail 8) — one more dimension
// checked by the same fail-closed function, not a separate parallel mechanism.
export type ClaimCheckVerdict = { creative: Creative; truthful: boolean; issues: string[]; fabricatesTestimonialIdentity?: boolean };
export function checkTruthfulClaims(creative: Creative, appProfile: AppProfile): Promise<ClaimCheckVerdict>;
```

Motion video (`videoFormat: "motion_graphics"`) resolves via Component 4's `motion_video_generation` capability; UGC video (`videoFormat: "ugc"`) via `ugc_video_generation` — real, verified illustrative tool: Arcads.ai. With no binding configured for either, returns a real storyboard/script rather than a fabricated asset reference.

**Extend `competitor-feed.ts` with two additive insight types** (not a rewrite — `CompetitorInsight` stays as-is for the evolution engine):

```ts
export type CompetitorAngleInsight = { competitor: string; angle: string; channel: string; relevance: string; source: string };
// Optionally MCP-upgraded via Component 4's competitor_research binding (real, verified: Foreplay.co)
export function researchCompetitorDistributionAngles(category: string): Promise<CompetitorAngleInsight[]>;

export type SocialTrendInsight = { platform: "tiktok" | "instagram" | "other"; trend: string; format: string; relevance: string; source: string };
export function researchSocialTrends(category: string, platforms: string[]): Promise<SocialTrendInsight[]>;
```

**Prompt-injection posture, extended from `agent.ts`'s existing threat model:** content fetched via `WebSearch`/`WebFetch` (or a competitor_research MCP like Foreplay) from arbitrary public sources is *less* trusted than the Sentry-sourced text `agent.ts` already delimits (`untrustedReportBlock`) — `growth-creative.ts`'s prompt builder needs an equivalent wrapper.

**Live-validation:** real creatives vs. real app profile, planted false claim caught; hand-written generic creative flagged, grounded creative not flagged; motion-graphics arm against empty config yields a real storyboard; UGC arm yields a real script; hand-written UGC creative fabricating a named testimonial caught by `fabricatesTestimonialIdentity`. Zero real money.

## Component 6: Execution layer + transparency feed

New files `orchestrator/src/growth-execution.ts`, `growth-feed.ts`. Composes 1–5, closes Component 3's feedback loop.

```ts
export type ChannelExecutionOptions = {
  creative: Creative; toolBinding: ToolBinding; spendRequest: SpendRequest;
  allowLiveAction?: boolean;   // default FALSE — opposite polarity from release.ts's dryRun, same late placement
};

export type ChannelExecutionResult =
  | { status: "blocked_by_claims_check"; verdict: ClaimCheckVerdict }
  | { status: "blocked_by_authenticity_check"; verdict: AuthenticityVerdict }
  | { status: "blocked_by_budget"; spendDecision: SpendDecision }
  | { status: "blocked_by_tool_policy"; reason: string }
  | { status: "blocked_by_unconnected_account"; capability: GrowthCapability }
  | { status: "simulated_stopped_before_live_action"; spendDecision: SpendDecision; wouldSpendUsd: number; wouldPublishTo: string }
  | { status: "executed"; spendDecision: SpendDecision; externalRef: string }
  | { status: "execution_failed"; reason: string };

export async function executeChannelAction(opts: ChannelExecutionOptions): Promise<ChannelExecutionResult>;

// On-demand (no scheduler): re-scans acquisition/activation events, matches back to the arm
// that produced each creative, calls growth-allocator.ts's recordOutcome. Run via CLI —
// or, per the Juno safety note, triggered by a bound autonomous tool ONLY on day2's own
// invocation, never the tool's internal schedule.
export function reconcileOutcomesIntoAllocator(auditFile: string, allocatorStatePath: string, sinceEvent?: string): AllocatorState;
```

Order, real and unconditional up to the last step: claims-check → authenticity-check → account-connection check → `evaluateSpend`/`recordSpend` (always unconditional) → tool-binding resolution (via `selectBestFitBinding`) → **only then** `allowLiveAction`.

**Transparency surface — new file, not an extension of `approvals.ts`/`proposals.ts`:**

```ts
export type GrowthActionRecord = {
  timestamp: string;
  strategy: { stage: AppStage; channel: string; competitorSignal?: string };
  arm: Arm;
  toolUsed: { capability: GrowthCapability; mcpServerName: string; reason: string };
  frequency: string;
  spend: { requested: number; allowed: boolean; runningMonthlyTotalUsd: number; monthlyBudgetUsd: number };
  claimsCheck: ClaimCheckVerdict;
  authenticityCheck: AuthenticityVerdict;
  executionResult: ChannelExecutionResult["status"];
  kpiSnapshot?: Record<string, number>;
};

export function recordGrowthAction(auditFile: string, record: GrowthActionRecord): void;
export function loadGrowthActions(auditFile: string, since?: Date): GrowthActionRecord[];
export function renderGrowthFeed(records: GrowthActionRecord[]): string;
```

`renderGrowthFeed` extends `owner-feed.ts`'s day-grouped pattern with a running **"$X of $Y used this month (Z%)"** line, a "N creatives flagged as generic" count, and Component 3's allocator summary. Ship `growth-feed-cli.ts` matching `owner-feed.ts`'s on-demand pattern.

New event types in `server.ts` (already pulled to current `origin/main`): `acquisition_landing` (`{source, campaign, creativeId, armKey}`), `referral_shared`, `referral_redeemed`.

**Live-validation:** full pipeline end-to-end in default-safe mode — real strategy with real competitor/trend signal, allocator-selected arm, real creative, both real checks, real budget math — confirm `simulated_stopped_before_live_action`; confirm `blocked_by_unconnected_account` for a social-operation attempt against the empty config; `reconcileOutcomesIntoAllocator` against a synthetic event log updates `AllocatorState` correctly. Zero real money, zero real publishing/posting.

## Component 7: Optional marketing website

New file `orchestrator/src/growth-website.ts`. Owner opt-in only (`GrowthConfig.website.enabled`, default `false`).

```ts
export type WebsiteGenerationResult =
  | { status: "generated"; previewRef: string; templateUsed: string; costUsd: number }
  | { status: "not_enabled" }
  | { status: "blocked_by_unconnected_account" }
  | { status: "generation_failed"; reason: string };

export function generateMarketingWebsite(
  appProfile: AppProfile, websiteConfig: WebsiteConfig, toolBinding: ToolBinding | undefined,
): Promise<WebsiteGenerationResult>;
```

Grounded the same way as Component 5. Resolves via Component 4's `website_generation` capability (Framer illustrative; a Juno-bound site-publishing capability is also plausible here per the multi-capability note above). Fails closed to `not_enabled`/`blocked_by_unconnected_account`, no silent fallback vendor.

**Cost is real and likely recurring (hosting)**, unlike everything else in this plan — flagged in Open Questions rather than forced into `evaluateSpend`'s one-off shape without a real design.

**Live-validation:** `enabled: false` (default) → `not_enabled` every time; `enabled: true` + no binding → `blocked_by_unconnected_account`; fixture binding → a real, grounded (not generic-template) preview from the real app profile. Zero real money.

## Simulate-mode default, per sub-component

| Sub-component | Real & unconditional today | Gated behind explicit opt-in (default false) |
|---|---|---|
| Budget ledger + allocator math | Always, no flag | Nothing |
| Creative generation + claims-check + authenticity-check | Always, full generation + both checks | Nothing — no external action here |
| SEO/content generation | Generation + checks + local/preview render | Publishing to a real public URL/route |
| Social account operation | Composing + all checks + connection check | Actually posting (`allowLiveAction`) |
| Ad campaign | Generation, checks, budget math, binding resolution | 3-way split below |
| Motion/UGC video generation | Storyboard/script always; real MCP call if bound | `allowLiveAction` for anything published |
| Marketing website | Generation/preview once owner-enabled | Live deployment (`allowLiveAction`) |
| App-store release | N/A — no native shell exists | `dryRun`-before-`fastlane deliver`, whenever a native wrapper exists |
| Any Juno-class autonomous tool | Its output/proposal, always | Real actions still gated exactly as above — its own scheduler is never the trigger (safety rail 9) |

**Ad platform 3-way split:** (1) generation/math/checks — always real; (2) a designated test/sandbox account — `allowSandboxPlatformCalls` (default false); (3) a real production account — `allowLiveSpend`, kept as an **unimplemented type-level seam only** in this pass.

## Open questions — flagged for the owner, not silently resolved

1. **Per-action safety rails vs. probationary approval** — deliberately not included; rails substitute for the removed approval step.
2. **"Doesn't read as generic AI content" is a real, disclosed judgment call**, not solved by a first-version pattern catalog.
3. **Whether allocator-outcome reconciliation needs this project's first scheduler** — defaults to on-demand; a Juno-class tool's own scheduling is a plausible future answer, but only ever as something day2 calls, never something that calls day2 (safety rail 9).
4. **Website hosting is a recurring cost, not a one-off spend action** — needs a dedicated design, not built in this pass.
5. **`agent-sandbox.ts`'s env-inheritance gap gets materially worse here** — real MCP/ad-platform/social/hosting credentials are coming; every new credential name must hit `DENIED_ENV_VARS` before it's ever set in the parent env.
6. **Idempotency on crash-and-retry** — `SpendRequest.id` replay covers exact retries, not mid-flight state.
7. **KPI goals are a transparency passthrough in v1**, not yet reweighting macro allocation.
8. **Day2-operator connection UX is unspecified** — a manually-edited platform config field (`orchestrator/.day2-platform-tools.json`) is sufficient for this pass; never owner-facing (see the correction above), but how a day2 operator actually connects a new identity resource is not designed further than that.
9. **Platform AI-content-disclosure requirements for UGC-style creative** are real, policy-dependent, and not hardcoded here.
10. **Multi-tool "mixing" (`selectBestFitBinding`) ships as a simple, disclosed rule in v1**, not itself learned — the natural extension (arm-level `toolHint` reinforcement) is named above and deliberately deferred.
11. **Whether day2 can actually obtain agency/multi-tenant-style access to identity-bearing platforms (social, ads, hosting) is a real business/API relationship, not something this codebase can create.** The design assumes it (see the tool table's provisioning note) since it's the only path consistent with "the owner never brings their own MCP," but whether Meta/TikTok/a given ad platform/a given hosting provider actually grants day2 that kind of multi-client access — and under what terms — is unresolved and outside this plan's scope to answer.
12. **`GrowthToolsConfig` is designed with an `appId` parameter for forward-compatibility, but day2 powers exactly one app today (expense-buddy).** True multi-tenancy (one day2 instance serving many apps, pooling the same tool subscriptions with per-app budget/spend metering) is a natural extension, not built or tested here.

## Implementation checklist (concrete, ordered — for whoever picks up each piece)

Each box is independently shippable per the sequencing above; check `COORDINATION.md` before starting in case another session already claimed it.

**Component 1 — Budget/spend governance**
- [ ] `orchestrator/src/spend-governance.ts`: types + `evaluateSpend`/`recordSpend`/`loadSpendLedger`/`renderBudgetSummary`
- [ ] `orchestrator/src/spend-governance.test.ts`: fuzz suite (`sum(allowed) <= monthlyBudgetUsd`), kill switch, per-action cap, exploration ceiling, idempotent replay
- [ ] `orchestrator/src/spend-config-cli.ts`: `--repo <path>` targeting `.day2-budget.json`, matching `autonomy-config-cli.ts`
- [ ] Live-validate: synthetic scenarios per rail, zero real money
- [ ] Update `COORDINATION.md` (claim + done row) and this doc's component section if design shifted

**Component 2 — App-stage detection + macro strategy**
- [ ] `expense-buddy/src/server.ts`: aggregate `/api/day2-stats` endpoint (PR, normal pipeline — not written by a growth agent)
- [ ] `orchestrator/src/growth-strategy.ts`: `deriveAppStage`, `deriveGrowthStrategy`, rule table
- [ ] `orchestrator/src/growth-strategy.test.ts`: stage boundaries, launch-stage lockout, unverifiable-LTV basis, competitor/trend citation
- [ ] Live-validate against real (small) device population

**Component 3 — Adaptive allocator**
- [ ] `orchestrator/src/growth-allocator.ts`: `Arm`/`ArmStats`/`AllocatorState`, `buildCandidateArms`, `selectArm`, `recordOutcome`, `applyExplorationCeiling`
- [ ] `orchestrator/src/growth-allocator.test.ts`: seeded-RNG convergence test, exploration-ceiling enforcement
- [ ] Live-validate: synthetic rigged environment, confirm reinforcement + non-collapsing exploration

**Component 4 — Tool-selection layer**
- [ ] Add `orchestrator/.day2-platform-tools.json` to `orchestrator/.gitignore`; check in `orchestrator/.day2-platform-tools.example.json` documenting the shape with placeholder values only
- [ ] `orchestrator/src/growth-tools-config.ts`: `GrowthCapability`/`ToolBinding`, `loadGrowthToolsConfig`, `resolveBindings`, `selectBestFitBinding`, `buildMcpServersOption`, `researchToolCandidates` — reads the platform-level file, never a `--repo`-scoped app config
- [ ] `orchestrator/src/growth-tools-config.test.ts`: round-trip, empty-default fail-closed, multi-binding selection, per-app unconnected-identity-resource fail-closed (independent of the platform-wide `enabled` flag)
- [ ] Live-validate: run `researchToolCandidates("competitor_research")` for real, cross-check against Foreplay's verified feature set above; confirm no real vendor credential ever needs to exist in `expense-buddy/`'s repo for any test to pass

**Component 5 — Creative generation**
- [ ] `orchestrator/src/ai-slop-patterns.ts` + `.test.ts`
- [ ] `orchestrator/src/competitor-feed.ts`: add `CompetitorAngleInsight`/`researchCompetitorDistributionAngles`, `SocialTrendInsight`/`researchSocialTrends`
- [ ] `orchestrator/src/growth-creative.ts`: `Creative`, `generateCreatives`, `checkTruthfulClaims`, `checkAuthenticity`
- [ ] `orchestrator/src/growth-creative.test.ts`: parser-level tests
- [ ] Live-validate: planted false claim caught, generic vs. grounded creative correctly flagged, motion/UGC storyboard fallback, fabricated-testimonial catch

**Component 6 — Execution + transparency**
- [ ] `expense-buddy/src/server.ts`: `acquisition_landing`/`referral_shared`/`referral_redeemed` event types
- [ ] `orchestrator/src/growth-execution.ts`: `executeChannelAction`, `reconcileOutcomesIntoAllocator`
- [ ] `orchestrator/src/growth-feed.ts` + `growth-feed-cli.ts`: `GrowthActionRecord`, `renderGrowthFeed`
- [ ] `orchestrator/src/growth-execution.test.ts`, `growth-feed.test.ts`
- [ ] Live-validate: full pipeline to `simulated_stopped_before_live_action`, `blocked_by_unconnected_account`, allocator reconciliation from a synthetic event log

**Component 7 — Optional website**
- [ ] `orchestrator/src/growth-website.ts`: `generateMarketingWebsite`
- [ ] `orchestrator/src/growth-website.test.ts`
- [ ] Live-validate: `not_enabled` default, `blocked_by_unconnected_account`, grounded fixture preview

**Cross-cutting, do once, not per-component**
- [ ] Confirm `git pull` on expense-buddy before any `server.ts` edit (done for this doc's writing session — re-check freshness if you're reading this later)
- [ ] Every new agent-invoking function uses `agent-sandbox.ts`'s `sandboxConfig()` — no new duplicated sandbox config
- [ ] Every real-world-facing flag defaults `false` (opposite of `release.ts`'s `dryRun` polarity) — spot-check at PR time
- [ ] `docs/expense-buddy-app-profile.md`'s `toneOfVoice`/style fields are actually read by Component 5, not just referenced in comments
