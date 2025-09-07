import Cocoa
import SpriteKit

class GameViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let skView = SKView(frame: view.bounds)
        skView.autoresizingMask = [.width, .height]
        view.addSubview(skView)
        let scene = GameScene(size: CGSize(width: 600, height: 400))
        scene.scaleMode = .aspectFit
        skView.presentScene(scene)
        view.window?.makeFirstResponder(scene)
    }
}
