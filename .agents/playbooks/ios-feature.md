---
extends: feature
when: Building or changing a feature in this SwiftUI VIPER + RIBs app, such as a new screen, a Presenter change, a reusable component, or a new Manager.
---

# iOS feature

Applies this project's conventions (`CLAUDE.md` and `.claude/docs/`) to pstack's Feature playbook.

- **In** "`how` over the affected subsystem." also read `CLAUDE.md`, `.claude/docs/viper-architecture.md` and `.claude/docs/project-structure.md`. Use `Core/Home` (View, Presenter, Router, Interactor, with `HomeDelegate` and the `CoreBuilder`/`CoreRouter` extensions at the bottom of `HomeView.swift`) as the reference screen.
- **After** "`architect` for parallel design exploration." keep every design inside View → Presenter → Interactor → Manager. Views hold layout only and call Presenter methods. Presenters are `@Observable @MainActor`, hold all screen state, and track an `Event: LoggableEvent` in every method. Navigation goes through a screen Router protocol implemented by `CoreRouter` using SwiftfulRouting. Data access goes through a screen Interactor protocol implemented by `CoreInteractor`. A new capability gets a Manager registered in `Root/Dependencies/Dependencies.swift` for every build configuration, in `DevPreview`, and resolved in `CoreInteractor`. Components are dumb UI: injected optional data, closure actions, `.anyButton()`, `ImageLoaderView`. No ViewModels.
- **In** "Delegate code-writing to a subagent" create new screens with the Xcode VIPER templates as `.claude/docs/action-create-screen.md` describes, managers per `action-create-manager.md`, models per `action-create-model.md`, and components per `action-create-component.md`. Name the `swiftui-pro`, `swift-concurrency-pro` or `swift-testing-pro` skill in the brief when the change touches that area.
- **Replace** "Verify on the matching surface." with: build and test with the Mock scheme, for example `xcodebuild test -scheme "Keyoku - Mock" -destination 'platform=iOS Simulator,name=<an installed iPhone>' -only-testing:KeyokuUnitTests`. Run `swiftlint lint --quiet` and leave no new warnings. For UI changes, drive the app through a project verify skill at `.claude/skills/verify/` (create it with `/pstack:create-verification-skill`) and fall back to the `run` skill when the repo has none. "It compiles" is not a pass.
- **Before** "Run **Opening a PR**." run the `ios-reviewer` agent on the diff (and `designer-reviewer` for UI changes) and fix every 🔴 Critical finding. If `git remote get-url no-mistakes` succeeds, this repo is set up for no-mistakes: keep Opening a PR's commit, title and description rules, but push and open the PR with `/no-mistakes` instead of `gh pr create`.
