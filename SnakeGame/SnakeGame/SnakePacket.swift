import Foundation

struct PlayerSnake: Codable, Equatable {
    var id: String
    var color: String
    var snake: [[Int]]
    var direction: [Int]
    var isAlive: Bool
}

struct SnakePacket: Codable {
    var allPlayers: [PlayerSnake]
    var food: [Int]
}
