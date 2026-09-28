# Day2 — Step 2 (self-adapting) working log

Companion to `STAGE0.md` (Stage 0 validation) and the control room in
`COORDINATION.md` — read that first for cross-session context and the
current gating status.

**Scope note:** per the roadmap, Step 2 doesn't formally start until Stage 0's
exit criterion (manual adaptation test shows a retention lift) is met — see
`COORDINATION.md`'s open gating tension, still open (user confirmed directly:
no real users available to run that test). Originally this log was
design/prep only, no production code. **Updated 2026-09-25:** the user
explicitly asked to continue building Step 2 infrastructure despite the gate
staying unmet — a real product decision, not a subagent call, so noted here
plainly rather than silently reinterpreted. What's actually landed (W9, W10)
stays on the "infra only, no adaptive behavior turned on" side of the line
regardless: real endpoints, real data capture, but nothing reads it back into
an actual per-user model or changes what any user sees. That distinction is
still being honored even though the broader "start Step 2" gate was
overridden by explicit instruction.

Test subject (tentative, pending a real decision): `expense-buddy`, same as
Stage 0 — already has a live orchestrator, CI, Sentry, and a real deployment,
so it's the natural place to ground a concrete design rather than designing
in the abstract.

## Log

### 2026-09-25 — First design pass (W1), grounded in expense-buddy's real code

Full spec: `docs/step2-self-adapting-spec.md`.

