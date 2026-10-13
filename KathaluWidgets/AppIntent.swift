import WidgetKit
import AppIntents

/// Per-instance configuration for the word-to-read widget. Romanization shows by
/// default; the toggle hides it (long-press → Edit Widget). Phrased as "hide" on
/// purpose: a fresh parameter key means every placed widget — including ones
/// saved under the old "Show romanization" toggle — starts with it showing.
struct WordWidgetConfig: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Word to Read" }
    static var description: IntentDescription { "Show a random Telugu word to read." }

    @Parameter(title: "Hide romanization", default: false)
    var hideRomanization: Bool
}

/// Same "hide" toggle for the sentence-to-read widget.
struct SentenceWidgetConfig: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Sentence to Read" }
    static var description: IntentDescription { "Show a sentence from the stories to read." }

    @Parameter(title: "Hide romanization", default: false)
    var hideRomanization: Bool
}
