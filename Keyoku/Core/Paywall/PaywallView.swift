//
//  PaywallView.swift
//  
//
//  
//

import SwiftUI

struct PaywallDelegate {

    let source: String

    init(source: String = "unknown") {
        self.source = source
    }

    var eventParameters: [String: Any]? {
        ["paywall_source": source]
    }
}

struct PaywallView: View {
    
    @State var presenter: PaywallPresenter
    let delegate: PaywallDelegate

    var body: some View {
        ZStack {
            storeKitPaywall
            // customPaywall

            if presenter.isProcessingPurchase {
                purchaseProcessingOverlay
            }
        }
        .task {
            await presenter.onLoadProducts()
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    private var purchaseProcessingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.4)

                Text("Processing purchase...")
                    .foregroundStyle(.white)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
    
    private var storeKitPaywall: some View {
        StoreKitPaywallView(
            productIds: presenter.productIds,
            onInAppPurchaseStart: presenter.onPurchaseStart,
            onInAppPurchaseCompletion: { (product, result) in
                presenter.onPurchaseComplete(product: product, result: result)
            }
        )
    }
    
    @ViewBuilder
    private var customPaywall: some View {
        if presenter.products.isEmpty {
            ProgressView()
        } else {
            CustomPaywallView(
                products: presenter.products,
                onBackButtonPressed: {
                    presenter.onBackButtonPressed()
                },
                onRestorePurchasePressed: {
                    presenter.onRestorePurchasePressed()
                },
                onPurchaseProductPressed: { product in
                    presenter.onPurchaseProductPressed(product: product)
                }
            )
        }
    }
    
}

#Preview("Paywall") {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return RouterView { router in
        builder.paywallView(router: router)
    }
}

extension CoreBuilder {
    
    func paywallView(router: AnyRouter, delegate: PaywallDelegate = PaywallDelegate()) -> some View {
        PaywallView(
            presenter: PaywallPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }

}

extension CoreRouter {
    
    func showPaywallView(delegate: PaywallDelegate = PaywallDelegate()) {
        router.showScreen(.sheet) { router in
            builder.paywallView(router: router, delegate: delegate)
        }
    }

}
