import Foundation

struct Game: Identifiable {
    let id = UUID()
    let name: String
    let path: URL
}

class GameManager: ObservableObject {
    @Published var games: [Game] = []
    
    private var gamesDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let gamesDir = documents.appendingPathComponent("Games")
        
        if !FileManager.default.fileExists(atPath: gamesDir.path) {
            try? FileManager.default.createDirectory(at: gamesDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        return gamesDir
    }
    
    func scanGames() {
        let dir = gamesDirectory
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            
            self.games = contents.filter { $0.hasDirectoryPath }.map { url in
                Game(name: url.lastPathComponent, path: url)
            }
        } catch {
            print("Failed to scan games: \(error)")
            self.games = []
        }
    }
}
