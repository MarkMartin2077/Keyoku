//
//  SettingsView.swift
//  
//
//  
//
import SwiftUI
import SwiftfulUI

struct SettingsView: View {

    @State var presenter: SettingsPresenter

    var body: some View {
        List {
            profileSection
            accountSection
            purchaseSection
            generalSection
            applicationSection
        }
        .lineLimit(1)
        .minimumScaleFactor(0.4)
        .navigationTitle("Settings")
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        Section {
            HStack(spacing: 14) {
                if let imageUrl = presenter.profileImageUrl {
                    ImageLoaderView(urlString: imageUrl)
                        .aspectRatio(1, contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 56, height: 56)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(presenter.profileName ?? "Guest")
                        .font(.headline)

                    if let email = presenter.profileEmail {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if presenter.isAnonymousUser {
                        Text("Anonymous account")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .removeListRowFormatting()
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        Section {
            if presenter.isAnonymousUser {
                settingsRow(icon: "person.badge.plus", title: "Save & back-up account") {
                    presenter.onCreateAccountPressed()
                }
            } else {
                settingsRow(icon: "rectangle.portrait.and.arrow.right", title: "Sign out") {
                    presenter.onSignOutPressed()
                }
            }

            settingsRow(icon: "trash", title: "Delete account", tint: .red) {
                presenter.onDeleteAccountPressed()
            }
        } header: {
            Text("Account")
        }
    }

    // MARK: - Purchases

    private var purchaseSection: some View {
        let isPremium = presenter.isPremium

        return Section {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .foregroundStyle(isPremium ? .yellow : .secondary)
                    .frame(width: 24)

                Text(isPremium ? "Premium" : "Free plan")
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isPremium {
                    Text("MANAGE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.accent)
                }
            }
            .rowFormatting()
            .accessibilityLabel(isPremium ? "Premium plan" : "Free plan")
            .accessibilityHint(isPremium ? "Manage subscription" : "")
            .anyButton(.highlight) {}
            .disabled(!isPremium)
            .removeListRowFormatting()
        } header: {
            Text("Purchases")
        }
    }

    // MARK: - General

    private var generalSection: some View {
        Section {
            settingsRow(icon: "bell.badge", title: "Notifications") {
                presenter.onNotificationsPressed()
            }
        } header: {
            Text("General")
        }
    }

    // MARK: - Application

    private var applicationSection: some View {
        Section {
            settingsRow(icon: "star", title: "Rate us on the App Store") {
                presenter.onRatingsButtonPressed()
            }

            settingsRow(icon: "hand.raised", title: "Privacy Policy") {
                presenter.onPrivacyPolicyPressed()
            }

            settingsRow(icon: "doc.text", title: "Terms of Service") {
                presenter.onTermsOfServicePressed()
            }

            HStack(spacing: 12) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                Text("Version")

                Spacer(minLength: 0)

                Text("\(Utilities.appVersion ?? "") (\(Utilities.buildNumber ?? ""))")
                    .foregroundStyle(.secondary)
            }
            .rowFormatting()
            .removeListRowFormatting()
        } header: {
            Text("Application")
        }
    }

    // MARK: - Helpers

    private func settingsRow(
        icon: String,
        title: String,
        tint: Color = .primary,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint == .primary ? .secondary : tint)
                .frame(width: 24)

            Text(title)
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .rowFormatting()
        .anyButton(.highlight) {
            action()
        }
        .removeListRowFormatting()
    }
}

private struct RowFormattingViewModifier: ViewModifier {
    
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(colorScheme.backgroundPrimary)
    }
}

fileprivate extension View {
    func rowFormatting() -> some View {
        modifier(RowFormattingViewModifier())
    }
}

#Preview("No auth") {
    let container = DevPreview.shared.container()
    container.register(AuthManager.self, service: AuthManager(service: MockAuthService(user: nil)))
    container.register(UserManager.self, service: UserManager(services: MockUserServices(user: nil)))
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    
    return RouterView { router in
        builder.settingsView(router: router)
    }
}
#Preview("Anonymous") {
    let container = DevPreview.shared.container()
    container.register(AuthManager.self, service: AuthManager(service: MockAuthService(user: UserAuthInfo.mock(isAnonymous: true))))
    container.register(UserManager.self, service: UserManager(services: MockUserServices(user: .mock)))
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    
    return RouterView { router in
        builder.settingsView(router: router)
    }
}
#Preview("Not anonymous") {
    let container = DevPreview.shared.container()
    container.register(AuthManager.self, service: AuthManager(service: MockAuthService(user: UserAuthInfo.mock(isAnonymous: false))))
    container.register(UserManager.self, service: UserManager(services: MockUserServices(user: .mock)))
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    
    return RouterView { router in
        builder.settingsView(router: router)
    }
}

extension CoreBuilder {
    
    func settingsView(router: AnyRouter) -> some View {
        SettingsView(
            presenter: SettingsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            )
        )
    }
    
}

extension CoreRouter {
    
    func showSettingsView() {
        router.showScreen(.sheet) { router in
            builder.settingsView(router: router)
        }
    }

}
