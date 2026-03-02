//
//  SRSExplanationBannerView.swift
//  Keyoku
//

import SwiftUI

struct SRSExplanationBannerView: View {

    let onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text("Why are cards \"due\"?")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("The app schedules each card for review right before you're likely to forget it — so your study time stays focused. Review when you're ready.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onDismiss?()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss explanation")
        }
        .padding(.vertical, 6)
        .listRowBackground(Color.secondary.opacity(0.06))
    }
}

#Preview {
    List {
        SRSExplanationBannerView(onDismiss: { })
    }
}
