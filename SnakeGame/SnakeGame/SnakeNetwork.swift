import Foundation
import Network

enum NetworkRole {
    case host
    case client
    case none
}

class SnakeNetwork: ObservableObject {
    private var listener: NWListener?
    private var connection: NWConnection?
    private let port: NWEndpoint.Port = 54000
    private let queue = DispatchQueue(label: "SnakeNetwork")
    @Published var receivedPacket: SnakePacket?
    @Published var connected = false
    var role: NetworkRole = .none

    var clientConnections: [String: NWConnection] = [:]
    var hostReceiveHandler: ((String, [Int]) -> Void)?

    func startHost() {
        role = .host
        do {
            listener = try NWListener(using: .tcp, on: port)
        } catch {
            print("Listener启动失败: \(error)")
            return
        }
        listener?.newConnectionHandler = { [weak self] newConn in
            self?.handleNewClient(conn: newConn)
        }
        listener?.start(queue: queue)
        print("主机已开启，端口 \(port)")
    }

    private func handleNewClient(conn: NWConnection) {
        conn.start(queue: queue)
        conn.receive(minimumIncompleteLength: 1, maximumLength: 256) { [weak self] data, _, _, _ in
            if let data = data, let info = try? JSONDecoder().decode([String].self, from: data),
               info.count == 2 {
                let clientID = info[0]
                self?.clientConnections[clientID] = conn
                print("新玩家 \(clientID) 加入")
                self?.receiveClientDir(conn: conn, clientID: clientID)
            }
        }
    }

    private func receiveClientDir(conn: NWConnection, clientID: String) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64) { [weak self] data, _, isComplete, error in
            if let data = data, let dir = try? JSONDecoder().decode([Int].self, from: data) {
                self?.hostReceiveHandler?(clientID, dir)
            }
            if !(isComplete || (error != nil)) {
                self?.receiveClientDir(conn: conn, clientID: clientID)
            }
        }
    }

    func hostBroadcast(_ packet: SnakePacket) {
        let data = try! JSONEncoder().encode(packet)
        for (_, conn) in clientConnections {
            conn.send(content: data, completion: .contentProcessed { _ in })
        }
    }

    func joinGame(hostIP: String, myID: String, myColor: String) {
        role = .client
        let host = NWEndpoint.Host(hostIP)
        connection = NWConnection(host: host, port: port, using: .tcp)
        connection?.start(queue: queue)
        connected = true
        let info = try! JSONEncoder().encode([myID, myColor])
        connection?.send(content: info, completion: .contentProcessed { _ in })
        receive()
    }

    func sendDirection(_ dir: [Int]) {
        guard let connection = connection else { return }
        let data = try! JSONEncoder().encode(dir)
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    private func receive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, isComplete, error in
            if let data = data, let packet = try? JSONDecoder().decode(SnakePacket.self, from: data) {
                DispatchQueue.main.async {
                    self?.receivedPacket = packet
                }
            }
            if !(isComplete || (error != nil)) {
                self?.receive()
            }
        }
    }

    func stop() {
        connection?.cancel()
        listener?.cancel()
        clientConnections.removeAll()
        connected = false
        role = .none
    }
}
