# AI Toolkit — Idea → Ship

This is the single index of every agent skill, subagent, and helper in Keyoku. It lists what
each tool does, when to reach for it, and how the tools chain from a raw idea to an App Store build.

> **Keep this doc current.** When you add, remove, or update a skill or agent, update this file in
> the same change. `./scripts/sync-ai-toolkit.sh --check` fails if an installed skill or agent is missing here.

---

## 1. What's installed and where

| Source | Author | How it's installed | Location |
| --- | --- | --- | --- |
| [mattpocock/skills](https://github.com/mattpocock/skills) | Matt Pocock | Vendored skills (`npx skills`) | `.claude/skills/` |
| [pstack](https://github.com/michael-denyer/pstack-claude) (Claude Code port of [Lauren Tan's pstack](https://github.com/cursor/plugins/tree/main/pstack)) | Lauren Tan (poteto) | Claude Code **plugin**, declared in `.claude/settings.json` | Installed on first trust prompt; skills are namespaced `pstack:*` |
| [SwiftUI](https://github.com/twostraws/SwiftUI-Agent-Skill) / [SwiftData](https://github.com/twostraws/SwiftData-Agent-Skill) / [Concurrency](https://github.com/twostraws/Swift-Concurrency-Agent-Skill) / [Testing](https://github.com/twostraws/Swift-Testing-Agent-Skill) Pro | Paul Hudson | Vendored skills | `.claude/skills/` |
| [kun](https://github.com/kunchenguid/kun), [lavish-axi](https://github.com/kunchenguid/lavish-axi), [vision](https://github.com/kunchenguid/vision), [no-mistakes](https://github.com/kunchenguid/no-mistakes) | Kun Chen | Vendored skills | `.claude/skills/` (`no-mistakes` and `wizard` are symlinks into `.agents/skills/`) |
| [firstmate](https://github.com/kunchenguid/firstmate) | Kun Chen | **Separate repo** (an "agent distro", not a skill) | `../firstmate` |
| Swift Concurrency / SwiftUI Expert reference skills | Antoine van der Lee | Reference docs (not slash commands) | `.claude/docs/swift-concurrency/`, `.claude/docs/swiftui-expert-skill/` |
| Project skills (`/subgo`, `/preship`, …) | This project | Hand-written | `.claude/skills/` |
| Project agents (`ios-reviewer`, `designer-reviewer`, `pm-reviewer`) | This project | Hand-written | `.claude/agents/` |
| Project playbook (`ios-feature`) | This project | Extends pstack's Feature playbook with the VIPER rules | `.agents/playbooks/` |
| Architecture & ACTION docs | This project | Referenced from `CLAUDE.md` | `.claude/docs/` |

`skills-lock.json` pins the source of every vendored skill so they can be restored or updated.
The vendored set was copied from `../MVVMStarterProject`.

### Why some skills were left out

- **MVVMStarterProject** — `add-ab-test`, the `screen-builder` agent and the `swift-reviewer` agent
  are written for that template's MVVM layout. Here, screens come from the VIPER templates
  (`.claude/docs/action-create-screen.md`) and `ios-reviewer` applies Paul Hudson's checklists.
- **Matt Pocock** — `migrate-to-shoehorn`, `setup-ts-deep-modules`, `scaffold-exercises`, and
  `setup-pre-commit` are TypeScript/JS-only. Add any back with `npx skills add mattpocock/skills -s <name> -a claude-code -y`.
- **pstack** — `typescript-best-practices` comes with the plugin but only triggers on `.ts` files.

### Name overlaps to know about

| You type | You get | The other one |
| --- | --- | --- |
| `/tdd` | Matt's red-green-refactor loop | `/pstack:tdd` — only when a cheap local test target exists |
| `/teach` | Matt's teaching session inside this workspace | `/pstack:teach` — explains a body of work using `how` + `why` |
| `/code-review` | Matt's Standards + Spec review against a fixed point | Claude Code's built-in code-review; the project skill takes precedence |
| `swift-concurrency-pro` | Paul Hudson's concurrency review checklist (auto-loads) | `.claude/docs/swift-concurrency/` — Antoine van der Lee's deeper reference; point Claude at it for migrations |
| `swiftui-pro` | Paul Hudson's SwiftUI review checklist (auto-loads) | `.claude/docs/swiftui-expert-skill/` — Antoine van der Lee's reference, incl. Liquid Glass |

---

## 2. One-time setup per machine

| Need | Command | Used by |
| --- | --- | --- |
| Node 22+ | `brew install node` | `npx skills`, `kun`, `lavish` |
| GitHub CLI | `brew install gh && gh auth login` | `to-spec`, `to-tickets`, `triage`, `pr`, `/respond`, `/sprint`, pstack PR skills, firstmate |
| no-mistakes CLI | `curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh \| sh` | `/no-mistakes` |
| lavish-axi | Nothing — runs through `npx -y lavish-axi` | `/lavish`, `/vision` |
| firstmate | `git clone https://github.com/kunchenguid/firstmate ../firstmate` | Parallel crews (§6) |
| Xcode templates | [SwiftfulThinking/XcodeTemplates](https://github.com/SwiftfulThinking/XcodeTemplates) | ACTION 1, 3, 4 docs |

## 3. One-time setup for this repo

1. Restart Claude in the repo and accept the **trust prompt**. Claude Code then offers to install
   the `pstack` plugin from `.claude/settings.json`. Accept it.
2. `/setup-matt-pocock-skills` — sets the issue tracker (GitHub Issues or local files), the triage
   labels, and the domain docs layout (`GLOSSARY.md`, ADRs) that the engineering skills use.
3. `no-mistakes init` — wires the push gate for this repo.
4. Optional: `/pstack:setup-pstack` (models and reasoning effort per role),
   `/git-guardrails-claude-code` (hooks that block `push --force`, `reset --hard`, and similar).
5. Optional: `/pstack:create-verification-skill` — generates a project skill that drives the app
   in the simulator the way a user would, so agents can prove their changes work.

---

## 4. Daily workflow: idea → ship

Start here. Sections 5–7 are reference.

**Lavish** (the 🎨 lines below) isn't a stage. It's a visual review loop you can use at any stage:
Claude writes an HTML page (plan, comparison, diagram, code walkthrough) into `.lavish/` and opens
it in your browser; you comment and hit **Send**; Claude revises until you **Send & End**.

```
Idea → Shape → Tickets → Build (pick a lane) → Verify → /no-mistakes (push + PR) → Merge → TestFlight / App Store → Retro
```

### 4.1 Shape the idea

- `/grill-with-docs` — Claude questions each assumption and records decisions as ADRs and glossary terms.
- `/decide` — a single technical or product decision, weighed by the iOS and PM reviewers in parallel.
- Optional: `/prototype` for the riskiest screen or state model (throwaway code), `/research` for
  facts such as StoreKit limits, `/vision` to draft and stress-test `VISION.md`.
- 🎨 **Lavish:** "put the options in lavish" for any decision with real alternatives.

### 4.2 Plan: turn the idea into tickets

- `/to-spec` turns what you decided into a spec issue.
- `/to-tickets` splits the spec into small tickets that each ship on their own, with dependency edges.
- `/sprint` breaks work into tasks and launches subagents that each open a GitHub PR.
- Too big for one session? `/wayfinder` maps the work as decision tickets.
- 🎨 **Lavish:** "show the ticket plan in lavish before publishing".

### 4.3 Build: pick a lane per ticket

| Lane | When | How |
| --- | --- | --- |
| **A. You + Claude** | One ticket, or work that must happen in order | `/implement #12` in your main session |
| **B. Subagents in worktrees** | 2–3 independent tickets | "Implement #12 and #13 in parallel, each in its own worktree." Or `/sprint`. |
| **C. firstmate** | Several independent tickets, longer work, finished PRs back | `cd ../firstmate && claude` → "ahoy! work issues #12–#16 on Keyoku." See §6. |

In every lane:

- **New screen / manager / model / component:** "create new screen …" etc. triggers the ACTION docs in `.claude/docs/`, which use the Xcode VIPER templates.
- **Test-first:** `/tdd`, following `.claude/docs/testing-guide.md`.
- **Paul Hudson's skills** (`swiftui-pro`, `swift-concurrency-pro`, `swift-testing-pro`, `swiftdata-pro`) load automatically when relevant.
- **Hands-off:** `/pstack:poteto-mode <goal>` picks the playbook and verifies its own work. For features it applies `.agents/playbooks/ios-feature.md`, which keeps the VIPER layering, verifies with the Mock scheme and SwiftLint, runs `ios-reviewer`, and ships through `/no-mistakes`.

### 4.4 Verify: before anything is pushed

1. **Tests:** run the `Keyoku - Mock` scheme (⌘U, or ask Claude to run the tests).
2. **`/subgo`:** runs `ios-reviewer`, `designer-reviewer` and `pm-reviewer` in parallel on recent changes.
3. **`/code-review`:** checks the code against both your standards and what the ticket asked for.
4. **`/perf <screen>`:** SwiftUI performance audit for a screen you touched.
5. **Risky change?** `/pstack:blast-radius` finds what else it could break.
6. **Something broken?** `/diagnosing-bugs`.

### 4.5 Push and open the PR

`/no-mistakes` is the one ship command. It reviews, tests, lints and checks docs, then pushes,
opens the PR and watches CI. After that:

- `/respond <PR>` or `/pstack:babysit` handles review comments and CI failures.
- `/pr` or `/pstack:make-pr-easy-to-review` polishes the PR body.

### 4.6 Ship to the App Store

1. `/preship` — the full pre-ship gate before a TestFlight or App Store submission.
2. `/changelog` and `/appstore` — release notes and App Store "What's New" copy from commits.
3. `/wizard` for steps only you can do (App Store Connect, certificates, RevenueCat/Firebase dashboards).
4. Upload via fastlane or Xcode → Archive → TestFlight. See `TestFlight_Checklist.md`.

### 4.7 Learn from it

- `/retro` after a milestone, `/pstack:reflect` to turn lessons into skill edits, `/handoff` before switching contexts.
- `/audit` periodically for force unwraps, missing analytics, TODOs and VIPER violations.

---

## 5. Skill reference by stage

If you're unsure which skill fits, ask `/ask-matt` (Matt's skills) or `/pstack:poteto-help` (pstack).

### Stage 1 — Shape the idea

| Skill | Use it when |
| --- | --- |
| `/vision` | Draft `VISION.md`, stress-test it, iterate on a Lavish review board. |
| `/grill-me` | Relentless interview to find the holes in a rough plan. |
| `/grill-with-docs` | Same interview, but records ADRs and glossary terms as it goes. |
| `grilling` | The interview engine the two grill skills share. Triggers on "grill me…". |
| `domain-modeling` | Build and sharpen `GLOSSARY.md` and ADRs. |
| `/decide` | Evaluate one decision with the iOS and PM reviewers in parallel. |
| `/research` | Facts from primary sources (Apple docs, API limits). Writes a Markdown file. |
| `/to-questionnaire` | A decision needs someone else's input. |
| `/kun` | Kun Chen's principal-engineer take on a problem. |
| `/lavish` | Any plan, comparison or diagram that's easier to review visually. |

### Stage 2 — Explore the design

| Skill | Use it when |
| --- | --- |
| `/prototype` | Check whether a state model or UI feels right. Throwaway code on purpose. |
| `/pstack:arena` | Run N candidate designs and graft the best parts together. |
| `/pstack:architect` | Sketch types, signatures and module boundaries before writing code. |
| `codebase-design` | Vocabulary for deep modules and seams, e.g. designing a Manager interface. |
| `/pstack:how`, `/pstack:why` | How does X work / why does it work this way? |

### Stage 3 — Plan the work

| Skill | Use it when |
| --- | --- |
| `/to-spec` | Turn the conversation into a spec on the issue tracker. |
| `/to-tickets` | Break a spec into tracer-bullet tickets with blocking edges. |
| `/sprint` | Break work into tasks and launch subagents, one PR each. |
| `/wayfinder` | Work too big for one session; resolve decision tickets one at a time. |
| `/triage` | Move incoming issues/PRs through triage states with agent-ready briefs. |

### Stage 4 — Build

| Tool | Use it when |
| --- | --- |
| `/implement` | Build from a spec or a set of tickets. |
| `/implement-spec` | Build directly from `/to-spec` + `/to-tickets` output. |
| ACTION docs | "create new screen/component/manager/model" — VIPER templates, see `CLAUDE.md`. |
| `swiftui-pro` | Auto-loads when writing SwiftUI. |
| `swiftdata-pro` | Auto-loads for `@Model`, `@Query`, `ModelContainer` work. |
| `swift-concurrency-pro` | Auto-loads for async/await, actors, `Sendable`, `@MainActor`. |
| `/pstack:poteto-mode` | Hands-off: give it a goal; it plans, delegates and verifies. |
| `/chief-of-staff` | A long-running goal in one session that coordinates subagents. |
| `/pstack:swarm` | Fan out N parallel workers and get one report. |
| `/wizard` | Generate an interactive bash walkthrough for steps only you can do. |

### Stage 5 — Verify & debug

| Skill | Use it when |
| --- | --- |
| `/tdd` | Build a feature or fix test-first. |
| `swift-testing-pro` | Auto-loads when writing tests (`@Test`, `#expect`). |
| `/diagnosing-bugs` | Something is broken, throwing, flaky or slow. |
| `/perf` | SwiftUI performance audit of one screen. |
| `/pstack:blast-radius` | What else could this change break? |

### Stage 6 — Review & harden

| Tool | Use it when |
| --- | --- |
| `ios-reviewer` (agent) | Architecture, VIPER rules, concurrency and Paul Hudson's checklists. |
| `designer-reviewer` (agent) | UX quality, visual consistency, accessibility, iOS conventions. |
| `pm-reviewer` (agent) | Completeness, edge cases, analytics instrumentation, production risk. |
| `/subgo` | Run all three reviewer agents in parallel on recent changes. |
| `/code-review` | Review a branch against repo standards *and* the originating spec. |
| `/audit` | Codebase-wide tech-debt scan. |
| `/improve-codebase-architecture` | Find deepening opportunities; HTML report. |
| `/pstack:interrogate`, `/pstack:thermo-nuclear-code-quality-review` | Adversarial / very strict reviews. |
| `/pstack:deslop`, `/pstack:correct` | Strip AI slop; turn a repeated mistake into a lint/test. |

### Stage 7 — Ship

| Skill | Use it when |
| --- | --- |
| `/no-mistakes` | Gate a push: review, tests, lint, docs, push, PR, CI. **Default ship path.** |
| `/pr` | Write a PR body. |
| `/respond` | Fetch PR review comments, fix, push and reply. |
| `/pstack:babysit` | Watch an open PR and drive it to mergeable. |
| `/preship` | Full pre-ship gate before TestFlight / App Store. |
| `/changelog` | User-facing release notes from commits. |
| `/appstore` | App Store "What's New" copy from commits. |

### Stage 8 — Learn & hand off

| Skill | Use it when |
| --- | --- |
| `/retro` | Retrospective on a session. |
| `/pstack:reflect` | Turn lessons from this transcript into skill edits. |
| `/handoff` | Compact the conversation into a document another agent can pick up. |
| `/claude-handoff` | Hand off to a fresh background agent that keeps working. |
| `/pstack:recall`, `/pstack:what-did-i-get-done` | Rebuild context; summarize recent commits. |

### Anytime helpers

| Skill | Use it when |
| --- | --- |
| `/ask-matt`, `/pstack:poteto-help` | Which skill fits this? |
| `/wait-what`, `/pstack:bro` | The last answer didn't land; re-pitch it plainly. |
| `/teach` | Learn a concept inside this workspace. |
| `/loop-me` | Grill you about a workflow you want to automate. |
| `/git-guardrails-claude-code` | Hooks that block destructive git commands. |
| `/setup-matt-pocock-skills` | (Re)configure tracker, labels and docs layout for Matt's skills. |
| `/writing-for-agents` | Editing `CLAUDE.md`, an agent, or a skill. |
| `/writing-fragments` → `/writing-shape` → `/writing-beats` | Matt's writing flow for blog posts or launch announcements. |

---

## 6. Running a crew with firstmate

firstmate is a separate repo you launch your agent *inside*. You talk to one "first mate" and it
runs parallel crewmates, each in its own git worktree and tmux tab, each handing back a PR.

```sh
cd ../firstmate && claude
> ahoy! look at my github project Keyoku, then build the deck sharing screen
```

Choose the `no-mistakes` ship mode so every crewmate's push goes through the same gate.
`/bearings` for status, `/ahoy` for pending decisions, `/afk` while you step away.

---

## 7. Recommended flows

**New feature**
`/grill-me` → `/pstack:architect` → ACTION 1 (VIPER screen) → `/tdd` → `/subgo` → `/no-mistakes`.

**Bug**
`/diagnosing-bugs` → regression test via `/tdd` → `/no-mistakes`.

**Before an App Store submission**
`/preship` → `/pstack:thermo-nuclear-code-quality-review` → `/changelog` + `/appstore` → `/wizard` for App Store Connect → `/retro`.

---

## 8. Maintaining the toolkit

| Task | Command |
| --- | --- |
| Update all vendored skills + check this doc | `./scripts/sync-ai-toolkit.sh` |
| Only check this doc covers every skill and agent | `./scripts/sync-ai-toolkit.sh --check` |
| Add a skill | `npx skills add <owner/repo> -s <skill> -a claude-code -y`, then add a row here |
| Remove a skill | `npx skills remove -s <skill> -y`, then delete its row here |
| Restore skills from the lock file | `npx skills experimental_install` |
| Find new skills | `npx skills find <query>` or [twostraws/Swift-Agent-Skills](https://github.com/twostraws/Swift-Agent-Skills) |

Improvements to the shared vendored set belong in `../MVVMStarterProject` too, so future projects start with them.
