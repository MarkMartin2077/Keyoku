//
//  GibberishDetector.swift
//  Keyoku
//

/// Returns true if the text is likely gibberish and should not be sent to the model.
///
/// Checks (in order):
/// 1. Long text with almost no whitespace = one big run of characters.
/// 2. Enough tokens but almost all identical = repetitive gibberish.
/// 3. No common English anchor words in a substantial block = keyboard mash.
func looksLikeGibberish(_ text: String) -> Bool {
    let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })

    if words.count < 5 && text.count > 200 {
        return true
    }

    let lowercasedWords = words.map { $0.lowercased() }
    let uniqueWords = Set(lowercasedWords)
    let uniqueRatio = Double(uniqueWords.count) / Double(max(1, words.count))
    if words.count >= 5 && uniqueRatio < 0.25 {
        return true
    }

    if text.count > 200 {
        let anchors: Set<String> = [
            "the", "a", "an", "in", "is", "it", "of", "to", "and", "or",
            "on", "be", "are", "was", "for", "this", "that", "with", "not",
            "have", "as", "at", "by", "from", "we", "he", "she", "you", "they"
        ]
        if uniqueWords.isDisjoint(with: anchors) {
            return true
        }
    }

    return false
}
