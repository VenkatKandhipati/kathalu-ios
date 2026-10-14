import Foundation

/// Fetches Telugu→English word meanings from the same free MyMemory API the
/// web reader uses. Only a fallback now — `DictionaryService` answers first.
/// Callers cache results in the vocab card.
enum TranslationService {
    struct MyMemoryResponse: Decodable {
        struct ResponseData: Decodable { let translatedText: String }
        let responseData: ResponseData
    }

    static func meaning(for teluguWord: String) async -> String? {
        var components = URLComponents(string: "https://api.mymemory.translated.net/get")!
        components.queryItems = [
            URLQueryItem(name: "q", value: teluguWord),
            URLQueryItem(name: "langpair", value: "te|en"),
        ]
        guard let url = components.url else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(MyMemoryResponse.self, from: data)
            let text = decoded.responseData.translatedText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return isUsable(text, for: teluguWord) ? text : nil
        } catch {
            return nil
        }
    }

    /// Rejects empty answers, provider warnings/quota messages, and answers
    /// that still contain Telugu (an echo or a half-translation).
    private static func isUsable(_ text: String, for word: String) -> Bool {
        guard !text.isEmpty, text != word else { return false }
        if text.contains("mymemory") || text.contains("query length limit") { return false }
        return !text.unicodeScalars.contains { (0x0C00...0x0C7F).contains($0.value) }
    }
}
