import Foundation

@main
struct Check {
    static func main() {
        for word in DariaArtworkPolicy.excludedStems {
            precondition(!DariaArtworkPolicy.allows(englishWord: word, style: "simple", isRussian: true, isLetterHunt: true))
        }
        for word in ["hi", "yes", "papa", "read", "look", "wave", "stand"] {
            precondition(!DariaArtworkPolicy.allows(englishWord: word, style: "simple", isRussian: true, isLetterHunt: true))
            precondition(DariaArtworkPolicy.allows(englishWord: word, style: "simple", isRussian: false, isLetterHunt: true))
            precondition(DariaArtworkPolicy.allows(englishWord: word, style: "simple", isRussian: true, isLetterHunt: false))
        }
        precondition(DariaArtworkPolicy.allows(englishWord: "apple", style: "simple", isRussian: true, isLetterHunt: true))
        precondition(!DariaArtworkPolicy.allows(englishWord: "apple", style: "watercolor", isRussian: true, isLetterHunt: true))
        print("PASS: all \(DariaArtworkPolicy.excludedStems.count) rejected stems filtered; audited apple retained; uninspected style blocked; archived modes preserved.")
    }
}
