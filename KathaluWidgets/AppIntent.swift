import WidgetKit
import AppIntents

/// Per-instance configuration for the word-to-read widget. Lets the user toggle
/// the romanization hint — add the widget twice (one with, one without) or edit
/// a single instance via long-press → Edit Widget.
struct WordWidgetConfig: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Word to Read" }
    static var description: IntentDescription { "Show a random Telugu word to read." }

    @Parameter(title: "Show romanization", default: false)
    var showRomanization: Bool
}
