# Flashcard generation: audit and recommendations (iOS 27)

Inputs: `docs/research/foundation-models-ios27.md` (Foundation Models research, cited) and a code audit of
`Core/CreateDeck/CreateDeckPresenter+Generation.swift` and `Core/DeckDetail/DeckDetailPresenter+Generation.swift`.

## Premise check: did the context window grow?

**Not reliably.** Apple's sources disagree on the on-device size:

- **4,096:** the "Managing the context window" doc, the Private Cloud Compute comparison table ("4K"), and an Apple engineer in WWDC26 Group Lab 8121.
- **8,192:** printed by a WWDC26 session 241 sample, which tells apps to "adapt … to the hardware it's running on".

iOS 27 also ships two on-device variants (`.core3`, `.coreAdvanced3`), so the size probably varies by device. Private Cloud Compute (`PrivateCloudComputeLanguageModel`) offers 32K, but it needs an entitlement and has a daily quota.

**So don't swap the hard-coded limit for a bigger one.** Replace it with a runtime budget:

- `SystemLanguageModel.contextSize` gives the window size.
- `SystemLanguageModel.tokenCount(for:)` measures text.

Both shipped in 26.4 and are back-deployed, so they're safe on our 27.0 target. Devices with 8K then get bigger, fewer batches automatically, and 4K devices keep working.

## How generation works today

There is no generation layer. About 250 lines of logic are copied across two presenter extensions:

```
PDFKit extract (main actor) → 5000-char split (findBreak) → ≥ceil(cards/3) chunks
  → serial loop: gibberish check → new LanguageModelSession per chunk
  → streamResponse(GeneratedFlashcardBatch) "exactly N" (N ≤ 3) → prefix(N)
  → substring leak filter → stop as soon as cardCount reached → save
```

All the 4096 workarounds are character heuristics, not token counts:
- 5000-char chunks
- 3 cards per call
- a fresh session per chunk
- `charsPerCard = 150` capping the stepper at 10–50

## Findings (ranked)

**Bugs**
1. **Leftover partial cards.** If a stream throws mid-batch, its half-streamed cards stay in `streamedFlashcards` and get saved. The quality filter and the reset never run.
2. **Only the start of a document is used.** The loop `break`s once enough cards exist, so for a 50k-char PDF with 10 cards, only about the first 40% of the text is ever read.
3. **The two prompts have drifted.**
   - The DeckDetail instructions lack the "gibberish → zero cards" rule.
   - The DeckDetail prompt lacks the "never reference the text" rule, yet DeckDetail still filters those cards out afterwards, wasting them.
4. **The leak filter over-matches.** It matches `"the text"` as a substring, which rejects "the textbook" and "the textile".
5. **The UI freezes during PDF import.** PDF extraction is synchronous on the main actor, so the `isExtractingPDF` spinner can never render.
6. **Errors are vague or misleading.**
   - Every failure is caught generically, and the user sees raw `localizedDescription` text.
   - "Skipped due to content restrictions" also covers gibberish chunks and plain errors.
7. **No cancellation.** Dismissal is blocked instead.
8. **Spotlight can index the wrong deck.** `CoreInteractor.createDeck` looks the deck up by name, which fails when two decks share a name.

**Architecture**
- Generation logic sits in Presenters, a VIPER violation, with no Manager/Service and no Mock.
- Views call `SystemLanguageModel.default.availability` directly.
- Only `looksLikeGibberish` has tests. Chunking, filtering and the batch loop are untested and, in their current form, untestable.

**iOS 27 deprecations**
- `LanguageModelSession.GenerationError` is deprecated in favour of `LanguageModelError` (`contextSizeExceeded`, `guardrailViolation`, `refusal`, `rateLimited`, …), `SystemLanguageModel.Error.assetsUnavailable` and `LanguageModelSession.Error.concurrentRequests`.
- `GenerationOptions(sampling:)` is deprecated in favour of `samplingMode:`.
- Keyoku references none of these today, so we can write the new handling against the new types directly.

**Dead code**
- `estimatedSecondsRemaining` and `updateTimeEstimate()`
- `flashcardStatusText`, `hasProgress`, `generationStartTime`
- the `validateChunk` wrapper and the `skippedBatches` pass-through
- the copied generating overlay UI (fake rotating phrases on a 3.5 s timer)

