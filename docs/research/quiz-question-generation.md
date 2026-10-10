# Quiz question generation with Foundation Models (iOS 27)

Researched 2026-10-09 for issue #5 ("Can Foundation Models generate a quiz question reliably?"), part of map #3 (Quiz mode v1).
Builds on `docs/research/foundation-models-ios27.md` (context sizes, APIs, iOS 27 changes) and `docs/research/flashcard-generation-recommendations.md`. It does not repeat them.

Labels:
- **[Apple]**: confirmed from an Apple primary source (developer docs read from their DocC JSON, WWDC session transcripts).
- **[Code]**: read from this repo.
- **[Estimate]**: my reasoning or arithmetic, not measured and not confirmed by Apple. Everything marked this way should be checked on a device with `Response.usage` or the Foundation Models instrument.

## Answers in short

| Question | Answer | Confidence |
|---|---|---|
| Can a `@Generable` schema force exactly three wrong answers? | **Yes, for the count.** `@Guide(.count(3))` on `[String]` is enforced by constrained decoding. **No, for the content.** No guide enforces distinct, non-empty answers or "not the correct answer", so validate and discard anyway. | High on count (Apple docs + two WWDC sessions). High that content needs validation (no such guide exists). |
| Token cost of one quiz question vs a flashcard | About **130–180 output tokens per question** vs the **90** the code budgets per flashcard, so roughly 1.5–2× a card. | Low/medium: an estimate. Measure it. |
| Questions per call | **On-device 4K: 2–3. 8K: about 5. PCC 32K: a whole 20-question quiz in one call** whenever the source fits in about 25K tokens. | Medium: follows from confirmed window sizes plus the estimate above. |
| Title in the same call, or a separate call? | Either works technically. Recommended: a **separate small title call over the final accepted questions**, with a fallback title if it fails. A same-call title is fine only when the whole quiz is one call (typical on PCC). | Medium: design judgement on top of confirmed property-order behaviour. |
| Avoiding previously asked questions | Apple has **no specific guidance** on avoid lists. Each listed question costs about 20–30 input tokens. Keep a capped list in the prompt (affordable on PCC, tight on 4K) and always back it with the code-side duplicate filter, plus spreading questions across different parts of the source. | Medium: cost is an estimate, absence of guidance is a negative finding. |

---

## 1. Can the schema force exactly three wrong answers?

### Confirmed
- [Apple] `GenerationGuide.count(_:)`: "Enforces that the array has exactly a certain number of elements." Declared `static func count<Element>(_ count: Int) -> GenerationGuide<[Element]>`. The doc example is `@Guide(description: "A list of items for sale", .count(3)) var inventory: [ShopItem]`. There is also a `count(_: ClosedRange<Int>)` overload. https://developer.apple.com/documentation/foundationmodels/generationguide/count(_:)
- [Apple] The full guide set: `anyOf`, `constant`, `count`, `element`, `maximum`, `maximumCount`, `minimum`, `minimumCount`, `pattern`, `range`. **None of them expresses uniqueness, or a relation between two properties** (such as "differs from `correctAnswer`"). https://developer.apple.com/documentation/foundationmodels/generationguide
- [Apple] WWDC25 *Deep dive into the Foundation Models framework* (301): guides are enforced by constrained decoding, which works "by masking out the tokens that are not valid… the model is only allowed to pick valid tokens according to the schema." In the same session, `.count` is used "to specify we want exactly three attributes for this array." https://developer.apple.com/videos/play/wwdc2025/301/
- [Apple] WWDC25 *Meet the Foundation Models framework* (286): guided generation "fundamentally guarantees structural correctness using a technique called constrained decoding." https://developer.apple.com/videos/play/wwdc2025/286/
- [Apple] WWDC25 code-along (259): "I can add a count, to make sure my days array always has exactly three elements." https://developer.apple.com/videos/play/wwdc2025/259/
- [Apple] PCC: "Getting structured output with Generable, or calling Tools, works just the same with the PCC model, as it does with the on-device model." (WWDC26 session 319) https://developer.apple.com/videos/play/wwdc2026/319/
- [Apple] `LanguageModelError.unsupportedGenerationGuide`: "This failure occurs if you attempt to use generation guides that a model does not support. For example, many models don't support certain guides using certain regex patterns." https://developer.apple.com/documentation/foundationmodels/languagemodelerror/unsupportedgenerationguide(_:)

