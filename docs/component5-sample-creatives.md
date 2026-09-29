# Component 5 sample creatives (real, live-generated)

Real output from `orchestrator/src/growth-creative.ts`'s `generateCreatives`, called live against expense-buddy's actual scanned app profile (`docs/expense-buddy-app-profile.md`) and the real deployed app at `https://pabloguillen-expense-buddy.pablo-guillen.workers.dev`. Requested by the user after Component 5's live-validation was reported in `COORDINATION.md` W42 — this file exists so the generated content itself (not just my summary of it) is reviewable and persisted, since nothing in the codebase writes generated creatives to disk yet (that's Component 6's transparency feed, still in progress by another session as of this writing).

Not committed as "final" copy for any real campaign — this is sample output demonstrating the pipeline works, generated during a chat session on 2026-09-29. Real money/real publishing are still withheld per this whole stage's load-bearing constraint (`STAGE4.md`'s scope note).

## Text creative, `channel: social_content`, `formatTag: show-content-run`

**Variant 1**
- Headline: *You don't need a finance app. You need five seconds.*
- Body: Add an expense. Amount, category, date. Done. Everyday shows your running total for the week or month — no spreadsheets, no dashboards, no noise. Just a quiet, simple way to see where your money's going.
- Claims checked: add an expense with amount/category/date; instantly see running total for the week/month; quiet, simple, minimal tracking experience.
- Cost: $0.0074

**Variant 2**
- Headline: *Set a budget. Watch the bar move as you spend.*
- Body: Every expense you log updates a simple progress bar against your budget target for the week or month. Tap in for a per-category breakdown when you want more detail — or don't. It's there when you need it, quiet when you don't.
- Claims checked: running total with progress bar vs. budget target; optional per-category breakdown view; logging an expense updates the total/progress bar.
- Cost: $0.0074

**Variant 3**
- Headline: *Your spending, your device — nobody else's.*
- Body: Everyday saves everything right in your browser. No sign-up, no server, no account to lose or forget. Just open it, log an expense, and see your totals. Simple, and yours.
- Claims checked: all data persists locally in the browser (localStorage); no login/server account required; add an expense; see running spend totals.
- Cost: $0.0074

## UGC-format video creative, `channel: social_content`, `videoFormat: ugc`, `formatTag: show-content-ugc`

**Headline:** *The 2-minute Sunday habit that keeps my spending honest*

**Video style:** Authentic, lightly-produced UGC selfie-video aesthetic mixed with clean screen recordings; natural lighting, handheld camera feel, minimal editing, brand color accents only in on-screen text and end card.

**Script/storyboard** (no `videoAssetRef` — no real video-generation tool was connected, per Component 4's `.day2-platform-tools.json` shipping empty; this is the plan's own specified fallback, a real script instead of a fabricated asset reference):

> [Stylized, dramatized UGC-style video — actor performance, not a real customer testimonial]
>
> Format: Vertical 9:16, handheld selfie-style + screen recording cutaways, 25–30 sec.
>
> **SHOT 1 (0:00–0:04)** — Talking head, natural light, kitchen counter, coffee mug in frame.
> On-screen text: "my sunday routine"
> VO: "Okay so every Sunday I do this one thing before my week starts—"
>
> **SHOT 2 (0:04–0:10)** — Cut to screen recording: phone opens Everyday app, home screen with progress bar showing month spend vs budget target.
> VO: "I open my expense tracker and just... look. No login, no setup, it's all just sitting there on my phone."
> On-screen text: "local only — no account needed"
>
> **SHOT 3 (0:10–0:16)** — Screen recording: scrolling the recent expenses list, grouped by day, categories visible (coffee, groceries, transport).
> VO: "It groups everything by day and category, so I can see exactly where last week's money went."
>
> **SHOT 4 (0:16–0:22)** — Screen recording: tapping 'add expense,' entering amount, picking a category, adding a quick note, date auto-filled.
> VO: "Logging something new takes like five seconds. Amount, category, done."
> On-screen text: "amount → category → done"
>
> **SHOT 5 (0:22–0:28)** — Back to talking head, holding phone, relaxed smile.
> VO: "It's not trying to lecture me about money. It just shows me the number, against my budget, and lets me decide."
> On-screen text: "quiet. simple. yours."
>
> **SHOT 6 (0:28–0:30)** — Static end card: app name/logo, calm dark teal background (`oklch(0.28 0.035 230)`), soft accent line (`oklch(0.52 0.07 180)`).
> On-screen text: "Everyday — track it your way"

Note the agent's own opening bracketed disclosure (`[Stylized, dramatized UGC-style video...]`) — added unprompted, beyond the literal safety-rail-8 instruction it was given, and the real color values pulled directly from the app's actual style guide rather than invented.

## How to reproduce

```ts
import { generateCreatives } from "orchestrator/src/growth-creative";

const result = await generateCreatives(
  "https://pabloguillen-expense-buddy.pablo-guillen.workers.dev",
  appProfile,   // real AppProfile — see docs/expense-buddy-app-profile.md for the source data
  { channel: "social_content", assetType: "text", formatTag: "my-run" },
  "budget-conscious-new-users",
);
```

Every call is a fresh, real (small-cost) agent invocation — output will differ run to run, same as any live LLM call. See `orchestrator/src/growth-creative.test.ts` for the deterministic, parser-level test suite that doesn't require a real agent call.
