# Distribution intelligence — reliability, compounding, and how day2 knows what works

The self-distribution pipeline and its closed loop (research → strategy →
creative → verification → execution → reconciliation) are the wedge —
whether day2's recommendations are actually trustworthy and whether they
get *better* over time is the whole bet. This doc covers three things
built/worked out in one continuous session: (1) five concrete capability
additions grounded in a competitor analysis, (2) a reliability and
compounding audit of the existing pipeline, and (3) a fully worked-out
algorithm for how day2 earns the right to say "we know what works" —
honestly, from day one, in a way that compounds instead of staying flat.

## Part 1 — Capability additions (grounded in a Revnu comparison)

[Revnu](https://revnu.com) (YC-backed, $3M raised, $20k MRR in 3 weeks)
sells an "AI growth hire" bundling outbound/SDR, paid ads, SEO+GEO, social,
and retention into one product — broader scope than day2's current
self-distributing component, with zero published detail on guardrails or
verification. The comparison wasn't "match their feature list" — day2's
actual differentiation is the safety/verification rigor Revnu's public
materials show no evidence of. Five concrete, additive capabilities came
out of this, all built, tested, and (where possible) live-verified this
session, none touching any file the parallel session owns:

- **`growth-winback.ts`** — derives a real, grounded churn-risk audience
  segment from actual per-device profiles (same `/api/day2-profile` fetch
  pattern `evolution.ts` already uses), then hands off to the *existing*
  `generateCreatives` — no new channel, no new safety surface, win-back
  creative goes through the same claims/authenticity checks as everything
  else.
- **`growth-geo.ts`** — generative-engine optimization (visibility inside
  ChatGPT/Claude/Gemini/Perplexity answers) as a sibling to `seo_content`.
  Research function (same evidence-tagged idiom as `growth-patterns.ts`)
  plus grounded Q&A generation plus an independent grounding check (same
  "fresh query, never shares state with the one that wrote it" discipline
  as `checkTruthfulClaims` — an ungrounded-but-confident GEO answer gets an
  app *mis*-cited, worse than not being cited).
- **`growth-digest.ts` + `growth-digest-cli.ts`** — push-based daily/weekly
  digest (Slack webhook) composed from data every other component already
  computes. No scheduler built here, same "CLI an operator's own cron
  calls" pattern as `auto-release-cli.ts`.
- **`growth-render.ts` extensions** (`planGraphicVariants`/
  `renderGraphicVariants`) — cheaply produces multiple real template-
  graphic variants from one piece of content, sharing a single browser
  launch. Live-verified: 6 distinct real PNGs from one call. Point: day2's
  zero-markup Tier 0 render pipeline can out-scale a vendor's "thousands of
  variants" claim on cost per variant, not just match it.
- **`growth-cross-channel.ts`** — lets a pattern that's a real,
  statistically above-average winner in one channel get suggested for a
  channel it hasn't been tried in yet, via a lightweight `Arm.formatTag`
  encoding convention (`buildFormatTagForPattern`/`patternIdFromFormatTag`)
  rather than modifying the allocator's actual types. Suggestion-only,
  never auto-applied.

## Part 2 — Reliability and compounding audit

### The one gap above all others

`growth-execution.ts`'s `performLiveAction` is still unimplemented — no
real MCP tool-invocation mechanism exists anywhere in this codebase yet.
**The loop has never actually closed in reality.** Every reconciliation
test runs against synthetic `executed` records. This is priority zero
above every other improvement in this doc: nothing below is *provable*
until this closes, carefully, one low-risk channel first, behind real
confirmation.

### What compounds today vs. what's thrown away

Reframed from "is this reliable" to "does every action make future actions
better, or does it evaporate":

- **Self-healing**: `autonomy-config.ts`'s per-area trust model IS a
  compounding mechanism in principle, but today's console toggle is
  manually flipped — nothing reads the existing audit log back as a trust
  signal ("12/12 approved in ui-fixes over 3 weeks" should surface as a
  reason to raise autonomy, not sit unused in a log). Similarly, nothing
  confirms whether `calibration.ts`'s false-positive pattern list grows
  from real human-confirmed outcomes or only from manual authoring.
- **Self-evolving**: nothing stops `proposeFeature` from re-proposing an
  already-rejected idea — rejection (with the real reason) should become a
  permanent filter, not a one-time ignored suggestion. Experiment
  conclusions should leave a reusable insight behind, not just a closed
  experiment record.
- **Self-distributing**: `growth-patterns.ts`'s own header comment states
  the design outright — "no persistent corpus... every call does live
  research fresh." Correct against the original cost question (no vector
  DB), but it means a pattern discovered today and one discovered in six
  months carry identical weight, because nothing remembers the first one.
  This is the direct motivation for Part 3 below.

