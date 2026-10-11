# Guardrails and structured output: what reduces false blocks

Researched 2026-10-10 for [#27](https://github.com/MarkMartin2077/Keyoku/issues/27) (map [#25](https://github.com/MarkMartin2077/Keyoku/issues/25)). Trigger: a 643-page PDF of *The 33 Strategies of War* (war, deception, violence) had many Sections blocked. Keyoku generates with guided generation (`@Generable GeneratedFlashcardBatch`), default guardrails, on `SystemLanguageModel.default` and `PrivateCloudComputeLanguageModel()`.

**How the sources were read.** Apple documentation pages render in JavaScript, so their text was read from the DocC JSON behind each page (`https://developer.apple.com/tutorials/data/documentation/foundationmodels/<path>.json`). The SDK sources are the iOS 27.0 SDK in Xcode on this Mac: `FoundationModels.framework/Modules/FoundationModels.swiftmodule/arm64e-apple-ios.swiftinterface` (declarations) and `arm64e-apple-ios.swiftdoc` (doc comments, read with `strings`).

Labels:
- **[Apple]** confirmed from Apple docs or the SDK.
- **[Apple forum]** an Apple-side forum reply (the poster is not always tagged as staff; noted where so).
- **[Inference]** my reading, not stated by Apple.
- **[Device]** only a device run can answer.

---

## Answer in short

1. **`permissiveContentTransformations` does not help guided generation.** It only relaxes guardrails when the response type is `String`. With `@Generable` output the default guardrails run as usual. [Apple]
2. **It is on-device only.** Only `SystemLanguageModel` takes a `guardrails:` argument. `PrivateCloudComputeLanguageModel` has only `init()`; PCC guardrails "have different policies that you can't directly configure." [Apple]
3. **On-device vs PCC strictness is not documented.** Apple says only that the policies differ. Measuring it is a [Device] task.
4. **What Apple recommends against over-blocking:** give the model a clear role with permission to work in the domain at the very start of the instructions, name the app's goal and audience, rephrase built-in prompts to find and avoid the trigger phrases, and use permissive mode for "notes in your study app that discuss sensitive topics". Nothing on section size or isolating a blocked paragraph. [Apple]
5. **`refusal` differs from `guardrailViolation`.** A guardrail violation is the safety system blocking input or output. A refusal is the model itself declining, "for prompts that do not violate any guardrail policy". With guided generation a refusal is thrown (no placeholder for a refusal message); with `String` output it arrives as ordinary text. Only `Refusal` has an `explanation`. [Apple] Keyoku currently maps both to `.restricted`.

---

## 1. Does permissive mode apply to `@Generable`?

No.

- [Apple] Doc comment on `SystemLanguageModel.Guardrails.permissiveContentTransformations` (SDK swiftdoc; same text at https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/guardrails/permissivecontenttransformations):
  > In this mode, requests you make to the model that generate a `String` will not throw `guardrailViolation(_:)` errors. However, the model may still sometimes refuse to respond to a sensitive prompt, in which case it generates a `String` refusal message.
  > When you generate responses other than `String`, this mode behaves the same way as `default` mode and throws `guardrailViolation(_:)` errors.
- [Apple] *Improving the safety of generative model output*, section "Use permissive guardrail mode for sensitive content" (https://developer.apple.com/documentation/foundationmodels/improving-the-safety-of-generative-model-output):
  > This mode only works for generating a string value. When you use guided generation, the framework runs the default guardrails against model input and output as usual, and generates `guardrailViolation(_:)` and `refusal(_:)` errors as usual.
- [Apple] The same article names our use case as a reason for the mode: "When you want to use the model to explain notes in your study app that discuss sensitive topics."
- [Apple] Even with permissive mode "the on-device system language model still has a layer of safety. For some content, the model may still produce a refusal message."

## 2. Is there a guardrail option on PCC?

No.

- [Apple] SDK interface: the only initialisers that take guardrails are on `SystemLanguageModel`:
  ```swift
  convenience public init(useCase: SystemLanguageModel.UseCase = .general,
                          guardrails: SystemLanguageModel.Guardrails = Guardrails.default)
  public struct Guardrails : Sendable { }
  extension SystemLanguageModel.Guardrails {
    public static let `default`: SystemLanguageModel.Guardrails
    public static let permissiveContentTransformations: SystemLanguageModel.Guardrails
  }
  ```
  `PrivateCloudComputeLanguageModel` exposes only `convenience public init()`; its `Executor.Configuration` has no public members.
- [Apple] Safety article: "The Apple Foundation Models on Private Cloud Compute (PCC) also have guardrails, but they have different policies that you can't directly configure."
- [Inference] Any "permissive" route therefore means the on-device model with `String` output, which brings the on-device context limit (4,096 tokens in Apple's docs; see `foundation-models-ios27.md`).

## 3. On-device vs PCC strictness

- [Apple] Only "different policies"; no comparison published.
- [Apple forum] An Apple-side poster (MB-Researcher, Nov 2025, not staff-tagged on the page): "The guardrails have some language-specific behavior … guardrails are over-triggering for some languages and locales", and asks reporters to include their Siri language setting "since the guardrails are influenced by locale." https://developer.apple.com/forums/thread/802921 , https://developer.apple.com/forums/thread/787736
- [Apple] iOS 26.4 shipped "improved guardrails with fewer false positives"; WWDC26 says guardrails were refined further (see `foundation-models-ios27.md`).
- [Device] Block rate per model on the benchmark sources. Record the device language/region with each run, since locale affects guardrails.

## 4. Recommended practices for sensitive but legitimate source text

From *Improving the safety of generative model output* [Apple]:

- **Role and domain permission at the start of the instructions.** "Adding Instructions is a way to help reduce over-blocking by helping a model understand what content is appropriate in your context. The very beginning of an Instructions string is an effective place to give the model a clear role with permission to work in a domain … By telling the model more about your app's goal and audience, you help the model more accurately assess the safety of a request."
- **Instructions beat prompts**, and uppercase words add emphasis. Never put untrusted input in the instructions (prompt injection); wrap it in the prompt.
- **Rephrase built-in prompts** that trigger guardrails: "experiment with re-phrasing the prompt to determine which phrases are activating the guardrails, and avoid those phrases." Same advice for refusals.
- **Input and output are both checked.** "the input prompt and the model output are both checked by a guardrail. If either fails the safety check, the model session throws a `guardrailViolation(_:)` error."
- **Report false positives** with `LanguageModelSession.logFeedbackAttachment(...)` and the issue category `.triggeredGuardrailUnexpectedly` ("The model throws a guardrail violation when it shouldn't", SDK swiftdoc) via Feedback Assistant. An Apple-side forum post asks developers to send false-refusal prompts. https://developer.apple.com/forums/thread/787736

Not covered by any Apple source I found: section size, splitting out a blocked paragraph, retrying a blocked call.

Inferences for Keyoku:
- [Inference] Because the input check covers the whole prompt, one sensitive paragraph blocks the whole Section. PCC Sections of ~100K chars make each block expensive: one hit loses a large share of the cards. Smaller Sections, or splitting a blocked Section and retrying the halves, should localise the loss. Whether halves pass is [Device].
- [Inference] Keyoku's instructions already open with a role ("You are an educational study aid assistant for a flashcard app") and permit sensitive history and medical topics. They do not name the audience (students studying their own material) or the domains this book hits (war, military strategy, deception, violence in historical or literary context). Adding these near the start follows Apple's advice. Effect is [Device].
- [Inference] Prompt wording such as "Cause and effect relationships" is harmless, but the generated output is also checked. Cards that restate tactics literally ("how to deceive an enemy") may trip the output check where the source passed. Asking for cards framed as study of the author's argument ("What does Greene argue about …") may help. [Device]
- [Inference] A possible fallback for blocked Sections: on-device with `.permissiveContentTransformations`, `String` output in a fixed plain-text format that the app parses, so guardrails do not apply. Costs: the on-device context limit, no schema guarantee (parsing can fail), and the model may still refuse in text, which is hard to detect programmatically (Apple: "You might not be able to programmatically determine whether a string response is a normal response or a refusal"). Whether this fits the map's rule "Blocked content is never forced through" is a product decision, not a research one; Apple presents this mode as a legitimate configuration for study apps, not a bypass.

## 5. `refusal` vs `guardrailViolation`

- [Apple] `LanguageModelError` (iOS 27) has separate cases:
  ```swift
  case guardrailViolation(LanguageModelError.GuardrailViolation)   // debugDescription, metadata
  case refusal(LanguageModelError.Refusal)                         // debugDescription, metadata, explanation, explanationStream
  ```
- [Apple] `guardrailViolation`: "The model's safety guardrails were triggered by content in a prompt or the response generated by the model."
- [Apple] `refusal`: "This failure can happen for prompts that do not violate any guardrail policy, but the model isn't able to provide the kind of response you requested." https://developer.apple.com/documentation/foundationmodels/languagemodelerror/refusal(_:)
- [Apple] Guided generation: "there's no placeholder for a refusal message. Instead, the model throws a `refusal(_:)` error." `refusal.explanation` asks the model why (async, costs another generation, may itself fail; fall back to `debugDescription`).
- [Apple] Both are fixed the same way for built-in prompts: rephrase. Neither is documented as retryable as-is.
- [Inference] They are worth counting separately in analytics: a refusal is the model's judgement and may respond to instruction wording; a guardrail violation is the safety classifier and may respond to section boundaries. Today `GenerationErrorClassifier` maps both to `.restricted`, so the field data cannot tell them apart.
- [Device] Which of the two the *33 Strategies* blocks actually are. The `debugDescription` of `GuardrailViolation` ("May contain sensitive or unsafe content" in forum reports) is the only detail exposed; there is no category or offending-span field.

## What only a device run can answer

- Block rate per model (PCC vs on-device) on the benchmark sources, split by `guardrailViolation` vs `refusal`.
- Whether a blocked Section passes when split into halves or smaller pieces.
- Whether stronger domain/audience wording in the instructions lowers the rate.
- Whether a permissive on-device `String` fallback yields usable cards for blocked Sections.
- Whether the device's language/region changes results.

## Sources

- Improving the safety of generative model output: https://developer.apple.com/documentation/foundationmodels/improving-the-safety-of-generative-model-output
- `SystemLanguageModel.Guardrails`: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/guardrails
- `permissiveContentTransformations`: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/guardrails/permissivecontenttransformations
- `LanguageModelError.guardrailViolation(_:)`: https://developer.apple.com/documentation/foundationmodels/languagemodelerror/guardrailviolation(_:)
- `LanguageModelError.refusal(_:)`: https://developer.apple.com/documentation/foundationmodels/languagemodelerror/refusal(_:)
- `PrivateCloudComputeLanguageModel`: https://developer.apple.com/documentation/foundationmodels/privatecloudcomputelanguagemodel
- iOS 27.0 SDK, `FoundationModels.swiftinterface` and `.swiftdoc` (Xcode on this Mac)
- Forum: Model Guardrails Too Restrictive? https://developer.apple.com/forums/thread/787736
- Forum: Detected Content Likely to be Unsafe: https://developer.apple.com/forums/thread/802921
