import Foundation

/// Word meanings, local-first: the bundled curated dictionary covers every
/// word in the stories; MyMemory is only a fallback for anything it misses.
enum DictionaryService {
    /// Loaded once, on first lookup.
    static let entries: [String: WordEntry] = {
        guard let url = Bundle.main.url(forResource: "dictionary", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: WordEntry].self, from: data)
        else { return [:] }
        return decoded
    }()

    static func entry(for word: String) -> WordEntry? {
        entries[word]
    }

    /// The curated meaning when there is one, otherwise a MyMemory lookup.
    static func meaning(for word: String) async -> String? {
        if let entry = entry(for: word) { return entry.meaning }
        return await TranslationService.meaning(for: word)
    }
}