### Other concrete reliability gaps (lower priority than the above)

- Claims-check and authenticity-check are each a single agent call —
  adversarial, multi-verifier checking (2-3 independent passes, require
  agreement) is the highest-leverage trust upgrade available, since it
  directly hardens the actual differentiator against a competitor selling
  speed over verification.
- `direct_outreach` is a typed `GrowthChannel`/`SpendCategory` member never
  allocated budget by any real stage-allocation function — a silent,
  confusing gap if it's ever surfaced as a selectable option.
- The allocator's `MIN_ARM_OBSERVATIONS = 5` is a flat cutoff, not a real
  confidence interval — the existing Beta-sampling machinery could compute
  one directly instead of treating "tried five times" as "proven."
- No full-loop integration test exists — every stage is unit-tested in
  isolation; nothing proves research → strategy → creative → checks →
  execution → reconciliation → allocator update actually wires together
  correctly as a system.

## Part 3 — How day2 knows what works: the Tier 0 / Tier 1 framework

### The actual goal, stated precisely

Day2 needs to credibly say "using day2 gives you a materially higher
chance of distribution success than going it alone" — available from day
one, honest about its own confidence, getting stronger the longer day2
runs — without buying that credibility through a licensed dataset,
ToS-violating scraping, or a naive "this company did X and won, so do X"
shortcut that collapses under the first serious question. Competitors
claiming "trained on 10M assets, 19K verified ads" are making a *volume*
claim, not a *validation* claim — volume of observed assets says nothing
about whether any of them actually caused the outcome attributed to them.

### Why single case studies don't transfer

- **Survivorship bias** — you only ever see companies that won; the
  (probably larger) set that tried the identical tactic and failed is
  invisible by default.
- **Confounding** — successful companies differ on dozens of dimensions at
  once (timing, funding, founder quality, luck); a case study can't
  isolate which variable — the tactic specifically — actually mattered.
- **Narrator bias** — a founder retrospective is a biased storyteller with
  every incentive to make their own strategy sound deliberate and causal.
- **Context-boundedness** — a tactic tied to one platform's algorithm at
  one moment is not a timeless principle.

### Two tiers, deliberately different rigor, never collapsed into one

**Tier 0 — Observational research.** Case studies, Wayback Machine
snapshots, trend data. Necessary and immediate (solves cold start), but
structurally limited — a retrospective story, not an experiment. More
volume doesn't fix that; more case studies just means more stories.

**Tier 1 — Applied, reconciled evidence.** What happens once day2 actually
executes something for a real customer and measures the real result.
Categorically stronger — day2 controls the application and measures the
outcome, the closest thing to a real experiment this system can produce —
and it's the one evidence type a competitor who hasn't executed as many
real actions structurally cannot have, regardless of training-corpus size.

**Strategic sequencing**: Tier 0 solves cold start. Tier 1 is the actual
moat. `growth-cross-channel.ts` (Part 1) already encodes the bridge —
every arm tagged with its source pattern means the moment real execution
exists, every application becomes a real test of that pattern's claimed
transferability, automatically.

### The Tier 0 algorithm

**Data model.** Every observation tagged on a controlled taxonomy, not
free text — `category` (consumer-finance, b2b-saas-productivity, ...),
`platform` (tiktok, instagram, youtube, google-search,
platform-agnostic, ...), `stage` (reuses the real `AppStage` type), `era`
(coarse buckets: pre-2023 / 2023-2024 / 2025+). Comparable values are what
make the context-overlap math in Stage 4 meaningful.

**Stage 1 — Candidate generation.** Runs the existing research functions
(`researchProvenPatterns`, `researchOrganicPatterns`, `researchGeoPatterns`,
`researchStageComparables`), with one required schema change: every
candidate must carry a `mechanism` (why would this transfer, not just what
happened) and a `mechanismDependsOn: Set<"category"|"platform"|"stage"|"era">`
— which context dimensions the *stated mechanism itself* claims matter.
This has to be captured at generation time, since only the agent that
found the pattern can reason about why it thinks it worked.

**Stage 2 — Adversarial pass, mandatory before anything enters the
library.** A separate, independent agent call (never sharing context with
the one that found the pattern) specifically hunts for counter-examples —
a company that tried the same tactic and said it failed, expert critique,
evidence it's already known to be era/platform-bound. Three outcomes, a
hard decision rule, not a soft weight:
- **Direct contradiction** → permanently caps the pattern at
  `single_observation` regardless of how much confirming replication
  exists elsewhere, contradiction always shown alongside it.
