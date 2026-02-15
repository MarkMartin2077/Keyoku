//
//  CreateDeckSuccessOverlay.swift
//  Keyoku
//
//  Created by Mark Martin on 2/13/26.
//

import SwiftUI

struct CreateDeckSuccessOverlay: View {

    let presenter: CreateDeckPresenter
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)

                Text("Generation Complete")
                    .font(.title2)
                    .fontWeight(.bold)

                statsCard

                notesSection

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor)
                        )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 16)
            }
            .padding(24)
        }
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(spacing: 12) {
            if presenter.generatedFlashcardCount > 0 {
                statRow(
                    icon: "rectangle.on.rectangle",
                    label: "Flashcards",
                    value: "\(presenter.generatedFlashcardCount)"
                )
            }

            if presenter.generatedMCCount + presenter.generatedTFCount > 0 {
                let totalQuestions = presenter.generatedMCCount + presenter.generatedTFCount
                statRow(
                    icon: "questionmark.circle",
                    label: "Quiz Questions",
                    value: "\(totalQuestions)"
                )

                if presenter.generatedMCCount > 0 {
                    statSubRow(label: "Multiple Choice", value: "\(presenter.generatedMCCount)")
                }

                if presenter.generatedTFCount > 0 {
                    statSubRow(label: "True & False", value: "\(presenter.generatedTFCount)")
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.accent)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
    }

    private func statSubRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 32)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - Notes

    @ViewBuilder
    private var notesSection: some View {
        VStack(spacing: 8) {
            if presenter.skippedBatches > 0 {
                noteLabel(
                    text: "\(presenter.skippedBatches) section(s) skipped due to content restrictions.",
                    color: .orange
                )
            }

            if let note = presenter.generationNote {
                noteLabel(text: note, color: .secondary)
            }
        }
    }

    private func noteLabel(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }
}
