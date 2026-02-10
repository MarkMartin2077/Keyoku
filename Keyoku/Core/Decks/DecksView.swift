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
    
    @State private var showCreateDeckAlert: Bool = false
    @State private var newDeckName: String = ""

    var body: some View {
        List {
            if presenter.decks.isEmpty {
                emptyStateView
            } else {
                decksSection
            }
        }
        .navigationTitle("Decks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                addButton
            }
        }
        .alert("Create New Deck", isPresented: $showCreateDeckAlert) {
            TextField("Deck Name", text: $newDeckName)
            Button("Cancel", role: .cancel) {
                newDeckName = ""
            }
            Button("Create") {
                presenter.onCreateDeckPressed(name: newDeckName)
                newDeckName = ""
            }
        } message: {
            Text("Enter a name for your new deck")
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
                showCreateDeckAlert = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowBackground(Color.clear)
    }
    
    private var decksSection: some View {
        Section {
            ForEach(presenter.decks) { deck in
                deckRow(deck: deck)
            }
            .onDelete { indexSet in
                presenter.onDeleteDecks(at: indexSet)
            }
        } header: {
            Text("\(presenter.decks.count) Deck\(presenter.decks.count == 1 ? "" : "s")")
        }
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
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .anyButton(.highlight) {
            presenter.onDeckPressed(deck: deck)
        }
    }
    
    private var addButton: some View {
//        Image(systemName: "plus")
//            .anyButton(.press) {
//                showCreateDeckAlert = true
//            }
        
        Button("Add Deck", systemImage: "plus") {
            showCreateDeckAlert = true
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
