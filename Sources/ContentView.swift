import SwiftUI

struct ContentView: View {
    @StateObject private var gameManager = GameManager()
    @State private var selectedGame: Game?
    
    var body: some View {
        NavigationView {
            List(gameManager.games) { game in
                Button(action: {
                    selectedGame = game
                }) {
                    HStack {
                        Image(systemName: "gamecontroller")
                            .foregroundColor(.blue)
                        Text(game.name)
                            .font(.headline)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("TyranoRunner")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        gameManager.scanGames()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(item: $selectedGame) { game in
                GameWebView(gameURL: game.path, gameName: game.name)
                    .edgesIgnoringSafeArea(.all)
            }
            .onAppear {
                gameManager.scanGames()
            }
        }
    }
}
