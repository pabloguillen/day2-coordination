# Step 2 (self-adapting) — architecture spec, grounded in expense-buddy

Design/prep only — no implementation. See `STAGE2.md` / `COORDINATION.md` for
why this is scoped as design-ahead-of-the-gate rather than a build.

Reference app: `expense-buddy` (`/Users/pabloguillen/expense-buddy`). The
entire UI is one file, `src/routes/index.tsx` (328 lines) — a single-page,
client-only React app (TanStack Router, shadcn/ui primitives in
`src/components/ui/`), no backend, no auth, state persisted to
`localStorage` under `everyday-expenses`. This matters throughout: expense-
buddy has no account system, so "per-user" below means per-*device*, not
per-authenticated-identity, until/unless that changes.

## 1. Adaptive slots

Candidate slots, named against the actual component tree in
`src/routes/index.tsx`:

| Slot | Current implementation | What varies |
|---|---|---|
| `AddExpenseForm` (lines 214–278) | Fixed 4-field form: amount, note, category select, date | Field order/visibility, default category (most-used vs. alphabetical-first), guided hint text vs. dense no-hint layout, keyboard-shortcut entry for power users |
| `SpendSummaryCard` (192–212) | Fixed: month total, budget-bar vs. hardcoded $2,000 | Budget source (hardcoded vs. user-set), period (monthly vs. weekly), density (single number vs. category breakdown) |
| `ExpenseList` (281–323) | Fixed: card-style list, newest first, hover-to-delete | Density (`cards` vs. dense table), bulk actions (select+delete, matches the source doc's "Ben, accountant... bulk editing by his second session"), grouping (by day/category) |
| `WeeklyReportSlot` (does not exist yet) | — | The source doc's own worked example: "Chloe... exports the same report three Fridays in a row. On the fourth, the app offers a one-tap weekly report." This is a genuinely new slot, not a variant of an existing one — first thing to prototype since it's spec'd almost verbatim in the source doc. |

Composer sits above these four and assembles per-user layout from verified
variants only — matches the source doc's "generative surface... combines
verified parts under rules."

## 2. Per-user model

Fields, scoped to what this specific app can actually observe:

| Field | Derived from | Notes |
|---|---|---|
| Skill level | Session count, time-to-submit on `AddExpenseForm`, whether note/date are ever edited from defaults | Novice → guided default; source doc's Ben case ("onboarding is skipped by his second session") implies a 2-session threshold, not a single heuristic score |
| Primary goal | Category distribution, proximity to budget-bar % | e.g. "stay under budget" (frequently near 100%) vs. "just logging" (rarely checks summary) |
| Habits | Repeated identical read-only actions across sessions (the Chloe pattern: same export/view N Fridays running) | This is the one field the current app can't observe at all yet — there is no "export" action to repeat; it doesn't exist until built |
| Stated preferences | Explicit answer to an "Ask a question" card (Apply/Undo/Ask pattern, source doc p.16) | The only field that isn't inferred — needs the config-plane UI to exist first |

**Explicitly excluded** per the source doc's discrimination/privacy
guardrail: age, gender, ethnicity, or any other protected attribute — not
collected today either way, since there's no account system to attach them
to.

**Identity resolution strategy — resolved (2026-09-25):** the identity the
per-user model keys off depends on what the app already has, decided per-app
at onboarding time, not fixed platform-wide:

- **App has existing auth/user accounts.** The runtime never stores or
  reasons about the app's real user identifiers directly. It derives an
  opaque anonymous ID from the app's own identity (e.g. a one-way hash/HMAC
  of the app's user ID under a runtime-held key, or a runtime-generated UUID
  the runtime maps internally to that user) and keys the per-user model to
  *that*. Day2 itself only ever sees the anonymous ID — matches the source
  doc's processor/controller split (p.13): the app owner controls real
  identity, the runtime only ever touches an anonymized derivative of it.
