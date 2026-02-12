//
//  TabBarView.swift
//  
//
//  
//

import SwiftUI

struct TabBarScreen: Identifiable {
    var id: String {
        title
    }
    
    let title: String
    let systemImage: String
    @ViewBuilder var screen: () -> AnyView
}

struct TabBarView: View {

    var tabs: [TabBarScreen]
    var searchView: (() -> AnyView)?

    var body: some View {
        TabView {
            ForEach(tabs) { tab in
                Tab(tab.title, systemImage: tab.systemImage) {
                    tab.screen()
                }
            }

            if let searchView {
                Tab(role: .search) {
                    searchView()
                }
            }
        }
    }
}

extension CoreBuilder {
    
    func tabbarView() -> some View {
        TabBarView(
            tabs: [
                TabBarScreen(title: "Home", systemImage: "house.fill", screen: {
                    RouterView { router in
                        homeView(router: router, delegate: HomeDelegate())
                    }
                    .any()
                }),
                TabBarScreen(title: "Decks", systemImage: "menucard.fill", screen: {
                    RouterView { router in
                        decksView(router: router, delegate: DecksDelegate())
                    }
                    .any()
                }),
                TabBarScreen(title: "Quizzes", systemImage: "questionmark.circle.fill", screen: {
                    RouterView { router in
                        quizzesView(router: router, delegate: QuizzesDelegate())
                    }
                    .any()
                })
            ],
            searchView: {
                RouterView { router in
                    searchView(router: router, delegate: SearchDelegate())
                }
                .any()
            }
        )
    }

}

#Preview("Fake tabs") {
    TabBarView(
        tabs: [
            TabBarScreen(title: "Explore", systemImage: "eyes", screen: {
                Color.red.any()
            }),
            TabBarScreen(title: "Chats", systemImage: "bubble.left.and.bubble.right.fill", screen: {
                Color.blue.any()
            }),
            TabBarScreen(title: "Profile", systemImage: "person.fill", screen: {
                Color.green.any()
            })
        ]
    )
}

#Preview("Real tabs") {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    
    return builder.tabbarView()
}
