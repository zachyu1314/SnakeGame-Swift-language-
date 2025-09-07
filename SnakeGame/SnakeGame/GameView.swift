import SwiftUI
import SpriteKit

struct GameView: View {
    @StateObject var network = SnakeNetwork()
    @State private var hostIP: String = ""
    @State private var showHostJoin = true

    // 只创建一次 scene！
    @State private var gameScene: GameScene = {
        let scene = GameScene()
        scene.size = CGSize(width: 600, height: 400)
        scene.scaleMode = .aspectFit
        return scene
    }()

    let myID: String = UUID().uuidString
    let myColor: String = snakeColorPool.randomElement()!
    let myIP: String = getWiFiAddress() ?? "IP不可用"

    var body: some View {
        VStack {
            Text("本机IP：\(myIP)").foregroundColor(.gray).padding(.bottom, 4)
            if showHostJoin {
                HStack {
                    Button("主机模式") {
                        network.startHost()
                        setupScene()
                        showHostJoin = false
                    }
                    TextField("主机IP", text: $hostIP)
                        .frame(width: 150)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("加入游戏") {
                        network.joinGame(hostIP: hostIP, myID: myID, myColor: myColor)
                        setupScene()
                        showHostJoin = false
                    }
                    Button("单机模式") {
                        setupScene()
                        showHostJoin = false
                    }
                }.padding()
            }
            if !showHostJoin {
                SpriteView(scene: gameScene)
                    .frame(width: 600, height: 400)
                    .background(Color.black)
                HStack {
                    Button("开始游戏") {
                        gameScene.startGame()
                    }
                    Button("重置") {
                        gameScene.resetGame()
                    }
                    Button("复活自己") {
                        gameScene.reviveMe()
                    }
                    Button("断开连接") {
                        network.stop()
                        showHostJoin = true
                    }
                }
                .padding()
            }
        }
        .frame(width: 650, height: 500)
        .onAppear {
            setupScene()
        }
    }

    private func setupScene() {
        gameScene.myID = myID
        gameScene.myColor = myColor
        gameScene.network = network
        gameScene.resetGame()
    }
}

// 获取本机IP
import SystemConfiguration.CaptiveNetwork

func getWiFiAddress() -> String? {
    var address : String?
    var ifaddr : UnsafeMutablePointer<ifaddrs>?
    if getifaddrs(&ifaddr) == 0 {
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            let interface = ptr!.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                    break
                }
            }
        }
        freeifaddrs(ifaddr)
    }
    return address
}
