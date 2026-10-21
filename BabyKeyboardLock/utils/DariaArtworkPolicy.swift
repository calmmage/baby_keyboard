import Foundation

/// Scope the inspected original-art policy to Daria's prepared Russian letter hunt.
/// Assets and all archived non-Daria modes remain intact.
enum DariaArtworkPolicy {
    static let excludedStems: Set<String> = [
        "arm",
        "aunt",
        "bicycle",
        "bike",
        "block",
        "brother",
        "bye",
        "cake",
        "cat",
        "cousin",
        "dance",
        "draw",
        "eat",
        "eye",
        "grandma",
        "grandpa",
        "helicopter",
        "hi",
        "laugh",
        "look",
        "love",
        "owl",
        "papa",
        "play",
        "read",
        "run",
        "sheep",
        "ship",
        "sister",
        "sit",
        "snow",
        "stand",
        "sun",
        "tiger",
        "train",
        "uncle",
        "wave",
        "write",
        "yes",
    ]

    static func allows(englishWord: String, style: String, isRussian: Bool, isLetterHunt: Bool) -> Bool {
        guard isRussian && isLetterHunt else { return true }
        // Only the simple source set was visually inspected in this revival.
        guard style == "simple" else { return false }
        let stem = englishWord.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased().replacingOccurrences(of: " ", with: "_")
        return !excludedStems.contains(stem)
    }
}
