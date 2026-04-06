# Keyoku — Flashcard Study App

**Keyoku** is an iOS flashcard app built for learners who want to study smarter. Create decks, generate cards with AI, and let spaced repetition bring the right cards back at the right time.

https://apps.apple.com/us/app/keyoku/id6759081180

---

## Features

### Flashcards & Decks
- Create decks with custom colors and cover images
- Add cards manually or **generate them with AI** — paste text or upload a PDF and Keyoku extracts study cards automatically
- Edit and delete cards at any time

### Spaced Repetition (SM-2)
- Every swipe schedules the card for future review using the SM-2 algorithm
- Swipe right → card comes back in 1 day, then 6 days, then at growing intervals
- Swipe left → card resets to review tomorrow
- Practice sessions surface **due cards first**, so you always study what matters most
- **Review Due** button on each deck lets you focus only on cards scheduled for today

### Smart Home Screen
- Due card badges on deck cards show at a glance how many are ready for review
- **Review Due** section groups all due cards across every deck
- **Still Learning** section collects cards you've struggled with, sorted by how often you've missed them
- Streak indicator keeps your daily study habit visible

### Study Reminders
- Toggle daily reminders on or off from Settings
- Pick any study time with the in-app time picker — no digging through system Settings

### Gamification
- Daily streak tracking with celebration animations
- App Store review prompts at meaningful streak milestones (3-day, 7-day)

### Premium
- Free tier supports up to 3 or 5 decks (A/B tested)
- Premium unlocks unlimited decks via in-app subscription

### Other
- Spotlight search — find decks without opening the app
- Deep links and home screen quick actions
- Swipe undo during practice sessions
- Shuffle mode

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI (iOS 26+) |
| Architecture | VIPER + RIBs |
| Local Persistence | SwiftData |
| Backend | Firebase (Auth, Firestore, Analytics) |
| Subscriptions | RevenueCat |
| Analytics | Mixpanel + Firebase Analytics |
| Crash Reporting | Firebase Crashlytics |
| Push Notifications | Firebase Cloud Messaging |
| AI Generation | On-device (Apple Intelligence) |

---

## Requirements

- iOS 26.0+
- Xcode 26+

---

## License

Private — all rights reserved.
