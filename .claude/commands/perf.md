Run a performance audit on a Keyoku screen or flow. The screen or area to audit is:

$ARGUMENTS

If no argument is provided, audit the three most recently modified screens.

---

## Step 1 — Identify files to audit

Find the View, Presenter, and any components used by the target screen.

## Step 2 — Audit for common iOS/SwiftUI performance issues

### 1. View body complexity
- Flag any `body` that exceeds ~50 lines — likely doing too much in one render pass
- Flag computed properties called directly inside `body` that do non-trivial work (sorting, filtering, string formatting)
- Flag any `ForEach` over a large unbounded collection without `.id()` stability

### 2. @Observable recompute scope
- Flag Views that hold a reference to the full Presenter but only use one or two properties — they recompute on any Presenter change
- Suggest extracting sub-views that take only the specific values they need, reducing recompute surface

### 3. Main thread work
- Flag any synchronous work in `onAppear` or `onFirstAppear` that could block the main thread
- Flag missing `Task { }` wrappers around async calls triggered from view lifecycle methods
- Flag heavy loops or data transformations happening synchronously on appear

### 4. Image loading
- Confirm `ImageLoaderView` (SDWebImage) is used for all URL images — it handles caching
- Flag any `AsyncImage` usage (no caching, reloads on every appear)
- Flag images loaded without size constraints — can cause layout thrashing

### 5. List/scroll performance
- Flag `List` or `ScrollView` + `ForEach` where rows contain heavy nested views
- Check if row views are broken into separate structs (better diffing) vs inlined
- Flag missing `Equatable` on data models used in `ForEach` — SwiftUI can't diff efficiently without it

### 6. Animation and transitions
- Flag `.animation(.default)` without a value — animates everything including unintended changes
- Flag heavy view hierarchies inside `withAnimation` blocks

### 7. Redundant state
- Flag `@State` or `@Observable` properties that recompute derived values on every access instead of caching
- Flag Presenter computed properties that do expensive work (sorting, filtering) without memoization — they run on every View access

## Step 3 — Output format

Group findings by severity:
- 🔴 **Fix now** — likely causing visible jank or lag
- 🟡 **Fix soon** — will cause problems as data grows
- 🟢 **Consider** — good practice, low urgency

For each finding:
- File name and line number
- What the issue is
- Concrete fix with code snippet

End with a **Performance Score** (1-10) and the single highest-impact change to make first.
