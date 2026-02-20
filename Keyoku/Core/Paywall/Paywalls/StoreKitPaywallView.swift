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
            VStack(spacing: 16) {
                heroIllustration

                VStack(spacing: 8) {
                    Text("Keyoku Premium")
                        .font(.system(size: 34, weight: .bold, design: .rounded))

                    Text("Unlimited decks, unlimited learning.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    featureRow(icon: "infinity", text: "Unlimited decks")
                    featureRow(icon: "apple.intelligence", text: "AI flashcard generation")
                    featureRow(icon: "flame.fill", text: "Streak tracking & stats")
                }
                .padding(.top, 4)

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

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.accent)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
        }
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
        .frame(height: 180)
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
            .frame(width: isMain ? 160 : 140, height: isMain ? 105 : 90)
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
