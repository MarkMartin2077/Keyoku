# Foundation Models framework in iOS 27: research notes

Researched 2026-10-09. Scope: the changes from iOS 26.x to iOS 27 that matter to Keyoku, which splits long source text into roughly 4K-token chunks and generates flashcards with `@Generable` structs.

**How the sources were read.** Apple documentation pages render in JavaScript, so their text was read from the DocC JSON behind each page (`https://developer.apple.com/tutorials/data/documentation/foundationmodels/<path>.json`). The citations below give the human-readable URLs. Availability values (`introducedAt`, `deprecatedAt`, deprecation messages) come straight from that JSON.

Labels used throughout:
- **[Apple]**: confirmed from an Apple primary source (developer docs, WWDC26 session transcript, release notes, machinelearning.apple.com).
- **[Secondary]**: from a third-party source and not confirmed by Apple.

---

## 1. Context window size and the APIs for it

### Answer in short
- **The on-device size in iOS 27 is not settled in Apple's own sources.** Apple's docs and an Apple engineer say 4,096. A WWDC26 session code sample prints 8,192 and tells developers to "adapt your app to the hardware it's running on." My reading, which Apple has not confirmed: the size may depend on the device or model variant (AFM 3 Core vs. AFM 3 Core Advanced). **Do not hard-code it. Read `contextSize` at runtime.**
- The Private Cloud Compute model is **32K**. [Apple]

### Evidence that it is 4,096
- [Apple] *Managing the context window* (current docs): "Apple’s on-device foundation model has a context window of 4096 tokens per session." The budget is shared by prompts, instructions, tool definitions and I/O, generable schemas, and responses. https://developer.apple.com/documentation/foundationmodels/managing-the-context-window
- [Apple] The PCC article compares the two models in a table: `SystemLanguageModel` context size "4K" against `PrivateCloudComputeLanguageModel` "32K". https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute
- [Apple] WWDC26 Group Lab *Coding Intelligence, Machine Learning & AI* (session 8121, about 8:11). Asked about the iOS 27 on-device window, an Apple presenter said: "So the context size is the same as it was before. It's 4096 and it is a shared window… PCC is 32 K." (auto-generated transcript) https://developer.apple.com/videos/play/wwdc2026/8121/
- [Apple] The deprecated `GenerationError.exceededContextWindowSize` docs still say "the context window of 4,096 tokens." https://developer.apple.com/documentation/foundationmodels/languagemodelsession/generationerror/exceededcontextwindowsize(_:)

### Evidence that it is larger, or varies by device
- [Apple] WWDC26 session 241 *What’s new in the Foundation Models framework* (about 2:34–3:21): "In iOS 26.4, we released new APIs for inspecting the model's context size and counting the tokens… You'll want to use these going forward to adapt your app to the hardware it's running on." The on-screen code sample is:
  ```swift
  let model = SystemLanguageModel()
  print(model.contextSize)
  // 8192
  ```
  https://developer.apple.com/videos/play/wwdc2026/241/
- [Apple] iOS 27 adds `SystemLanguageModel.variant` / `SystemLanguageModel.Variant` with the cases `core3` ("AFM 3 Core") and `coreAdvanced3` ("AFM 3 Core Advanced"). That means the on-device model can differ from device to device. https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/variant-swift.struct
- [Apple] The ML research post describes AFM 3 Core as a 3B dense model and AFM 3 Core Advanced as a 20B-total sparse model (1–4B active) "unlocked by and optimized for our most capable Apple silicon systems." It gives **no** context-length figures for any model. https://machinelearning.apple.com/research/introducing-third-generation-of-apple-foundation-models
- [Secondary] A DEV Community post claims 8,192 without citing a source: https://dev.to/hariharanjagan/whats-new-in-apples-foundation-models-framework-at-wwdc-2026-5227. Michael Tsai's roundup quotes Greg Pierce saying the local context is "still 4K": https://mjtsai.com/blog/2026/06/16/apple-foundation-models-in-appleos-27/
- [Secondary] A GitHub issue reports the iOS 27 **simulator** returning `contextSize == 0`. Fall back to a default when the value is 0. https://github.com/ManifoldKit/ManifoldKit/issues/2518

**Unconfirmed:** whether `contextSize` returns 8192 on Core Advanced devices and 4096 on Core devices. No Apple text says so explicitly.

