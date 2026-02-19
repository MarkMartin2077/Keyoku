//
//  SearchView.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI
import SwiftfulUI

struct SearchDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

struct SearchView: View {

    @State var presenter: SearchPresenter
    let delegate: SearchDelegate

    var body: some View {
        List {
            if !presenter.isSearching {
                suggestionsSection
            } else if presenter.filteredDecks.isEmpty {
                noResultsView
            } else {
                decksResultsSection
            }
        }
        .navigationTitle("Search")
        .searchable(text: $presenter.searchText, prompt: "Search decks")
        .onSubmit(of: .search) {
            presenter.onSearchSubmitted()
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    // MARK: - Suggestions

    private var suggestionsSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Search your library")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Find decks by name or card content")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowBackground(Color.clear)
    }

    // MARK: - No Results

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No results found")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Try a different search term")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowBackground(Color.clear)
    }

    // MARK: - Helpers

    private func deckSubtitle(for deck: DeckModel) -> String {
        let cardCount = deck.flashcards.count
        let cardLabel = "\(cardCount) card\(cardCount == 1 ? "" : "s")"
        let matchCount = presenter.matchingCardCount(in: deck)
        if matchCount > 0 {
            return "\(cardLabel) · \(matchCount) match\(matchCount == 1 ? "" : "es")"
        }
        return cardLabel
    }

    // MARK: - Deck Results

    private var decksResultsSection: some View {
        Section {
            ForEach(presenter.filteredDecks) { deck in
                HStack {
                    Circle()
                        .fill(deck.color.color.gradient)
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(deck.name)
                            .font(.headline)
                        Text(deckSubtitle(for: deck))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(deck.name), \(deck.flashcards.count) \(deck.flashcards.count == 1 ? "card" : "cards")")
                .accessibilityHint("Opens deck")
                .anyButton(.highlight) {
                    presenter.onDeckPressed(deck: deck)
                }
            }
        } header: {
            Text("Decks")
        }
    }

}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = SearchDelegate()

    return RouterView { router in
        builder.searchView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {

    func searchView(router: AnyRouter, delegate: SearchDelegate) -> some View {
        SearchView(
            presenter: SearchPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }

}
