# Keyoku — Product & Engineering Review

> Evaluated from the perspective of a staff iOS engineer + product manager.
> Target user: solo studier who wants to make AI flashcards and stay consistent.

---

## Staff iOS Engineer View

### What's impressive

**Architecture is the main story.** VIPER + RIBs with protocol-based DI, proper mock services, three build configs, and a real DependencyContainer is not what you see in solo projects. Most portfolio apps are MVC with singletons. This is legitimately what a well-run iOS team looks like. Any senior engineer reviewing this will notice immediately.

**Analytics instrumentation is production-quality.** Every presenter method tracks an event. `_Start` / `_Success` event pairs on async operations. Typed `LoggableEvent` enums rather than raw strings. This signals product thinking baked into the engineering.

**The SM-2 implementation is clean.** Correctly integrated into the persistence layer, doesn't leak into the view, undo behavior is acknowledged as a known limitation. The SRS sort logic in `PracticePresenter.init` is the right place for it.

**Good test discipline.** The `(Manager, MockLogService)` tuple pattern and event verification in unit tests shows you know how to test analytics alongside behavior, not just state.

### Gaps an engineer would flag

**SRS fields are silently dropped when editing a card.** In `onSaveEditedCard`, the updated `FlashcardModel` is constructed without `repetitions`, `interval`, `easeFactor`, or `dueDate`. Editing any card resets its SRS progress to zero. That's a real data integrity bug.

**`onResetLearnedStatus` in the menu doesn't confirm before running.** It's a destructive action that wipes all progress. There's no alert, no undo. Should at minimum confirm.

**`isDue` definition includes `dueDate == nil`**, meaning brand-new unreviewed cards count as due. The `hasDueDecks` filter correctly gates on `isLearned && isDue`, but worth auditing that the badge logic and section logic stay consistent as the codebase grows.

**PDF extraction is synchronous on the main thread.** `extractText(from:)` is called directly in the presenter without being offloaded to a background thread. A large PDF will block the UI.

---

## Product Manager View

### Core loop

Create deck → generate cards with AI → practice (swipe) → get reminded → come back → see due cards surfaced on home.

**Solid.** The biggest friction point in flashcard apps is making the cards, and AI generation directly attacks that. SM-2 scheduling means the app gets smarter over time. Streak and reminders close the retention loop.

### What's missing that matters

**1. Onboarding is invisible.** An empty home screen with a "New Deck" button tells the user nothing. New users have no idea AI generation exists, what spaced repetition means, or why they should care about streaks. A 3-step first-run flow (what the app does → make your first deck with AI → how reviews work) is the highest-leverage thing to add. Without it, churn in the first session will be brutal.

**2. No session length control.** If a deck has 80 cards, the practice session shows all 80. Serious students want "give me 20 cards." Casual users want "just 5 minutes." This is table stakes and a common reason people abandon long sessions.

**3. No stats or insights screen.** All the SRS data is tracked — `isLearned`, intervals, swipe counts — but users can't see any of it. A simple screen showing review history, retention percentage, and cards due over the next 7 days would transform the app from "feels productive" to "proves I'm learning." Also the natural place to show premium value.

**4. Free tier of 3–5 decks is aggressive.** A student taking 4 courses needs at least 4 decks. Hitting the paywall immediately is right for monetization experiments, but watch for churn. A student with real needs will bounce before converting.

**5. No Anki import.** Competitors have 20 years of community decks. An `.apkg` importer lets users bring existing content and get value immediately — fastest path to habit formation.

### Competitive position

Keyoku beats most competitors on code quality and architecture. Loses to Anki on depth (statistics, media, community), Quizlet on content library, and both on study modes (swiping vs. typing answers, matching, tests).

**The real differentiator:** AI generation + SRS in a clean, fast native app. The big players have legacy UX debt. Keyoku is built on iOS 26 with modern SwiftUI. That's an advantage if you use it.

---

## Priority List

### For the user experience (in order)

1. **Fix edit card SRS data loss bug** — silent regression, will confuse users
2. **Add stats / insights screen** — retention rate, due cards this week, streak history
3. **Add session length control** — "study N cards" option before starting practice
4. **Add onboarding flow** — 2–3 screens explaining AI generation and how reviews work

### For the portfolio

- Architecture already stands on its own
- A stats screen demonstrates data visualization
- An Anki importer shows file parsing + schema mapping skills
- Either of those + the bug fix rounds this into something genuinely impressive for a hiring manager
