import StoreKit
import UIKit

enum AppStoreRatingsHelper {

    private static let hasRequestedReviewKey = "hasRequestedAppStoreReview"

    static var hasRequestedReview: Bool {
        get { UserDefaults.standard.bool(forKey: hasRequestedReviewKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasRequestedReviewKey) }
    }

    @MainActor
    static func requestRatingsReview() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        AppStore.requestReview(in: windowScene)
    }

    @MainActor
    static func requestReviewIfNeeded() {
        guard !hasRequestedReview else { return }
        hasRequestedReview = true
        requestRatingsReview()
    }
}
