//
//  PaywallPresenter.swift
//  
//
//  
//
import SwiftUI
import StoreKit

@Observable
@MainActor
class PaywallPresenter {
    
    private let interactor: PaywallInteractor
    private let router: PaywallRouter

    private(set) var products: [AnyProduct] = []
    private(set) var productIds: [String] = EntitlementOption.allProductIds
    
    init(interactor: PaywallInteractor, router: PaywallRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear(delegate: PaywallDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: PaywallDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
    
    func onLoadProducts() async {
        interactor.trackEvent(event: Event.loadProductsStart)

        do {
            products = try await interactor.getProducts(productIds: productIds)
            interactor.trackEvent(event: Event.loadProductsSuccess)
        } catch {
            interactor.trackEvent(event: Event.loadProductsFail(error: error))
            router.showAlert(error: error)
        }
    }
    
    func onBackButtonPressed() {
        interactor.trackEvent(event: Event.backButtonPressed)
        router.dismissScreen()
    }
    
    func onRestorePurchasePressed() {
        interactor.trackEvent(event: Event.restorePurchaseStart)

        Task {
            do {
                let entitlements = try await interactor.restorePurchase()

                if entitlements.hasActiveEntitlement {
                    interactor.trackEvent(event: Event.restorePurchaseSuccess)
                    router.dismissScreen()
                } else {
                    interactor.trackEvent(event: Event.restorePurchaseNoEntitlements)
                }
            } catch {
                interactor.trackEvent(event: Event.restorePurchaseFail(error: error))
                router.showAlert(error: error)
            }
        }
    }
    
    func onPurchaseProductPressed(product: AnyProduct) {
        interactor.trackEvent(event: Event.purchaseStart(product: product))

        Task {
            do {
                let entitlements = try await interactor.purchaseProduct(productId: product.id)
                interactor.trackEvent(event: Event.purchaseSuccess(product: product))

                if entitlements.hasActiveEntitlement {
                    router.dismissScreen()
                }
            } catch {
                interactor.trackEvent(event: Event.purchaseFail(error: error))
                router.showAlert(error: error)
            }
        }
    }
    
    func onPurchaseStart(product: StoreKit.Product) {
        let product = AnyProduct(storeKitProduct: product)
        interactor.trackEvent(event: Event.purchaseStart(product: product))
    }
    
    func onPurchaseComplete(product: StoreKit.Product, result: Result<Product.PurchaseResult, any Error>) {
        let product = AnyProduct(storeKitProduct: product)

        switch result {
        case .success(let value):
            switch value {
            case .success:
                interactor.trackEvent(event: Event.purchaseSuccess(product: product))
                router.dismissScreen()
            case .pending:
                interactor.trackEvent(event: Event.purchasePending(product: product))
            case .userCancelled:
                interactor.trackEvent(event: Event.purchaseCancelled(product: product))
            default:
                interactor.trackEvent(event: Event.purchaseUnknown(product: product))
            }
        case .failure(let error):
            interactor.trackEvent(event: Event.purchaseFail(error: error))
        }
    }
    
}

extension PaywallPresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: PaywallDelegate)
        case onDisappear(delegate: PaywallDelegate)
        case purchaseStart(product: AnyProduct)
        case purchaseSuccess(product: AnyProduct)
        case purchasePending(product: AnyProduct)
        case purchaseCancelled(product: AnyProduct)
        case purchaseUnknown(product: AnyProduct)
        case purchaseFail(error: Error)
        case loadProductsStart
        case loadProductsSuccess
        case loadProductsFail(error: Error)
        case restorePurchaseStart
        case restorePurchaseSuccess
        case restorePurchaseNoEntitlements
        case restorePurchaseFail(error: Error)
        case backButtonPressed

        var eventName: String {
            switch self {
            case .onAppear:               return "Paywall_Appear"
            case .onDisappear:            return "Paywall_Disappear"
            case .purchaseStart:          return "Paywall_Purchase_Start"
            case .purchaseSuccess:        return "Paywall_Purchase_Success"
            case .purchasePending:        return "Paywall_Purchase_Pending"
            case .purchaseCancelled:      return "Paywall_Purchase_Cancelled"
            case .purchaseUnknown:        return "Paywall_Purchase_Unknown"
            case .purchaseFail:           return "Paywall_Purchase_Fail"
            case .loadProductsStart:              return "Paywall_Load_Start"
            case .loadProductsSuccess:            return "Paywall_Load_Success"
            case .loadProductsFail:               return "Paywall_Load_Fail"
            case .restorePurchaseStart:           return "Paywall_Restore_Start"
            case .restorePurchaseSuccess:         return "Paywall_Restore_Success"
            case .restorePurchaseNoEntitlements:  return "Paywall_Restore_NoEntitlements"
            case .restorePurchaseFail:            return "Paywall_Restore_Fail"
            case .backButtonPressed:              return "Paywall_BackButton_Pressed"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .purchaseStart(product: let product), .purchaseSuccess(product: let product), .purchasePending(product: let product), .purchaseCancelled(product: let product), .purchaseUnknown(product: let product):
                return product.eventParameters
            case .purchaseFail(error: let error), .loadProductsFail(error: let error), .restorePurchaseFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .purchaseFail, .loadProductsFail, .restorePurchaseFail:
                return .severe
            default:
                return .analytic
            }
        }
    }

}
