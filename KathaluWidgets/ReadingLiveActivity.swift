import ActivityKit
import WidgetKit
import SwiftUI

/// Lock Screen + Dynamic Island presentation of the reading Live Activity that
/// ReadingActivityController (app side) starts when a story opens.
struct ReadingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingActivityAttributes.self) { context in
            ReadingLockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(WidgetPalette.background)
                .activitySystemActionForegroundColor(WidgetPalette.accent)
                .widgetURL(WidgetShared.Link.story(context.attributes.storyIndex))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.finished ? "checkmark.seal.fill" : "book.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(WidgetPalette.accent)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(percent(context.state))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetPalette.accent)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 0) {
                        Text(context.attributes.title)
                            .font(WidgetPalette.telugu(17).weight(.bold))
                            .lineLimit(1)
                        Text(context.attributes.titleEn)
                            .font(.system(size: 11, design: .serif).italic())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        ProgressView(value: context.state.progress)
                            .tint(WidgetPalette.accent)
                        Text(statsLine(context.state))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                }
            } compactLeading: {
                Image(systemName: context.state.finished ? "checkmark.seal.fill" : "book.fill")
                    .foregroundStyle(WidgetPalette.accent)
            } compactTrailing: {
                Text(percent(context.state))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(WidgetPalette.accent)
            } minimal: {
                Image(systemName: "book.fill")
                    .foregroundStyle(WidgetPalette.accent)
            }
            .widgetURL(WidgetShared.Link.story(context.attributes.storyIndex))
            .keylineTint(WidgetPalette.accent)
        }
    }
}

private struct ReadingLockScreenView: View {
    let attributes: ReadingActivityAttributes
    let state: ReadingActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: state.finished ? "checkmark.seal.fill" : "book.fill")
                .font(.system(size: 26))
                .foregroundStyle(WidgetPalette.accent)
            VStack(alignment: .leading, spacing: 4) {
                WidgetCaption(text: state.finished ? "Finished — nice work!" : "Continue reading")
                Text(attributes.title)
                    .font(WidgetPalette.telugu(19).weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                ProgressView(value: state.progress)
                    .tint(WidgetPalette.accent)
                Text(statsLine(state))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(16)
    }
}

private func percent(_ state: ReadingActivityAttributes.ContentState) -> String {
    "\(Int((state.progress * 100).rounded()))%"
}

/// "45% · 3:12 read · 5 looked up"
private func statsLine(_ state: ReadingActivityAttributes.ContentState) -> String {
    let minutes = state.secondsRead / 60
    let seconds = state.secondsRead % 60
    let looked = state.wordsLookedUp == 1 ? "1 word looked up" : "\(state.wordsLookedUp) words looked up"
    return "\(percent(state)) · \(minutes):\(String(format: "%02d", seconds)) read · \(looked)"
}
