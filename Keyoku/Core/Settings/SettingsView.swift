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
            legalSection
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

    // MARK: - Legal

    private var legalSection: some View {
        Section {
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

#Preview {
    let container = DevPreview.shared.container()
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
