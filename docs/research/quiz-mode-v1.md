# Quiz mode v1: agreed design

Outcome of the quiz mode grilling session. Terms are defined in `GLOSSARY.md`. The two hard-to-reverse decisions are recorded in `docs/adr/0001-quizzes-only-from-source-text.md` and `docs/adr/0002-quizzes-do-not-affect-card-scheduling.md`.

Inspiration: Paul Hudson's iOS 27 "Questionable" tutorial (Foundation Models + Private Cloud Compute).

## Source

- A quiz is generated only from a deck's source text, never from the model's own knowledge.
- Questions are spread across the whole source text, the same way flashcard generation covers a whole document.
- Hand-made decks (empty source text) can't have quizzes. The deck screen explains why.

## Saving and syncing

- Quizzes are saved, and synced with their deck through the same on-device and Firestore route decks use.
- A deck can have several quizzes, with no cap.
- Each quiz gets a short title written by the model, shown with its creation date. No renaming in v1.
- A new quiz avoids questions already in that deck's other quizzes.
- Deleting a deck deletes its quizzes and their attempt history.

## Generation

- A stepper sets 5 to 20 questions, default 10, capped by how much source text there is (like the flashcard count).
- No refinement questions and no difficulty choice.
- Each question has one correct answer, exactly three plausible wrong answers, and a one-sentence explanation.
- Badly formed questions are discarded automatically: the correct answer repeated among the wrong ones, duplicate wrong answers, or empty fields. If that leaves the quiz short, run one top-up request. A quiz is saved only if it ends with at least 5 valid questions.
- Uses the existing `LanguageModelRouter`: Private Cloud Compute first, on-device fallback.

## Deck screen

- A "Quizzes" section on the deck's detail screen lists each quiz's title, date, best score and question count.
- A "New Quiz" button creates one. Tapping a quiz starts an attempt. Swipe to delete.
- If no AI model is available, saved quizzes still play. "New Quiz" is disabled, with the same explanation and Settings button the flashcard flow uses.

## Taking a quiz

- Questions and answer order are shuffled on every attempt.
- One tap per question.
- After each answer: right or wrong, the correct answer, and the explanation, with the app's existing haptics and sounds.
- End screen: score, XP earned, and "Retake".
- Leaving mid-quiz records nothing and earns no XP.

## Records and rewards

- Each attempt records only a summary: date, score, total.
- A finished quiz records a streak event and awards 10 XP per correct answer. Quizzes are the app's first XP source (Practice records streaks but awards no XP).
- Quiz results never change any card's spaced-repetition schedule.
- Free for now. Track `QuizStarted` and `QuizCompleted` to inform a later paywall decision.

## Follow-ups (not in v1)

- Retry only the questions you got wrong (needs per-answer records).
- Quizzes built from a hand-made deck's cards (see ADR 0001).
- XP for Practice.
- Paywall decision once there's usage data.
