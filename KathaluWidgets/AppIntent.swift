import WidgetKit
import AppIntents

/// Per-instance configuration for the word-to-read widget. Lets the user toggle
/// the romanization hint — add the widget twice (one with, one without) or edit
/// a single instance via long-press → Edit Widget.
struct WordWidgetConfig: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Word to Read" }
    static var description: IntentDescription { "Show a random Telugu word to read." }

    @Parameter(title: "Show romanization", default: true)
    var showRomanization: Bool
}

/// Same toggle for the sentence-to-read widget.
struct SentenceWidgetConfig: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Sentence to Read" }
    static var description: IntentDescription { "Show a sentence from the stories to read." }

    @Parameter(title: "Show romanization", default: true)
    var showRomanization: Bool
}