### What that means for a Quiz Question
- The **number** of wrong answers can be forced to 3. Two equivalent ways to do it: `@Guide(.count(3)) let wrongAnswers: [String]`, or three separate `String` properties. Both are structural, so both are guaranteed.
- These are **not** guaranteed, and the design doc's discard rules (`docs/research/quiz-mode-v1.md`) are still needed:
  - a wrong answer that repeats the correct answer
  - two identical wrong answers
  - empty or whitespace-only strings
  - wrong answers that are actually correct, or implausible (a quality issue no guide can express)
- [Estimate] A `.pattern` guide (for example, at least one non-space character) could block empty strings. But the error doc warns that some models don't support some regex patterns, and the router can switch between PCC and on-device mid-run. Doing the empty check in code is simpler and safer than adding a regex guide.
- **A complete response has exactly 3. A partial one may not.** `PartiallyGenerated` snapshots can hold fewer than 3 wrong answers while a stream is in progress, and if a stream throws, its last snapshot is incomplete. The existing flashcard path already deals with this (`GeneratedCardDraft` drops cards with nil fields). The quiz path must accept a question only when it has all its fields **and** `wrongAnswers.count == 3`, or only take questions from the final response.
- [Apple] Don't use `maximumResponseTokens` to keep output short. Apple says it "can cause the model to generate incomplete or grammatically incorrect responses." https://developer.apple.com/documentation/foundationmodels/managing-the-context-window

**Unverified:** whether PCC honours `.count` exactly as on-device does. Apple says Generable works "just the same", and `.count` isn't a regex guide, so I expect yes. Cover it with one device test per model.

### Suggested shape
```swift
@Generable
struct GeneratedQuizQuestion {
    let question: String
    let correctAnswer: String
    @Guide(.count(3))
    let wrongAnswers: [String]
    @Guide(description: "One sentence")
    let explanation: String
}
```
- [Apple] "The model generates `Generable` properties in the order they're declared." https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation
- The order above has the model commit to the correct answer before writing distractors, so it can write wrong answers that differ from it. The explanation comes last so it can refer to both.
- [Apple] Apple recommends short property names and adding `@Guide` descriptions only where needed, because every description costs schema tokens (*Managing the context window*, above).

---

## 2. Token cost and questions per call

### Confirmed inputs
- [Apple] On-device context: 4,096 tokens per the docs, the Group Lab and session 319 ("The on-device model offers 4k"). Session 241's sample prints 8,192. Read `contextSize` at runtime (see `foundation-models-ios27.md` §1). PCC: 32K.
- [Apple] The window is shared by instructions, prompt, schema and response: "if you input 4000 tokens, your response can go up to the remaining 96" (WWDC26 Group Lab 8121). https://developer.apple.com/videos/play/wwdc2026/8121/
- [Apple] The schema is sent to the model as JSON, and `@Guide` descriptions count toward it. `includeSchemaInPrompt` defaults to `true`. Turning it off saves tokens, but only when the model already knows the format (same-type follow-up requests in one session, or a full example in the instructions), and it drops the guide descriptions (session 259; `respond(to:generating:options:contextOptions:metadata:)` docs).
- [Apple] One token is about 3–4 characters in English and about 1 character in CJK (*Managing the context window*).
- [Apple] Reasoning on PCC "uses tokens. This counts towards your context size limit" (session 319). Apple doesn't document the default `reasoningLevel` when you pass none. Keyoku's `LanguageModelRouter` passes none.

### How flashcards budget today [Code]
- `GenerationBudget` in `Keyoku/Managers/FlashcardGeneration/Logic/BatchPlanner.swift`:
  - `outputTokensPerCard = 90`
  - `freeTokensPerCard = 1_000`, which gives 3 cards per call on 4K, 7 on 8K and the ceiling of 10 on 32K
  - `sourceSafetyFactor = 0.9`
- Overhead is measured at runtime as `tokenCount(instructions) + tokenCount(prompt template) + schemaTokenCount()` (`FlashcardGenerationManager.run()`).
- `LanguageModelRouter.tokenCount` always uses the **on-device** tokenizer, as an estimate for PCC too ("Private Cloud Compute has no tokenizer").

