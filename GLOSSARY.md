# Keyoku

A study app that turns a learner's own material into flashcards and quizzes, generated only from that material.

## Language

**Source Text**:
The learner's material a deck is generated from: pasted text or text extracted from a PDF. All generated study content must come from it, never from outside knowledge.
_Avoid_: Input, content, document

**Quiz**:
A saved, titled set of multiple-choice questions generated from one deck's source text. A deck can have several; a deck without source text has none.
_Avoid_: Test, exam

**Quiz Question**:
One question in a quiz, with exactly one correct answer, three plausible wrong answers, and a one-sentence explanation.
_Avoid_: Item, MCQ

**Quiz Attempt**:
One play-through of a quiz, in shuffled order, with one answer per question and a final score.
_Avoid_: Round, run, session
