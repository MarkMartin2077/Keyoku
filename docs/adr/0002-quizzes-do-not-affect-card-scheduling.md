# Quiz results don't change card scheduling

Quiz answers never update any flashcard's spaced-repetition state (repetitions, interval, ease, due date); quizzes feed only streaks and XP. Quiz questions are generated from the source text independently of the cards, so there's no reliable link from a question to the card it covers, and guessing one would corrupt schedules the learner relies on.

## Consequences

Linking quizzes to scheduling later would need each quiz question to record which card it tests, which changes how quizzes are generated and stored.
