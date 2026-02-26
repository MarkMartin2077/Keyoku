//
//  GibberishDetectorTests.swift
//  KeyokuUnitTests
//

import Testing
@testable import Keyoku

@Suite("GibberishDetector")
struct GibberishDetectorTests {

    // MARK: - Should flag as gibberish

    @Test("No-space blob over 200 chars is gibberish")
    func noSpaceBlob() {
        let text = String(repeating: "dwaidjwaidjawoidjwadiowajda", count: 10) // 260 chars, no spaces
        #expect(looksLikeGibberish(text) == true)
    }

    @Test("Highly repetitive spaced tokens are gibberish")
    func repetitiveTokens() {
        let text = String(repeating: "blah ", count: 60) // "blah blah blah..." 300 chars
        #expect(looksLikeGibberish(text) == true)
    }

    @Test("Keyboard mash with spaces but no anchor words is gibberish")
    func keyboardMashWithSpaces() {
        // Simulates the screenshot case: spaced random tokens, no real English words
        let text = "djwa odj waoij fwjaio dkwaj zxqp fjwao dkwaj zxqp fjwao dkwaj " +
                   "djwa odj waoij fwjaio dkwaj zxqp fjwao dkwaj zxqp fjwao dkwaj " +
                   "djwa odj waoij fwjaio dkwaj zxqp fjwao dkwaj zxqp fjwao dkwaj " +
                   "djwa odj waoij fwjaio dkwaj zxqp fjwao dkwaj"
        #expect(looksLikeGibberish(text) == true)
    }

    @Test("150 chars of spaced random chars with no anchor words is gibberish")
    func shortKeyboardMash() {
        // Under 200 chars, so only the repetition check applies
        let text = "qwrt sdfg zxcv hjkl qwrt sdfg zxcv hjkl qwrt sdfg zxcv hjkl " +
                   "qwrt sdfg zxcv hjkl qwrt sdfg zxcv hjkl qwrt sdfg"
        // uniqueRatio will be low since the same 4 tokens repeat
        #expect(looksLikeGibberish(text) == true)
    }

    // MARK: - Should pass as real text

    @Test("Normal English prose passes")
    func normalProse() {
        let text = """
        Photosynthesis is the process by which plants use sunlight, water, and carbon dioxide \
        to produce oxygen and energy in the form of sugar. This process takes place in the \
        chloroplasts of plant cells, specifically using the green pigment chlorophyll. \
        The light-dependent reactions occur in the thylakoid membranes.
        """
        #expect(looksLikeGibberish(text) == false)
    }

    @Test("Short text under 200 chars with spaces passes")
    func shortRealText() {
        // Under 200 chars — only the word-count and repetition checks apply, not the anchor check
        let text = "The mitochondria is the powerhouse of the cell and produces ATP energy."
        #expect(looksLikeGibberish(text) == false)
    }

    @Test("Technical text with anchor words passes")
    func technicalText() {
        let text = """
        A binary search tree is a data structure in which each node has at most two children. \
        For any given node, all values in the left subtree are less than the node value, \
        and all values in the right subtree are greater. This property allows for efficient \
        search, insertion, and deletion operations in O(log n) average time.
        """
        #expect(looksLikeGibberish(text) == false)
    }

    @Test("Diverse vocabulary with function words passes")
    func diverseVocabularyWithFunctionWords() {
        let text = "The water cycle is a continuous process in which water evaporates from " +
                   "oceans and lakes, rises into the atmosphere, condenses to form clouds, " +
                   "and falls back to the surface as precipitation. This cycle is driven by " +
                   "solar energy and gravity, and it plays a critical role in distributing " +
                   "fresh water around the planet."
        #expect(looksLikeGibberish(text) == false)
    }

    // MARK: - Edge cases

    @Test("Empty string is not flagged")
    func emptyString() {
        #expect(looksLikeGibberish("") == false)
    }

    @Test("Single word is not flagged")
    func singleWord() {
        #expect(looksLikeGibberish("hello") == false)
    }
}