expense-buddy's entire UI is one file (`src/routes/index.tsx`, 328 lines),
no backend, no auth, `localStorage`-only. Found 4 candidate adaptive slots
by reading the actual component tree — `AddExpenseForm`, `SpendSummaryCard`,
`ExpenseList`, and a **new** `WeeklyReportSlot` that's essentially the source
doc's own Chloe example ("exports the same report three Fridays in a row →
app offers a one-tap weekly report") spec'd almost verbatim. Per-user model
fields, first 2-3 building-block contracts, and a config-plane sketch
(Workers KV, since there's no backend to add a config service to otherwise)
are all in the spec.

**Open question that needs a human decision, not more design work:**
expense-buddy has no accounts — everything is anonymous and per-device. The
source doc's per-user model assumes a persistent user to attach a profile
to; this app has none. A device-keyed profile silently resets on storage
clear or device switch. Two ways forward: accept that as a known Step 2
limitation, or require auth to exist before Step 2 starts on this app. Not
resolving this unilaterally — see `COORDINATION.md`.

### 2026-09-25 — Step 1 gap analysis (W2) — why Step 2 can't build yet anyway

Full analysis: `docs/step1-self-healing-gap-analysis.md`. Even once the
per-user-model question above is settled, Step 2 has nothing to build on:
the orchestrator has no event pipeline and no config-serving infrastructure
at all today — both hard requirements Step 2 needs from Step 1 (see spec
§6). Step 1 itself isn't done: real gaps are canary rollout + automatic
rollback and an explicit autonomy-level model (nothing ships without a human
clicking merge today, so the pipeline never exceeds L2 "Prepare" — it needs
to reach L3 "Act on low risk" for Step 1's own exit criterion). Also
surfaced: **"swarm" means two different things across the docs** —
STAGE0.md's swarm is Sentry production monitoring (after the fact);
the source doc's swarm is persona/adversarial/accessibility agents that
pre-test changes before release. Neither the source doc's kind, nor any
task-completing test swarm, exists in the codebase yet. Worth keeping
straight across sessions so "swarm" claims aren't assumed to mean the same
thing.

### 2026-09-25 — W9: config plane built (Session A), first real Step 2 infra

Full detail: `COORDINATION.md` W9. Real `GET /api/day2-config` endpoint in
expense-buddy, Workers-KV backed, device-scoped anonymous ID (the "no auth"
branch of the identity strategy resolved above). Closes half of spec §6's
dependency list. Infra only — serves a static default matching what the app
already renders, nothing reads it back yet.

### 2026-09-25 — W10: event pipeline built (Session B), closes spec §6

The other half of spec §6's dependency list. `POST /api/day2-events`,
same `globalThis.__env__` pattern W9 established, new `DAY2_EVENTS` KV
namespace (separate from `DAY2_CONFIG` — write-heavy/append vs.
read-heavy/small). Bounded per-device log (most-recent 200), strict
`eventType` allow-list + metadata size cap since it's an anonymous,
unauthenticated endpoint. Two real signals wired in, taken directly from
this spec's §2 table rather than invented: `session_start`, and
`expense_added` carrying `categoryWasDefault`/`dateWasDefault` — the exact
skill-level signal §2 describes ("whether note/date are ever edited from
defaults").

Live-verified against a real local Workers runtime (`wrangler dev --local`,
real KV namespace): two real POSTs to the same device appended correctly
(confirmed via the KV explorer API), validation rejected malformed input on
every checked path, W9's endpoint confirmed still unaffected. 9 new unit
tests, 16/16 project tests passing. `git diff` confirmed the only
`index.tsx` change is the two fire-and-forget `recordEvent()` calls — no
rendering/behavior change. Branch `add-event-pipeline`, PR
[#15](https://github.com/pabloguillen/expense-buddy/pull/15), **not
merged** — left for a deliberate decision, same pattern as W3/W7/W8/W9.

**Spec §6's dependency list is now fully closed**: both the event pipeline
and config plane exist for real. What's still missing for Step 2 to build
actual adaptive behavior: the retention-lift gate itself (still blocked, no
real users), the building-block extraction (spec §3 — the 3 candidate
contracts are designed but expense-buddy's `index.tsx` hasn't actually been
refactored into them yet), and the composer/adaptive-slot rendering layer
(spec §1) that would read `checkInWithConfigPlane()`'s result and actually
vary what renders — none of that exists, and building it would cross from
"infra" into "real adaptive behavior," which is where the gate actually
bites.

### 2026-09-25 — W11: per-user model computation (Session A), spec §2 for real

Full detail: `COORDINATION.md` W11. User said the other session was moving
into building-block extraction (spec §3) next; picked the per-user model
(spec §2) as the deliberately non-colliding complement — needs zero changes
to `index.tsx`, since it only reads W10's already-merged event log.

New `GET /api/day2-profile?deviceId=<id>`, read-only, no new storage.
`skillLevel` and `categoryDistribution` are genuinely computed from real
`DAY2_EVENTS` data (2-session threshold + ever-overrode-a-default heuristic
for skill level, quoting the source doc's Ben case; real category counts).
`primaryGoal`, `habits`, `statedPreferences` are honestly `null` with an
explanation — the event pipeline doesn't capture what those fields need
yet, and fabricating values for them would be worse than reporting the real
gap. 12 new tests + live-verified against a real local Workers runtime
(seeded real events via the actual POST endpoint, confirmed the profile
reflects them).

**Merged and shipped to production via the canary mechanism** (10%
traffic, clean monitor, promoted) — same discipline as W9. One transient
404 observed on the very first post-promote request against the live
endpoint (immediately after the "promoted" log line), resolved on retry and
stable on three follow-up checks; most likely edge-cache/propagation timing
right at the version-switch boundary rather than a code issue, given every
other request since has been consistently correct. Noted rather than
silently ignored.

Spec §2's dependency chain is now: retention-lift gate (blocked) +
building-block extraction (other session, in progress) + the composer
(spec §1, needs both of those) stand between here and actual adaptive
behavior. Nothing built this round crosses that line.

### 2026-09-25 — W12: building-block extraction (Session B), spec §3 for real

Full detail: `COORDINATION.md` W12 (renumbered from a W11 collision with
Session A's per-user-model entry above — caught before it mattered). PR
[#17](https://github.com/pabloguillen/expense-buddy/pull/17), CI green, not
merged.

Extracted `ExpenseEntryForm`, `SpendSummaryCard`, `ExpenseList` from
`index.tsx` into typed components matching spec §3's contracts exactly,
each implementing both branches of its config (not just the one currently
live) so they're real, tested building blocks rather than thin wrappers —
call site in `index.tsx` passes fixed props reproducing today's exact
behavior, no wiring to W9's config plane or any adaptive decision.

The valuable part wasn't the extraction itself, it was almost shipping it
wrong three times and catching each one before it mattered:
1. Clamped a displayed percentage that the original never clamps.
2. Reset form fields on rejected submissions that the original leaves alone.
3. Broke `divide-y`'s row dividers via an extra wrapper div — invisible to
   reasoning about the JSX, caught only by actually running the repo's own
   `visual-diff.sh` locally before opening the PR and reading the diff image
   pixel-by-pixel rather than trusting "tests pass, ship it."

Spec §3 is now real. What's left before spec §1's composer could exist:
still the retention-lift gate (blocked, no real users) — nothing here
changes that.

### 2026-09-26 — W14: the composer (Session B), spec §1 — user explicitly overrode the gate

Full detail: `COORDINATION.md` W14 (renumbered from a W13 collision with
Session A's swarm-v1 entry — no real overlap, caught before it mattered).
PR [#18](https://github.com/pabloguillen/expense-buddy/pull/18), based on
`extract-building-blocks` (PR #17, not yet merged — hard dependency).

**This is a different kind of workstream than everything above.** W9–W12
were all infrastructure, each proven to change nothing by default. The
composer is the piece that actually reads per-device config and varies
what renders — the moment "self-adapting" stops being infrastructure and
becomes a real capability. The user was told this plainly before
authorizing it ("build the composer anyway — your call to make, same as
the earlier gate calls"), and made the call explicitly. Noted here, not
silently reinterpreted, same as the earlier "continue with Step 2 despite
the gate" decision at the top of this file.

`index.tsx` now consumes `checkInWithConfigPlane()`'s result and merges it
over each building block's defaults, per slot, partial-override style (the
served config only ever contains the fields meant to vary — `fields`,
`defaultCategory`, structural data, stay app-controlled). Added real
calendar-week data filtering, since the `period: "week"` branch of the
config contract existed with nothing behind it. SSR-safe by construction:
`slotConfig` starts `null`, identical on server and first client render,
same pattern already used for `expenses`/`hydrated` — no new
hydration-mismatch risk.

**Proved two different, necessary things — not one:**
1. Default rendering is unchanged today: `visual-diff.sh` vs. `origin/main`,
   0.002% (noise), matching W12's own result.
2. The adaptive capability genuinely works, live, not just mocked: seeded a
   real non-default config for a test device in local KV (`wrangler dev
   --local`), confirmed the real endpoint served it back via `curl`, then
   loaded the real app in a real Playwright browser using that exact
   device ID — a real `<table>`, "Spent this week", and a category
   breakdown all rendered, none of which show for the default device. This
   is the first time in this whole project that "the app can actually
   adapt" has been demonstrated for real rather than designed for. Test
   key deleted after, confirmed via a follow-up `curl`.

5 new component tests, 45/45 total passing, build clean, 0 new lint
errors. CI on the real PR hasn't run yet — its workflow only triggers on
PRs against `main`, and this one's based on `extract-building-blocks`
until #17 merges and GitHub retargets it.

**Explicitly not built:** anything that decides *what* config a device
should get. `index.tsx` is now *capable* of rendering per-config; nothing
anywhere yet writes a non-default config for a real device. That mapping
(per-user model → config decision) is Step 3's evolution-engine
territory — the retention-lift gate that's been open this whole time is
about to become directly relevant again the moment that mapping exists,
since that's the point real adaptive behavior would actually reach a real
user.

### 2026-09-27 — W25 (Session A-Swarm): the per-user-model → config decision, and W26 (Session C): statedPreferences stops being null

Full detail: `COORDINATION.md` W25/W26. Two threads worth separating
even though they landed close together:

**W25** is the mapping this file's own note above said was "about to
become directly relevant" — the user explicitly authorized skipping the
retention-lift gate and continuing Step 2's production build.
`decideSlotConfig()` (`expense-buddy/src/server.ts`) is real and
rule-based (spec §5's launch-stage design, not statistics), wiring
`ExpenseList.bulkActions` and `SpendSummaryCard`'s category-breakdown
density to a device's actual `skillLevel`/`categoryDistribution` for the
first time — the retention-lift question this whole gate has been about
is now live for real, not synthetic.

**W26** picks up spec §2's other open thread: `statedPreferences` was the
one per-user-model field explicitly honest about needing UI that didn't
exist yet ("needs the config-plane Apply/Undo/Ask UI to exist first").
Built that UI — a real `AskAQuestionCard` shown to actual end users
(distinct from `COORDINATION.md` W20's owner-facing review cards) — and
wired `derivePerUserModel` to read real answers. Deliberately stopped
short of feeding the answer into `decideSlotConfig` itself, to keep this
change to "the field is now observable," not a second adaptive-behavior
change bundled into the same PR. Left unmerged (PR #34) for explicit
review, same as W25 was before its own merge — a new end-user-facing
capability isn't a call to make unilaterally.

**Where spec §2 stands now:** `skillLevel`/`categoryDistribution` (fully
observed, now also fully wired into real decisions via W25) and
`statedPreferences` (observed as of W26, not yet wired into decisions).
Only `habits` remains genuinely unbuildable — it needs a repeatable
read-only action (an export) that doesn't exist in the app yet, matching
the spec's own original note.
