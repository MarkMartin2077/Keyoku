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

struct DeckItem: View {
    var deck: DeckModel
    
    var body: some View {
        VStack(spacing: 20) {
            if let imageUrl = deck.imageUrl {
                ImageLoaderView(urlString: imageUrl, resizingMode: .fit)
                    .scaledToFit()
                    .frame(width: 200, height: 200)
            } else {
                Image(systemName: "rectangle.on.rectangle")
                    .font(.system(size: 64))
            }
            Text(deck.name)
                .font(.title)
            if !deck.flashcards.isEmpty {
                Text("Cards: \(deck.flashcards.count)")
                    .font(.subheadline)
                    .padding(.bottom, 16)
            } else {
                ContentUnavailableView("No cards yet. Add some!", systemImage: "plus")
            }
            
        }
        .foregroundStyle(.white)
        .frame(width: 200, height: 200)
        .background(deck.color.color.gradient)
        .clipShape(.rect(cornerRadius: 32))
        .shadow(color: deck.color.color.opacity(0.5), radius: 30, y: 15)
    }
}

struct DecksView: View {
    
    @State var presenter: DecksPresenter
    let delegate: DecksDelegate
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if presenter.decks.isEmpty {
                    emptyStateView
                } else {
                    decksSection
                }
            }
        }
        .navigationTitle("Decks")
        .searchable(text: $presenter.searchText, prompt: "Search decks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                addButton
            }
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
    }
    
    private var decksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(presenter.filteredDecks.count) Deck\(presenter.filteredDecks.count == 1 ? "" : "s")")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .animation(.none, value: presenter.searchText)

            ForEach(presenter.filteredDecks) { deck in
                deckRow(deck: deck)
                    .bouncyScroll()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                if deck.id != presenter.filteredDecks.last?.id {
                    Divider()
                        .padding(.leading)
                }
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.3), value: presenter.searchText)
    }

    private func deckRow(deck: DeckModel) -> some View {
        HStack {
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
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .anyButton(.highlight) {
            presenter.onDeckPressed(deck: deck)
        }
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