### Exact APIs [Apple]
| API | Declaration | Availability |
|---|---|---|
| `SystemLanguageModel.contextSize` | `@backDeployed(before: iOS 26.4, macOS 26.4, visionOS 26.4) final var contextSize: Int { get }`, "The maximum context size in tokens that the model supports." | Introduced in 26.4 and back-deployed, so it can be called from 26.0 |
| `SystemLanguageModel.tokenCount(for:)` | Four `nonisolated(nonsending) final func … async throws -> Int` overloads: `tokenCount(for instructions: Instructions)`, `tokenCount(for prompt: some PromptRepresentable)`, `tokenCount(for schema: GenerationSchema)`, `tokenCount(for tools: [any Tool])`, `tokenCount(for transcriptEntries: some Collection<Transcript.Entry>)` | iOS/iPadOS/macOS/visionOS/Mac Catalyst **26.4** |
| `PrivateCloudComputeLanguageModel.contextSize` | The context size of the PCC model | iOS 27 |
| `LanguageModelSession.usage` / `LanguageModelSession.Response.usage` / `LanguageModelSession.Usage` (`input`, `output`, `totalTokenCount`, `metadata`) | Actual token usage after a call. Session 241 also shows `input.cachedTokenCount` and `output.reasoningTokenCount` | iOS **27.0** |

Sources: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/contextsize, https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/tokencount(for:), https://developer.apple.com/documentation/foundationmodels/languagemodelsession/usage-swift.struct, https://developer.apple.com/documentation/updates/foundationmodels

Note: the `tokenCount(for schema: GenerationSchema)` overload lets you measure what a `@Generable` flashcard schema costs, by passing `Flashcard.generationSchema`.

---

## 2. What's new in iOS 27 compared with iOS 26.x

From the *Foundation Models updates* page, June 2026 entry, unless noted otherwise. https://developer.apple.com/documentation/updates/foundationmodels

**Model**
- [Apple] A new on-device `SystemLanguageModel` that "follows instructions more accurately… Because the model changes when a person updates to iOS 27… test your prompts with the new model." The `SystemLanguageModel` docs list three model versions: 26.0–26.3, 26.4, and 27.0. https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel
- [Apple] Session 241: the model was "rebuilt from the ground up… better at logic and tool calling," guardrails were refined further after 26.4, and the model can now read images (Vision capabilities).
- [Apple] The `SystemLanguageModel.Variant` values `core3` and `coreAdvanced3` (iOS 27), described above.

**Model abstraction and server access**
- [Apple] The `LanguageModel` protocol (iOS 27) lets you plug any model, server or on-device, into `LanguageModelSession`. Related types: `LanguageModelCapabilities`, `LanguageModelExecutor`. https://developer.apple.com/documentation/foundationmodels/languagemodel
- [Apple] `PrivateCloudComputeLanguageModel` (iOS 27, plus watchOS 27) offers a 32K context, reasoning, and a daily quota per user (`quotaUsage`, `PrivateCloudComputeLanguageModel.Error.quotaLimitReached`). It needs the `com.apple.developer.private-cloud-compute` managed entitlement and a network connection. Apple says to fall back to the on-device model when it fails. https://developer.apple.com/documentation/foundationmodels/privatecloudcomputelanguagemodel
- [Apple] Session 241: PCC carries no cloud API cost for developers with fewer than 2 million first-time downloads, and the framework is going open source. Its open-source companions are `foundation-models-utilities`, `CoreAILanguageModel`, and `MLXLanguageModel`. Anthropic and Google ship Swift packages for their models.

**Sessions, context, and transcript**
- [Apple] `ContextOptions(includeSchemaInPrompt:reasoningLevel:)` (iOS 27). `ReasoningLevel` has `.light`, `.moderate`, and `.deep`. The on-device model does not support reasoning ("Not supported" in the PCC table). New `respond`/`streamResponse` overloads take `options:contextOptions:metadata:`. https://developer.apple.com/documentation/foundationmodels/contextoptions
- [Apple] `LanguageModelSession.DynamicProfile`, `Profile`, `DynamicInstructions`, and `@SessionProperty` (iOS 27). Profile modifiers include `historyTransform(_:)`, `onPrompt`, `maximumResponseTokens(_:)`, `temperature(_:)`, and `transcriptErrorHandlingPolicy(_:)`. https://developer.apple.com/documentation/foundationmodels/languagemodelsession/dynamicprofile
- [Apple] `transcriptErrorHandlingPolicy` / `TranscriptErrorHandlingPolicy` with `.preserveTranscript` and `.revertTranscript` (iOS 27). https://developer.apple.com/documentation/foundationmodels/transcripterrorhandlingpolicy
- [Apple] `Transcript.history` (the entries without the leading instructions; it can be written), `Transcript.structuredTranscript`, `Transcript.Reasoning`, and attachment segments (iOS 27). https://developer.apple.com/documentation/foundationmodels/transcript
- [Apple] `prewarm(promptPrefix:)` is unchanged since 26.0. Apple's context article still recommends `newSession.prewarm()` after building a condensed session.

