//
//  StoreKitPaywallView.swift
//  
//
//  
//
import SwiftUI
import StoreKit

struct StoreKitPaywallView: View {

    var productIds: [String] = EntitlementOption.allProductIds
    var onInAppPurchaseStart: ((Product) async -> Void)?
    var onInAppPurchaseCompletion: ((Product, Result<Product.PurchaseResult, any Error>) async -> Void)?

    @State private var savingsPercent: Int?

    var body: some View {
        SubscriptionStoreView(productIDs: productIds) {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("Keyoku Premium")
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text("Unlimited decks, unlimited learning.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    featureRow(text: "Unlimited decks")
                    featureRow(text: "AI flashcard generation")
                    featureRow(text: "Streak tracking & stats")
                }

                if let savingsPercent {
                    Text("Save \(savingsPercent)% with the yearly plan")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.accentColor))
                }
            }
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .task {
                await loadSavings()
            }
            .containerBackground(for: .subscriptionStore) {
                Color(.systemBackground)
            }
        }
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.visible, for: .policies)
        .subscriptionStoreControlStyle(.prominentPicker)
        .subscriptionStorePolicyDestination(url: URL(string: Constants.privacyPolicyUrlString)!, for: .privacyPolicy)
        .subscriptionStorePolicyDestination(url: URL(string: Constants.termsOfServiceUrlString)!, for: .termsOfService)
        .onInAppPurchaseStart(perform: onInAppPurchaseStart)
        .onInAppPurchaseCompletion(perform: onInAppPurchaseCompletion)
    }

    // MARK: - Savings Calculation

    private func loadSavings() async {
        guard let products = try? await Product.products(for: Set(productIds)) else { return }

        let yearly = products.first { $0.subscription?.subscriptionPeriod.unit == .year }
        let monthly = products.first { $0.subscription?.subscriptionPeriod.unit == .month }

        guard let yearlyPrice = yearly?.price, let monthlyPrice = monthly?.price else { return }

        let monthlyAnnual = monthlyPrice * 12
        guard monthlyAnnual > yearlyPrice else { return }

        let savings = monthlyAnnual - yearlyPrice
        let percent = Int(NSDecimalNumber(decimal: savings * 100 / monthlyAnnual).doubleValue.rounded())
        guard percent > 0 else { return }

        savingsPercent = percent
    }

    // MARK: - Feature Row

    private func featureRow(text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.accent)
                .font(.body)
            Text(text)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

}

#Preview {
    StoreKitPaywallView(
        onInAppPurchaseStart: nil,
        onInAppPurchaseCompletion: nil
    )
}
