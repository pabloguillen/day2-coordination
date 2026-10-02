# App profile

**What it does:** Everyday is a simple personal expense tracker: users log an expense's amount, category, and date, and instantly see their total spent this week or month, optionally against a budget target — all solving the problem of quick, low-friction day-to-day spending awareness.
**Who it's for:** Individuals who want a 'quiet, simple' way to track their own everyday personal spending on one device, per the app's own tagline and description copy, rather than teams, businesses, or accountants.

## Main features
- Add an expense with amount, optional note, category (Groceries, Coffee, Dining out, Transit, Health, Books, Home, Fun, Other), and date
- View a running total spent this month or week, with a progress bar and percentage against a configurable budget target
- Optional per-category spend breakdown view
- Recent expenses list (card view or table view), with day/category grouping options and single or bulk delete
- All data persists locally in the browser (localStorage) — no login or server account
- 404 and error boundary pages with friendly recovery actions ('Try again' / 'Go home')

## Style
Tailwind CSS v4 with shadcn/ui-style Radix UI components; Newsreader (display serif), Inter (sans), JetBrains Mono (mono) fonts; glassmorphism 'glass-panel' utility, colors: oklch(0.28 0.035 230) ink, oklch(0.52 0.07 180) sky/primary, oklch(0.87 0.015 220) line, oklch(0.91 0.02 180) wash, oklch(0.93 0.012 220) canvas, oklch(0.95 0.01 220) canvas-2, oklch(0.73 0.02 220) ghost, oklch(0.577 0.245 27.325) destructive

## Tone of voice
Calm, minimal, and quietly confident — short declarative UI copy like 'A quiet, simple expense tracker', 'Add an expense', 'saved on this device', and 'No expenses yet — add your first one on the left'.

## Business model
No payment/pricing code found.

## Competitors
Not scanned — needs live web/store search, out of scope for this pass.

## Current state
0 unresolved error(s) in Sentry.

## Notes
- No payment, billing, subscription, or pricing code or copy was found anywhere in the app (searched for stripe/billing/subscription/price/checkout/payment/plan), so businessModel is null — this appears to be a free, local-only tool as currently built.
- No project-root README was found (only a routing-conventions note under src/routes/), so purpose/targetUsers are drawn from route <head> meta/description tags and on-page copy rather than authored documentation.
- **Correction (2026-10-03):** the line below was wrong by the day after it was written, and a fresh automated re-scan (via `onboarding-rescan-cli.ts`, 2026-10-02) *still* didn't catch the correction — it hedged the config-plane as "unverified... internal infrastructure" rather than confirming it's live. Checked directly against the code instead: `routes/index.tsx` calls `checkInWithConfigPlane()` and merges the real per-device slot config into all three building blocks (`ExpenseEntryForm`, `SpendSummaryCard`, `ExpenseList`) on every page load, and `server.ts::decideSlotConfig` has returned `density: "byCategory"` for any non-novice user with 2+ categories since PR #31 (merged 2026-09-27, one day after the scan below). The per-device adaptive UI (day2 Step 2) is a real, live, currently-visible feature, not latent infrastructure. `ACTIVE_EXPERIMENTS` is still a hardcoded empty array, though, so there is no running experiment behind it yet — every device gets the same rule-based config, just not the same *fixed* one.
- ~~There is unwired infrastructure (a 'config-plane' check-in, per-device building-block config overrides, and an event-recording pipeline) that could let the app vary its UI or track usage per device in the future, but today it always resolves to the same fixed defaults shown to every user — this is a caveat about future/latent behavior, not a currently visible feature.~~ (false since 2026-09-27 — see correction above)
- Styled colors were read directly from an explicit CSS custom-properties theme file (src/styles.css), not inferred from a generic Tailwind default config, so confidence in styleGuide is high, but no separate 'brand kit' or design-tokens file beyond this CSS was found.

_Scanned 2026-09-26T10:51:49.007Z. Correct anything wrong before going live._
_Re-scanned 2026-10-02T22:04:54.685Z via onboarding-rescan-cli — no prior stored `.day2-app-profile.json` existed in expense-buddy to diff against, so this landed as a first-ever `.day2-app-profile.pending.json`, awaiting a human's review/promotion there; not auto-merged into this doc._