## Recommended work (separate tickets)

Order: **A** first (everything else builds on it). **B, C and D** can then run in parallel. **E** comes last. **F** is a decision, not a task.

### A. Extract a `FlashcardGenerationManager` (foundation)
- Add a Service Manager per ACTION 3:
  - `FlashcardGenerationService` protocol
  - `ProdFlashcardGenerationService`, which wraps FoundationModels
  - `MockFlashcardGenerationService`, which returns canned cards so Mock builds and UI tests can exercise generation
- Register it in `Dependencies`/`DevPreview` and expose it through `CoreInteractor` and the CreateDeck/DeckDetail interactor protocols.
- API sketch: `func generate(from text: String, cardCount: Int) -> AsyncThrowingStream<GenerationEvent, Error>`, where an event is `.cards([FlashcardModel])`, `.progress(done:total:)` or `.skipped(reason:)`.
- Move the following into the manager or pure helpers, and delete the presenter copies:
  - chunking (`findBreak`, the splitters, `makeChunks` taking text as a parameter)
  - the prompt and instructions, unified so the drift is fixed
  - the quality filter
  - `looksLikeGibberish`
  - PDF extraction (off the main actor)
- Presenters keep only UI state, which leaves about 6 properties instead of about 15.
- Unit-test the pure helpers and the manager with a mock service (`makeManager` tuple pattern).

### B. Token-budgeted batching (the "4096 → bigger window" item)
- Replace `5000 chars` / `3 cards` with a budget computed at runtime:
  - `contextSize − tokenCount(instructions) − tokenCount(schema) − prompt overhead − reserved output`
  - reserved output is `cardsPerBatch × measured tokens per card`
- Size chunks with `tokenCount(for:)` instead of character counts. This also fixes CJK text, which runs about 1 token per character.
- Spread the cards across all chunks in proportion to each chunk's size, instead of stopping at the first N. This fixes bug 2.
- Add `@Guide(.maximumCount(n))` on `GeneratedFlashcardBatch.cards`, and use `maximumResponseTokens` as a safety cap.
- Reconsider `charsPerCard = 150` / the 10–50 clamp once real budgets are known.
- Expected effect: on 8K devices, roughly 2× fewer model calls and better coverage. On 4K devices, the same behaviour but measured instead of guessed.

### C. iOS 27 error handling, cancellation and availability
- Catch the iOS 27 error types:
  - `contextSizeExceeded` → split the chunk in half and retry once
  - `guardrailViolation` / `refusal` → skip, counted separately
  - `rateLimited` / `concurrentRequests` → back off and retry
  - `unsupportedLanguageOrLocale` → show a specific message
- Map each case to a localized user message instead of `localizedDescription`.
- Roll back partial cards when a batch throws (bug 1).
- Store the generation `Task` and support Cancel, checking cancellation between batches.
- Move availability checks into the presenter/interactor.
- Fix the `App-Prefs:` private URL; use `UIApplication.openSettingsURLString`.
- Verify on a device what iOS 27 actually throws (the research couldn't confirm it).

### D. Output quality
- Use one shared instructions/prompt.
- Make the leak filter match whole words or phrases (bug 4).
- Dedup near-duplicate questions across batches.
- Top up with one extra batch when filtering leaves us short of `cardCount`.
- Optionally `prewarm()` the session when the generate sheet opens.

### E. Cleanup and UI
- Delete the dead state listed above.
- Replace the fake rotating phrases with real `.progress` events.
- Make the generating overlay one shared component.
- Localize the status and PDF error strings.
- Split the honest skip message ("N sections skipped: unreadable / restricted").
- Fix the Spotlight name lookup (bug 8).

### F. Decision: Private Cloud Compute for long documents?
- 32K context would let a whole chapter fit in one or two calls, with better quality.
- Costs:
  - an entitlement
  - a daily quota
  - a network dependency
  - privacy wording, since the app currently markets on-device generation
- Options:
  - stay on-device only
  - use PCC as an opt-in for long PDFs
  - use PCC automatically, falling back to on-device
- Worth a `/grill-me` or `/decide` before any code.
- Related: the full PDF text is persisted and pushed to Firestore, which risks the 1 MiB document limit.
