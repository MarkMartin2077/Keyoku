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

    var body: some View {
        SubscriptionStoreView(productIDs: productIds) {
            VStack(spacing: 16) {
                heroIllustration

                VStack(spacing: 8) {
                    Text("Keyoku Premium")
                        .font(.system(size: 34, weight: .bold, design: .rounded))

                    Text("Unlimited decks, unlimited learning.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .containerBackground(for: .subscriptionStore) {
                ZStack {
                    Color(.systemBackground)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.accentColor.opacity(0.3), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .frame(width: 400, height: 400)
                        .offset(x: -80, y: -300)
                        .blur(radius: 60)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.purple.opacity(0.2), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 180
                            )
                        )
                        .frame(width: 360, height: 360)
                        .offset(x: 120, y: -180)
                        .blur(radius: 50)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.indigo.opacity(0.15), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 140
                            )
                        )
                        .frame(width: 280, height: 280)
                        .offset(x: 60, y: 100)
                        .blur(radius: 40)
                }
            }
        }
        .storeButton(.visible, for: .restorePurchases)
        .subscriptionStoreControlStyle(.prominentPicker)
        .onInAppPurchaseStart(perform: onInAppPurchaseStart)
        .onInAppPurchaseCompletion(perform: onInAppPurchaseCompletion)
    }

    // MARK: - Hero Illustration

    private var heroIllustration: some View {
        ZStack {
            // Back card
            floatingCard(
                color: .purple,
                rotation: -8,
                offset: CGSize(width: -28, height: 12),
                frontText: "A"
            )

            // Middle card
            floatingCard(
                color: .indigo,
                rotation: 4,
                offset: CGSize(width: 24, height: -8),
                frontText: "Q"
            )

            // Front card
            floatingCard(
                color: .accentColor,
                rotation: 0,
                offset: .zero,
                frontText: nil,
                isMain: true
            )
        }
        .frame(height: 220)
    }

    private func floatingCard(
        color: Color,
        rotation: Double,
        offset: CGSize,
        frontText: String?,
        isMain: Bool = false
    ) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                LinearGradient(
                    colors: [color, color.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: isMain ? 180 : 160, height: isMain ? 120 : 105)
            .overlay {
                if isMain {
                    VStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(.white)

                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.white.opacity(0.4))
                                    .frame(height: 4)
                            }
                        }
                        .padding(.horizontal, 24)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white.opacity(0.25))
                            .frame(width: 80, height: 4)
                    }
                } else if let frontText {
                    Text(frontText)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .shadow(color: color.opacity(0.3), radius: 16, x: 0, y: 8)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
    }
}

#Preview {
    StoreKitPaywallView(
        onInAppPurchaseStart: nil,
        onInAppPurchaseCompletion: nil
    )
}
