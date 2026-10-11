# Private Cloud Compute: failures, quota and limits

Researched 2026-10-10 for issue #26 (map #25, "Reliable flashcard generation").

**Question.** For `PrivateCloudComputeLanguageModel` on iOS 27: what can a call throw, and which errors pass (network, service, rate limit) and which last (quota, unavailable)? How is quota measured, what are the limits, and what does `quotaUsage` report? Are guardrail blocks and refusals `LanguageModelError` or PCC errors? What is PCC's real context size?

**Labels used**
- **[SDK]**: the iOS 27.0 SDK's `FoundationModels.swiftinterface` and `.swiftdoc` from this Mac's Xcode (`iPhoneOS.sdk/System/Library/Frameworks/FoundationModels.framework/Modules/FoundationModels.swiftmodule/arm64e-apple-ios.*`, module version 2.0.68.1.101). The doc-comment text is what Xcode Quick Help shows.
- **[Apple docs]**: developer.apple.com documentation, read from the DocC JSON behind each page.
- **[WWDC]**: WWDC26 session 319, *Build with the new Apple Foundation Model on Private Cloud Compute* (https://developer.apple.com/videos/play/wwdc2026/319/).
- **[Apple staff]**: a reply marked Apple Staff on the Developer Forums.
- **[Field]**: a developer's own measurement, not confirmed by Apple.
- **[Inference]**: my reading of the above.
- **[Unknown]**: only a device run can answer it.

---

## Answer in short

- **PCC has exactly three PCC-specific errors** [SDK]: `PrivateCloudComputeLanguageModel.Error.networkFailure`, `.serviceUnavailable` and `.quotaLimitReached(resetDate:, limitIncreaseSuggestion:)`. Everything else a PCC call can throw comes from the shared types: `LanguageModelError` (including `rateLimited`, `timeout`, `guardrailViolation`, `refusal` and `contextSizeExceeded`), `LanguageModelSession.Error` and `GeneratedContent.ParsingError`.
- **Guardrail blocks and refusals on PCC are `LanguageModelError`, not PCC errors.** The PCC error enum has no case for them [SDK]. PCC has no guardrails setting [SDK]. Developers report that PCC blocks often arrive **mid-stream** and that the same request often succeeds when re-run [Field].
- **The daily limit counts requests, not tokens.** Each person (iCloud account) gets a daily request limit, and iCloud+ raises it [Apple docs, WWDC]. Apple publishes no number. Apple's published PCC client rate limiter counts *successful requests* in a rolling window [Apple source]. Field reports show walls around 500–800 requests a day, and Apple's own features share the same account [Field].
- **`quotaUsage` is a status, not a meter.** It reports `belowLimit(isApproachingLimit:)` or `limitReached`, a `resetDate`, and a `limitIncreaseSuggestion` (the iCloud+ upsell sheet). It has no count and no remaining amount [SDK]. In the field it read healthy even while every request was being refused [Field].
- **The wall can surface as either `LanguageModelError.rateLimited` or `PrivateCloudComputeLanguageModel.Error.quotaLimitReached`** [Field, acknowledged by Apple staff as worth investigating]. So `rateLimited` from PCC is not always short-lived.
- **The context size is 32,768 tokens** [WWDC code sample; Apple docs say "32K"]. `contextSize` is `async throws` [SDK]. PCC has no tokenizer API; only `SystemLanguageModel` has `tokenCount(for:)` [SDK].
- **What this means for Keyoku's code:** `LanguageModelRouter.streamFromCloud` catches only `PrivateCloudComputeLanguageModel.Error`. A PCC `rateLimited` or `timeout` therefore stays on PCC, and every later section can fail the same way (see "Implications").

---

## 1. Errors a PCC call can throw

### Verified [SDK]

```swift
extension PrivateCloudComputeLanguageModel {
  public enum Error : Error, LocalizedError {
    case networkFailure(PrivateCloudComputeLanguageModel.Error.NetworkFailure)        // debugDescription
    case quotaLimitReached(PrivateCloudComputeLanguageModel.Error.QuotaLimitReached)  // limitIncreaseSuggestion?, resetDate: Date?, debugDescription
    case serviceUnavailable(PrivateCloudComputeLanguageModel.Error.ServiceUnavailable) // debugDescription
  }
}
```

Doc comments [SDK]:
- `networkFailure`: "An error that occurs when a network is available, but PCC is inaccessible." The DocC page says: "Information about a network problem that prevented a request from completing." https://developer.apple.com/documentation/foundationmodels/privatecloudcomputelanguagemodel/error/networkfailure
- `serviceUnavailable`: "Services are unavailable." The DocC page says: "Information about the model service being unable to handle a request."
- `quotaLimitReached`: "The allotted usage quota has been reached." `resetDate` is "The date that the usage limit resets."

The enum is **not** `@frozen`, so a `@unknown default` is required and Apple may add cases.

Shared errors that apply to any `LanguageModel`, PCC included [SDK]:

```swift
public enum LanguageModelError : LocalizedError {
  case contextSizeExceeded(ContextSizeExceeded)   // contextSize, tokenCount, debugDescription, metadata
  case rateLimited(RateLimited)                   // resetDate: Date?, debugDescription, metadata
  case guardrailViolation(GuardrailViolation)     // debugDescription, metadata
  case refusal(Refusal)                           // debugDescription, metadata, explanation / explanationStream
  case unsupportedCapability(UnsupportedCapability)
  case unsupportedTranscriptContent(UnsupportedTranscriptContent)
  case unsupportedGenerationGuide(UnsupportedGenerationGuide)
  case unsupportedLanguageOrLocale(UnsupportedLanguageOrLocale)
  case timeout(Timeout)                           // "The request timed out before the model could produce a response."
}
public enum LanguageModelSession.Error { case concurrentRequests, transcriptMutationWhileResponding }
```

- `rateLimited` doc [SDK]: "The session has been rate limited. This failure can happen if you make too many requests in a short window. You can recover from this error by spacing your requests or reducing system load. The exact solution may be model dependent."
- Streaming methods warn [SDK]: "If running in the background, use the non-streaming `respond(to:options:)` method to reduce the likelihood of encountering `LanguageModelError/rateLimited(_:)` errors."
- `ContextSizeExceeded` carries the model's `contextSize` and the request's `tokenCount` [SDK]. That gives the exact overshoot on PCC, where the app cannot count tokens itself.

### Availability [SDK, Apple docs]
`availability` is `.available` or `.unavailable(.deviceNotEligible | .systemNotReady)`. `isAvailable` means "the system is entirely ready". The docs state: "Quotas are orthogonal to a model's availability — a model can be available even after its usage limit has been reached." So `isAvailable` never reflects quota. https://developer.apple.com/documentation/foundationmodels/privatecloudcomputelanguagemodel/quotausage-swift.struct

### Apple's fallback guidance [Apple docs]
"Using PCC requires a network connection, so if the request fails because the network connection is unavailable, retry the request using the on-device model." Apple gives no fallback guidance for any other error. https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute

### Which errors pass and which last

| Error from a PCC call | Passes or lasts | Basis |
|---|---|---|
| `PCC.Error.networkFailure` | Passes (seconds to minutes). Retry on-device now | Apple docs say to fall back to on-device on network failure |
| `PCC.Error.serviceUnavailable` | Probably passes, length unknown | [Inference] from the name. Apple gives no guidance |
| `PCC.Error.quotaLimitReached` | **Lasts** until `resetDate` (may be nil) or an iCloud+ upgrade. Field recovery took between 41 min and 20 h | Apple docs, [Field] |
| `LanguageModelError.rateLimited` **from PCC** | **Can last for hours.** It is documented as "too many requests in a short window", but in the field it also carried the daily-wall meaning. `resetDate` may be nil | [SDK], [Field] thread 843046 |
| `LanguageModelError.timeout` | Passes | [SDK] doc. Not observed on PCC |
| `LanguageModelError.guardrailViolation` / `.refusal` | Tied to the content, not the model. Often passes on a plain re-run on PCC | [SDK], [Field] thread 848404 |
| `LanguageModelError.contextSizeExceeded` | Tied to the request. Shrink the input | [SDK] |
| `availability == .unavailable(.deviceNotEligible)` | Lasts | [SDK] |
| `availability == .unavailable(.systemNotReady)` | Passes | [SDK] |

---

## 2. Quota: what's counted, the limits, and what `quotaUsage` reports

### Verified
- **Unit and owner.** The docs describe "a daily request limit" that each person gets, upgradable through iCloud+ [Apple docs]. `QuotaUsage` describes "the model's per-user request budget" [SDK]. Session 319 at 7:10: "Requests are counted with your user's iCloud account" [WWDC]. Session 319 at 1:23: "Each user gets a daily limit. And users can upgrade to iCloud+ to get higher limits."
- **No published number.** "Daily limits may vary by feature, request complexity, system demand, system policies, and other factors." (https://developer.apple.com/private-cloud-compute/) Apple's support article lists "Developer apps using Apple Foundation Models in Private Cloud Compute" among the features with usage limits, alongside Siri AI and Image Playground. It gives no number and does not say whether they share one pool (https://support.apple.com/en-us/127901).
- **Cost.** There is no cloud API cost for Small Business Program developers with fewer than 2M first-time downloads. "Expanded access … will be available for a fee in the future." (https://developer.apple.com/private-cloud-compute/)
- **The `QuotaUsage` API** [SDK]:
  ```swift
  public struct QuotaUsage : Sendable {
    public var status: Status                    // .belowLimit(BelowLimit{ isApproachingLimit: Bool }) | .limitReached(LimitReached{})
    public var limitIncreaseSuggestion: LimitIncreaseSuggestion?   // .show() presents the upgrade flow
    public var resetDate: Date?
    public var isLimitReached: Bool { get }
  }
  final public var quotaUsage: QuotaUsage { get }   // synchronous; the class is @Observable
  ```
  - `resetDate` doc [SDK]: "A `nil` value indicates that the model provider has not reported a reset time." The article adds: "This value is empty when the reset date isn't known or when the person is well below their limit."
  - `limitIncreaseSuggestion` doc [SDK]: "A `nil` value indicates that the model provider does not surface an upgrade path through this API."
  - **It has no count, no remaining amount and no percentage.** It is a three-state status: below, approaching, reached.
- **Apple's UI guidance** [Apple docs, WWDC]: use a lasting status label instead of an alert ("Avoid showing an alert for the usage limit. Because this UI should persist"). Disable the request button when the limit is reached, and offer `suggestion.show()`.
- **Testing.** In Xcode, go to Edit Scheme > Run > Options > "Simulated Apple Foundation Models Availability" and choose "Approaching Quota Usage Limit" or "Quota Usage Limit Reached" [Apple docs].

### How the published PCC client counts (Apple source, May 2026 release; may differ from shipping builds)
Apple's open `security-pcc` client source, file `Thimble/PrivateCloudComputeDaemon/RateLimiting/RateLimiter.swift` (https://github.com/apple/security-pcc/blob/e3b4584d3caeb0b4244728a01fca50405101b42c/Thimble/PrivateCloudComputeDaemon/RateLimiting/RateLimiter.swift), works like this:
- It counts **successful requests** (`appendSuccessfulRequest`), not tokens. Denied requests are logged apart and don't count.
- The window is **rolling**: `requestLog.count(now:newerThan: config.timing.duration, filteredBy: config.filter)`. A request is denied when `existingRequestCount >= config.timing.count`.
- Rules filter on `bundleID`, `featureID`, `workloadType` and `workloadTags`. The limits are "discovered" from configuration delivered to the device, not hard-coded.
- A denial is **cached** with a retry-after date (oldest request in the window + duration + jitter). Later matching requests are refused locally without contacting the server.
- A session already in progress gets a small "softening" allowance so it isn't cut off partway through.

### Field reports (not Apple-confirmed)
- **Thread 843046** (https://developer.apple.com/forums/thread/843046), macOS 27 beta, entitled app: the wall hit at about **786 cumulative generations in a day** (501 in one sitting was fine), with no warning. The first run surfaced as `LanguageModelError.rateLimited`. A second run surfaced as `PCC.Error.quotaLimitReached` (fail-fast in 67 ms). **Throughout both runs, `quotaUsage` read `belowLimit`, `isApproachingLimit == false`, `isLimitReached == false` and `resetDate == nil`, and availability read `.available`.** While blocked, refusals came back locally in about 230 ms. Recovery came somewhere between 41 minutes and 20 hours. `limitIncreaseSuggestion` was non-nil after the first PCC contact whether serving or blocked.
  - **[Apple staff]** (Apple Designer): "Since rate limiting is more about the current server load, it's up to each server model provider to decide when to rate limit. I wouldn't assume a fixed number… current capacity, per-request length, and other factors." The same person suggested "instead of 500+ short requests, could you send <200 longer requests". A DTS engineer said the cumulative-ledger `rateLimited` behavior "is indeed worth a closer look" (FB24515295).
- **Thread 849570** (https://developer.apple.com/forums/thread/849570), iOS 27 release: device logs show `InferenceError::rateLimited::PrivateCloudComputeError: deniedDueToUserDeviceRateLimit` and `rate limit discovered: count=500, duration=86400` (for an Apple TV feature). **Hitting the limit from apps also broke Siri AI and HomeKit PCC features on the same account.** A higher iCloud storage tier made no visible difference.
- **Thread 847716** (https://developer.apple.com/forums/thread/847716), iOS 27.2 beta: Siri's planner was denied with `count=320, duration=86400` while another PCC request succeeded 2 seconds later. This suggests the limits are per feature or workload, not one global counter.

### [Inference]
- The daily allowance belongs to the person and is probably shared with Apple's own features. Spending it hurts the user beyond Keyoku. This backs the map's "spend as little quota as possible" rule.
- Requests count, not tokens. So **fewer, larger calls cost less quota** than many small ones. One 30K-token section costs the same as one 3K-token section. Reasoning tokens and retries count against context, but each retry is one more request.
- `quotaUsage` is not a reliable preflight. `canUseCloud` (`isAvailable && !isLimitReached`) can read `true` while every call fails. The only reliable signal is the error from the call itself.

---

## 3. Guardrails and refusals on PCC

### Verified [SDK]
- `PrivateCloudComputeLanguageModel` has only `init()`. Unlike `SystemLanguageModel(useCase:guardrails:)`, **PCC has no guardrails setting**, so `.permissiveContentTransformations` isn't available.
- The PCC error enum has only network, quota and service cases. Guardrail blocks and refusals can therefore only arrive as `LanguageModelError.guardrailViolation` or `LanguageModelError.refusal` (or, for builds that still use it, the deprecated `GenerationError`).
- `Refusal` has `explanation` and `explanationStream`: the model can say why it refused, at the cost of another call. `LanguageModelFeedback` has the category `.triggeredGuardrailUnexpectedly` for reporting false positives with `logFeedbackAttachment`.

### Field (thread 848404, https://developer.apple.com/forums/thread/848404, iOS 27.0, iPhone 16 Pro, FB24938334)
- PCC "refuses a large share of harmless requests, and the same requests often succeed when simply re-run". One example succeeded 52 seconds later with an identical request.
- Most failures were "Streamed response may contain sensitive or unsafe content", **arriving mid-generation**. That suggests the output is checked, not only the input.
- On-device `.permissiveContentTransformations` answered the same prompts.
- Rewording the instructions didn't change the refusal rate. There were no Apple replies.

### [Inference]
- On PCC, a guardrail block is **not deterministic**. A single plain retry of the same section is worth trying before treating the section as blocked. This contrasts with today's "skip with no retry".
- Because blocks arrive mid-stream, cards may already have streamed to the UI before the error. The run must decide whether to keep them (they were generated before the block) or drop them.

---

## 4. Context size

### Verified
- [WWDC] session 319 at 5:58, code sample:
  ```swift
  SystemLanguageModel().contextSize
  // 4096 on 26.0
  // 8192 on 27.0 (newer devices)
  PrivateCloudComputeLanguageModel().contextSize
  // 32768
  ```
  [WWDC] at 4:00: "The on-device model offers 4k, and with PCC you get 32K." The article table says "32K" [Apple docs].
  (This also settles the open question in `foundation-models-ios27.md`: on-device is 8,192 on iOS 27 on newer devices and 4,096 otherwise.)
- [SDK] `nonisolated(nonsending) final public var contextSize: Int { get async throws }`. On PCC it's async and can throw, unlike the synchronous on-device property. The doc says the size covers "both input prompts and generated responses".
- [SDK] `tokenCount(for:)` exists only on `SystemLanguageModel`. The PCC tokenizer can't be queried. After a call, `LanguageModelSession.Usage` / `Response.usage` give the actual `input.totalTokenCount`, `input.cachedTokenCount`, `output.totalTokenCount` and `output.reasoningTokenCount`.
- [WWDC] Reasoning "uses tokens. This counts towards your context size limit." `ContextOptions(reasoningLevel:)` takes `.light`, `.moderate`, `.deep` or `nil` [SDK].

### [Unknown]
- Whether PCC reasons by default when `reasoningLevel` is nil, which is what Keyoku passes today. If it does, reasoning tokens eat into the 32K and add latency. Measure `response.usage.output.reasoningTokenCount` on a device.
- How far off on-device token counts are as an estimate of PCC tokens. The router assumes they match. `ContextSizeExceeded.tokenCount` and `Usage.input.totalTokenCount` give the real figure on a device.

---

## Implications for Keyoku's code today

From `Keyoku/Managers/AI/LanguageModelRouter.swift`, `Keyoku/Managers/FlashcardGeneration/Logic/GenerationErrorClassifier.swift` and `Keyoku/Managers/FlashcardGeneration/GenerationRun.swift`:

1. **`streamFromCloud` catches only `PrivateCloudComputeLanguageModel.Error`.** A PCC `LanguageModelError.rateLimited` (the field-observed daily wall) goes to `GenerationRun`. The classifier maps it to `.rateLimited`. The run waits up to 5 s, retries once **on PCC**, skips the section, and the router stays on PCC. Each later section repeats this, so a run that hits the wall could skip **every** section instead of falling back. `timeout` (classified `.other`) behaves the same way.
2. **Any PCC error moves the run to on-device for good**, including `networkFailure` and `serviceUnavailable`, which should pass. That's safe but slow on the 1.48M-char PDF. On the other hand, `quotaLimitReached` *should* stay on-device for the run, and probably for the rest of the day.
3. **The `canUseCloud` preflight can't be trusted** ([Field]: `quotaUsage` read healthy while blocked). After a quota or rate-limit wall, each new run's `beginRun()` picks PCC again. The fail-fast is cheap (67–230 ms) and doesn't count against quota, so this costs little. But the "Using Private Cloud Compute" announcement followed by an immediate switch to on-device is noise.
4. **Guardrail blocks on PCC are skipped with no retry.** Field data says a plain re-run often succeeds on PCC, and on-device with permissive guardrails often succeeds where PCC refuses. Note that permissive guardrails only apply to `String` output, not `@Generable` output [SDK].
5. **The PCC `contextSize` read can throw.** The router then falls back to the *on-device* size (4K/8K) and budgets PCC sections at 1/4–1/8 of their capacity. That means more requests and more quota.
6. **Quota counts requests.** Today's planner sends about 14 PCC calls for the 643-page PDF. That's cheap against a limit of a few hundred, but parallel or retried calls multiply it. Session-level retries (`hasRetried`) each cost one request.

## Open questions for a device run
- Which type a quota wall throws on iOS 27.0 release builds: `rateLimited`, `quotaLimitReached`, or both. Log `String(reflecting: error)` and `quotaUsage` before and after.
- What PCC throws with the device fully offline: `networkFailure`, a `URLError`, or `availability` flipping. The doc says `networkFailure` means "network is available, but PCC is inaccessible".
- The PCC guardrail rate on the three benchmark sources, and how often a plain retry succeeds.
- Default reasoning on PCC (`usage.output.reasoningTokenCount` with `reasoningLevel` nil vs `.light`) and its effect on latency.
- Whether `contextSize` on PCC ever throws while `isAvailable` is true.
- Real PCC token counts against on-device `tokenCount` estimates for the same section.
