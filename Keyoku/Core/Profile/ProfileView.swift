import SwiftUI
import SwiftfulUI

struct ProfileDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

struct ProfileView: View {

    @State var presenter: ProfilePresenter
    let delegate: ProfileDelegate

    var body: some View {
        List {
            profileHeaderSection
            studyStatsSection
            accountSection
        }
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                settingsButton
            }
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    // MARK: - Profile Header

    private var profileHeaderSection: some View {
        Section {
            VStack(spacing: 16) {
                if let imageUrl = presenter.profileImageUrl {
                    ImageLoaderView(urlString: imageUrl)
                        .aspectRatio(1, contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    Text(presenter.profileName ?? "Guest")
                        .font(.title2)
                        .fontWeight(.semibold)

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

                if presenter.isAnonymousUser {
                    Text("Save & back-up account")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.accent)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.accent.opacity(0.15))
                        }
                        .anyButton(.press) {
                            presenter.onCreateAccountPressed()
                        }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .removeListRowFormatting()
        }
    }

    // MARK: - Study Stats

    private var studyStatsSection: some View {
        Section {
            statRow(icon: "flame.fill", iconColor: .orange, label: "Day Streak", value: "\(presenter.currentStreak)")
            statRow(icon: "menucard.fill", iconColor: .blue, label: "Total Decks", value: "\(presenter.totalDecks)")
            statRow(icon: "rectangle.portrait.on.rectangle.portrait.fill", iconColor: .purple, label: "Total Cards", value: "\(presenter.totalCards)")
            statRow(icon: "checkmark.circle.fill", iconColor: .green, label: "Learned", value: "\(presenter.learnedCards)")
        } header: {
            Text("Study Stats")
        }
    }

    private func statRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 24)

            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        Section {
            if !presenter.isAnonymousUser {
                accountRow(icon: "rectangle.portrait.and.arrow.right", title: "Sign out") {
                    presenter.onSignOutPressed()
                }
            }

            accountRow(icon: "trash", title: "Delete account", tint: .red) {
                presenter.onDeleteAccountPressed()
            }
        } header: {
            Text("Account")
        }
    }

    private func accountRow(
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .anyButton(.highlight) {
            action()
        }
        .removeListRowFormatting()
    }

    // MARK: - Toolbar

    private var settingsButton: some View {
        Image(systemName: "gear")
            .font(.headline)
            .foregroundStyle(.accent)
            .accessibilityLabel("Settings")
            .anyButton {
                presenter.onSettingsButtonPressed()
            }
    }
}

#Preview("Signed in") {
    let container = DevPreview.shared.container()
    container.register(AuthManager.self, service: AuthManager(service: MockAuthService(user: UserAuthInfo.mock(isAnonymous: false))))
    container.register(UserManager.self, service: UserManager(services: MockUserServices(user: .mock)))
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = ProfileDelegate()

    return RouterView { router in
        builder.profileView(router: router, delegate: delegate)
    }
}

#Preview("Anonymous") {
    let container = DevPreview.shared.container()
    container.register(AuthManager.self, service: AuthManager(service: MockAuthService(user: UserAuthInfo.mock(isAnonymous: true))))
    container.register(UserManager.self, service: UserManager(services: MockUserServices(user: .mock)))
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = ProfileDelegate()

    return RouterView { router in
        builder.profileView(router: router, delegate: delegate)
    }
}

#Preview("No auth") {
    let container = DevPreview.shared.container()
    container.register(AuthManager.self, service: AuthManager(service: MockAuthService(user: nil)))
    container.register(UserManager.self, service: UserManager(services: MockUserServices(user: nil)))
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = ProfileDelegate()

    return RouterView { router in
        builder.profileView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {

    func profileView(router: AnyRouter, delegate: ProfileDelegate = ProfileDelegate()) -> some View {
        ProfileView(
            presenter: ProfilePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }

}

extension CoreRouter {

    func showProfileView(delegate: ProfileDelegate) {
        router.showScreen(.push) { router in
            builder.profileView(router: router, delegate: delegate)
        }
    }

}
