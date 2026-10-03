# day2 — offering logic

What ships as an open-source SDK, what stays a paid hosted product, and how
pricing is structured. Grounded in how nine comparable open-core companies
actually draw this line (researched directly — pricing pages and licensing
docs cited below, not assumed from memory), plus one cautionary tale from a
company that redrew the line after the fact and lost a chunk of its
community to a fork over it.

## TL;DR

**Self-healing and self-evolving ship as a real, permissively-licensed SDK**
(MIT/Apache-2.0) — the fix pipeline, autonomy engine, canary release, swarm
testing, evolution/experiments. It runs entirely on the owner's own
infrastructure and API keys; day2 earns nothing directly from it.

**The console and the self-distributing (growth) engine are the paid
product** — not because they're harder to build, but because they're
structurally impossible to self-host: the growth engine depends on day2
holding the vendor/ad-platform relationships, and the console is where
multi-app, multi-tenant, real-money operation actually lives.

Pricing follows the pattern every AI-agent tool in this space has converged
on: a flat subscription with a bundled allowance metered in day2's own
units — scans, verified fixes, releases, creatives — not raw tokens, and
never a percentage of ad spend.

## The three-part structure

Every company researched draws the same line, just described differently:
*what a single builder needs to be self-sufficient is free; what a team
needs to operate safely, together, at scale — or with real money and real
external accounts on the line — is paid.* day2 maps onto that line unusually
cleanly, because it already has three components that sit on three
different sides of it.

| Part | What's in it | License |
|---|---|---|
| **Give away** — self-healing + self-evolving SDK | Bug detection → fix → PR → canary release → rollback (`pipeline.ts`, `agent.ts`, `autonomy.ts`/`autonomy-config.ts`, `release.ts`/`canary-cli.ts`, `swarm.ts`, `calibration.ts`, `git.ts`, `pr.ts`). Feature proposals and experiments (`evolution.ts`, `experiments.ts`, `proposals.ts`). | MIT / Apache-2.0 |
| **Sell — hosted product** — day2 Console + Growth Engine | The dashboard, onboarding, multi-app management (`apps-registry.ts`, `api-server.ts`, the console itself); spend governance, growth strategy/allocator/creative/execution (`spend-governance.ts`, `growth-*.ts`), ad-platform and creative-vendor tool bindings (`growth-tools-config.ts`). | Proprietary, hosted only |
| **Sell — org scale** — team & governance layer | Seats, RBAC, SSO, extended audit-log retention, custom spend limits, dedicated vendor-tool bindings, SLA-backed support. | Proprietary, custom contract |

## Why this exact line

**1. The mechanical core is the cheapest thing to give away.** Temporal
(MIT), Supabase (Apache-2.0), Trigger.dev (Apache-2.0), and LangChain's own
framework are all fully open with zero feature gating — the deterministic
engine, self-hosted, costs the company nothing to give away and buys
adoption and community fixes on exactly the part that benefits from more
eyes. Self-healing's pipeline/autonomy/canary mechanics and self-evolving's
proposal/experiment engine are that same kind of core for day2.

