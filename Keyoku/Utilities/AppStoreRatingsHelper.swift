import StoreKit
import UIKit

enum AppStoreRatingsHelper {

    @MainActor
    static func requestRatingsReview() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        AppStore.requestReview(in: windowScene)
    }
}
