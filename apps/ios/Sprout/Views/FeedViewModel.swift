//
//  FeedViewModel.swift
//  Sprout
//
//  Created by Michael Dadi on 8/21/25.
//

import StreamFeeds
import Foundation
import Combine

@MainActor class FeedViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    private let feed: Feed
    @Published var activities: [ActivityData] = []

    init(feed: Feed) {
        self.feed = feed
        setupRealtimeUpdates()
    }

    private func setupRealtimeUpdates() {
        feed.state.$activities
            .sink { [weak self] activities in
                self?.activities = activities
            }
            .store(in: &cancellables)
    }
}
