import Cocoa
import SpriteKit

final class SeasonScene: SKScene {
    override func didMove(to view: SKView) {
        backgroundColor = .clear
        let square = SKSpriteNode(color: .red, size: CGSize(width: 80, height: 80))
        square.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(square)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let screenFrame = NSScreen.main!.frame

let window = NSWindow(contentRect: screenFrame,
                      styleMask: .borderless,
                      backing: .buffered,
                      defer: false)
window.isOpaque = false
window.backgroundColor = .clear
window.hasShadow = false
window.level = .statusBar
window.ignoresMouseEvents = true
window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

let skView = SKView(frame: screenFrame)
skView.allowsTransparency = true
let scene = SeasonScene(size: screenFrame.size)
scene.scaleMode = .resizeFill
skView.presentScene(scene)

window.contentView = skView
window.makeKeyAndOrderFront(nil)

app.run()