### Estimate per quiz question [Estimate]
| Part | Approx. tokens |
|---|---|
| question (about 15–25 words) | 20–35 |
| correct answer (a short phrase) | 5–15 |
| 3 wrong answers | 15–45 |
| explanation (one sentence) | 20–35 |
| JSON keys and punctuation for 5 fields | 20–30 |
| **Total** | **about 130–180** |

That's about 1.5–2× the 90 tokens budgeted per flashcard: a quiz question has 5 fields where a flashcard has 2, though its answer is shorter than a flashcard's 1–2 sentence answer. The schema is a little larger than `GeneratedFlashcardBatch` (an extra nested type with 4 fields). Measure it with `tokenCount(for: GeneratedQuizBatch.generationSchema)` rather than guessing.

### Questions per call [Estimate]
Assumptions: overhead of about 700–900 tokens (instructions + template + schema, comparable to flashcards), 160 output tokens per question, and the planner's rule of leaving the rest for source text.

| Context | Free after overhead | Questions per call | Source left per call |
|---|---|---|---|
| 4,096 (on-device) | about 3,200 | **2–3** (freeTokensPerQuestion ≈ 1,200–1,500) | about 2,400 tokens ≈ 9K English chars |
| 8,192 (on-device, if real) | about 7,300 | **about 5** | about 5,800 tokens |
| 32K (PCC) | about 31,000 | **all 20** (20 × 160 = 3,200) | about 25K tokens ≈ 90–100K English chars |

**What this implies:**
- Reuse `GenerationBudget` with quiz-specific constants (`outputTokensPerQuestion` ≈ 160, `freeTokensPerQuestion` ≈ 1,200–1,500). Don't reuse the flashcard numbers.
- On 4K, a 10-question quiz means 4–5 calls. That's fine; the flashcard path already works like this.
- On PCC, most decks fit a whole quiz in one call. That spends one request of the user's daily quota instead of several. [Apple] Session 319: "Requests are counted with your user's iCloud account."
- Validate the constants after the first device run with [Apple] `LanguageModelSession.Response.usage` (iOS 27: input/output token counts), then tune them, as was done for flashcards.

**Unverified:** whether PCC caps output length separately from its 32K window. No Apple source mentions one.

---

## 3. Title in the same call, or separately?

### Confirmed
- [Apple] Putting a title next to an array in one `@Generable` works, and Apple's own examples do it: the docs' `Shop` puts `name` before `.count(3) inventory`, and the code-along `Itinerary` has `title`, then description, then day plans (sessions 259 and 286).
- [Apple] Properties are generated in declaration order. That order "matters both for animations and for the quality of the model's output. For example, you may find that the model produces the best summaries when they're the last property in the struct." (session 286)

### Analysis [Estimate]
- **Same call:** a `title` property costs about 10–20 output tokens and a few schema tokens.
  - Declare it **after** the questions so it summarises them, per Apple's tip above.
  - But in a multi-batch run (anything on 4K), each call sees only one chunk. Every batch type would carry a title nobody uses, or you'd need a second "first batch" type. Either way, the title describes one chunk, not the quiz.
  - It also gets streamed and validated along with questions that might later be discarded.
- **Separate call:** prompt with the **final accepted questions** (20 × about 25 tokens ≈ 500 tokens) and get back `@Generable struct QuizTitle { let title: String }`, or plain text.
  - It describes the quiz that is actually saved, covers the whole source, and fits easily in 4K.
  - If it fails (guardrail, refusal, quota), fall back to a deterministic title such as `"<Deck name> Quiz"`, so the quiz is still saved.
  - Cost: one more request. That's free on-device, and one quota unit on PCC.
- **Recommendation:** a separate title call, preferring the on-device model (no quota; the input is tiny). Exception: if the run turns out to be a single call (common on PCC), add `title` as the last property and skip the extra request. That's an optimisation, not a requirement, and v1 can skip it.

---

## 4. Avoiding previously asked questions

### Confirmed
- [Apple] Apple's docs and the sessions I read have **no guidance specific to "don't repeat these items" lists**. The nearest guidance:
  - Session 248 (*Explore prompt design & safety*): the model "will respond well to an all caps command: 'DO NOT'". Give it "less than five examples" of the output you want. Keep prompts to a single specific task. https://developer.apple.com/videos/play/wwdc2025/248/
  - *Managing the context window*: keep prompts concise ("three paragraphs at most"). Everything in the prompt counts toward the shared window.
  - Session 301: to stop a tool returning the same contact twice, Apple keeps the "already used" state **in code** (a stateful tool) rather than relying on the prompt. That's the same principle as filtering duplicates in code.