**Generation options and tool calling**
- [Apple] `GenerationOptions` adds `samplingMode` (`SamplingMode.greedy`, `.random(top:seed:)`, `.random(probabilityThreshold:seed:)`) and `init(samplingMode:temperature:maximumResponseTokens:[toolCallingMode:])`. The old `sampling` property and `init(sampling:temperature:maximumResponseTokens:)` are flagged **deprecated** in the topic list. https://developer.apple.com/documentation/foundationmodels/generationoptions
- [Apple] `GenerationOptions.ToolCallingMode` with `.allowed`, `.disallowed`, and `.required` (iOS 27). https://developer.apple.com/documentation/foundationmodels/generationoptions/toolcallingmode-swift.struct

**Guided generation and streaming**
- [Apple] `@Generable(description:representNilExplicitlyInGeneratedContent:)` (26.4). `GeneratedContent.ParsingError` (iOS 27) replaces `GenerationError.decodingFailure`. The `GenerationGuide` set is unchanged (`pattern`, `anyOf`, `range`, `minimum`/`maximum`, `minimumCount`/`maximumCount`/`count`, `element`). https://developer.apple.com/documentation/foundationmodels/generable
- [Apple] The `ResponseStream`, `Snapshot`, `PartiallyGenerated`, and `asPartiallyGenerated()` topics show no changes or deprecations. I found no Apple source describing a streaming behavior change in iOS 27. https://developer.apple.com/documentation/foundationmodels/languagemodelsession/responsestream

**Errors (restructured)** [Apple]
- `LanguageModelError` (iOS 27, `@nonexhaustive`) covers any model: `contextSizeExceeded`, `rateLimited`, `refusal`, `timeout`, `guardrailViolation`, `unsupportedCapability`, `unsupportedTranscriptContent`, `unsupportedGenerationGuide`, `unsupportedLanguageOrLocale`. https://developer.apple.com/documentation/foundationmodels/languagemodelerror
- `LanguageModelSession.Error` (iOS 27): `concurrentRequests`, `transcriptMutationWhileResponding`. https://developer.apple.com/documentation/foundationmodels/languagemodelsession/error
- `SystemLanguageModel.Error` (iOS 27): `assetsUnavailable`. https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/error
- `LanguageModelSession.GenerationError` is **deprecated in 27.0** (mapping in section 3).

**Multimodal, availability, languages**
- [Apple] `Attachment`, `ImageAttachmentContent`, and `ImageReference` (iOS 27) add image input. Vision-backed `OCRTool` and `BarcodeReaderTool` are available. Session 241: "larger images will consume more tokens." https://developer.apple.com/documentation/foundationmodels/attachment
- [Apple] `SystemLanguageModel.UseCase` still has only `.general` and `.contentTagging`. `supportedLanguages` and `supportsLocale(_:)` are unchanged since 26.0. The PCC availability enum uses `.systemNotReady`. The on-device enum still uses `.deviceNotEligible` and `.modelNotReady`.
- [Apple] Adapters: I found no adapter changes in the iOS 27 docs or updates page. Not confirmed either way.
- [Apple] Instruments: the Foundation Models instrument now shows tokens, tools, and latency in detail.

---

## 3. Deprecations and behavior changes that affect chunked flashcard generation

1. **Error handling must migrate.** [Apple] Every `GenerationError` case is deprecated in iOS 27. The replacements, taken from the docs' deprecation messages:
   - `exceededContextWindowSize` → `LanguageModelError.contextSizeExceeded(_:)`
   - `guardrailViolation` → `LanguageModelError.guardrailViolation(_:)`
   - `rateLimited` → `LanguageModelError.rateLimited(_:)`
   - `unsupportedGuide` → `LanguageModelError.unsupportedGenerationGuide(_:)`
   - `decodingFailure` → `GeneratedContent.ParsingError`
   - `assetsUnavailable` → `SystemLanguageModel.Error.assetsUnavailable(_:)`
   - `concurrentRequests` → `LanguageModelSession.Error.concurrentRequests`
   - `refusal` and `unsupportedLanguageOrLocale` move to the matching `LanguageModelError` cases.

   Source: https://developer.apple.com/documentation/foundationmodels/languagemodelsession/generationerror

   Deprecated isn't removed. The deployment target decides the approach: on iOS 26, keep the old catches. On iOS 27, `#available`-gate catches of the new types. **Not verified:** whether iOS 27 runtimes throw the new types instead of the old `GenerationError`. If they do, a catch that only matches `GenerationError.exceededContextWindowSize` would miss the error. Test this on a device.
