# Step 1 (self-healing) — gap analysis: prototype vs. full scope

Compares what `orchestrator/src/*` actually implements (read in full:
`types.ts`, `index.ts`, `pipeline.ts`, `agent.ts`, `git.ts`, `pr.ts`,
`sources/manual.ts`, `sources/sentry.ts`, `README.md`) against Step 1's full
scope per the source doc's Product sequencing table ("One-click onboarding,
healing layer, release pipeline with canary and rollback, swarm as
regression tester, plain-language feed") plus the relevant System
architecture layers. Read-only research — no code changed.

## Component by component

| Component | Status | Grounded reason |
|---|---|---|
| Healing layer (reproduce → fix → verify) | **Built** | `agent.ts::runFixAgent` implements reproduce-first exactly per spec; `pipeline.ts` wires the full loop. Proven live in STAGE0.md (PR #1, PR #3). |
| Independent verifier | **Built** | `agent.ts::runVerifierAgent` runs in a fresh context, explicitly told to try to refute. STAGE0.md Run 1 shows it actually caught a hollow fix the fix-agent had falsely claimed success on. |
| Isolated workspace / never touch `main` | **Built** | `git.ts::cloneIsolatedWorkspace` + `createFixBranch` always branch off `origin/main`; `pr.ts` never merges, only opens a PR. |
| Prompt-injection defense on report content | **Built** | `agent.ts::untrustedReportBlock` delimits and neutralizes bug-report text as data, not instructions — matches the source doc's "data from tools is untrusted input" principle. |
| One-click onboarding | **Not started** | `index.ts::parseArgs` requires `--repo` plus either `--manual-report <file>` or `--sentry-org`/`--sentry-project` CLI flags. This is a developer CLI, not the ~5-minute "Connect with GitHub → confirm app profile → go live" flow the doc specifies for non-technical owners. |
| Release pipeline with canary + automatic rollback | **Not started** | `pr.ts::openFixPr` opens a GitHub PR and stops — a human must `gh pr merge` manually. No staged rollout to 1–5% of users, no guardrail-breach detection, no automatic rollback. Expense-buddy's own CI (`ci.yml` + `lint-diff.sh`) is a pre-merge verification gate, not a post-release canary. |
| Swarm as regression tester | **Not started — and a naming collision risk** | The source doc's swarm = persona/adversarial/accessibility AI agents that *complete tasks in the app* pre-release. What STAGE0.md calls "swarm" (Sentry error monitoring + session replay + feedback widget) is production *observability*, a completely different mechanism — it detects problems after real users hit them, it doesn't test changes before they ship. No task-completing swarm agents exist anywhere in this codebase. Worth flagging explicitly so this doesn't get conflated across sessions — same word, two different things in the two docs. |
| Plain-language feed | **Not started as persistent infra** | What exists today: per-run console output, an agent-written plain-language PR description, and STAGE0.md itself (a human-maintained narrative log). None of these is a system-generated, persistent, owner-facing feed the way the doc describes ("Fixed a checkout crash... Proposing a simplified import flow..."). |
| Event pipeline (usage data for later adaptation) | **Not started** | `.day2-processed.json` is only a dedup ledger of processed `sourceId`s — not behavioral/usage event data. Sentry gives error and session-replay data (STAGE0.md), but nothing captures the per-user usage events Step 2's per-user model will need. |
| Config plane | **Not started** | No config service exists. Nothing is toggleable at runtime (kill switch, autonomy level, rollout %) without a code change. |
| Governance: autonomy levels L0–L5 | **Not started as an explicit model** | The pipeline today behaves like a fixed point between the doc's L1 ("Suggest") and L2 ("Prepare") — it drafts and opens tested PRs but never ships without a human clicking merge. There's no per-area level setting, no way to dial it up, no formal audit trail beyond git/GitHub history plus `.day2-processed.json`. |
| Building block library | **Not started** | Not expected yet at Step 1 (it's core to Step 2), but the source doc lists it as one of the five things that should exist "from day one, even if only partly used" — noting its absence for completeness. |

## The single biggest gap vs. Step 1's exit criterion

Step 1 exits when **"paying customers keep automatic releases switched on."**
Today, nothing ships automatically at all — every fix, however small and
however confidently verified, still ends as a GitHub PR waiting for a human
to click merge. The pipeline never exceeds the doc's **L2 ("Prepare")**
autonomy level; it never reaches **L3 ("Act on low risk")**, which is the
level that actually ships low-risk fixes on its own. Without L3 autonomy
*plus* a canary/auto-rollback mechanism to make shipping-without-a-human
safe, "automatic releases" isn't a real customer-facing capability yet — the
current system is a well-verified PR-drafting assistant, not something a
non-technical owner can switch on and walk away from. Canary+rollback and an
explicit autonomy-level model are the two concrete pieces of infrastructure
standing between today's prototype and that exit criterion; everything else
(onboarding UI, plain-language feed, event pipeline) is real missing scope
but doesn't block the exit criterion the same way.