- **Contextual caveat** → narrows `contextBoundaries` directly (how the
  system learns its own blind spots).
- **Nothing found despite a real search** → recorded explicitly as
  `counterEvidenceChecked: true, found: false` — "checked and clean" is
  meaningfully different from "never checked," and only the first
  contributes to confidence.

**Stage 3 — Matching against the existing library.** Cheap
keyword/category pre-filter shortlists ~5 plausibly-related existing
patterns; a single LLM judgment call compares the candidate only against
that shortlist, explicitly biased toward *not* merging, required to state
why it did or didn't match (an audit trail, not a silent yes/no).

**Stage 4 — Tier computation.**
```
isCrossContextReplication(a, b, mechanismDependsOn):
  for each dimension in mechanismDependsOn:
    if a[dimension] != b[dimension]: return true   // differs on a dimension
      // the mechanism claims matters, and it STILL replicated — strong signal
  return false   // identical on every dimension the mechanism says could matter
```
Two TikTok observations in different categories do **not** count as
cross-context replication for a platform-dependent mechanism — they share
the one dimension the mechanism itself says matters. The same two
observations *would* count as cross-context for a platform-agnostic
psychological mechanism. Tiers: `single_observation` (≤1 observation),
`replicated_same_context` (2+, never differing on a dependency dimension),
`replicated_cross_context` (2+, differing on at least one dependency
dimension and still holding).

**Stage 5 — Evidence directness, a second, orthogonal axis.** Tier
(replication breadth) and evidence strength (how directly observable each
individual instance is — the existing `EvidenceStrength`/
`OrganicEvidenceStrength`/`GeoEvidenceStrength` work) never collapse into
one fake-precise number. `evidenceBasis: "first_party" | "mixed" |
"inferred_only"` shown alongside tier, not merged into it.

**Stage 6 — Periodic synthesis into principles.** Not per-candidate —
triggers on a schedule or once a category crosses a size threshold (≥8
validated patterns). Feeds only `replicated_*`-tier patterns (never raw
single observations) to an agent looking for a smaller number of patterns
sharing one underlying principle. Every principle stores
`derivedFromPatternIds` — never an ungrounded assertion.

**Stage 7 — Freshness and decay.** `stalenessRisk` derived directly from
`mechanismDependsOn` — era/platform-dependent patterns decay fast and need
re-checking on a short cycle; patterns claimed evergreen decay slowly.

**Stage 8 — Honest presentation.** Every surfaced pattern always carries
tier + evidenceBasis + any caveats/counter-evidence + staleness flag.
Never collapsed to a single score.

### Worked example (real data from this session)

The live `researchOrganicPatterns` call earlier this session returned
"#loudbudgeting... 10M+ views," tagged `platform_trending`.

- **Stage 1**: mechanism = "public, specific financial disclosure reduces
  money-talk stigma and triggers algorithmic amplification of
  vulnerable/relatable content." `mechanismDependsOn = {platform, era}` —
  category is *not* a dependency.
- **Stage 2**: an adversarial pass plausibly finds the trend has cooled by
  2026 — a `contextual_caveat` narrowing the era boundary, not a
  disqualifying contradiction.
- **Stage 3**: checked against "YNAB founder-led teach-don't-sell content"
  — different mechanism entirely, correctly stays separate, not merged.
- **Stage 4**: one observation → `single_observation`. A later
  vulnerable-disclosure finding in a *different* category but still on
  TikTok in the same era would still only be `replicated_same_context` —
  it hasn't differed on either dependency dimension.
- **Stage 8 (shown to an owner)**: *"Single example — platform/era-
  dependent (TikTok, 2023-2025 'loud budgeting' moment), not yet confirmed
  to generalize. Worth testing cheaply, not a recommendation."*

### Organic content's real data-sparsity problem, and the fix

Paid ads have institutionalized public transparency infrastructure (Ad
Library, Creative Center). Organic virality has no equivalent — it's an
anecdotal genre by nature, and success-biased at the *source* level (nobody
writes "my organic post flopped"), which starves Stage 2's disconfirming
search specifically. Four additional source categories, none of them
account-browsing:

1. **Academic/research literature** on virality and social behavior — real
   methodology, and academic work routinely states its own boundary
   conditions, which is disconfirming evidence built into the source.
2. **Platform-published aggregate trend reports** (TikTok's "What's Next,"
   YouTube Culture & Trends, Meta's own published research) — first-party,
   aggregate, publicly released as PR material, stronger than any single
   creator's story.
3. **Marketing-tool vendors' state-of-industry reports** (Buffer, Hootsuite,
   Sprout Social, Later) — pre-aggregated findings across the vendor's real
   client base, structurally closer to what Stage 4 wants than one
   anecdote.