2. [Apple] The iOS 27 release notes include this fixed bug: "`@Generable` on an `enum` produces a deprecation warning about `GenerationError` that cannot be silenced." If you saw that warning in betas, the release build resolves it. https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes
3. [Apple] **The model changed, so prompts need retesting.** The iOS 27 model differs from the 26.4 model, which differs from the 26.0–26.3 model. Apple recommends versioning prompts with `#available` and recording outputs before each update. https://developer.apple.com/documentation/foundationmodels/updating-prompts-for-new-model-versions
4. **Chunk size.** A fixed ~4K-token chunk budget is still safe if the device window is 4,096, but only after you subtract instructions, the schema, and the response. Budget the chunk from `contextSize`, minus `tokenCount(for: instructions)`, minus `tokenCount(for: schema)`, minus a reserve for the response. Count the chunk with `tokenCount(for:)` (26.4+) rather than estimating from characters. If `contextSize` comes back larger (e.g. 8192 on Core Advanced devices, unconfirmed) or 0 (simulator, secondary), adjust accordingly.
5. [Apple] `GenerationOptions(sampling:…)` is deprecated in favor of `samplingMode:`. Only relevant if Keyoku passes sampling options.
6. [Apple] A fix in iOS 27: "When using the on-device Apple Foundation Model for both tool calling and guided generation, some prompts might cause the model to call tools excessively." (release notes, link above)

Project check (local grep): Keyoku creates `LanguageModelSession(instructions:)` in `Keyoku/Core/CreateDeck/CreateDeckPresenter+Generation.swift` and `Keyoku/Core/DeckDetail/DeckDetailPresenter+Generation.swift`. The grep found no direct references to `GenerationError` cases, `contextSize`, or `tokenCount`.

---

## 4. Apple's best-practice guidance for long documents and guided generation

All from *Managing the context window* [Apple] (https://developer.apple.com/documentation/foundationmodels/managing-the-context-window) unless noted:
- **Split large tasks across sessions.** Chunk the text, process each chunk in a **new** `LanguageModelSession`, and include the previous chunk's summary in the next prompt for continuity. Then merge the results in a final session. The article includes sample code for exactly this pattern.
- **Tokens.** One token is roughly 3–4 characters in Latin-alphabet languages and about 1 character in Chinese, Japanese, Korean, and Vietnamese. This matters for a Japanese-learning app: size Japanese chunks by `tokenCount(for:)`, not by character count.
- **Keep generable types lean.** The schema is sent as JSON and every `@Guide` description costs tokens. Use short property names, add `@Guide` only where needed, and bound arrays with `.maximumCount(n)` to limit output.
- **Use `maximumResponseTokens` only as a guard against runaway output.** It can truncate output into malformed responses.
- **Keep prompts concise**, three paragraphs at most, with imperative verbs.
- **Recover from overflow.** Catch `LanguageModelError.contextSizeExceeded`, then build a new session, optionally seeded with a condensed `Transcript` (first and last entries), and call `prewarm()`.
- **Profile** with the Foundation Models instrument (Product > Profile).
- [Apple] `includeSchemaInPrompt`: "Consider using the default value of `true`… The exception… is when the model has knowledge about the expected response format… or because it has seen exhaustive examples during this session." In iOS 27 it is also available on `ContextOptions`. https://developer.apple.com/documentation/foundationmodels/languagemodelsession/respond(to:generating:options:contextoptions:metadata:)
- [Apple] WWDC26 Group Lab: drop tool calls and outputs once they're used, drop or compress older entries, run independent tasks in separate sessions ("each of them have the whole context window for themselves"), and use the Evaluations framework to measure quality. For larger windows, use PCC (32K) or a third-party `LanguageModel`. https://developer.apple.com/videos/play/wwdc2026/8121/
- [Apple] Start on-device, evaluate, and move to PCC only if the feature needs more context or reasoning. https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute

---

## 5. iOS 26.1–26.4 point releases

- [Apple] **26.1–26.3:** the `SystemLanguageModel` docs group "26.0 - 26.3" as one model version, and the Foundation Models updates page lists no entries for 26.1–26.3. I found no API or model changes for those releases.
- [Apple] **26.4 (February 2026 entry):** a new on-device model with better instruction following and tool calling, improved guardrails with fewer false positives, `tokenCount(for:)`, `contextSize` (back-deployed), and a `#Playground` token-usage estimate shown "of 4,096 tokens." `@Generable(…representNilExplicitlyInGeneratedContent:)` also arrived in 26.4. https://developer.apple.com/documentation/updates/foundationmodels
- [Apple] **March 2026:** `python-apple-fm-sdk` gives Python access to the on-device model (same page).

---

## Open questions (not confirmed)
- The exact on-device `contextSize` on each iOS 27 device and variant: 4096 (docs, Group Lab) against 8192 (session 241 sample).
- Whether iOS 27 throws `LanguageModelError` at runtime in place of the deprecated `GenerationError` for apps built against the iOS 26 SDK.
- Any changes to `PartiallyGenerated` or streaming behavior, or to adapters. No Apple source mentions either.
