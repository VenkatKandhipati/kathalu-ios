import Foundation

/// Fetches Telugu→English word meanings from the same free MyMemory API the
/// web reader uses. Callers cache results in the vocab card.
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
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }
}