4. **Startup-postmortem genres** (Failory, CB Insights, Indie Hackers "what
   didn't work" threads) — specifically for Stage 2: one of the only
   content genres that exists to document failure.

When even this is thin: widen Stage 1's search to adjacent categories
(Stage 4's `mechanismDependsOn` logic already handles cross-category
evidence correctly) rather than stopping, and when real data genuinely
isn't there, say so — an explicit `dataSparsity: "thin" | "adequate"` flag
per category/research-type, set honestly rather than papering over it.
This gap is also the sharpest argument for Tier 1: organic is where
external coverage is structurally thinnest, which makes day2's own applied
history *disproportionately* more valuable there than for paid channels,
where competitors can already lean on Ad Library data.

### Trends need a second, deliberately non-rigorous track

A multi-stage adversarial-verification pipeline cannot validate a trend
with a few days' relevance — there's no disconfirming evidence to find yet
(nobody's had time to fail at something 3 days old), and by the time the
pipeline finishes, the trend is dead. This is a category error, not a
speed problem — the fix is two tracks with different epistemics, not a
faster Track A.

**Track A** — everything above, unchanged: slow, adversarially verified,
compounding.

**Track B** — trend/timely, new:
- Fast, frequent (daily+) polling of genuinely real-time-native sources —
  TikTok's public Trends page is the standout.
- No adversarial pass — explicitly labeled `status: "currently trending",
  validated: false, relevanceWindow: "3-7 days"`, never Track A's tier
  vocabulary.
- Short TTL, auto-retired once the window passes — the opposite of Track
  A, where staleness is flagged but the pattern stays visible.
- Tags *format*, not mechanism — "duet/stitch reaction," "POV format" —
  enough to execute, not a causal claim.
- Pull-based, computed fresh right before content generation needs it, not
  pre-seeded (Track A's proactive seeding makes sense because durable
  patterns stay useful; pre-computing today's trends for an unused
  category just goes stale before anyone uses it). This also means the
  original "no persistent corpus" design in `growth-patterns.ts` wasn't
  wrong — it's exactly correct for Track B, just not sufficient alone for
  Track A's compounding needs.

**Promotion path**: any individual trend is short-lived, but the
underlying *format* often isn't ("POV: ___" is dead in a week; the POV
format itself has recurred for years). Track B tracks recurrence of the
structural format across independent trend cycles over time, reusing the
same replication-counting logic as Stage 4. Once a format recurs enough
times independently, it graduates into Track A's durable library as a real
validated meta-pattern.

**Real-world finding, resolving part of Open question #4**: implementing
Track B's primary source (a Playwright render of TikTok's Creative Center
Trends page, not a plain `fetch` — that page is client-rendered, so a
non-JS GET sees an empty app shell) surfaced a harder wall underneath the
rendering problem: TikTok's own edge returns a flat HTTP 403 to the
render — an active bot-detection block on even this one public,
no-login-required marketing page, not a timing/layout issue. Getting past
that reliably would mean fingerprint spoofing or residential-proxy
rotation against a platform whose ToS explicitly forbids automated
access — a line this project doesn't cross regardless of the page being
nominally public.

The resolution isn't to defeat the block, it's to add sources that don't
have this problem because they're official, authenticated APIs rather
than rendered pages:
- **YouTube Data API v3** (`chart=mostPopular`) — free-tier, API-key
  auth, genuinely trending data, not scraped.
- **Reddit's OAuth2 API** (client-credentials grant, a registered
  "script" app) — not Reddit's unauthenticated `.json` endpoints, which
  Reddit itself now rate-limits/blocks for the same bot-detection reasons
  as TikTok.

Neither fully replaces TikTok-native trend granularity — YouTube's
`mostPopular` chart is generic trending video, not TikTok's micro-format
trend cycles, and Reddit surfaces trend *discussion*, not the trend
itself. Both are handed to the research agent as real grounding alongside
TikTok's render attempt (which still runs first and is used whenever it
succeeds) and WebSearch, with an honest caveat disclosed whenever a
source has no data (missing credentials, a failed call) rather than
fabricated content standing in for it.

**A fourth option, documented but deliberately not built**: a licensed
trend-data vendor (Exploding Topics-style tools, social-listening
platforms like Brandwatch/Sprout Social) has already solved compliant
TikTok-trend access as a paid product, and would close the TikTok-
specific gap the two sources above can't fully close. Not built here
because it directly reverses this project's margin-preserving "no
external tools" stance (same reasoning that ruled out arcads-style
middleman tools earlier in this project's research) — named here as a
real, available option if that trade-off is ever revisited, not as a
recommendation.

