import Foundation

/// Write-through cloud sync, mirroring js/sync.js:
/// 1. First sign-in on this device: bulk-import any local data, then hydrate from cloud.
/// 2. After that, individual mutations are pushed in the background.
/// 3. Signed-out users are untouched — everything stays local.
final class SyncEngine {
    enum Status: Equatable {
        case idle, syncing, synced, offline
    }

    private let api: APIClient
    private(set) var status: Status = .idle

    init(api: APIClient) {
        self.api = api
    }

    private func importedFlagKey(userID: String) -> String { "kathaluImported:\(userID)" }

    /// Runs the first-login import + hydration. Returns the merged data.
    func activate(userID: String, local: UserData) async -> UserData {
        status = .syncing
        var merged = local

        let flagKey = importedFlagKey(userID: userID)
        let alreadyImported = UserDefaults.standard.bool(forKey: flagKey)

        if !alreadyImported, !local.cards.isEmpty || !local.storyProgress.isEmpty || !local.readingDates.isEmpty {
            let payload = ImportPayload(
                cards: local.cards.values.map {
                    ImportCard(
                        telugu: $0.telugu, trans: $0.trans, meaning: $0.meaning,
                        storyIdx: $0.storyIdx, interval: $0.interval,
                        easeFactor: $0.easeFactor, repetitions: $0.repetitions,
                        nextReview: $0.nextReview, addedAt: $0.addedAt)
                },
                storyProgress: local.storyProgress.map {
                    StoryProgressIn(storyIdx: $0.key, bestPct: $0.value.bestPct)
                },
                readingDays: local.readingDates)
            _ = try? await api.importData(payload)
        }
        UserDefaults.standard.set(true, forKey: flagKey)

        do {
            let cards = try await api.listCards()
            let progress = try await api.listProgress()

            // Cloud wins for scheduling state; local keeps lookup tallies.
            for remote in cards {
                var card = merged.cards[remote.telugu] ?? VocabCard(telugu: remote.telugu)
                card.trans = remote.trans ?? card.trans
                card.meaning = remote.meaning ?? card.meaning
                card.storyIdx = remote.storyIdx ?? card.storyIdx
                card.interval = remote.interval
                card.easeFactor = remote.easeFactor
                card.repetitions = remote.repetitions
                card.nextReview = remote.nextReview
                card.addedAt = remote.addedAt
                card.serverID = remote.id
                merged.cards[remote.telugu] = card
            }
            for entry in progress {
                let local = merged.storyProgress[entry.storyIdx]
                merged.storyProgress[entry.storyIdx] = StoryProgressEntry(
                    bestPct: max(entry.bestPct, local?.bestPct ?? 0),
                    lastRead: DayStamp(date: entry.lastReadAt))
            }
            status = .synced
        } catch {
            status = .offline
        }
        return merged
    }

    // MARK: Background pushes (fire-and-forget; local storage is the source of truth)

    func pushCard(_ card: VocabCard) {
        Task { [api] in
            let sync = CardStateSync(
                telugu: card.telugu, trans: card.trans, meaning: card.meaning,
                storyIdx: card.storyIdx, interval: card.interval,
                easeFactor: card.easeFactor, repetitions: card.repetitions,
                nextReview: card.nextReview, lastQuality: nil)
            await self.push { try await api.syncCardStates(CardStateSyncBatch(cards: [sync])) }
        }
    }

    func pushProgress(storyIdx: Int, bestPct: Int) {
        Task { [api] in
            await self.push { _ = try await api.saveProgress(StoryProgressIn(storyIdx: storyIdx, bestPct: bestPct)) }
        }
    }

    func pushReadingDay(storyIdx: Int, pct: Int?) {
        Task { [api] in
            await self.push { try await api.markReadingDay() }
            await self.push { try await api.recordSession(ReadingSessionIn(storyIdx: storyIdx, pct: pct)) }
        }
    }

    private func push(_ operation: () async throws -> Void) async {
        status = .syncing
        do {
            try await operation()
            status = .synced
        } catch {
            status = .offline
        }
    }
}
