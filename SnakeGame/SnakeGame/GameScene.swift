import SpriteKit

let snakeColorPool = ["red", "green", "blue", "purple", "orange", "cyan"]

func colorFromName(_ name: String) -> SKColor {
    switch name {
    case "red": return .red
    case "green": return .green
    case "blue": return .blue
    case "purple": return .purple
    case "orange": return .orange
    case "cyan": return .cyan
    default: return .white
    }
}

class GameScene: SKScene {
    let cellSize = 20
    let width = 30
    let height = 20

    var myID: String = ""
    var myColor: String = ""
    var food: CGPoint = .zero
    var allPlayers: [PlayerSnake] = []
    var isGameOver = false
    var isStarted = false
    var network: SnakeNetwork?
    var isHost: Bool { network?.role == .host }
    var isClient: Bool { network?.role == .client }

    var lastUpdate: TimeInterval = 0
    let moveInterval: TimeInterval = 0.15

    override var acceptsFirstResponder: Bool { true }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        view.window?.makeFirstResponder(self)
        backgroundColor = .black
        setupHostHandler()
        if allPlayers.isEmpty {
            resetGame()
        }
    }

    func setupHostHandler() {
        if isHost {
            network?.hostReceiveHandler = { [weak self] clientID, dir in
                guard let self = self,
                      let idx = self.allPlayers.firstIndex(where: { $0.id == clientID }) else { return }
                if self.allPlayers[idx].isAlive {
                    self.allPlayers[idx].direction = dir
                }
            }
        }
    }

    func resetGame() {
        isGameOver = false
        isStarted = false
        lastUpdate = 0
        food = randomFoodPosition()
        allPlayers = []
        // 始终加入自己（单机/主机/客户端都适用，客户端后续会被主机同步覆盖）
        allPlayers.append(newPlayerSnake(id: myID, color: myColor))
        removeAllChildren()
        drawAll()
    }

    func newPlayerSnake(id: String, color: String) -> PlayerSnake {
        let body = [[8,8],[7,8],[6,8]]
        return PlayerSnake(id: id, color: color, snake: body, direction: [1,0], isAlive: true)
    }

    func startGame() {
        isStarted = true
        isGameOver = false
        lastUpdate = 0
        removeAllChildren()
        drawAll()
    }

    func randomFoodPosition() -> CGPoint {
        var pos: CGPoint
        repeat {
            pos = CGPoint(x: Int.random(in: 0..<width), y: Int.random(in: 0..<height))
            let posArr = [Int(pos.x), Int(pos.y)]
            if !allPlayers.flatMap({ $0.snake }).contains(where: { $0 == posArr }) {
                break
            }
        } while true
        return pos
    }

    func drawAll() {
        for player in allPlayers where player.isAlive {
            let color = colorFromName(player.color)
            for (i, seg) in player.snake.enumerated() {
                let node = SKShapeNode(rectOf: CGSize(width: cellSize-2, height: cellSize-2))
                node.position = CGPoint(x: CGFloat(seg[0]) * CGFloat(cellSize) + CGFloat(cellSize/2),
                                        y: CGFloat(seg[1]) * CGFloat(cellSize) + CGFloat(cellSize/2))
                node.fillColor = i == 0 ? .white : color
                node.strokeColor = .clear
                addChild(node)
            }
        }
        let foodNode = SKShapeNode(rectOf: CGSize(width: cellSize-2, height: cellSize-2))
        foodNode.position = CGPoint(x: food.x * CGFloat(cellSize) + CGFloat(cellSize/2),
                                    y: food.y * CGFloat(cellSize) + CGFloat(cellSize/2))
        foodNode.fillColor = .yellow
        foodNode.strokeColor = .clear
        addChild(foodNode)
    }

    override func update(_ currentTime: TimeInterval) {
        guard isStarted else { return }
        if currentTime - lastUpdate < moveInterval { return }
        lastUpdate = currentTime

        if isHost || network?.role == .none {
            removeAllChildren()
            moveAllSnakes()
            drawAll()
            if isHost {
                let packet = SnakePacket(
                    allPlayers: allPlayers,
                    food: [Int(food.x), Int(food.y)]
                )
                network?.hostBroadcast(packet)
            }
        } else if isClient {
            if let packet = network?.receivedPacket {
                allPlayers = packet.allPlayers
                food = CGPoint(x: packet.food[0], y: packet.food[1])
                removeAllChildren()
                drawAll()
            }
        }
    }

    func moveAllSnakes() {
        for idx in allPlayers.indices {
            guard allPlayers[idx].isAlive else { continue }
            let dir = allPlayers[idx].direction
            let head = allPlayers[idx].snake.first!
            let newHead = [head[0] + dir[0], head[1] + dir[1]]
            if newHead[0] < 0 || newHead[0] >= width ||
                newHead[1] < 0 || newHead[1] >= height ||
                allPlayers.flatMap({ $0.snake }).contains(where: { $0 == newHead }) {
                allPlayers[idx].isAlive = false
                continue
            }
            allPlayers[idx].snake.insert(newHead, at: 0)
            if newHead == [Int(food.x), Int(food.y)] {
                food = randomFoodPosition()
            } else {
                allPlayers[idx].snake.removeLast()
            }
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isStarted else { return }
        guard let i = allPlayers.firstIndex(where: { $0.id == myID }), allPlayers[i].isAlive else { return }
        let curDir = allPlayers[i].direction
        var newDir = curDir
        switch event.keyCode {
        case 123: if curDir != [1,0] { newDir = [-1,0] }
        case 124: if curDir != [-1,0] { newDir = [1,0] }
        case 125: if curDir != [0,1] { newDir = [0,-1] }
        case 126: if curDir != [0,-1] { newDir = [0,1] }
        default: return
        }
        allPlayers[i].direction = newDir
        if isClient {
            network?.sendDirection(newDir)
        }
    }

    func reviveMe() {
        if let idx = allPlayers.firstIndex(where: { $0.id == myID }) {
            if !allPlayers[idx].isAlive {
                allPlayers[idx] = newPlayerSnake(id: myID, color: myColor)
            }
        } else {
            allPlayers.append(newPlayerSnake(id: myID, color: myColor))
        }
        removeAllChildren()
        drawAll()
    }
}
