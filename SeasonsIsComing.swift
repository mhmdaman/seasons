import Cocoa
import SpriteKit

// MARK: - Seasons
enum Shape { case dot, leaf, petal }

struct Season {
    let name: String
    let shape: Shape
    let palette: [NSColor]
    let count: Int
    let fallSpeed: CGFloat
    let sizeScale: CGFloat
    let swayScale: CGFloat
    let spin: CGFloat
    let flip: Bool
    let twinkle: Bool
    let minAlpha: CGFloat
    let additive: Bool
}

func makeSeason(_ name: String) -> Season? {
    func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
        NSColor(calibratedRed: r, green: g, blue: b, alpha: 1)
    }
    switch name {
    case "winter":
        return Season(name: "winter", shape: .dot, palette: [.white],
                      count: 260, fallSpeed: 1.5, sizeScale: 1.0, swayScale: 1.0,
                      spin: 0, flip: false, twinkle: false, minAlpha: 0, additive: false)
    case "autumn":
        return Season(name: "autumn", shape: .leaf,
                      palette: [c(0.85, 0.30, 0.10), c(0.95, 0.60, 0.10),
                                c(0.70, 0.15, 0.10), c(0.85, 0.75, 0.20),
                                c(0.55, 0.30, 0.10)],
                      count: 90, fallSpeed: 0.9, sizeScale: 2.4, swayScale: 1.8,
                      spin: 1.6, flip: true, twinkle: false, minAlpha: 0.85, additive: false)
    case "spring":
        return Season(name: "spring", shape: .petal,
                      palette: [c(1.0, 0.78, 0.85), c(1.0, 0.88, 0.92), c(0.97, 0.65, 0.78)],
                      count: 130, fallSpeed: 0.7, sizeScale: 1.9, swayScale: 1.5,
                      spin: 1.0, flip: true, twinkle: false, minAlpha: 0.8, additive: false)
    case "summer":
        return Season(name: "summer", shape: .dot,
                      palette: [c(1.0, 0.92, 0.45), c(0.85, 1.0, 0.45)],
                      count: 70, fallSpeed: 0.12, sizeScale: 1.6, swayScale: 1.4,
                      spin: 0, flip: false, twinkle: true, minAlpha: 0.5, additive: true)
    default:
        return nil
    }
}

// MARK: - Settings
struct Layer {
    let size: ClosedRange<CGFloat>
    let speed: ClosedRange<CGFloat>
    let alpha: ClosedRange<CGFloat>
    let sway: ClosedRange<CGFloat>
    let wind: CGFloat
    let z: CGFloat
}

let layers: [Layer] = [
    Layer(size: 1.8...3.0, speed: 22...38,  alpha: 0.30...0.50, sway: 5...10,  wind: 0.5, z: 1),
    Layer(size: 3.0...4.8, speed: 40...65,  alpha: 0.60...0.80, sway: 9...16,  wind: 0.8, z: 2),
    Layer(size: 4.8...7.5, speed: 70...105, alpha: 0.85...1.00, sway: 14...24, wind: 1.1, z: 7),
]

enum Cfg {
    static let pollInterval: CGFloat = 1.0 / 30.0   // how often window positions are read (s)
    static let showDebugOutlines = true             // turn off once piles are working
}

func rnd(_ a: CGFloat, _ b: CGFloat) -> CGFloat { CGFloat.random(in: a...b) }

