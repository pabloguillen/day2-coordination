# W16 — swarm-based adaptive-vs-static comparison: results

> ## ⚠ CORRECTION (added after W16c) — every result below is void
>
> **All three rounds (W16, W16b, W16c) were comparing the deployed
> production app against itself.** The building blocks (W12/PR#17) and the
> composer (W14/PR#18) were merged to `main` on GitHub but **never actually
> deployed** — the last real production deployment was `day2 promote
> 67cf2c95` (W11), before either merge. Confirmed directly: the live
> bundle's `routes-*.js` contains W9's config-check-in code
> (`day2-config`/`day2-device-id`) but zero occurrences of `slotConfig` or
> `bulkActions` anywhere. The config plane was correctly storing whatever
> got seeded; nothing on the deployed frontend ever read it to change
> rendering. **None of the "no meaningful difference" or "personas don't
> use bulk actions" conclusions below are evidence of anything about
> adaptation or persona behavior — they're evidence that the code under
> test was identical in both conditions.** Left the original writeup below
> intact rather than deleting it, since the actual mistake (and how it
> surfaced) is itself worth keeping on the record. Real fix: deploy latest
> `main` to production, then rerun.


**What this is and isn't.** This is synthetic evidence toward the
retention-lift question that has blocked Step 2's formal validation since
Stage 0 (no real users available to run the manual-adaptation-with-holdout
test the roadmap actually calls for). It uses exactly the mechanism the
source doc proposes for apps without traffic yet: "A swarm of synthetic
users... solves the cold-start problem" and "swarm carries most decisions"
pre-launch. **It does not satisfy the letter of Stage 0's exit criterion** —
that specifically means real humans. It's real, decision-useful evidence on
the underlying question, generated the honest way: reported as-is, including
if the result is a non-finding.

## Method

Reused the real swarm v1 infrastructure (`orchestrator/src/swarm.ts`,
`runComparisonPersona`) — a real Claude Agent SDK + Playwright session per
run, against the actual live deployed app
(`https://pabloguillen-expense-buddy.pablo-guillen.workers.dev`), not a mock.

**Task** (identical across both conditions): add 6 new expenses across at
least 3 categories, review the spending summary, then find and delete the 3
oldest of the ones just added, and confirm the total updates correctly.

**Two conditions:**
- **Control** — a fresh, never-seen device ID each run. Gets the real
  default config on first check-in (guided form, card list, month/total
  summary) — today's actual behavior for every real device.
- **Treatment** — one device ID, pre-seeded directly in the real `DAY2_CONFIG`
  KV namespace with a genuinely different, internally-coherent "power user"
  profile: compact entry form, table-density list with bulk actions enabled,
  category-broken-down summary — using slot variants that exist in the
  building blocks (W12) and are servable by the composer (W14) but have
  never been served to anyone before this test.

Device identity was controlled via `page.addInitScript()` (not
`page.evaluate()` after load) to guarantee the device ID landed in
`localStorage` before the app's own hydration effect fired its config
check-in — verified this ordering matters by reading `day2-config.ts`'s
actual hydration-effect code before designing the test, not assumed.

3 independent runs per condition (6 total). Small N — this is directional,
not statistically powered, and said so throughout rather than only in a
caveats section at the end.

## Results

| Condition | Completed | Action counts | Mean actions |
|---|---|---|---|
| Control (static default) | 3/3 | 39, 51, 39 | 43.0 |
| Treatment (adaptive) | 3/3 | 40, 43, 39 | 40.7 |

**Task completion: identical, 100% both conditions (6/6 overall).**
**Action-count efficiency: no meaningful difference** — a ~2.3-action gap
against a control-group spread of 39–51 is well within the noise of a
3-run sample. This experiment did not detect an efficiency benefit from the
adaptive config, at this sample size, for this task.

## What the friction notes actually showed

Every run (both conditions) independently reported the same real, pre-existing
app bug: the list's "newest first" label doesn't reflect actual same-day
insertion order the way a user would expect, forcing the persona to read
live DOM order rather than trust the label. This is a genuine, unrelated
finding (present in both conditions, so it isn't an artifact of the
treatment config) — worth a `bun run fix` pass separately from this test's
own conclusions, same pattern as W15.

One control run also re-surfaced the already-known hover-dependent delete
button issue (invisible until row hover) — consistent with W13's earlier
finding, not new information, but independent corroboration.

## A real flaw in this experiment's own design

The task wording asked personas to delete the 3 oldest expenses "one at a
time" — meaning the treatment condition's `bulkActions: true` capability
(select-multiple + bulk delete) was **never actually exercised by either
condition**, despite being one of the more meaningful differences between
the two configs. This wasn't caught during design, only after the fact. It
means this run is a weaker test of the treatment config than intended — the
table/byCategory/compact differences were exercised, but the one feature
most likely to produce a real efficiency gap for a "power user cleaning up
old entries" task was not. A rerun with wording that actually invites bulk
selection (e.g. "select and remove the 3 oldest at once") would be a more
honest test of that specific capability.

## Honest interpretation

- **No signal, in either direction, at this N.** This doesn't mean adaptation
  doesn't help — it means this specific experiment (one task, one persona
  archetype, n=3 per arm) wasn't powered to detect anything short of a large
  effect, and didn't find one. A plausible reason: the task itself may not
  differentiate the two layouts enough — adding 6 expenses is nearly
  identical work under either config; only the review/delete portion (a
  minority of total actions) actually exercises the table vs. cards,
  byCategory vs. total differences.
- **Simulated users are not real users.** The source doc's own "Decision
  weight" section is explicit about this: synthetic users find *problems*
  well but predict *preferences* poorly (citing SimAB's 67% real-outcome
  match rate). This result should be read as "no problems found with the
  adaptive config, and no measured efficiency difference for this task" —
  not as evidence about real user *preference* or *retention*, which this
  method can't speak to.
- **What this genuinely does show:** the full adaptive pipeline — config
  seeding, device-scoped serving, and the composer actually rendering
  differently — works correctly end-to-end under real task-completion
  conditions, not just the earlier synthetic single-page checks (W14). That's
  a real, useful confirmation, distinct from the (null) efficiency result.

## What would actually move this forward

Per the source doc's own decision-weight guidance, swarm evidence is meant
to *filter*, not substitute for real users once any exist. A larger persona
set (more task types, more profile archetypes), more runs per condition, or
a task that exercises the review/delete path more heavily could sharpen this
— but the honest conclusion from this round is: build more evidence before
concluding adaptation helps, not "it doesn't," and not "it does." A cheap
next step: rerun this same design with 3 self-adapting task variations that spend
more of their action budget in the varied slots than in expense entry.

## Cleanup

All 4 test device IDs (1 treatment, 3 control) deleted from the real
`DAY2_CONFIG` KV namespace and individually confirmed via a follow-up
`wrangler kv key get` returning a real `404`, not assumed clean.

---

## W16b — rerun with the wording flaw fixed, and a new finding

User asked directly for a redesigned task that actually exercises the
bulk-action difference. Fixed the one variable: task no longer says "one at
a time" — it just says "find the 3 oldest expenses you just added and
remove them from the list," letting the interface and the persona's own
judgment determine the method. Everything else (conditions, device-ID
mechanics, metrics, the treatment config itself) held identical to W16 on
purpose. Script: `orchestrator/src/w16b-run-comparison.ts`. Run directly,
not delegated to a subagent, given W16's duplicate-concurrent-execution
anomaly — tighter supervision this round.

### Results

| Condition | Completed | Action counts | Mean actions |
|---|---|---|---|
| Control (static default) | 3/3 | 54, 51, 45 | 50.0 |
| Treatment (adaptive) | 3/3 | 51, 57, 55 | 54.3 |

**The fix didn't work as intended.** Removing the "one at a time"
constraint did not lead personas to discover or use the checkbox/bulk-select
affordance — none of the 6 friction reports mention selecting more than one
row or clicking "Delete selected"; all six read as individual-delete
workflows. Treatment's mean action count went *up* slightly relative to
control (54.3 vs. 50.0) rather than down — the opposite direction from W16's
original (noise-level) result, and still not attributable to bulk actions
since they weren't used either way.

**Honest read:** this still isn't a clean test of whether bulk actions
help — it's now evidence that *neutral* task wording alone doesn't cause a
task-completing LLM persona to spontaneously seek out a more efficient
interaction pattern it wasn't told about. That's a real, if different,
finding: these personas complete tasks as literally described rather than
optimizing for fewer actions, at least for this affordance and this task
phrasing. Testing whether bulk actions *help once used* would need wording
that explicitly asks for efficiency (e.g. "using as few interface actions
as you can") — a real design difference from either version run so far, not
attempted here without checking in given two imperfect designs in a row.

### A second issue surfaced, not fully explained

One control run's friction note reported "the test device already had 6
pre-existing expenses" before that run's own additions — unexpected, since
each control run uses a freshly generated device ID and the app has no
server-side expense storage (expenses live in each browser's own
`localStorage`, separate from the device-ID mechanism). This suggests browser-
profile isolation between persona runs may not be fully reliable in every
case (e.g. a shared default Chromium user-data directory across runs,
depending on how a given persona's self-written script launches the
browser) — noted honestly rather than ignored, since it's a real
reliability question for this test method that neither W16 nor W16b was
designed to catch. Not investigated further this round; worth knowing
before treating any single run's action count as fully independent.

### Cleanup

All 4 test device IDs (1 treatment, 3 control) deleted and individually
confirmed via follow-up `wrangler kv key get` returning `404`.

---

## W16d — the real test, against an actually-deployed composer

Root cause of the correction above: `main` was current but production
wasn't. That's now fixed (a separate session deployed `main`, promoted to
100% after one earlier attempt auto-rolled-back on a different, unrelated
error). Verified independently before spending any agent budget: fetched
the live `routes-*.js` bundle directly and confirmed `bulkActions` is
present (42KB vs. the pre-fix bundle's 9KB); called the real
`/api/day2-config` endpoint via `curl` for the seeded treatment device and
confirmed it returns the treatment config, not a default. Same task
wording as W16c (explicit efficiency-seeking) — that design was sound, only
the deployment was broken.

### Results

| Condition | Actions | Mean |
|---|---|---|
| Control (static default) | 45, 45, 51 | 47.0 |
| Treatment (adaptive) | 46, 52, 46 | 48.0 |

### This time it's a real finding

**Control personas correctly determined bulk delete wasn't available to
them** — two of three explicitly report reading the JS bundle and querying
`/api/day2-config` themselves to confirm `bulkActions: false` for their
device before falling back to individual deletes. That's the composer
working correctly for the default case, now genuinely observed, not
assumed.

**Treatment personas discovered and used the real bulk-delete affordance.**
Two of three friction reports explicitly describe finding the checkbox +
"Delete selected" control and using it to remove all 3 entries "in one
click instead of three." The third reported no friction without describing
its method, so it's not confirmed either way.

**And yet, action counts came out essentially even (47.0 vs. 48.0) — bulk
delete, used correctly, did not reduce the total actions needed for this
task.** The reason is visible in the UI's own design, not a persona
limitation: bulk delete here means checking a box on each of the 3 rows
(one action per item — the same cost as 3 individual delete-button clicks)
*plus* one extra click to confirm ("Delete selected"). For a 3-item
deletion, that's 4 actions via the bulk path vs. 3 via individual deletes —
worse, not better. The bulk mechanism would very plausibly show a real
efficiency win at larger N (its per-item cost stays the same, but the
one-time confirm cost gets amortized), but this experiment's task (3 items)
never tested that regime.

### What this actually establishes

- The full adaptive pipeline is real and correct end to end: config
  seeding → device-scoped serving → composer rendering → feature
  discoverable and usable by a real user (simulated), confirmed live in
  production, not locally.
- The specific feature tested (bulk delete via checkbox-select) doesn't
  help at this task's scale, by design of the UI, not by any fault in the
  adaptive mechanism. That's a real, actionable product finding, separate
  from the retention-lift question this whole line of testing was meant to
  inform.
- The retention-lift question itself is still unanswered — this establishes
  the machinery works and gives one concrete (negative, at this N) data
  point on one feature's efficiency, not evidence about user preference or
  retention, which — per the source doc's own caution about simulated
  users — this method was never suited to answer.

### Cleanup

All 4 test device IDs (1 treatment, 3 control) deleted from `DAY2_CONFIG`
KV, individually confirmed via follow-up `404`s.
