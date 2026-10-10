# Quiz mode v1: agreed design

Outcome of the quiz mode grilling session, updated with the decisions from the [Quiz mode v1 map](https://github.com/MarkMartin2077/Keyoku/issues/3). Terms are defined in `GLOSSARY.md`. The hard-to-reverse decisions are recorded in `docs/adr/0001-quizzes-only-from-source-text.md`, `docs/adr/0002-quizzes-do-not-affect-card-scheduling.md` and `docs/adr/0003-quizzes-stored-flat-beside-decks.md`.

Inspiration: Paul Hudson's iOS 27 "Questionable" tutorial (Foundation Models + Private Cloud Compute).

## Source

- A quiz is generated only from a deck's source text, never from the model's own knowledge.
- Questions are spread across the whole source text, the same way flashcard generation covers a whole document.
- A deck needs at least 1,500 characters of source text to have quizzes. Hand-made decks (empty source text) can't have quizzes, and the deck screen explains why; decks with too little source text say "Add more source text to make a quiz".

## Saving and syncing

- Quizzes are saved on-device and synced to Firestore, in their own collection beside decks rather than inside the deck (ADR 0003).
- A deck can have several quizzes, with no cap.
- Each quiz gets a short title written by the model, shown with its creation date. No renaming in v1.
- A new quiz avoids questions already in that deck's other quizzes.
- Deleting a deck deletes its quizzes and their attempt history.

Details: [Where do quizzes and quiz attempts live?](https://github.com/MarkMartin2077/Keyoku/issues/4)

## Generation

- A stepper sets 5 to 20 questions, default 10, capped by how much source text there is (about one question per 300 characters).
- No refinement questions and no difficulty choice.
- Each question has one correct answer, exactly three plausible wrong answers, and a one-sentence explanation.
- Badly formed questions are discarded automatically: the correct answer repeated among the wrong ones, duplicate wrong answers, empty fields, references to "the text", or repeats of other questions. If that leaves the quiz short, run one top-up request. A quiz is saved only if it ends with at least 5 valid questions.
- Uses the existing `LanguageModelRouter`: Private Cloud Compute first, on-device fallback.
- Progress shows counts only, never question text, so the quiz isn't spoiled. Cancelling saves nothing.

Details: [How is a quiz generated?](https://github.com/MarkMartin2077/Keyoku/issues/6), research: [Can Foundation Models generate a quiz question reliably?](https://github.com/MarkMartin2077/Keyoku/issues/5)

## Deck screen

- A "Quizzes" section on the deck's detail screen shows a horizontal strip of quiz cards: title, best score, question count and date, led by a "+ New Quiz" card.
- Tapping a quiz starts an attempt. Long-press → Delete (with confirmation) removes one.
- If no AI model is available, saved quizzes still play. The "+ New Quiz" card is disabled, with the same explanation and Settings button the flashcard flow uses.

Details: [What do the quiz screens look like?](https://github.com/MarkMartin2077/Keyoku/issues/7)

## Taking a quiz

- Questions and answer order are shuffled on every attempt.
- One tap per question, on a 2×2 grid of answers.
- After each answer, a sheet shows right or wrong, the correct answer, and the explanation. Right and wrong play the `.success` and `.error` haptics; there are no sound effects.
- End screen: score, best score, and "Retake".
- Leaving mid-quiz asks for confirmation, then records nothing.

## Records and rewards

- Each attempt records only a summary: date, score, total.
- A finished quiz records a streak event. There is no XP in v1.
- Quiz results never change any card's spaced-repetition schedule.
- Free for now. Track `QuizStarted` and `QuizCompleted` to inform a later paywall decision.

## Follow-ups (not in v1)

- Retry only the questions you got wrong (needs per-answer records).
- Quizzes built from a hand-made deck's cards (see ADR 0001).
- XP for quizzes and for Practice.
- Sound effects for right and wrong answers.
- Paywall decision once there's usage data.
