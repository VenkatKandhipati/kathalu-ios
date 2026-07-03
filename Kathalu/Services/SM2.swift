import Foundation

/// SM-2 spaced repetition, ported from backend/app/sm2.py so offline scheduling
/// matches the server exactly.
enum SM2 {
    struct Result {
        var interval: Int
        var easeFactor: Double
        var repetitions: Int
        var nextReview: DayStamp
    }

    static func schedule(
        interval: Int,
        easeFactor: Double,
        repetitions: Int,
        quality: Int,
        today: DayStamp = .today
    ) -> Result {
        precondition((0...5).contains(quality), "quality must be in [0, 5]")

        if quality < 3 {
            return Result(
                interval: 1,
                easeFactor: max(1.3, easeFactor),
                repetitions: 0,
                nextReview: today.adding(days: 1))
        }

        let newInterval: Int
        switch repetitions {
        case 0: newInterval = 1
        case 1: newInterval = 6
        default: newInterval = Int((Double(interval) * easeFactor).rounded())
        }

        let q = Double(5 - quality)
        let newEF = max(1.3, easeFactor + 0.1 - q * (0.08 + q * 0.02))

        return Result(
            interval: newInterval,
            easeFactor: newEF,
            repetitions: repetitions + 1,
            nextReview: today.adding(days: newInterval))
    }

    /// Human label for the interval a rating would produce ("<1m", "1d", "6d"...).
    static func intervalPreview(for card: VocabCard, quality: Int) -> String {
        if quality < 3 { return "<1m" }
        let result = schedule(
            interval: card.interval,
            easeFactor: card.easeFactor,
            repetitions: card.repetitions,
            quality: quality)
        return "\(result.interval)d"
    }
}