// MARK: - Textures (white, so they can be tinted)
@MainActor func makeTexture(_ shape: Shape) -> SKTexture {
    let s: CGFloat = 64
    let img = NSImage(size: NSSize(width: s, height: s), flipped: false) { _ in
        guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
        switch shape {
        case .dot:
            let colors = [
                CGColor(red: 1, green: 1, blue: 1, alpha: 1.0),
                CGColor(red: 1, green: 1, blue: 1, alpha: 0.6),
                CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
            ] as CFArray
            let locs: [CGFloat] = [0, 0.45, 1]
            guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors, locations: locs) else { return false }
            let c = CGPoint(x: s / 2, y: s / 2)
            ctx.drawRadialGradient(grad, startCenter: c, startRadius: 0,
                                   endCenter: c, endRadius: s / 2, options: [])
        case .leaf:
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 6, y: 32))
            p.addQuadCurve(to: CGPoint(x: 58, y: 32), control: CGPoint(x: 32, y: 66))
            p.addQuadCurve(to: CGPoint(x: 6, y: 32), control: CGPoint(x: 32, y: -2))
            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            ctx.addPath(p)
            ctx.fillPath()
            ctx.setStrokeColor(CGColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1))
            ctx.setLineWidth(1.6)
            ctx.move(to: CGPoint(x: 4, y: 32))
            ctx.addLine(to: CGPoint(x: 56, y: 32))
            ctx.strokePath()
        case .petal:
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 32, y: 6))
            p.addCurve(to: CGPoint(x: 32, y: 54),
                       control1: CGPoint(x: 64, y: 22), control2: CGPoint(x: 58, y: 62))
            p.addCurve(to: CGPoint(x: 32, y: 6),
                       control1: CGPoint(x: 6, y: 62), control2: CGPoint(x: 0, y: 22))
            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            ctx.addPath(p)
            ctx.fillPath()
        }
        return true
    }
    return SKTexture(image: img)
}

// MARK: - One particle
@MainActor final class Flake {
    let node: SKSpriteNode
    var fallSpeed: CGFloat = 50
    var swayAmp: CGFloat = 10
    var swayFreq: CGFloat = 1
    var phase: CGFloat = 0
    var windFactor: CGFloat = 1
    var spinRate: CGFloat = 0
    var baseAlpha: CGFloat = 1
    var flipFreq: CGFloat = 1
    init(texture: SKTexture) { node = SKSpriteNode(texture: texture) }
}

// MARK: - Scene
final class SeasonScene: SKScene {
    var season = makeSeason("winter")!
    var flakes: [Flake] = []
    var pool: [Flake] = []
    var tex: SKTexture?
    var lastT: TimeInterval = 0
    var t: CGFloat = 0
    let world = SKNode()

