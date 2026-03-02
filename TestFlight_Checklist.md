# Keyoku Beta Testing Checklist

Thanks for testing Keyoku! This checklist walks you through the key parts of the app. Work through each section and note anything that feels broken, confusing, or off.

**How to report issues:**
- Screenshot or screen record the problem
- Note what you were doing when it happened
- Reply to the TestFlight email or message directly

---

## 1. First Launch & Sign In

- [ ] App opens without crashing
- [ ] Welcome screen looks correct
- [ ] Tap **Get Started** — do the onboarding tutorial screens display properly?
- [ ] Try signing in with **Apple** — does it complete and land you on the Home screen?
- [ ] Try signing in with **Google** — does it complete and land you on the Home screen?
- [ ] After signing in, does your name appear in the greeting? (e.g. "Good morning, Sarah")
- [ ] If you sign in anonymously or skip name setup, does the greeting disappear entirely (no name = no greeting)?

---

## 2. Home Screen — Empty State

> Do this before creating any decks.

- [ ] With no decks, does a centered "Create your first deck" screen appear?
- [ ] Is the layout clean with no awkward empty space?
- [ ] Tap the **Create Deck** button in the middle of the screen — does it open the deck creation flow?
- [ ] Tap the **+** button in the top-right corner — does it also open deck creation?
- [ ] Do both buttons lead to the same place?

---

## 3. Creating a Deck — AI Generation

- [ ] Tap the **+** button to start a new deck
- [ ] Give the deck a name
- [ ] Pick a color — does the color selection work?
- [ ] Choose **Generate with AI**
- [ ] Paste a paragraph or two of text (any topic — class notes, Wikipedia, anything)
- [ ] Select a card count (try 10 or 20)
- [ ] Tap **Generate** — does a progress indicator appear?
- [ ] Watch the card count go up — does it ever go *down* during generation? If so, note when
- [ ] Does generation complete without crashing?
- [ ] Are the generated flashcards readable and relevant to your text?
- [ ] Can you delete individual cards before saving?
- [ ] Save the deck — does it appear on the Home screen?

---

## 4. Creating a Deck — Manually

- [ ] Create a second deck using **Start Empty**
- [ ] Add at least 3 cards manually
- [ ] Do cards save correctly?

---

## 5. Home Screen — With Decks

- [ ] After creating a deck, does the Home screen update to show it?
- [ ] Does the deck count and card count in the subtitle look correct?
- [ ] Does the horizontal deck carousel scroll smoothly?
- [ ] Tap a deck card — does it open the deck?

---

## 6. Practice Session

- [ ] Open a deck and start a practice session
- [ ] **If the deck has more than 5 cards**, does a card count selector appear before starting? (options like 5, 10, 20, All)
- [ ] Select 5 cards from a 20+ card deck and start
- [ ] Swipe **right** on a card — does it mark it as Learned?
- [ ] Swipe **left** on a card — does it mark it as Still Learning?
- [ ] Does the progress bar advance with each card?
- [ ] Tap **Undo** — does it bring back the last card?
- [ ] Tap **Shuffle** — does the card order change?
- [ ] Complete all cards — does the summary screen appear?
- [ ] Summary screen should show how many you Learned vs. Still Learning
- [ ] Tap **Practice Again**
  - [ ] Does it restart with the **same number of cards** you originally selected? (e.g. if you chose 5 cards, Practice Again should give you 5, not the whole deck)
- [ ] Tap **Done** — does it return to the deck or home screen?

---

## 7. Streaks

- [ ] After completing a practice session, does your streak increase on the Home screen?
- [ ] Does the 🔥 flame icon appear next to your streak count?
- [ ] Complete a session on two separate days — does the streak increment each day?

---

## 8. Insights Tab

- [ ] Tap the **Insights** tab
- [ ] Do your stats display (streak, learned cards, due today, retention)?
- [ ] Does anything look wrong or crash?

---

## 9. Decks Tab

- [ ] Tap the **Decks** tab
- [ ] Do all your decks appear?
- [ ] Try searching for a deck by name — does search work?
- [ ] Tap a deck — does it open the deck detail correctly?

---

## 10. Deck Detail

- [ ] Open a deck
- [ ] Does the card list display correctly?
- [ ] Can you edit a card?
- [ ] Can you delete a card?
- [ ] Can you add a new card?
- [ ] Does the **Practice** button start a session?

---

## 11. Profile Tab

- [ ] Tap the **Profile** tab
- [ ] Does your name and email display correctly?
- [ ] Do your stats (streak, learned, due today) display?
- [ ] Tap **Settings** — does the Settings screen open?

---

## 12. Settings

- [ ] Does the Settings screen open without crashing?
- [ ] Tap **Privacy Policy** — does it open in a browser?
- [ ] Tap **Terms of Service** — does it open in a browser?
- [ ] Is the app version number visible at the bottom of Settings?
- [ ] If you haven't granted notification permission yet, do you see an **Enable Notifications** option? Tap it and check the prompt works

---

## 13. Notifications & Reminders

- [ ] Go to **Profile** and find the **Reminder** toggle
- [ ] Toggle reminders **on** — if notifications aren't enabled, does it ask for permission?
- [ ] Can you change the reminder time?
- [ ] After a practice session, do scheduled notifications update?

---

## 14. Edge Cases & Stress Testing

- [ ] Force-close the app mid-session and reopen — does it recover gracefully?
- [ ] Generate a deck with a very large amount of text (paste a full article)
- [ ] Generate a deck with nonsense or random characters — does the app handle it without crashing?
- [ ] Try creating more than 3 decks on a free account — does a paywall appear?
- [ ] Rotate to landscape — does anything break?
- [ ] Switch between tabs quickly — any crashes or blank screens?

---

## 15. General Feel

These don't have right/wrong answers — just your honest opinion:

- [ ] Is anything confusing on first use?
- [ ] Does any screen feel slow or laggy?
- [ ] Is there any text that's hard to read (too small, low contrast)?
- [ ] Did anything surprise you — in a good or bad way?
- [ ] What's the one thing you'd change?

---

## Priority Bug Flags

If you run into any of the following, please report immediately:

- 🔴 App crashes (any screen)
- 🔴 Sign-in fails or gets stuck
- 🔴 Deck generation never completes
- 🔴 Cards not saving after a session
- 🔴 Practice Again gives a different number of cards than you started with
- 🔴 Streak resets unexpectedly

---

Thanks again for your time — it genuinely helps make the app better. 🙏