**The sharper Tier 1 connection**: trend-chasing is actually a *faster*
source of real Tier 1 evidence than structural-pattern testing, because
trends cycle quickly — day2 can apply a trend-based tactic and measure the
real result within days, instead of waiting months for a structural
pattern's transferability to get tested.

### Ad hoc trend-triggered campaigns

Not every app should jump on every trend that fits generically — the
default has to be skip, with a specific bar for the exception.

- **Fit evaluation** — a dedicated, cheap, early filter grounded in the
  real `AppProfile` (tone compatibility, topical connection, audience
  overlap), separate from and upstream of the authenticity check. Default
  output `fits: false`; that's the expected majority case, not a failure.
- **A separate event-trigger path, same downstream safety rails** — not
  folded into the regular allocator cycle (`selectArm`'s cadence is
  pull-based; a trend is a react-now external event). A fitting trend
  flows through the exact same `generateCreatives` → claims-check →
  authenticity-check → spend governance → execution → `GrowthActionRecord`
  pipeline as everything else, tagged with the trend's format for the
  promotion path above. Only the trigger differs, never the gate.
- **The timing/oversight tension, resolved the same way autonomy already
  is** — a dedicated, explicit, opt-in toggle ("let day2 post about
  relevant trends automatically, within the trend's live window"), off by
  default, same pattern as the console's "let day2 ship low-risk fixes
  automatically" switch. Without the opt-in, a fitting trend becomes a
  high-priority, time-stamped notification for the owner to approve
  quickly — never silently skipped, never silently posted.
- **Anti-spam** — an ad hoc trend post substitutes for that week's already-
  budgeted organic posting slot (`growth-strategy.ts`'s existing
  `frequencyPerWeek`), it doesn't add unlimited volume on top. Same total
  cadence, better-timed content — a brand that jumps on every fitting
  trend reads as thirsty, the same authenticity failure mode the system
  already screens for elsewhere.

## Part 4 — The proprietary judge model (distilling Tier 1 into a cheap, learned predictor)

**The idea, stated precisely.** Every other piece of this intelligence
layer produces a judgment by either calling an agent fresh every time
(claims-check, authenticity-check, Tier 0 research) or running simple
frequency statistics (the allocator's Beta-Bernoulli sampling). A model
trained specifically on day2's own accumulated real Tier 1 outcomes is
categorically different — cheap enough to call before a candidate arm is
even generated, and structurally impossible for a competitor to replicate
without day2's own execution history. This is the technical artifact that
makes "the moat is applied outcomes" (Part 3) literal rather than
rhetorical — a real, swappable predictor, not just a narrative about why
day2's position is defensible.

**Why this can't be real yet, and why building it anyway is correct.** A
model needs labeled (features, real outcome) examples. Today:
`performLiveAction` is a stub, so zero real `executed` `GrowthActionRecord`s
exist; `reconcileOutcomes` has only ever run against synthetic fixtures.
There is nothing to train on. This is the same gating fact as the
Validation strategy section above, one level more specific: that section
is about the comparative/causal claim made to users, this is about one
internal capability's training precondition. Building the scaffolding now
— so it's ready the moment real data exists — follows the same discipline
already established elsewhere in this codebase: `.day2-platform-tools.json`
ships with `bindings: []`, and `reconcileOutcomes` itself is "built and
tested against synthetic `executed` records now anyway."

**What's built now (synthetic data, pure math, zero agent/MCP dependency —
`orchestrator/src/growth-judge-model.ts`, `growth-judge-model.test.ts`):**

1. **A persisted labeled-outcomes ledger — the real gap this closes.**
   `reconcileOutcomes` computes a per-`creativeId` `success: boolean` and
   immediately folds it into `ArmStats`'s aggregate counts, discarding the
   individual example — there was no training corpus even in principle,
   independent of whether real execution existed yet. `growth-execution.ts`
   gained one small, behavior-preserving refactor to make this possible
   without duplicating logic: the landing/activation join inside
   `reconcileOutcomes` is now its own exported pure function,
   `resolveActivationOutcome` — `reconcileOutcomes`'s own test suite passes
   unmodified, confirming zero behavior change. `growth-judge-model.ts`
   reuses that same join to derive a `LabeledOutcome` per real, reconciled
   action and appends it to a new append-only JSONL ledger (same idiom as
   `growth-feed.ts`'s `recordGrowthAction`), idempotently — a repeated run
   never double-labels the same `creativeId`.
2. **A feature schema grounded in what a real `GrowthActionRecord`
   actually carries** — `arm` (channel/assetType/videoFormat),
   `strategy.stage`, `toolUsed?.capability`, the claims/authenticity
   verdicts, and now `groundingPatternTier`/`groundingPatternEvidenceBasis`.
   That last pair required closing a real, previously undocumented gap
   found while doing this: `growth-creative.ts`'s `generateCreatives` was
   bypassing `pattern-library.ts`'s whole adversarially-validated, tiered
   library entirely — it only ever consumed raw, pre-validation
   `ProvenPattern[]` from `growth-patterns.ts`, never a real
   `TransferablePattern[]`. Every bit of Part 3's validation/tiering
   machinery was producing patterns that grounded zero actual creatives.
   Fixed: `generateCreatives` now optionally accepts real
   `TransferablePattern[]`, renders each via `renderPatternSummary` inside
   the existing untrusted-research wrapper, and a creative may honestly
   disclose `groundedInPatternId` — validated against the real provided
   pattern list at parse time (`parseCreativeGenerationResult`'s
   `validPatternIds`), so a fabricated or stale id is dropped, never
   trusted. `GrowthActionRecord` carries it through; `growth-judge-model.ts`
   resolves it to the pattern's real `tier`/`evidenceBasis` via a
   caller-supplied `GroundingPatternLookup` (`buildGroundingPatternLookup`
   projects a real `PatternLibrary`'s patterns into one directly) —
   unresolvable or absent degrades honestly to `"none"`, never thrown.
   `category`/`platform`/`era` remain deliberately excluded — not a gap
   left open through inattention, but for a reason specific to each,
   corrected from this doc's own earlier framing: `category`/`platform`
   have no curated, versioned taxonomy yet (Part 3's Open Question #1) and
   are open-ended, which breaks this file's fixed-vocabulary one-hot
   design outright. `era` turns out not to be a well-defined per-action
   feature at all on reflection (an earlier draft of this doc assumed it
   would be derived from the current timestamp, which was wrong) — a
   `TransferablePattern`'s `observations` can genuinely span multiple eras
   by design, that heterogeneity is exactly what cross-context replication
   tracks, so there is no single honest "this pattern's era" value without
   an undisclosed, arbitrary pick.
3. **The model: pure-TS logistic regression over one-hot categorical
   features, zero ML dependency** — matches this codebase's own "pure math
   first" discipline (`spend-governance.ts`, `growth-allocator.ts`) and
   `offering-logic.md`'s margin-preserving stance (no external model/service
   for something this cheap to run in-process). Deterministic (zero-
   initialized weights, full-batch gradient descent, no RNG needed, unlike
   the allocator's own Thompson sampling), L2-regularized, every
   time-dependent value (`trainedAt`) injected rather than read from the
   system clock — pure and testable throughout.
4. **A mandatory fail-closed fallback, the single most important property
   of this module.** `MIN_LABELED_EXAMPLES_TO_TRAIN = 50` (a disclosed
   guess, same status as `MIN_ARM_OBSERVATIONS = 5`, deliberately much
   higher — an under-trained ~20-dimensional logistic model is actively
   worse than honestly having no model at all). Below that threshold, or
   with no model at all, `predict()` always returns
   `{predictedSuccessProbability: 0.5, confidence: "none", basis:
   "no_model_fallback"}` — an honest "no information" prior, never a
   fabricated confident number. There is exactly one entry point
   (`predict`) and it can never be bypassed to reach raw, under-trained
   weights. This model is additive and can only ever supplement judgment
   (e.g. a cheap pre-screen before `buildCandidateArms` proposes a real-
   spend arm) — it must never replace `checkTruthfulClaims`/
   `checkAuthenticity` (`growth-creative.ts`), which stay safety-critical
   and independently explainable by design regardless of how good this
   model ever gets.
5. **Live-validation now, honest about what it proves.** A seeded synthetic
   dataset (one feature combination planted to succeed ~85% of the time,
   another ~15%) confirms the trained model's predicted probabilities
   actually separate the two, and confirms the fallback engages correctly
   below the labeled-example threshold and when no model exists at all.
   This proves the pure-math core is correct. It proves nothing about
   real-world predictive power, which is unknowable until real labeled
   examples exist.
6. **Held-out-by-app evaluation** (`splitByApp`/`evaluateGeneralization`) —
   splits by `appId` (a new field on `LabeledOutcome`/`GrowthActionRecord`,
   defaulting to `UNKNOWN_APP_ID` on every record today, since day2 powers
   exactly one app), trains on one set of apps, evaluates on an app never
   trained on, and reports the train/test accuracy gap. Correction from an
   earlier draft of this doc, which wrongly filed this under "needs real
   data to even attempt": the *mechanism* — does a train/test split by app
   correctly catch a model that only memorized one app's idiosyncrasy — is
   a general software property, testable now with a planted synthetic
   scenario exactly like item 5's convergence test. Confirmed two ways:
   a synthetic pair of apps sharing the same real relationship reports a
   near-zero gap; a synthetic pair where app A's training data has a
   confound that doesn't hold in app B reports a large, correctly-signed
   gap. What's still genuinely unknowable without real apps is the real-
   world *magnitude* any gap would show — that's a fact about reality, not
   about this code, and no synthetic data can reveal it (any dataset has
   exactly the properties it was given).
7. **Calibration checking + drift detection**
   (`computeCalibrationCurve`/`meanCalibrationError`/`detectDrift`) — same
   correction as item 6. `meanCalibrationError` is a standard sample-size-
   weighted expected-calibration-error computation, confirmed against a
   planted perfectly-calibrated synthetic prediction set (near-zero error)
   and a planted badly-miscalibrated one (high error). `detectDrift` is a
   deliberately simple v1 (a global success-rate shift past a disclosed
   `DRIFT_THRESHOLD = 0.15`, not a per-feature-bucket or statistically
   rigorous changepoint test — a real CUSUM/Page-Hinkley-style detector is
   a reasonable future upgrade, not built here), confirmed against planted
   stable and planted-shifted synthetic success-rate windows. Both
   mechanisms are real and tested; what they'd report on real outcomes —
   whether day2's predictions are actually well-calibrated, whether real
   accuracy actually drifts — is unknowable until real predictions and
   real subsequent outcomes exist to feed them.
8. **Retraining cadence + version comparison**
   (`shouldRetrain`/`compareModelVersions`) — built directly on top of
   items 6-7's own machinery: `compareModelVersions` reuses the same
   held-out-accuracy computation to decide whether a new model version
   earns promotion over the current one, rather than inventing a separate
   comparison mechanism. `oldWeights: null` (no prior version at all) is
   handled by `predict`'s own existing fallback, not a special case — a
   nonexistent prior version's "accuracy" is honestly just the base
   success rate of guessing 0.5 every time, which a genuinely useful new
   version should beat. `RETRAIN_AFTER_NEW_EXAMPLES = 50` and
   `MIN_ACCURACY_IMPROVEMENT_TO_PROMOTE = 0.02` are disclosed guesses, same
   status as every other constant in this file — the real-world cadence
   that makes sense depends on how fast real labeled examples actually
   accumulate, which is unknowable until execution is live.
9. **A real call site — `predictForCandidate`, and `GrowthActionRecord`
   grew an advisory `judgePrediction` field.** Before this, the entire
   module had zero callers anywhere in the codebase — a complete,
   tested library nothing ever invoked. `JudgePredictionInputs` splits out
   of `GrowthActionRecordForJudgeModel` exactly the fields a prediction
   actually needs (arm, stage, `toolUsed`, the claims/authenticity
   verdicts, an optional `groundedInPatternId`) — no `creativeId`,
   `executionResult`, or spend required — so `predictForCandidate` is
   callable the moment `checkTruthfulClaims`/`checkAuthenticity` have run
   for a freshly-generated `Creative`, well before any ledger entry or
   execution decision exists. `growth-feed.ts`'s `GrowthActionRecord`
   carries the result as `judgePrediction?: JudgePrediction` — purely
   advisory, never read by `executeChannelAction`'s gating logic at all.
   `renderActionLine` deliberately suppresses the note entirely unless
   `basis === "learned_model"` — printing "no prediction yet" on every
   single line forever (true for every record today) would be noise, not
   transparency; a real trained prediction gets a real line
   (`judge model: 73% predicted (medium confidence, n=300)`).

**What's still genuinely gated on real data — not attempted here:**

10. **Whether the model's own confidence should feed back into
    `applyExplorationCeiling`'s exploration budget** (a well-calibrated model
    could justify less forced exploration on arms it's already confident
    about) — different in kind from items 6-9 above: this one is
    mechanically easy (a few lines wiring `predict`'s confidence into the
    ceiling calculation) but deliberately not done, because doing it safely
    depends on item 7's calibration check actually running against real
    data first. An uncalibrated model that's confidently wrong could
    quietly suppress the allocator's own safety rail — the one real
    protection against premature certainty — in exactly the cases that
    matter most. A sequencing judgment call, not a technical blocker.
11. **A real, curated, versioned `category`/`platform` taxonomy** (Part 3's
    own Open Question #1) — the actual blocker on adding either as a
    trainable feature, since both are open-ended today and this file's
    one-hot encoding needs a fixed vocabulary. Once that taxonomy exists,
    adding them here is mechanical; designing the taxonomy itself is not
    this file's problem to solve.

**How this connects to the Validation strategy section above**: items 1-9
are all real, tested mechanisms today — none of them have been exercised
against real data, because none exists yet. The vibecoded-apps validation
phase (once a good-enough version of day2 exists) is specifically where
these get fed real multi-app data for the first time: `splitByApp` gets a
real second app to hold out, `computeCalibrationCurve` gets real
predictions to check, `detectDrift` gets a real time series to watch. The
tools are ready; what they'd report about reality is not yet known, and
this doc doesn't pretend otherwise.

**Where this sits in the phased plan below.** This is the concrete
technical mechanism behind step 4's "earned claim" — the thing that turns
applied-outcome depth into something day2 can act on cheaply at scale,
rather than only describe qualitatively.

## Phased plan

1. **Bootstrap Tier 0** — adversarial/disconfirming pass added to the
   existing research functions; transferability tiering; proactive
   seeding sweep across common categories so a brand-new customer's first
   session shows real, tiered research, not a blank slate.
2. **Wire Tier 1** — `performLiveAction`, scoped to one low-risk channel
   first, behind real confirmation. Every executed action's pattern tag
   flows into reconciliation; every reconciled outcome promotes or demotes
   that pattern's confidence.
3. **Cross-customer synthesis** — once there's more than one real customer
   with real history, patterns validated across multiple different real
   day2 customers become the strongest tier of all.
4. **The earned claim** — only once (2)/(3) have real depth does day2 get
   to make its own version of "we know what works," specific about how
   much of any recommendation is backed by applied outcomes versus
   observational research, tier by tier — more defensible than a raw
   asset-count claim precisely because it's willing to say that.

## Validation strategy — deliberately deferred, not skipped

Current work (this doc, the allocator, the creative/execution pipeline) is
being judged against the market on technical/architectural merit — bandit
correctness, evidence-pipeline rigor, execution actually closing the
loop — not yet against real-world outcomes. That's a sequencing choice,
not an oversight.

**The plan**: once day2 reaches a version judged good enough on its own
technical/intelligence merits — the allocator converges correctly on real
(not just synthetic) data, the Tier 0/Tier 1 pipeline runs end-to-end, the
execution loop actually closes for at least one channel — the next phase
is applying it to a handful of real, independent vibecoded apps (not just
expense-buddy) and observing actual performance. That is where validation
questions (does the allocator actually outperform a human's judgment? does
Tier 1 evidence actually compound across apps? does any of this move a
real distribution outcome?) get answered — with real data, from multiple
real apps, not before.

**Why defer rather than build validation machinery now**: a measurement
framework built before there's a second real app to measure against has
nothing to measure. Step 3 above ("cross-customer synthesis") already
names this precondition structurally — this section just makes explicit
that the precondition is a planned future phase, not an open-ended
dependency to solve for prematurely. Effort between now and then goes into
making the underlying intelligence substantially better, not into proving
it early against a sample size of one.

**What this does not mean**: it doesn't relax the safety rails, the
honesty-about-confidence discipline, or the existing live-validation bar
every component already carries (synthetic-data tests, fuzz suites,
live-but-synthetic verification runs). It means the comparative/causal
question — is day2 actually better than doing it yourself or using a
market competitor — stays explicitly open and unclaimed until there's a
real multi-app track record to answer it from.

## Open questions — flagged, not silently resolved

1. The category taxonomy (consumer-finance, b2b-saas-productivity, ...)
   needs an actual curated, versioned list — not designed here.
2. Stage 3's matching cost/latency at real library scale (hundreds of
   patterns per domain) isn't modeled — the pre-filter shortlist size (5)
   is a starting guess.
3. `mechanismDependsOn` classification accuracy (does the agent correctly
   identify which dimensions matter) has no evaluation harness yet — a
   wrong classification silently miscalibrates Stage 4's tiering.
4. Track B's trend-polling frequency isn't fully enumerated. Which
   platforms beyond TikTok's Trends page qualify as "genuinely
   real-time-native and publicly accessible" is now partly answered:
   TikTok's own page turned out to return a flat HTTP 403 to an
   automated render (active bot detection, not a layout issue — see
   "Trends need a second, deliberately non-rigorous track" above), so
   YouTube Data API and Reddit's OAuth2 API were added as the real,
   compliant alternatives. Still open: whether any other platform has a
   similarly accessible official API worth adding, and whether the
   licensed-vendor option documented above is ever worth revisiting.
5. Ad hoc trend-campaign fit evaluation needs its own cost/budget
   treatment — it's a real agent call per (trend, app) pair; at scale
   across many apps this needs a cap, not modeled here.
6. The Stage 6 synthesis threshold (≥8 validated patterns) and Stage 7's
   decay-cycle lengths are disclosed guesses, not derived from anything.