- **App has no auth/user system (expense-buddy today).** Falls back to a
  device-keyed profile: an anonymous ID generated once and stored alongside
  the app's existing `localStorage` data. The known limitation stands and is
  not hidden: this profile resets silently on storage clear or device
  switch, and a shared device/browser means a shared profile. Acceptable as
  a stated limitation for apps in this category, not a blocker.

**Detection mechanism:** this slots into onboarding's existing "automatic
app understanding" scan (source doc p.15, already scans routes/components/
schema) — detecting a login route, session/JWT handling, or a `users`-shaped
table in the schema is the same kind of static scan already planned, not new
onboarding scope.

**Left open, not urgent:** the migration case — an app that starts with no
auth (device-keyed) and adds accounts later. Whether/how a device-keyed
profile gets carried forward into the new anonymized-account-keyed one on
first login isn't addressed here; revisit if/when a Step 2 pilot app is
actually in that situation.

## 3. Building block registry — first 2–3 candidates

| Block | Typed contract (sketch) | Tests | Accessibility |
|---|---|---|---|
| `ExpenseEntryForm` | `{ fields: FieldConfig[]; defaultCategory: string; layout: 'guided' \| 'compact' }` | Fills + submits via keyboard only; rejects invalid amount; respects `defaultCategory` | Label/input association, visible focus order, error text tied to field via `aria-describedby` |
| `SpendSummaryCard` | `{ period: 'week' \| 'month'; budgetTarget: number \| null; density: 'total' \| 'byCategory' }` | Renders correctly with zero expenses, with budget unset, with overspend | Progress bar has accessible name + value text, not color-only |
| `ExpenseList` | `{ density: 'cards' \| 'table'; bulkActions: boolean; groupBy: 'none' \| 'day' \| 'category' }` | Bulk-select + delete round-trips correctly against `localStorage`; empty state renders | Table variant has real `<table>` semantics, not divs; delete button has accessible name per row (already true today — `aria-label` exists) |

Each enters the registry only after passing this pipeline — matches the
source doc's "verified components... enter the library only after passing
the verification pipeline."

## 4. Config plane

expense-buddy is deployed static (Cloudflare Workers, no backend today).
"No release, no commit, no app store update" per-user slot serving therefore
needs a genuinely new piece of infrastructure that doesn't exist in
`orchestrator/` at all: a small config-read endpoint (Workers KV is the
natural fit given the existing Cloudflare deployment) that the SDK calls on
load, keyed by a device-scoped anonymous ID, returning today's slot
assignment as data. Nothing here touches the app's shipped code or its
git history — matches "most evolution never touches the repo."

## 5. Deferred to Step 3 (self-evolving) — explicitly out of scope here

- Generating genuinely new features/flows (Step 2 only composes and selects
  among *existing verified* blocks — it doesn't invent new ones).
- Competitor-informed feature proposals.
- Statistical A/B experiments with real cohorts at scale — Step 2 launch
  stage uses "rules and swarm-based defaults for a few archetypes" per the
  source doc's App stages table, not live experimentation.

## 6. What this needs from Step 1 (not built yet)

Checked against `orchestrator/src/` (agent.ts, git.ts, index.ts, pipeline.ts,
pr.ts, sources/, types.ts) — none of this exists yet:

- **Event pipeline.** Nothing currently records product-usage events (which
  slot rendered, which field a user edited, session cadence). Sentry
  (`src/lib/sentry.ts`) captures errors and session replay only, not
  structured usage events the per-user model needs.
- **Config plane infrastructure.** The orchestrator only ever produces git
  PRs (`src/pr.ts`) — there is no live, no-deploy config-serving path at all.
- **Plain-language feed / autonomy dial.** No owner-facing UI exists for
  approving or reviewing adaptations (Apply/Undo/Ask).
- **Swarm v1.** No persona/adversarial/accessibility agents exist yet;
  Step 2's launch-stage defaults ("rules and swarm-based defaults for a few
  archetypes") have no swarm to draw on.

This is the concrete blocker list for "when can Step 2 actually start
building" — see the companion gap analysis (W2) for how far Step 1 itself
is from covering these.
