//
//  OnboardingCompletedPresenter.swift
//  
//
//  
//
import SwiftUI

@Observable
@MainActor
class OnboardingCompletedPresenter {

    static let totalPages = 3

    private let interactor: OnboardingCompletedInteractor
    private let router: OnboardingCompletedRouter

    var currentPage: Int = 0
    private(set) var isCompletingProfileSetup: Bool = false

    var isLastPage: Bool {
        currentPage >= Self.totalPages - 1
    }

    init(interactor: OnboardingCompletedInteractor, router: OnboardingCompletedRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear(delegate: OnboardingCompletedDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: OnboardingCompletedDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    func onPageChanged(_ page: Int) {
        interactor.trackEvent(event: Event.onPageChanged(page: page))
    }

    func onContinuePressed() {
        interactor.trackEvent(event: Event.onContinuePressed(fromPage: currentPage))

        guard !isLastPage else { return }
        currentPage += 1
    }

    func onFinishButtonPressed() {
        isCompletingProfileSetup = true
        interactor.trackEvent(event: Event.finishStart)

        Task {
            do {
                try await interactor.saveOnboardingComplete()
                interactor.trackEvent(event: Event.finishSuccess)

                router.switchToCoreModule()
            } catch {
                router.showAlert(error: error)
                interactor.trackEvent(event: Event.finishFail(error: error))
            }

            isCompletingProfileSetup = false
        }
    }

    enum Event: LoggableEvent {
        case onAppear(delegate: OnboardingCompletedDelegate)
        case onDisappear(delegate: OnboardingCompletedDelegate)
        case onPageChanged(page: Int)
        case onContinuePressed(fromPage: Int)
        case finishStart
        case finishSuccess
        case finishFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:            return "OnboardingView_Appear"
            case .onDisappear:         return "OnboardingView_Disappear"
            case .onPageChanged:       return "OnboardingView_Page_Changed"
            case .onContinuePressed:   return "OnboardingView_Continue_Pressed"
            case .finishStart:         return "OnboardingView_Finish_Start"
            case .finishSuccess:       return "OnboardingView_Finish_Success"
            case .finishFail:          return "OnboardingView_Finish_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .onPageChanged(page: let page):
                return ["page": page]
            case .onContinuePressed(fromPage: let page):
                return ["from_page": page]
            case .finishFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .finishFail:
                return .severe
            default:
                return .analytic
            }
        }
    }

}