**2. The growth engine can't be self-hosted even if we wanted to give it
away.** It isn't a licensing choice — it's structural. `growth-tools-config.ts`
is explicitly platform-held: the creative-generation, ad-platform, and
app-store vendor relationships and credentials belong to day2 as the
operator, not the app owner ("held and paid for by day2 as the platform
operator, not the app owner" — see that file's own header comment). That's
the same shape as an ad agency's own vendor seat — nobody self-hosts their
agency's media-buying relationships. This makes "hosted-only" a fact about
the product, not a monetization decision, which is a stronger and more
durable boundary than a feature flag.

**3. Split by product, not by feature flag.** LangChain/LangSmith is the
cleanest precedent: the framework is entirely open, and the observability
platform is a wholly separate, wholly closed product built on top of it —
not one codebase with paid features unlocked by a license key. day2's
console is the same relationship to the SDK: a genuinely separate product,
not a locked mode of the open one.

**4. A percentage of managed ad spend is a conflict of interest we'd be
building on purpose.** Traditional media-buying agencies and tools like
Smartly.io charge 2–25% of spend under management — which quietly rewards
the vendor for the owner spending *more*. That's the opposite of day2's own
safety design: hard per-action caps, an exploration ceiling, a kill switch,
and "nothing real happens until you say so" (`spend-governance.ts`). A flat
subscription is the only pricing model that doesn't fight the product's own
values.

**5. Meter in day2's own units, never raw tokens or opaque credits.**
LangSmith meters traces, Braintrust meters "scores" — real,
product-meaningful units instead of tokens or an invented currency.
Lovable- and Bolt-style opaque credit pools draw real user complaints about
reverse-engineering what a "credit" costs. Given day2 already runs on
radical transparency about what happened and why (the owner feed, the
growth feed, the status-pill honesty system), day2 should meter the same
way it already reports: a scan, a verified fix, a release, a creative
generated-and-checked.

## Pricing tiers

Seats are free everywhere except Enterprise — Sentry and Braintrust both
found that gating on data/usage volume rather than headcount removes the
single most common objection to team adoption.

| Tier | Price | What it includes | Gated on |
|---|---|---|---|
| **Community** | $0 | The full self-healing + self-evolving SDK, self-hosted. Every mechanic at full fidelity — no console, no growth engine. Your own Claude API key, your own GitHub/Cloudflare/Sentry accounts. | Nothing — this is the adoption tier |
| **Starter** | $29/mo | Hosted console for one app: dashboard, onboarding, plain-language approvals, canary visibility. Growth engine visible in read-only strategy mode, spend disabled. Includes 25 scans/fixes per month. | 1 app · overage on scans+fixes beyond 25/mo |
| **Growth** | $149/mo | Everything in Starter, plus the full growth engine: real (capped) spend, creative generation with truthfulness/authenticity checks, format allocator, transparency feed. Includes 5 apps, 40 creatives generated+checked/mo, unlimited scans/fixes. | Apps · creatives/mo · flat fee regardless of ad spend |
| **Enterprise** | Custom | Unlimited apps, team seats, RBAC, SSO/SAML, extended audit retention, custom spend ceilings, dedicated vendor-tool bindings, SLA-backed support. | Contract — seats and governance, not usage |

Disclosed judgment call: the exact prices and allowances above ($29/$149,
25 scans, 5 apps, 40 creatives) are a reasonable starting point matched to
the comparable tiers researched (Lovable Pro $25, Cursor Pro $20, Braintrust
Pro $249, PostHog's paid platform add-ons $250–750) — not something derived
from day2's own real unit-cost data, since no real customer usage exists
yet to calibrate against. Revisit once real Claude-API and vendor-tool cost
per scan/fix/creative is known.

## Content-generation strategy: no SaaS middleman

A margin-protection refinement on top of the Growth tier above, since flat
pricing (not %-of-spend, see principle 4) means every vendor dollar spent on
creative generation comes straight out of day2's own margin, not the
owner's. The organizing question for every content type isn't "which vendor
is cheapest" — it's "can Claude + deterministic code produce this at all
before reaching for any external generative model."

**Tier 0 — Claude + code, zero external generative cost.** Three real,
already-built or newly-added pieces:

- `growth-patterns.ts` (W45, already shipped) — two live, on-demand research
  functions (`researchProvenPatterns`, `researchStageComparables`), Claude +
  WebSearch/WebFetch only. This directly replaces the "trained on 10M+
  assets, 19K verified ads" pitch (tryholo.ai's own marketing) with a small,
  curated, evidence-tagged library instead — every pattern carries a real
  `EvidenceStrength` (`platform_ranked`/`published_case_study`/
  `award_judged`/`longevity_proxy`) so confidence is never overstated. No
  embeddings, no vector database, no fine-tuning, no persistent corpus at
  all — confirmed deliberately scoped out after investigating what a
  vector-DB approach would have cost, in favor of fresh research per call.
- `design-references.ts` (W46, already shipped) — real, owner-uploaded
  brand assets (logo, illustrations, photography) plus optional Figma
  grounding, stored in the app's own repo (`.day2-brand-assets/`). Grounds
  creative in real brand material beyond what the onboarding code-scan can
  see.
- `growth-render.ts` (new) — the actual rendering step for two of `Arm`'s
  asset shapes, using Playwright directly (not agent-mediated — rendering a
  known template or replaying a fixed step sequence needs no LLM judgment
  at the point of execution):
  - `renderTemplateGraphic` — a branded graphic ad (quote/stat-callout/
    feature-announcement), authored as real HTML/CSS grounded in the app's
    real colors and uploaded logo, rasterized headless. Covers the same
    ground a "37-template image-ad library" sells as a paid feature.
  - `captureProductDemo` — a genuine screen-recording of the real app
    performing a real, already-decided flow (Playwright's `recordVideo`),
    not generated b-roll. More authentic, not less — reinforces rather than
    fights the authenticity check already in `growth-creative.ts`.

**Tier 1 — direct MCP to raw model providers, real cost, no reseller
markup.** Only for what Tier 0 structurally can't do:

- Photorealistic/novel-scene images (no real scene exists to screen-record)
  — a raw image model route (e.g. Flux/SDXL via fal.ai or Replicate).
- Conceptual/abstract generative video (when a real screen-capture isn't
  the right fit) — a raw video model route (e.g. Seedance, $0.04–$0.78/sec
  depending on resolution, via BytePlus/fal.ai/Replicate).
- UGC-style avatar talking-head video — the one deliberate exception. This
  needs a licensed, consented synthetic-avatar identity no amount of local
  rendering can manufacture. Higgsfield is the concrete recommendation:
  pay-as-you-go at published rates (no subscription, spend stops at zero —
  structurally aligned with day2's own kill-switch philosophy, unlike a
  %-of-spend or committed-monthly model), a real MCP server (a genuine
  drop-in for `growth-tools-config.ts`'s existing `ToolBinding` model,
  unlike Arcads' Claude-Code-skills-only packaging), and its own cleared
  "Soul 2.0" avatar roster so day2 never has to become an avatar-licensing
  business itself. One disclosed compliance step, not a footnote: commercial
  usage rights reportedly vary by Higgsfield plan tier — verify the actual
  terms for whichever tier gets used before anything ships.

**Tier 2 — day2's own licensed avatar roster (a later lever, not v1).**
Once UGC-video volume is large enough that even Higgsfield's margin on top
of raw compute matters, the next step is day2 licensing a small avatar
roster directly and calling a raw video model itself. A real legal/capital
undertaking, not a v1 decision.

Disclosed scope note: neither `growth-render.ts` function is wired into any
orchestration path yet — same deliberately-unbuilt seam as
`growth-execution.ts`'s own `performLiveAction` (no real MCP tool-invocation
mechanism exists anywhere in this codebase yet; nothing external is called
today, everything stops at `simulated_stopped_before_live_action`). This
section documents the capability and the vendor selection logic for when
that orchestration gets built, not a claim that it's live today.

## One thing not to do

HashiCorp relicensed Terraform and Vault from MPL to BSL in 2023 to stop
cloud providers reselling their own OSS — and within five days, 120+
companies signed a protest manifesto, and within weeks the Linux Foundation
had forked the last MPL release as OpenTofu, which now has independent
governance and has meaningfully diverged. The lesson isn't "don't restrict
competitors" — it's that **retroactively changing the license on something
the ecosystem already depends on reads as a breach of trust, not a business
decision, and it costs you the fork rather than the compliance.** Whatever
line we draw for self-healing/self-evolving's MIT license needs to be one we
intend to hold permanently. Any future tightening should apply only to
net-new components we haven't shipped as open yet — never clawed back from
what's already out.

## Research trail

- [krusemediallc/arcads-claude-code](https://github.com/krusemediallc/arcads-claude-code) — MIT, 1,557★; Claude Code/Cursor skill pack wrapping Arcads.ai's REST API, not an MCP server
- [Meet the Higgsfield API](https://higgsfield.ai/blog/higgsfield-api) — pay-as-you-go, no subscription, 50+ models, official MCP server
- [Higgsfield Expands Developer Access With APIs and GitHub Tools](https://entarabi.com/en/2026/09/higgsfield-expands-developer-access-with-apis-and-github-tools/)
- [Higgsfield UGC Ads Explained (Tadka)](https://tadkai.io/resources/higgsfield-ugc-ads-explained-2026) — Soul 2.0 avatar model, 40+ avatar roster
- [Seedance 2.0 API Pricing & Benchmarks](https://openrouter.ai/bytedance/seedance-2.0)
- [Seedance 2.0: Complete Specifications, Pricing, API Access (Gate.AI)](https://gate.ai/blog/seedance-2-0-bytedance-specs-pricing-api-use-cases) — official BytePlus route + fal/Replicate/Atlas Cloud/WaveSpeed
- [Temporal pricing teardown, 2026](https://dev.to/beton/temporal-pricing-teardown-2026-2j11)
- [Supabase pricing explained, 2026](https://schematichq.com/blog/supabase-pricing)
- [n8n Sustainable Use / fair-code license](https://docs.n8n.io/n8n-community-license)
- [Dagster vs Dagster+ differences](https://www.getorchestra.io/guides/dagster-vs-dagster-key-differences-and-insights)
- [LangSmith FAQ — self-hosting & pricing](https://docs.langchain.com/langsmith/faq)
- [LangChain pricing: $0 open source vs LangSmith enterprise, 2026](https://techjacksolutions.com/ai-tools/langchain/langchain-pricing/)
- [PostHog as strategic open-source alternative](https://www.opentechhub.io/posthog/)
- [PostHog usage-based pricing guide](https://flexprice.io/blog/posthog-pricing-guide)
- [Airbyte: Cloud vs Open Source vs Enterprise](https://airbyte.com/blog/airbyte-cloud-vs-open-source-vs-enterprise)
- [Airbyte licenses](https://docs.airbyte.com/community/licenses)
- [Metabase / open-source BI governance features](https://www.domo.com/learn/article/open-source-bi-tools)
- [Trigger.dev, 2026 — fully open, zero feature gating](https://automationatlas.io/tools/trigger-dev/)
- [Inngest vs Trigger.dev vs BullMQ, 2026](https://www.buildmvpfast.com/blog/inngest-vs-trigger-dev-vs-bullmq-background-jobs-nextjs-2026)
- [The OpenTofu Manifesto](https://opentofu.org/manifesto/)
- [OpenTofu vs Terraform in 2026 — the fork finally diverged](https://jorijn.com/en/blog/opentofu-vs-terraform-2026-the-fork-finally-diverged/)
- [HashiCorp's BSL change, explained](https://www.techtarget.com/searchitoperations/news/366548016/HashiCorp-open-source-change-targets-competitors)
- [HashiCorp: is open source a defect or a feature?](https://www.nanalyze.com/2023/10/hashicorp-opensource-defect-or-feature/)
- [Lovable pricing, 2026](https://uxmagic.ai/blog/lovable-pricing)
- [Replit Agent pricing, 2026](https://vantaige.io/blog/replit-pricing-explained-2026)
- [Bolt.new pricing plans, tokens, and real costs, 2026](https://www.jetadmin.io/blog/bolt-new-pricing-plans-tokens-and-real-costs-in-2026/)
- [Updated v0 pricing — Vercel](https://vercel.com/blog/updated-v0-pricing)
- [Base44 pricing, 2026](https://www.nocode.mba/articles/base44-pricing-2026)
- [LangSmith pricing breakdown](https://inference.net/content/langsmith-pricing/)
- [Braintrust pricing](https://www.truefoundry.com/blog/braintrust-pricing)
- [Cursor pricing, 2026](https://www.nocode.mba/articles/cursor-pricing)
- [GitHub Copilot pricing & AI Credits](https://costbench.com/software/ai-coding-assistants/github-copilot/)
- [Sentry pricing](https://www.g2.com/products/sentry/pricing)
- [Smartly.io: % of ad spend model](https://superscale.ai/alternatives/smartly/pricing)
- [AdCreative.ai flat-fee pricing, 2026](https://www.tryatria.com/blog/adcreative-ai-pricing)
- [AI marketing agency pricing guide](https://www.hashmeta.ai/en/ai-seo/ai-marketing-pricing)

## Open questions — flagged, not silently resolved

1. Which specific files/modules cross from `orchestrator/src/` into a
   separate, publishable SDK package (own repo? own npm/JSR package inside
   the existing `day2-orchestrator` repo?) is not decided here — this
   document only draws the license/product boundary, not the packaging
   mechanics.
2. The Starter/Growth tier prices and allowances are a starting hypothesis
   (see the disclosed judgment call above), not backed by real unit-cost
   data yet.
3. Whether Community-tier self-hosters get any support channel (community
   Discord/GitHub issues only, or something more) is undecided.
4. Migration path for an existing Community (self-hosted) user who wants to
   upgrade to a hosted tier without re-onboarding isn't designed yet.
5. No orchestration script exists yet that decides, per `Arm`, whether to
   call `growth-render.ts` (Tier 0), resolve a real `ToolBinding` (Tier 1),
   or do neither (organic/text-only) — same disclosed gap as
   `growth-execution.ts`'s own unimplemented `performLiveAction`.
6. Higgsfield's commercial usage rights reportedly vary by plan tier — the
   actual terms for whichever tier day2 buys into need verifying before any
   UGC video ships, not assumed from the pay-as-you-go pricing alone.