    // window tracking
    let myPID = getpid()
    var pollAcc: CGFloat = 0
    var outlines: [Int: SKShapeNode] = [:]          // window number -> debug outline
    var order: [(id: Int, rect: CGRect)] = []       // windows, front to back (SpriteKit coordinates)
    var lastCount = -1

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        tex = makeTexture(season.shape)
        addChild(world)
        for _ in 0..<season.count { spawnFlake(y: rnd(0, size.height)) }
    }

    func obtain() -> Flake {
        let f = pool.popLast() ?? Flake(texture: tex!)
        world.addChild(f.node)
        flakes.append(f)
        return f
    }

    func recycle(at i: Int) {
        let f = flakes[i]
        f.node.removeFromParent()
        flakes.swapAt(i, flakes.count - 1)
        flakes.removeLast()
        pool.append(f)
    }

    func spawnFlake(y: CGFloat? = nil) {
        let f = obtain()
        let r = CGFloat.random(in: 0...1)
        let li = r < 0.40 ? 0 : (r < 0.68 ? 1 : 2)
        let L = layers[li]
        let s = CGFloat.random(in: L.size) * season.sizeScale

        f.fallSpeed = CGFloat.random(in: L.speed) * season.fallSpeed
        f.swayAmp = CGFloat.random(in: L.sway) * season.swayScale
        f.swayFreq = rnd(0.6, 1.6)
        f.phase = rnd(0, 6.28)
        f.windFactor = L.wind
        f.flipFreq = rnd(1.5, 3.5)
        f.spinRate = season.spin * rnd(0.4, 1.0) * (Bool.random() ? 1 : -1)
        f.baseAlpha = max(CGFloat.random(in: L.alpha), season.minAlpha)

        f.node.color = season.palette.randomElement()!
        f.node.colorBlendFactor = 1
        f.node.blendMode = season.additive ? .add : .alpha
        f.node.alpha = f.baseAlpha
        f.node.size = CGSize(width: s * 2.2, height: s * 2.2)
        f.node.zRotation = season.spin > 0 ? rnd(0, 6.28) : 0
        f.node.xScale = 1
        f.node.zPosition = L.z
        f.node.position = CGPoint(x: rnd(-40, self.size.width + 40),
                                  y: y ?? self.size.height + rnd(2, 30))
    }

    // MARK: Windows
    /// Read every on-screen window and convert its frame to SpriteKit coordinates.
    /// macOS reports y from the TOP of the screen; SpriteKit counts from the BOTTOM, so we flip it.
    func pollWindows() {
        let H = size.height
        var newOrder: [(id: Int, rect: CGRect)] = []

        if let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                 kCGNullWindowID) as? [[String: Any]] {
            for w in info {
                guard let layerN = w[kCGWindowLayer as String] as? NSNumber, layerN.intValue == 0,   // normal windows only
                      let pidN = w[kCGWindowOwnerPID as String] as? NSNumber, pidN.int32Value != myPID, // not our overlay
                      let numN = w[kCGWindowNumber as String] as? NSNumber,
                      let bd = w[kCGWindowBounds as String] as? NSDictionary,
                      let b = CGRect(dictionaryRepresentation: bd as CFDictionary) else { continue }
                let alpha = (w[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
                if alpha < 0.05 || b.width < 80 || b.height < 40 { continue }   // ignore tiny / invisible ones
                newOrder.append((id: numN.intValue,
                                 rect: CGRect(x: b.minX, y: H - b.maxY, width: b.width, height: b.height)))
            }
        }
        order = newOrder

        if newOrder.count != lastCount {
            lastCount = newOrder.count
            print("Windows found: \(newOrder.count)")
        }

        if Cfg.showDebugOutlines { updateOutlines() }
    }

    /// Debug view: cyan frame around each window, thick magenta line on its TOP edge
    func updateOutlines() {
        let alive = Set(order.map { $0.id })
        for (id, node) in outlines where !alive.contains(id) {
            node.removeFromParent()
            outlines[id] = nil
        }
        for item in order {
            let node: SKShapeNode
            let top: SKShapeNode
            if let n = outlines[item.id] {
                node = n
                top = n.childNode(withName: "top") as! SKShapeNode
            } else {
                node = SKShapeNode()
                node.strokeColor = NSColor.cyan.withAlphaComponent(0.8)
                node.fillColor = .clear
                node.lineWidth = 1.5
                node.zPosition = 20
                top = SKShapeNode()
                top.name = "top"
                top.strokeColor = .magenta
                top.lineWidth = 4
                top.zPosition = 1
                node.addChild(top)
                addChild(node)
                outlines[item.id] = node
            }
            let r = item.rect
            node.path = CGPath(rect: r, transform: nil)
            let line = CGMutablePath()
            line.move(to: CGPoint(x: r.minX, y: r.maxY))
            line.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            top.path = line
        }
    }

    // MARK: Per-frame update
    override func update(_ currentTime: TimeInterval) {
        if lastT == 0 { lastT = currentTime }
        let dt = CGFloat(min(currentTime - lastT, 1.0 / 20.0))
        lastT = currentTime
        t += dt

        pollAcc += dt
        if pollAcc >= Cfg.pollInterval {
            pollAcc = 0
            pollWindows()
        }

        let wind = sin(t * 0.15) * 12 + 8

        var i = flakes.count - 1
        while i >= 0 {
            let f = flakes[i]
            let sway = cos(t * f.swayFreq + f.phase) * f.swayAmp
            var p = f.node.position
            p.x += (sway + wind * f.windFactor) * dt
            p.y -= f.fallSpeed * dt
            if p.x > size.width + 40 { p.x = -40 }
            if p.x < -40 { p.x = size.width + 40 }
            f.node.position = p

            if season.spin > 0 { f.node.zRotation += f.spinRate * dt }
            if season.flip {
                f.node.xScale = 0.25 + 0.75 * abs(cos(t * f.flipFreq + f.phase))
            }
            if season.twinkle {
                f.node.alpha = f.baseAlpha * (0.35 + 0.65 * (0.5 + 0.5 * sin(t * f.flipFreq + f.phase)))
            }

            if p.y < -20 {
                recycle(at: i)
                spawnFlake()
            }
            i -= 1
        }
    }
}

// MARK: - Choose the season:  ./SeasonsIsComing autumn
let requested = CommandLine.arguments.dropFirst().first ?? "winter"
guard let chosen = makeSeason(requested) else {
    print("Unknown season '\(requested)'. Use: winter, autumn, spring or summer")
    exit(1)
}
print("Season: \(chosen.name)   (Ctrl+C to quit)")

// MARK: - Window setup
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
scene.season = chosen
scene.scaleMode = .resizeFill
skView.presentScene(scene)

window.contentView = skView
window.makeKeyAndOrderFront(nil)

app.run()
