//
//  DecksView.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI
import SwiftfulUI

struct DecksDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

struct DecksView: View {
    
    @State var presenter: DecksPresenter
    let delegate: DecksDelegate
    
    var body: some View {
        List {
            if presenter.decks.isEmpty {
                emptyStateView
            } else {
                decksSection
            }
        }
        .listStyle(.plain)
        .navigationTitle("Decks")
        .searchable(text: $presenter.searchText, prompt: "Search decks")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    ForEach(DeckSortOption.allCases, id: \.self) { option in
                        Button {
                            presenter.onSortOptionSelected(option)
                        } label: {
                            if presenter.sortOption == option {
                                Label(option.title, systemImage: "checkmark")
                            } else {
                                Text(option.title)
                            }
                        }
                    }
                } label: {
                    Image(systemName: presenter.sortOption == .recentlyStudied
                          ? "line.3.horizontal.decrease.circle"
                          : "line.3.horizontal.decrease.circle.fill")
                        .frame(width: 44, height: 44)
                        .accessibilityLabel("Sort decks, \(presenter.sortOption.title)")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                addButton
            }
        }
        .onFirstAppear {
            presenter.onFirstAppear(delegate: delegate)
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No Decks Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Create your first deck to start studying")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Create Deck") {
                presenter.onAddDeckPressed()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    
    private var decksSection: some View {
        Section {
            ForEach(presenter.filteredDecks) { deck in
                deckRow(deck: deck)
            }
            .onDelete { indexSet in
                presenter.onDeleteDecks(at: indexSet)
            }
        } header: {
            Text("^[\(presenter.filteredDecks.count) deck](inflect: true)")
        }
    }

    private func deckRow(deck: DeckModel) -> some View {
        Button {
            presenter.onDeckPressed(deck: deck)
        } label: {
            HStack(spacing: 12) {
                if let imageUrl = deck.displayImageUrlString {
                    ImageLoaderView(urlString: imageUrl)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(deck.color.color.gradient)
                        .frame(width: 44, height: 44)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(deck.name)
                        .font(.headline)
                    Text("\(deck.flashcards.count) card\(deck.flashcards.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(deck.name), \(deck.flashcards.count) \(deck.flashcards.count == 1 ? "card" : "cards")")
        .accessibilityHint("Opens deck details")
    }
    
    private var addButton: some View {
        Button("Add Deck", systemImage: "plus") {
            presenter.onAddDeckPressed()
        }
        .buttonStyle(.glassProminent)
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = DecksDelegate()
    
    return RouterView { router in
        builder.decksView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {
    
    func decksView(router: AnyRouter, delegate: DecksDelegate) -> some View {
        DecksView(
            presenter: DecksPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showDecksView(delegate: DecksDelegate) {
        router.showScreen(.push) { router in
            builder.decksView(router: router, delegate: delegate)
        }
    }
    
}
