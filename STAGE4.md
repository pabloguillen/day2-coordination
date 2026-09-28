# Day2 — Step 4 (self-distributing) working log

Companion to `STAGE0.md`–`STAGE3.md` and the control room in `COORDINATION.md` — read that first for cross-session context and current session assignments. Design doc: `docs/step4-self-distributing-plan.md` (all seven components, sequencing, domain/tool orchestration principle, and why).

**Scope note:** per the roadmap, Step 4 is gated the same way every prior stage was — no real users, no real elapsed time to prove a real distribution strategy against. The user explicitly directed this session to design and build it anyway, with an explicit, load-bearing constraint that bounds the whole thing: **no real money spent and no real public-facing action taken until the owner separately authorizes it.** Every component below ships in a default-simulate mode; the "self" in self-distributing is real (zero per-action approval within budget, once trusted), the "real world" part is deliberately not turned on yet.

## Log

### 2026-09-28 — Plan written and approved (W37 claimed, Session A-Swarm)

Full plan: `docs/step4-self-distributing-plan.md`. Covers all seven components (budget/spend governance, app-stage strategy, adaptive format/content allocator, config-driven MCP tool-selection layer, creative generation, execution + transparency feed, optional marketing website) with a recommended build order and, for each, an implementation-ready design (types, function signatures, fail-closed safety rules, live-validation plan). Grew from the user's original framing (agents + MCPs, owner-configured budget, KPI-derived strategy) through several rounds of explicit user requirements gathered during planning — preserved in the doc's own Context/roadmap sections rather than re-summarized here:

- No real money/public action yet; zero per-action approval within budget; full transparency of strategy/KPIs/tool reasoning/frequency/spend; strategy adapts to budget size.
- Competitor analysis feeds the strategy itself, not just creative copy.
- Content must not read as generically AI-generated — a first-class, checkable design requirement (`ai-slop-patterns.ts`, an independent authenticity-check agent).
- Social trend-scouting (TikTok/Instagram) informs content format choice.
- Motion-graphics video and UGC-style (AI-presented testimonial) video are both first-class, distinct formats.
- Agents can operate (never create) a social media account.
- Real adaptive reinforcement — "try different things, reinforce what works, as fast as possible" — a genuinely new Thompson-sampling allocator (`growth-allocator.ts`), since this codebase has no bandit/adaptive-allocation primitive anywhere (confirmed by direct search).
- An optional, owner-opt-in marketing website (Framer-style, template-based).
- **Design principle, stated explicitly by the user and load-bearing for Component 4's whole shape:** day2 doesn't need to be the expert in SEO/ad-creative/UGC-video/social-scheduling/website-building — it identifies the relevant domain, finds the best real tool already built for it, and orchestrates that tool via MCP inside day2's own budget/safety/transparency machinery. This is why `growth-tools-config.ts` ships with a real, repeatable tool-discovery function (`researchToolCandidates`), not just a static, one-time vendor list.

**Real tools cited in the plan were live-verified before attribution, not guessed** (one earlier attribution mistake — KiveAI — was caught and corrected by the user mid-session; treated as a live lesson, not silently fixed): Foreplay.co (competitor ad-creative research/tracking — verified via web search, maps to the `competitor_research` domain), tryholo.ai (brand-DNA-grounded ad/social/email generation — verified via web search; its real product mechanism independently validates this plan's own Component 5 grounding design), Juno AI / getjuno.com (an autonomous "AI coworker" — browser automation, own filesystem, code-writing, hosted-site publishing, own schedule and mailbox — verified via web search; architecturally different from every other named tool since it spans multiple domains at once and introduces a new safety rail: its own autonomous scheduling must never be what triggers a real spend or publish action, only day2's own invocation of it may). Arcads.ai (UGC video), Semrush (SEO) cited per the user's own naming, standard/well-established enough not to need a fresh verification pass.

**Worktree adopted for this work**: `day2/scripts/new-worktree.sh orchestrator step4-self-distributing` — this session's first time using the isolation tooling Session C built in W34, specifically to avoid repeating the W32/W33 shared-checkout file-attribution mixup while multiple components of this plan may get picked up by different sessions in parallel, same as Step 3's four components were.

Component 1 (budget/spend governance) is the recommended starting point — pure math, zero agent/MCP dependency, and the plan's own required test bar (a property-based fuzz suite proving the budget cap is never exceeded) is cited directly from the source spec's own red-team section. Not yet started as of this log entry — see `COORDINATION.md` W37 for live status.
