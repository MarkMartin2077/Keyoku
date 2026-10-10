# Quizzes are stored flat beside decks, not inside them

Each quiz is its own Firestore document in `users/{uid}/quizzes/{quizId}`, pointing at its deck by a `deck_id` field, and locally in its own SwiftData store keyed by that same id rather than a relationship to the deck. We kept quizzes out of the deck document because it already holds every card and the whole source text under Firestore's 1 MiB limit, and we chose a flat collection over a per-deck subcollection because sign-in downloads everything up front: flat is one query, and deleting a deck's quizzes is one `deck_id` filter.

## Consequences

Nothing cascades when a deck is deleted, locally or remotely. Deleting a deck must also delete its quizzes, and sign-in sweeps away any quiz whose deck no longer exists, so quizzes sync after decks.
