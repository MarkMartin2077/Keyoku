# Generation calls: parallelism and per-call latency

Researched 2026-10-10 for [#28](https://github.com/MarkMartin2077/Keyoku/issues/28) (map: [#25 Reliable flashcard generation](https://github.com/MarkMartin2077/Keyoku/issues/25)).

**Question.** Can several `LanguageModelSession` calls run at once, on Private Cloud Compute (PCC) and on-device? Are there documented concurrency or rate limits? What drives the latency of one call (prompt prefill or output tokens)? And so: on each model, do fewer, larger sections finish faster than more, smaller ones?

**How the sources were read.** Apple documentation pages were read from the DocC JSON behind each page (`https://developer.apple.com/tutorials/data/documentation/foundationmodels/<path>.json`). The links below are the human-readable URLs. The API declarations come from the Xcode SDK on this Mac: `iPhoneOS.sdk/System/Library/Frameworks/FoundationModels.framework/Modules/FoundationModels.swiftmodule/arm64e-apple-ios.swiftinterface` (iOS 27.0 SDK).

Labels:
- **[Apple]**: Apple documentation, the SDK interface, a WWDC transcript, machinelearning.apple.com, or an answer from someone with an Apple Staff badge on the developer forums.
- **[Secondary]**: anyone else, including notes other people took at Apple sessions.
- **[Inference]**: my reasoning from the facts above. Not stated by any source.
- **[Measure]**: only a device run can settle it. See [What to time on a device](#what-to-time-on-a-device).

---

## Answer in short

1. **A single session takes one request at a time.** Calling it a second time while it's responding throws `LanguageModelSession.Error.concurrentRequests`. That error means the app misused the session. It is not a sign of load. [Apple]
2. **Several sessions can run at once without errors, but the on-device model runs them one after another.** Apple staff say on-device inference "runs serially one at a time" on the Neural Engine, and the OS caps concurrent requests. Requests over the cap are delayed, not refused. **Running on-device calls in parallel will not cut the run's total time much.** [Apple]
3. **On-device, an app in the foreground has no rate limit.** Background use can be rate-limited (`LanguageModelError.rateLimited`). [Apple]
4. **PCC has a daily per-user request limit and a separate short-window rate limit.** Apple publishes neither number. Apple publishes nothing about running PCC calls in parallel: it neither says they run in parallel nor says they are serialized. [Apple] Whether parallel PCC calls finish sooner is **[Measure]**.
5. **Latency per call = prefill (all input tokens) + decode (each output token) + fixed costs (model load, session setup).** Apple's own on-device figures (2024 model, iPhone 15 Pro) are about **0.6 ms per prompt token** to first token and about **30 output tokens/s**. Output tokens cost about 50 times as much as input tokens. [Apple, 2024 model] Figures for the iOS 27 models are not published. [Measure]
6. **So:** on-device, total time is set by the total tokens across all calls. The size of each section matters only through the overhead each call repeats: instructions, schema, prompt template, session setup. The cards' output tokens cost the same however the work is split. Fewer, larger sections save that repeated overhead. Sampling, which reads less source, saves more. [Inference] On PCC, fewer, larger sections also save **quota**, because Apple counts the quota in requests. [Apple + Inference]

---

## 1. Concurrency

### One session
- [Apple] `LanguageModelSession.Error.concurrentRequests`: "The session received multiple concurrent requests. A language model session only supports one request at a time. Wait for the current request to complete before starting another." https://developer.apple.com/documentation/foundationmodels/languagemodelsession/error/concurrentrequests
- [Apple] Its deprecated iOS 26 predecessor, `GenerationError.concurrentRequests(_:)`: "An error that happens if you attempt to make a session respond to a second prompt while it's still responding to the first one." https://developer.apple.com/documentation/foundationmodels/languagemodelsession/generationerror/concurrentrequests(_:)
- [Apple] `isResponding`: "You should not call any of the respond methods while this property is `true`." https://developer.apple.com/documentation/foundationmodels/languagemodelsession/isresponding
- [Apple] SDK interface (iOS 27.0):
  ```swift
  extension LanguageModelSession {
    final public var isResponding: Bool { get }
    final public var usage: LanguageModelSession.Usage { get }   // iOS 27
  }
  extension LanguageModelSession : @unchecked Sendable {}
  extension LanguageModelSession {
    public enum Error : Foundation.LocalizedError {             // iOS 27
      case concurrentRequests
      case transcriptMutationWhileResponding
    }
  }
  ```
  `LanguageModelSession` is `@unchecked Sendable`, and `SystemLanguageModel` and `PrivateCloudComputeLanguageModel` are both `Sendable`. One model instance can back many sessions across tasks.

### Several sessions
- [Apple] DTS Engineer (Ziqiao Chen), accepted answer, Aug 2025: "You can follow the Swift concurrency rules to run multiple Foundation Models sessions / tasks concurrently. The framework doesn't impose any extra rules for concurrency. Note that the inference tasks will eventually run on the neural engine serially though." An Apple Designer added in the same thread: "currently all inference against the on-device model runs serially one at a time, and the model is a shared resource across the operating system." https://developer.apple.com/forums/thread/798113
- [Apple] Frameworks Engineer, recommended answer, Jun 2026, iOS 27: "The OS limits the amount of concurrent requests to the model. While the framework won't return an error if the model is already being accessed, there might be a delay before the OS relays your request to the model." https://developer.apple.com/forums/thread/833642
- [Apple] WWDC26 Group Lab 8121 (~39:42) recommends separate sessions for independent tasks: "each of them have the whole context window for themselves." https://developer.apple.com/videos/play/wwdc2026/8121/
- [Secondary] Notes from Apple's FoundationModels code-along Q&A (Sep 2025): "You can create multiple sessions to run multiple requests in parallel" and "no limit on the amount of sessions." https://gist.github.com/stinger/81891077161002819c0ec233f73edc74
- **PCC:** no Apple source covers concurrent PCC sessions. Nothing documents a per-app or per-user cap on concurrent requests. The only documented PCC limits are the daily quota and rate limiting (section 2).

### Inferences
- [Inference] On-device, parallel sessions mostly queue. Running two calls at once could still save a little: the app-side work (quality filter, token counting, building the next prompt) and any per-call setup can overlap with inference. That saving is small next to roughly 3K-token prefills.
- [Inference] Parallel calls also make the router's state harder to manage. `LanguageModelRouter` is `@MainActor` and keeps one `activeModel`, set to `.onDevice` for the rest of the run after any PCC error, plus a single `prewarmed` slot. When several calls fail at once, each of them would flip `activeModel`, and each `didYield` decision would have to be made per call. Bring in `swift-concurrency-pro` if parallel calls ship.

## 2. Rate limits and quota

- [Apple] `LanguageModelError.rateLimited(_:)` (iOS 27): "This failure can happen if you make too many requests in a short window. You can recover from this error by spacing your requests or reducing system load. The exact solution may be model dependent." Its payload carries `resetDate: Date?`. https://developer.apple.com/documentation/foundationmodels/languagemodelerror/ratelimited(_:)
- [Apple] The deprecated `GenerationError.rateLimited(_:)`: "This error will only happen if your app is running in the background and exceeds the system defined rate limit." https://developer.apple.com/documentation/foundationmodels/languagemodelsession/generationerror/ratelimited(_:)
- [Apple] WWDC26 Group Lab 8121 (~11:22): "With the local foundation model, you won't get limited as long as your apps in the foreground." "With the private cloud Compute language model, you may hit rate limiting for other reasons." "There's rate limiting that happens because the system is busy and then there's rate limiting. That can happen because you've sent too many requests in a very short period. And those manifest as different kinds of errors in the API." Background calls give "the same response… It just might take a little longer." (auto-generated transcript)
- [Apple] *Adding server-side intelligence with Private Cloud Compute*: usage limits are "Unlimited" for `SystemLanguageModel` and "Limit per day" for PCC. "People just need a device that supports Apple Intelligence and gets a daily request limit." Exceeding it throws `PrivateCloudComputeLanguageModel.Error.quotaLimitReached` (payload: `resetDate`, `limitIncreaseSuggestion`). "Unlike rate limiting, where a person waits for a period of time before trying again, exceeding the daily quota means a person either waits for their usage quota to refresh or they upgrade." https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute
- [Apple] WWDC26 session 319 *Build with the new Apple Foundation Model on Private Cloud Compute*: "Each user gets a daily limit… Requests are counted with your user's iCloud account." https://developer.apple.com/videos/play/wwdc2026/319/
- **Not published:** the daily quota number, the short-window rate limit, and whether the quota counts requests or tokens. Apple's wording is "request limit" and "requests are counted", which points to requests. [Apple wording, Inference on meaning]
- [Secondary] The code-along notes: "There is no rate limit when your device is connected to power, or when your app runs in the foreground."

## 3. What one call costs in time

- [Apple] WWDC25 session 301 *Deep dive into the Foundation Models framework*: "Each token in your instructions and prompt adds extra latency. Before the model can start producing response tokens, it first needs to process all the input tokens. And generating tokens also has a computational cost, which is why longer outputs take longer to generate." https://developer.apple.com/videos/play/wwdc2025/301/
- [Apple] *Analyzing the runtime performance of your Foundation Models app*: "More output tokens generally require more processing time… summarizing a document requires much less processing time than generating a new article, because it's mostly a reading task." "High token counts affect both initial processing time and memory usage." Excluding the schema with `includeSchemaInPrompt: false` "can save hundreds of tokens per request." The Foundation Models instrument splits each request into **Model Loading**, **Model Inference**, **Time to First Token** and **Response Duration**. It also shows token counts: Consumed, Generated, **Cached**. https://developer.apple.com/documentation/foundationmodels/analyzing-the-runtime-performance-of-your-foundation-models-app
- [Apple] *Introducing Apple's On-Device and Server Foundation Models* (June 2024, the first-generation model): "on iPhone 15 Pro we are able to reach time-to-first-token latency of about 0.6 millisecond per prompt token, and a generation rate of 30 tokens per second… before employing token speculation techniques." https://machinelearning.apple.com/research/introducing-apple-foundation-models. The 2025 update adds KV-cache sharing "significantly improving the time-to-first-token" and speculative decoding in the OS daemon. https://machinelearning.apple.com/research/apple-foundation-models-2025-updates. The 2026 AFM 3 post gives no latency figures. https://machinelearning.apple.com/research/introducing-third-generation-of-apple-foundation-models
- [Apple] KV cache: within a session, a stable prefix (instructions, then tools, then transcript) is cached, so each new turn processes only the tokens added. `prewarm(promptPrefix:)` "precompute[s] the prefix into the cache"; use it when the request is at least 1–2 s away. Prewarming doesn't guarantee the system loads assets "particularly if your app is running in the background or the system is under load." A session restored from a transcript "starts without a KV cache." Cache handling "is up to the model provider." https://developer.apple.com/documentation/foundationmodels/optimizing-key-value-caching-in-language-model-sessions, https://developer.apple.com/documentation/foundationmodels/languagemodelsession/prewarm(promptprefix:)
- [Apple] iOS 27 `Response.usage` / `session.usage` report `input.totalTokenCount`, `input.cachedTokenCount`, `output.totalTokenCount` and `output.reasoningTokenCount` per call (SDK interface; WWDC26 241).
- [Apple] PCC reasoning: "A lower reasoning effort reduces latency, while deeper reasoning trades latency for more analysis." `ContextOptions(reasoningLevel:)` takes `.light`, `.moderate` or `.deep`. The SDK default is `nil`, and Apple doesn't document what `nil` means on PCC. At Group Lab 8121 Apple said: "reasoning is the first thing I drop… even if it is reasoning, still costs you latency."
- [Secondary] Code-along notes: when the model isn't in memory yet, "prewarm can easily save 500ms."

### Rough numbers for Keyoku (inference from the 2024 figures; the iOS 27 models differ)
- [Inference] One on-device call with a ~3K-token input: about 1.8 s of prefill. One flashcard is perhaps 60–100 output tokens of `@Generable` JSON (**[Measure]**), so about 2–3 s of decode per card. That makes about 4–5 s per one-card call. Fifty calls take about 4 minutes, which fits the >5 minutes observed on the 643-page PDF.
- [Inference] **Decode sets a floor no way of splitting the work can remove.** At 30 tokens/s, 50 cards × ~80 tokens is about 130 s of decode alone, whatever the sectioning. The on-device target of < ~3 min for 50 cards leaves only about 50 s for all prefill and overhead. That is about 30K input tokens in total, or about 10 calls of 3K tokens. Hitting the target means far fewer calls than 50 (several cards per call) and reading far less source than "cover everything." Tokens per card is the number to measure first.
- [Inference] Each call starts a fresh session (`LanguageModelRouter.makeSession`), so the instructions, schema and prompt template are prefilled on every call. Apple documents the KV cache only within a session, and doesn't say whether the system's prefix cache carries over between sessions. `usage.input.cachedTokenCount` on a fresh session's first call answers that. If it is near 0, every extra section costs one more `overheadTokens` prefill plus session setup.
- [Inference] PCC has a 32K window. Prefill per token on PCC is probably much cheaper than on-device. Network round trips and server queueing add a fixed cost per call. Reasoning tokens (if the default level reasons) add decode time. Fewer, larger sections should win on PCC too, and also save quota.

## 4. What this means for the other tickets

- **#30 (how sections are picked):** on-device, plan for **serial** calls. Parallel calls are not a speed lever there. The levers are total input tokens (sample less text), repeated overhead per call (fewer, larger sections, more cards per call), and output tokens per card (lean schema). On PCC, prefer fewer, large sections: that saves quota (counted in requests) and per-call fixed costs. Parallel PCC calls stay an option only if a device run shows they cut wall time without `rateLimited`.
- **#29 (baseline measurement):** add the measurements below to its checklist. Those numbers decide the trade-offs in #30.
- **Possible new ticket, small bug:** `GenerationErrorClassifier` maps `LanguageModelSession.Error.concurrentRequests` (and the legacy `GenerationError.concurrentRequests`) to `.rateLimited`, so the run sleeps and retries. Apple defines that error as reusing one session while it is still responding, a programming error, not a load signal. It should be classified as `.other` and caught in debug (`assertionFailure`). Only `LanguageModelError.rateLimited` should back off.
- **Possible new ticket, PCC reasoning level:** `LanguageModelRouter` never sets `ContextOptions(reasoningLevel:)`. If `usage.output.reasoningTokenCount` is non-zero on PCC flashcard calls, set `.light` (or the lowest level that keeps quality) to cut latency.
- **Possible follow-up, cheaper prompts:** try `includeSchemaInPrompt: false` with a short format example in the instructions, if quality holds ("can save hundreds of tokens per request").

## What to time on a device

Use a real device in the foreground, plugged in, and not under thermal pressure (Apple's advice for the instrument). Profile with **Xcode > Product > Profile > Foundation Models** template, and log `response.usage` for each call.

| # | What | How | Decides |
|---|---|---|---|
| 1 | Prefill speed per model | Same prompt with 500 / 1.5K / 3K input tokens, 1 card. Read Time to First Token and Consumed Tokens. ms/token = slope. | Cost of reading more source |
| 2 | Decode speed and tokens per card | Same ~1.5K input, 1 / 3 / 5 cards. Read Response Duration and Generated Tokens. | Output floor for 50 cards. Whether the < 3 min on-device target is reachable |
| 3 | Fixed cost per call | Intercept of 1 and 2. Model Loading lane on the first call vs later calls, with and without `prewarm()`. | Value of fewer, larger sections |
| 4 | Prefix cache across sessions | `usage.input.cachedTokenCount` on the first call of each new session within a run. | Whether repeated instructions/schema cost a full prefill every call |
| 5 | Parallel on-device | Run N = 1, 2, 4 independent one-card sessions at once (`withThrowingTaskGroup`). Record wall time and errors. | Confirms the serial behaviour Apple describes |
| 6 | Parallel PCC | Same as 5 on PCC with N = 1, 2, 4, 8. Record wall time, `LanguageModelError.rateLimited` (and its `resetDate`), and `quotaUsage.status` before and after. | Whether parallel PCC is a speed lever, and where rate limiting starts |
| 7 | PCC reasoning | `usage.output.reasoningTokenCount` with default options vs `ContextOptions(reasoningLevel: .light)`. | Whether to set the reasoning level explicitly |
| 8 | Quota cost | `quotaUsage.status` before and after a full 50-card PCC run. Approaching-limit simulation via Scheme > Run > Options > "Simulated Apple Foundation Models Availability". | How many full runs a day the quota allows |

## Not found

- The iOS 27 models' prefill and decode speeds, on-device or PCC.
- Any statement about running PCC requests concurrently.
- The daily PCC quota and the rate-limit thresholds.
- What `reasoningLevel: nil` means on PCC.
- Whether the prefix (KV) cache carries over between separate sessions that share instructions.