- [Code] Flashcards already do both halves:
  - `FlashcardPrompt.prompt(…avoiding:)` appends a "Do NOT repeat or rephrase any of these existing questions" list.
  - `FlashcardQualityFilter(avoiding:)` drops normalised duplicates in code.
  - The top-up gives the avoid list at most one third of the source budget (`topUpIfShort`).

### Cost [Estimate]
- About 20–30 input tokens per listed question (about 80–120 English characters, plus the `  - ` bullet).
- A deck with 3 previous 20-question quizzes means about 60 questions, which is about 1,500 tokens. That's roughly half of what a 4K call has free, and trivial on PCC (about 5% of 32K).

### Recommendation
1. **Always filter in code.** Normalise and compare each new question against the deck's other quizzes, and against questions already accepted in this run. Only this is guaranteed. Reuse `FlashcardQualityFilter`'s normalisation.
2. **Put the list in the prompt only up to a cap.** Follow the `topUpIfShort` rule (the list may take at most about a third of the source budget, newest questions first). On PCC that usually covers everything; on 4K it covers the most recent questions.
3. **Lower the chance of repeats structurally.** Spread questions across the whole source (the design doc already requires this). Repeats then mainly come from the same chunk being asked about again. A cheap option that needs no prompt text is to vary chunk boundaries or the order of focus per quiz. Default random sampling also varies output from call to call ([Apple] session 301), so don't use `.greedy` for quizzes.
4. Count discarded duplicates toward the shortfall that triggers the design doc's single top-up request.

**Unverified:** how reliably the iOS 27 on-device model obeys a long "do not repeat" list. Nobody has measured it. Track it with a `duplicatesDiscarded` analytics parameter, just as flashcards track `avoiding_count`.

---

## Open items to verify on a device
- Output tokens per quiz question on the on-device model and PCC (`Response.usage`), and schema tokens (`tokenCount(for: schema)`).
- That `.count(3)` holds on PCC as well as on-device.
- The default PCC `reasoningLevel` when none is passed, and whether reasoning tokens eat into the quiz budget.
- How often a correct answer leaks into the wrong answers, or two wrong answers repeat, after the iOS 27 model update (this sets how often the top-up runs).

## Sources
- GenerationGuide: https://developer.apple.com/documentation/foundationmodels/generationguide
- count(_:): https://developer.apple.com/documentation/foundationmodels/generationguide/count(_:)
- maximumCount(_:): https://developer.apple.com/documentation/foundationmodels/generationguide/maximumcount(_:)
- Generating Swift data structures with guided generation: https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation
- Managing the context window: https://developer.apple.com/documentation/foundationmodels/managing-the-context-window
- respond(to:generating:options:contextOptions:metadata:): https://developer.apple.com/documentation/foundationmodels/languagemodelsession/respond(to:generating:options:contextoptions:metadata:)
- ContextOptions: https://developer.apple.com/documentation/foundationmodels/contextoptions
- LanguageModelError.unsupportedGenerationGuide: https://developer.apple.com/documentation/foundationmodels/languagemodelerror/unsupportedgenerationguide(_:)
- Adding server-side intelligence with Private Cloud Compute: https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute
- WWDC25 286 Meet the Foundation Models framework: https://developer.apple.com/videos/play/wwdc2025/286/
- WWDC25 301 Deep dive into the Foundation Models framework: https://developer.apple.com/videos/play/wwdc2025/301/
- WWDC25 259 Code-along: https://developer.apple.com/videos/play/wwdc2025/259/
- WWDC25 248 Explore prompt design & safety: https://developer.apple.com/videos/play/wwdc2025/248/
- WWDC26 241 What's new in the Foundation Models framework: https://developer.apple.com/videos/play/wwdc2026/241/
- WWDC26 319 Build with the new Apple Foundation Model on Private Cloud Compute: https://developer.apple.com/videos/play/wwdc2026/319/
- WWDC26 8121 Group Lab: https://developer.apple.com/videos/play/wwdc2026/8121/
- Repo: `Keyoku/Managers/FlashcardGeneration/Logic/BatchPlanner.swift`, `GenerationModels.swift`, `FlashcardPrompt.swift`, `FlashcardGenerationManager.swift`, `Keyoku/Managers/AI/LanguageModelRouter.swift`
