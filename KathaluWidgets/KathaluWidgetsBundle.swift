import WidgetKit
import SwiftUI

@main
struct KathaluWidgetsBundle: WidgetBundle {
    var body: some Widget {
        StreakWidget()
        WordWidget()
        TodayStoryWidget()
        LetterWidget()
        SentenceWidget()
        FlashcardWidget()
        ReadingLiveActivity()
    }
}
