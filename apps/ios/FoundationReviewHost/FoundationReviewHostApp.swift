import SwiftUI

@main
struct FoundationReviewHostApp: App {
    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.arguments.contains("-homeReview") {
                HomeReviewView()
            } else if ProcessInfo.processInfo.arguments.contains("-activityReview") {
                ActivityReviewView()
            } else {
                FoundationReviewView()
            }
        }
    }
}
