import Cocoa
import SpriteKit
import ServiceManagement
import ApplicationServices

// =============================================================================
// SeasonsIsComing.swift
// Complete macOS desktop overlay app: falling particles, responsive piles,
// snow clumps on window moves, snowball rolling, picking up, stacking,
// characters (snowman, scarecrow, flower creature), menu bar controls & persistence.
// =============================================================================

// MARK: - 1. Seasons & Configuration

enum Shape { case dot, leaf, petal }

struct Season {
    let name: String
    let symbol: String          // Menu bar symbol: winter ❄︎, autumn 🍂, spring 🌸, summer ✺
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
    // Piles
    let pileTop: NSColor       // Colour of the pile surface
    let pileShade: NSColor     // Darker colour underneath (shadow/depth)
    let pileMax: CGFloat       // Max pile height on a window (0 = nothing piles on windows)
    let groundMax: CGFloat     // Max pile height at the bottom of the screen (0 = none)
    let pileAmount: CGFloat    // How much each landing particle adds
    // Balls (Snowball / Leaf ball / Petal clump)
    let ballColor: NSColor     // Primary highlight colour (top-left lit)
    let ballShade: NSColor     // Base/shadow colour of ball
    let speckColor: NSColor    // Specks that rotate to show ball rolling
}

func makeSeason(_ name: String) -> Season? {
    func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
        NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
    }
    switch name.lowercased() {
    case "winter":
        return Season(name: "winter", symbol: "❄︎", shape: .dot, palette: [.white],
                      count: 260, fallSpeed: 1.5, sizeScale: 1.0, swayScale: 1.0,
                      spin: 0, flip: false, twinkle: false, minAlpha: 0, additive: false,
                      pileTop: c(1, 1, 1, 0.97), pileShade: c(0.70, 0.78, 0.92, 0.9),
                      pileMax: 16, groundMax: 34, pileAmount: 0.6,
                      ballColor: c(1.0, 1.0, 1.0, 1.0),
                      ballShade: c(0.75, 0.82, 0.92, 0.95),
                      speckColor: c(0.55, 0.60, 0.68, 0.65))
    case "autumn":
        return Season(name: "autumn", symbol: "🍂", shape: .leaf,
                      palette: [c(0.85, 0.30, 0.10), c(0.95, 0.60, 0.10),
                                c(0.70, 0.15, 0.10), c(0.85, 0.75, 0.20),
                                c(0.55, 0.30, 0.10)],
                      count: 90, fallSpeed: 0.85, sizeScale: 2.4, swayScale: 1.2,
                      spin: 0, flip: false, twinkle: false, minAlpha: 0.85, additive: false,
                      pileTop: c(0.80, 0.45, 0.12, 0.97), pileShade: c(0.45, 0.22, 0.08, 0.9),
                      pileMax: 12, groundMax: 26, pileAmount: 3.0,
                      ballColor: c(0.78, 0.44, 0.14, 1.0),
                      ballShade: c(0.45, 0.22, 0.08, 0.95),
                      speckColor: c(0.32, 0.14, 0.05, 0.85))
    case "spring":
        return Season(name: "spring", symbol: "🌸", shape: .petal,
                      palette: [c(1.0, 0.78, 0.85), c(1.0, 0.88, 0.92), c(0.97, 0.65, 0.78)],
                      count: 90, fallSpeed: 0.85, sizeScale: 2.4, swayScale: 1.2,
                      spin: 0, flip: false, twinkle: false, minAlpha: 0.85, additive: false,
                      pileTop: c(1.0, 0.85, 0.90, 0.97), pileShade: c(0.85, 0.55, 0.65, 0.9),
                      pileMax: 9, groundMax: 20, pileAmount: 2.5,
                      ballColor: c(0.98, 0.82, 0.88, 1.0),
                      ballShade: c(0.85, 0.55, 0.65, 0.95),
                      speckColor: c(0.70, 0.35, 0.48, 0.75))
    case "summer":
        return Season(name: "summer", symbol: "✺", shape: .dot,
                      palette: [c(1.0, 0.92, 0.45), c(0.85, 1.0, 0.45)],
                      count: 70, fallSpeed: 0.12, sizeScale: 1.6, swayScale: 1.4,
                      spin: 0, flip: false, twinkle: true, minAlpha: 0.5, additive: true,
                      pileTop: .clear, pileShade: .clear,
                      pileMax: 0, groundMax: 0, pileAmount: 0,
                      ballColor: .clear, ballShade: .clear, speckColor: .clear)
    default:
        return nil
    }
}

// Global settings
enum Cfg {
    static let pollInterval: CGFloat = 1.0 / 30.0   // Window positions poll rate (s)
    static let colW: CGFloat = 3                    // Width of one column of a pile (px)
    static let groundGain: CGFloat = 4              // Ground pile grows faster than window tops
    static let showDebugOutlines = false            // Set true to show window frames
    static let hideInFullscreen = true              // Hide overlay while a fullscreen app is active

    // Particle ramp-up & budget
    static let rampUpSeconds: CGFloat = 8.5         // Staggered particle appearance from above

    // Snow clumps falling when window moves
    static let clumpGravity: CGFloat = 900.0        // px/s^2
    static let clumpIgnoreDuration: CGFloat = 0.35  // Clumps ignore source pile for 0.35s
    static let maxClumps: Int = 900                 // Clump budget cap

    // Snowball rolling & physics
    static let ballMinRadius: CGFloat = 5.0         // Initial radius when starting to roll
    static let ballMaxRadius: CGFloat = 28.0        // Max radius for rolled snowballs
    static let leafMinDim: CGFloat = 14.0           // Minimum size for autumn leaves (small)
    static let leafMaxDim: CGFloat = 36.0           // Maximum size for autumn leaves (includes slightly bigger leaves)
    static let maxBalls: Int = 20                   // Max resting/rolling balls on screen
    static let ballGravity: CGFloat = 900.0         // px/s^2 for falling balls
    static let stackHorizontalTolerance: CGFloat = 0.9 // Drop above within 0.9 lower radius

    // Monitor strategy: We select the primary screen containing the menu bar (screens.first),
    // which aligns directly with origin (0, 0) and avoids coordinate offset jitter.
    static let monitorChoice = "Primary display with menu bar"
}

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

func rnd(_ a: CGFloat, _ b: CGFloat) -> CGFloat { CGFloat.random(in: a...b) }

// MARK: - 2. Procedural Textures

@MainActor func makeParticleTexture(_ shape: Shape) -> SKTexture {
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

/// Ball body texture: radial gradient lit from the top-left (drawn in code)
@MainActor func makeBallTexture(season: Season) -> SKTexture {
    let s: CGFloat = 128
    let img = NSImage(size: NSSize(width: s, height: s), flipped: false) { _ in
        guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
        let circlePath = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: s, height: s), transform: nil)
        ctx.addPath(circlePath)
        ctx.clip()

        let light = season.ballColor.cgColor
        let shade = season.ballShade.cgColor
        let colors = [light, shade] as CFArray
        let locs: [CGFloat] = [0.0, 1.0]
        guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: colors, locations: locs) else { return false }
        // Lit from top-left: center of start light is at ~35% x, ~65% y (macOS coords)
        let startCenter = CGPoint(x: s * 0.35, y: s * 0.65)
        let endCenter = CGPoint(x: s * 0.5, y: s * 0.5)
        ctx.drawRadialGradient(grad, startCenter: startCenter, startRadius: 0,
                               endCenter: endCenter, endRadius: s * 0.55, options: [.drawsAfterEndLocation])
        return true
    }
    return SKTexture(image: img)
}

/// Rotating specks texture: tiny flecks of dark color so ball rotation is clearly visible
@MainActor func makeSpecksTexture(season: Season) -> SKTexture {
    let s: CGFloat = 128
    let img = NSImage(size: NSSize(width: s, height: s), flipped: false) { _ in
        guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
        let circlePath = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: s, height: s), transform: nil)
        ctx.addPath(circlePath)
        ctx.clip()

        ctx.setFillColor(season.speckColor.cgColor)
        // Draw 14 deterministic specks scattered inside the ball
        let coords: [(CGFloat, CGFloat, CGFloat)] = [
            (0.30, 0.40, 2.2), (0.65, 0.35, 1.8), (0.45, 0.70, 2.0),
            (0.25, 0.65, 1.6), (0.70, 0.65, 2.4), (0.50, 0.25, 1.9),
            (0.35, 0.20, 1.5), (0.80, 0.48, 1.7), (0.20, 0.48, 2.0),
            (0.55, 0.52, 2.5), (0.40, 0.80, 1.6), (0.60, 0.80, 1.8),
            (0.58, 0.15, 1.5), (0.42, 0.45, 2.1)
        ]
        for (rx, ry, r) in coords {
            ctx.fillEllipse(in: CGRect(x: rx * s - r, y: ry * s - r, width: r * 2, height: r * 2))
        }
        return true
    }
    return SKTexture(image: img)
}

// MARK: - Leaf Textures Loader (with automatic background removal)

@MainActor func removeWhiteBackgroundIfNeeded(from image: NSImage) -> NSImage {
    guard let tiff = image.tiffRepresentation,
          let sourceRep = NSBitmapImageRep(data: tiff),
          let cgImage = sourceRep.cgImage else { return image }
    
    let w = cgImage.width
    let h = cgImage.height
    guard w > 0, h > 0 else { return image }
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    var cornerPixels = [UInt32](repeating: 0, count: 4)
    guard let cornerCtx = CGContext(data: &cornerPixels, width: 2, height: 2,
                                    bitsPerComponent: 8, bytesPerRow: 8,
                                    space: colorSpace,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        return image
    }
    cornerCtx.draw(cgImage, in: CGRect(x: 0, y: 0, width: 2, height: 2))
    
    var needsRemoval = false
    for px in cornerPixels {
        let r = CGFloat(px & 0xFF)
        let g = CGFloat((px >> 8) & 0xFF)
        let b = CGFloat((px >> 16) & 0xFF)
        let a = CGFloat((px >> 24) & 0xFF)
        if a > 200 && r > 215 && g > 215 && b > 215 {
            needsRemoval = true
            break
        }
    }
    
    guard needsRemoval else { return image }
    
    guard let ctx = CGContext(data: nil, width: w, height: h,
                              bitsPerComponent: 8, bytesPerRow: w * 4,
                              space: colorSpace,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        return image
    }
    ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
    guard let data = ctx.data else { return image }
    let ptr = data.bindMemory(to: UInt32.self, capacity: w * h)
    
    for i in 0..<(w * h) {
        let px = ptr[i]
        let r = Double(px & 0xFF)
        let g = Double((px >> 8) & 0xFF)
        let b = Double((px >> 16) & 0xFF)
        
        let cmax = max(r, max(g, b))
        let cmin = min(r, min(g, b))
        let sat = (cmax == 0) ? 0 : (cmax - cmin) / cmax
        let bright = (r + g + b) / 3.0
        
        if sat < 0.12 && bright > 215 {
            let fade = max(0.0, min(1.0, (245 - bright) / 30.0))
            if fade <= 0.05 {
                ptr[i] = 0
            } else {
                let newA = UInt32(fade * 255.0)
                ptr[i] = (px & 0x00FFFFFF) | (newA << 24)
            }
        }
    }
    
    guard let outCg = ctx.makeImage() else { return image }
    return NSImage(cgImage: outCg, size: image.size)
}

@MainActor func loadAutumnLeafTextures() -> [SKTexture] {
    let fm = FileManager.default
    var candidateDirs: [URL] = []
    
    if let resUrl = Bundle.main.resourceURL {
        candidateDirs.append(resUrl.appendingPathComponent("leaves"))
    }
    candidateDirs.append(URL(fileURLWithPath: "leaves"))
    candidateDirs.append(Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("leaves"))
    
    for dir in candidateDirs {
        guard fm.fileExists(atPath: dir.path) else { continue }
        if let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            let pngs = files.filter {
                $0.pathExtension.lowercased() == "png" &&
                !$0.lastPathComponent.hasPrefix(".") &&
                !$0.path.contains("originals")
            }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            
            var textures: [SKTexture] = []
            for fileUrl in pngs {
                if let rawImg = NSImage(contentsOf: fileUrl) {
                    let cleaned = removeWhiteBackgroundIfNeeded(from: rawImg)
                    let tex = SKTexture(image: cleaned)
                    textures.append(tex)
                }
            }
            if !textures.isEmpty {
                return textures
            }
        }
    }
    return []
}

@MainActor func loadSpringLeafTextures() -> [SKTexture] {
    let fm = FileManager.default
    var candidateDirs: [URL] = []
    
    if let resUrl = Bundle.main.resourceURL {
        candidateDirs.append(resUrl.appendingPathComponent("spring_leaves"))
    }
    candidateDirs.append(URL(fileURLWithPath: "spring_leaves"))
    candidateDirs.append(Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("spring_leaves"))
    
    for dir in candidateDirs {
        guard fm.fileExists(atPath: dir.path) else { continue }
        if let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            let pngs = files.filter {
                $0.pathExtension.lowercased() == "png" &&
                !$0.lastPathComponent.hasPrefix(".") &&
                !$0.path.contains("originals")
            }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            
            var textures: [SKTexture] = []
            for fileUrl in pngs {
                if let rawImg = NSImage(contentsOf: fileUrl) {
                    let cleaned = removeWhiteBackgroundIfNeeded(from: rawImg)
                    let tex = SKTexture(image: cleaned)
                    textures.append(tex)
                }
            }
            if !textures.isEmpty {
                return textures
            }
        }
    }
    return []
}

// MARK: - 3. Particle, Pile & Clump Classes

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

/// Snow clump falling off when windows move
@MainActor final class Clump {
    let node: SKShapeNode
    var pos: CGPoint
    var vx: CGFloat
    var vy: CGFloat
    var age: CGFloat = 0
    let sourcePileId: Int
    let amount: CGFloat

    init(pos: CGPoint, vx: CGFloat, vy: CGFloat, sourcePileId: Int, color: NSColor, amount: CGFloat = 0.3) {
        self.pos = pos
        self.vx = vx
        self.vy = vy
        self.sourcePileId = sourcePileId
        self.amount = amount
        node = SKShapeNode(circleOfRadius: rnd(1.6, 2.8))
        node.fillColor = color
        node.strokeColor = .clear
        node.zPosition = 8  // Drawn in front of windows
        node.position = pos
    }
}

/// Pile: column height map drawn as a smooth mound
@MainActor final class Pile {
    var minX: CGFloat
    var topY: CGFloat
    let width: CGFloat
    let maxH: CGFloat
    var h: [CGFloat]          // Height of each column
    var caps: [CGFloat]       // Max height per column
    var occ: [Bool]           // True = this column is covered by a window in front
    let body = SKShapeNode()
    let shade = SKShapeNode()
    var dirty = false

    init(minX: CGFloat, topY: CGFloat, width: CGFloat, maxH: CGFloat, rounded: Bool = true,
         parent: SKNode, top: NSColor, shadeColor: NSColor) {
        self.minX = minX
        self.topY = topY
        self.width = width
        self.maxH = maxH
        let n = max(1, Int((width / Cfg.colW).rounded(.up)))
        h = Array(repeating: 0, count: n)
        occ = Array(repeating: false, count: n)
        caps = (0..<n).map { (i: Int) -> CGFloat in
            if !rounded { return maxH }
            let edgeDist = min(CGFloat(i) + 0.5, CGFloat(n - i) - 0.5) * Cfg.colW
            let t = min(1, edgeDist / (maxH * 2.2))
            return maxH * t.squareRoot()
        }
        body.fillColor = top
        body.strokeColor = .clear
        body.lineWidth = 0
        body.zPosition = 5
        shade.fillColor = shadeColor
        shade.strokeColor = .clear
        shade.lineWidth = 0
        shade.zPosition = 4
        shade.position = CGPoint(x: 0, y: -1.5)
        parent.addChild(shade)
        parent.addChild(body)
    }

    var count: Int { h.count }
    var total: CGFloat { h.reduce(0, +) }

    func col(at x: CGFloat) -> Int? {
        guard x >= minX else { return nil }
        let c = Int((x - minX) / Cfg.colW)
        return (c >= 0 && c < count) ? c : nil
    }
    func colX(_ c: Int) -> CGFloat { minX + (CGFloat(c) + 0.5) * Cfg.colW }
    func surface(_ c: Int) -> CGFloat { topY + h[c] }

    func add(at c: Int, amount: CGFloat) {
        let spread: [(Int, CGFloat)] = [(0, 1), (-1, 0.75), (1, 0.75), (-2, 0.45), (2, 0.45), (-3, 0.2), (3, 0.2)]
        for (o, w) in spread {
            let i = c + o
            guard i >= 0, i < count, !occ[i] else { continue }
            h[i] = min(caps[i], h[i] + amount * w)
        }
        dirty = true
    }

    func relax() -> Bool {
        guard count > 1 else { return false }
        var moved = false
        for i in 0..<(count - 1) where !occ[i] && !occ[i + 1] {
            let d = h[i] - h[i + 1]
            if abs(d) > 1.0 {
                let m = (abs(d) - 1.0) * 0.3 * (d > 0 ? 1 : -1)
                h[i] = max(0, min(caps[i], h[i] - m))
                h[i + 1] = max(0, min(caps[i + 1], h[i + 1] + m))
                if abs(m) > 0.02 { moved = true }
            }
        }
        return moved
    }

    func redraw() {
        guard dirty else { return }
        dirty = relax()
        let p = CGMutablePath()
        p.move(to: CGPoint(x: minX, y: topY))
        var any = false
        for c in 0..<count {
            let hh = occ[c] ? 0 : h[c]
            if hh > 0.3 { any = true }
            p.addLine(to: CGPoint(x: colX(c), y: topY + hh))
        }
        p.addLine(to: CGPoint(x: minX + width, y: topY))
        p.closeSubpath()
        if any {
            body.path = p
            shade.path = p
        } else {
            body.path = nil
            shade.path = nil
        }
    }

    func remove() {
        body.removeFromParent()
        shade.removeFromParent()
    }
}

// MARK: - 4. Snowball Class & Character Stacking

@MainActor final class Snowball {
    let node = SKNode()
    let bodySprite: SKSpriteNode
    let specksSprite: SKSpriteNode
    let charDecorationsNode = SKNode()

    var pos: CGPoint {
        didSet { node.position = pos }
    }
    var radius: CGFloat {
        didSet { updateRadiusVisuals() }
    }
    var rotation: CGFloat = 0 {
        didSet { specksSprite.zRotation = rotation }
    }
    var vx: CGFloat = 0
    var vy: CGFloat = 0

    var isHeld = false
    var isFalling = false
    var currentPileWindowId: Int? = nil // nil = on ground
    var isGround = false

    weak var stackedOn: Snowball?
    weak var stackedAbove: Snowball?

    var isBottomStacked: Bool { stackedAbove != nil && stackedOn == nil }

    init(at pos: CGPoint, radius: CGFloat, bodyTex: SKTexture, specksTex: SKTexture) {
        self.pos = pos
        self.radius = radius
        bodySprite = SKSpriteNode(texture: bodyTex, size: CGSize(width: radius * 2, height: radius * 2))
        specksSprite = SKSpriteNode(texture: specksTex, size: CGSize(width: radius * 2, height: radius * 2))
        node.addChild(bodySprite)
        node.addChild(specksSprite)
        node.addChild(charDecorationsNode)
        node.position = pos
        node.zPosition = 10
    }

    func updateRadiusVisuals() {
        let sz = CGSize(width: radius * 2, height: radius * 2)
        bodySprite.size = sz
        specksSprite.size = sz
    }

    func removeCharacterDecorations() {
        charDecorationsNode.removeAllChildren()
    }

    /// Build character decorations when 3 balls are stacked (head, torso, base)
    func buildCharacter(seasonName: String, role: CharacterRole) {
        charDecorationsNode.removeAllChildren()
        let r = radius
        switch seasonName {
        case "winter":
            buildSnowmanPart(role: role, r: r)
        case "autumn":
            buildScarecrowPart(role: role, r: r)
        case "spring":
            buildFlowerCreaturePart(role: role, r: r)
        default:
            break
        }
    }

    enum CharacterRole { case topHead, middleTorso, bottomBase }

    private func buildSnowmanPart(role: CharacterRole, r: CGFloat) {
        switch role {
        case .topHead:
            // Two black eyes
            for ox: CGFloat in [-r * 0.35, r * 0.35] {
                let eye = SKShapeNode(circleOfRadius: 1.8)
                eye.fillColor = .black
                eye.strokeColor = .clear
                eye.position = CGPoint(x: ox, y: r * 0.25)
                eye.zPosition = 1
                charDecorationsNode.addChild(eye)
            }
            // Orange carrot nose
            let nosePath = CGMutablePath()
            nosePath.move(to: CGPoint(x: 0, y: r * 0.05))
            nosePath.addLine(to: CGPoint(x: r * 0.75, y: -r * 0.05))
            nosePath.addLine(to: CGPoint(x: 0, y: -r * 0.15))
            nosePath.closeSubpath()
            let nose = SKShapeNode(path: nosePath)
            nose.fillColor = NSColor(calibratedRed: 1.0, green: 0.5, blue: 0.05, alpha: 1)
            nose.strokeColor = .clear
            nose.zPosition = 2
            charDecorationsNode.addChild(nose)

            // Coal smile dots
            let dots: [CGPoint] = [
                CGPoint(x: -r * 0.32, y: -r * 0.25),
                CGPoint(x: -r * 0.12, y: -r * 0.36),
                CGPoint(x:  r * 0.12, y: -r * 0.36),
                CGPoint(x:  r * 0.32, y: -r * 0.25)
            ]
            for pt in dots {
                let dot = SKShapeNode(circleOfRadius: 1.1)
                dot.fillColor = .black
                dot.strokeColor = .clear
                dot.position = pt
                dot.zPosition = 1
                charDecorationsNode.addChild(dot)
            }

            // Red scarf at base of head with hanging tail
            let scarf = SKShapeNode(rectOf: CGSize(width: r * 1.6, height: 4), cornerRadius: 2)
            scarf.fillColor = NSColor(calibratedRed: 0.90, green: 0.15, blue: 0.15, alpha: 1)
            scarf.strokeColor = .clear
            scarf.position = CGPoint(x: 0, y: -r + 2)
            scarf.zPosition = 3
            charDecorationsNode.addChild(scarf)

            let tailPath = CGMutablePath()
            tailPath.move(to: CGPoint(x: r * 0.3, y: -r + 2))
            tailPath.addLine(to: CGPoint(x: r * 0.45, y: -r - 12))
            let tail = SKShapeNode(path: tailPath)
            tail.strokeColor = NSColor(calibratedRed: 0.90, green: 0.15, blue: 0.15, alpha: 1)
            tail.lineWidth = 3.5
            tail.zPosition = 3
            charDecorationsNode.addChild(tail)

        case .middleTorso:
            // 3 black buttons
            for yOffset: CGFloat in [r * 0.4, 0, -r * 0.4] {
                let btn = SKShapeNode(circleOfRadius: 1.8)
                btn.fillColor = .black
                btn.strokeColor = .clear
                btn.position = CGPoint(x: 0, y: yOffset)
                btn.zPosition = 1
                charDecorationsNode.addChild(btn)
            }
            // Brown stick arms
            let armL = CGMutablePath()
            armL.move(to: CGPoint(x: -r * 0.85, y: r * 0.2))
            armL.addLine(to: CGPoint(x: -r * 1.7, y: r * 0.6))
            armL.move(to: CGPoint(x: -r * 1.3, y: r * 0.4))
            armL.addLine(to: CGPoint(x: -r * 1.5, y: r * 0.75))
            let armNodeL = SKShapeNode(path: armL)
            armNodeL.strokeColor = NSColor(calibratedRed: 0.45, green: 0.25, blue: 0.1, alpha: 1)
            armNodeL.lineWidth = 2.0
            armNodeL.zPosition = -1
            charDecorationsNode.addChild(armNodeL)

            let armR = CGMutablePath()
            armR.move(to: CGPoint(x: r * 0.85, y: r * 0.2))
            armR.addLine(to: CGPoint(x: r * 1.7, y: r * 0.6))
            armR.move(to: CGPoint(x: r * 1.3, y: r * 0.4))
            armR.addLine(to: CGPoint(x: r * 1.5, y: r * 0.75))
            let armNodeR = SKShapeNode(path: armR)
            armNodeR.strokeColor = NSColor(calibratedRed: 0.45, green: 0.25, blue: 0.1, alpha: 1)
            armNodeR.lineWidth = 2.0
            armNodeR.zPosition = -1
            charDecorationsNode.addChild(armNodeR)

        case .bottomBase:
            break
        }
    }

    private func buildScarecrowPart(role: CharacterRole, r: CGFloat) {
        switch role {
        case .topHead:
            // Two button eyes
            for ox: CGFloat in [-r * 0.35, r * 0.35] {
                let eye = SKShapeNode(circleOfRadius: 2.0)
                eye.fillColor = NSColor(calibratedRed: 0.25, green: 0.12, blue: 0.05, alpha: 1)
                eye.strokeColor = .clear
                eye.position = CGPoint(x: ox, y: r * 0.2)
                eye.zPosition = 1
                charDecorationsNode.addChild(eye)
            }
            // Pumpkin-orange nose
            let nosePath = CGMutablePath()
            nosePath.move(to: CGPoint(x: -3, y: 0))
            nosePath.addLine(to: CGPoint(x: 3, y: 0))
            nosePath.addLine(to: CGPoint(x: 0, y: -6))
            nosePath.closeSubpath()
            let nose = SKShapeNode(path: nosePath)
            nose.fillColor = NSColor(calibratedRed: 0.95, green: 0.45, blue: 0.05, alpha: 1)
            nose.strokeColor = .clear
            nose.zPosition = 2
            charDecorationsNode.addChild(nose)

            // Patched cheeks
            for ox: CGFloat in [-r * 0.55, r * 0.55] {
                let patch = SKShapeNode(rectOf: CGSize(width: 5, height: 5))
                patch.fillColor = NSColor(calibratedRed: 0.65, green: 0.25, blue: 0.15, alpha: 1)
                patch.strokeColor = .clear
                patch.position = CGPoint(x: ox, y: -r * 0.1)
                patch.zPosition = 1
                charDecorationsNode.addChild(patch)
            }

            // Straw hat (brim + crown)
            let brim = SKShapeNode(ellipseOf: CGSize(width: r * 2.5, height: 6))
            brim.fillColor = NSColor(calibratedRed: 0.85, green: 0.72, blue: 0.35, alpha: 1)
            brim.strokeColor = .clear
            brim.position = CGPoint(x: 0, y: r * 0.8)
            brim.zPosition = 3
            charDecorationsNode.addChild(brim)

            let crownPath = CGMutablePath()
            crownPath.move(to: CGPoint(x: -r * 0.6, y: r * 0.8))
            crownPath.addLine(to: CGPoint(x: -r * 0.4, y: r * 1.5))
            crownPath.addLine(to: CGPoint(x: r * 0.4, y: r * 1.5))
            crownPath.addLine(to: CGPoint(x: r * 0.6, y: r * 0.8))
            crownPath.closeSubpath()
            let crown = SKShapeNode(path: crownPath)
            crown.fillColor = NSColor(calibratedRed: 0.80, green: 0.68, blue: 0.30, alpha: 1)
            crown.strokeColor = .clear
            crown.zPosition = 3
            charDecorationsNode.addChild(crown)

        case .middleTorso:
            // Stick arms
            let armL = CGMutablePath()
            armL.move(to: CGPoint(x: -r * 0.85, y: r * 0.1))
            armL.addLine(to: CGPoint(x: -r * 1.8, y: r * 0.3))
            let armNodeL = SKShapeNode(path: armL)
            armNodeL.strokeColor = NSColor(calibratedRed: 0.55, green: 0.35, blue: 0.15, alpha: 1)
            armNodeL.lineWidth = 2.0
            armNodeL.zPosition = -1
            charDecorationsNode.addChild(armNodeL)

            let armR = CGMutablePath()
            armR.move(to: CGPoint(x: r * 0.85, y: r * 0.1))
            armR.addLine(to: CGPoint(x: r * 1.8, y: r * 0.3))
            let armNodeR = SKShapeNode(path: armR)
            armNodeR.strokeColor = NSColor(calibratedRed: 0.55, green: 0.35, blue: 0.15, alpha: 1)
            armNodeR.lineWidth = 2.0
            armNodeR.zPosition = -1
            charDecorationsNode.addChild(armNodeR)

        case .bottomBase:
            break
        }
    }

    private func buildFlowerCreaturePart(role: CharacterRole, r: CGFloat) {
        switch role {
        case .topHead:
            // Two cute eyes with white sparkle
            for ox: CGFloat in [-r * 0.32, r * 0.32] {
                let eye = SKShapeNode(circleOfRadius: 2.2)
                eye.fillColor = NSColor(calibratedRed: 0.20, green: 0.10, blue: 0.15, alpha: 1)
                eye.strokeColor = .clear
                eye.position = CGPoint(x: ox, y: r * 0.18)
                eye.zPosition = 1
                let sparkle = SKShapeNode(circleOfRadius: 0.7)
                sparkle.fillColor = .white
                sparkle.strokeColor = .clear
                sparkle.position = CGPoint(x: 0.6, y: 0.6)
                eye.addChild(sparkle)
                charDecorationsNode.addChild(eye)
            }
            // Small smile
            let smilePath = CGMutablePath()
            smilePath.move(to: CGPoint(x: -r * 0.22, y: -r * 0.15))
            smilePath.addQuadCurve(to: CGPoint(x: r * 0.22, y: -r * 0.15), control: CGPoint(x: 0, y: -r * 0.35))
            let smile = SKShapeNode(path: smilePath)
            smile.strokeColor = NSColor(calibratedRed: 0.85, green: 0.35, blue: 0.55, alpha: 1)
            smile.lineWidth = 1.4
            smile.zPosition = 1
            charDecorationsNode.addChild(smile)

            // Petals on top of head (flower crown)
            for angleDeg: CGFloat in [-40, -20, 0, 20, 40] {
                let rad = angleDeg * .pi / 180
                let petal = SKShapeNode(ellipseOf: CGSize(width: 5, height: 10))
                petal.fillColor = NSColor(calibratedRed: 1.0, green: 0.65, blue: 0.78, alpha: 1)
                petal.strokeColor = .clear
                petal.position = CGPoint(x: sin(rad) * (r * 0.85), y: cos(rad) * (r * 0.85) + 3)
                petal.zRotation = -rad
                petal.zPosition = 2
                charDecorationsNode.addChild(petal)
            }

        case .middleTorso, .bottomBase:
            break
        }
    }
}

// MARK: - 5. Main Season Scene

@MainActor final class SeasonScene: SKScene {
    var season: Season = makeSeason("winter")!
    var amountMultiplier: CGFloat = 1.0

    // Particle system
    var flakes: [Flake] = []
    var pool: [Flake] = []
    var tex: SKTexture?
    var leafTextures: [SKTexture] = []
    var springLeafTextures: [SKTexture] = []
    var ballTex: SKTexture?
    var specksTex: SKTexture?

    // Staggered ramp-up (snow falls from the top with no burst)
    var targetFlakeCount: Int = 0
    var spawnAcc: CGFloat = 0

    // Timing & world
    var lastT: TimeInterval = 0
    var t: CGFloat = 0
    let world = SKNode()

    // Windows & Piles
    let myPID = getpid()
    var pollAcc: CGFloat = 0
    var piles: [Int: Pile] = [:]                    // Window number -> pile
    var ground: Pile?                               // Ground pile at bottom of screen
    var outlines: [Int: SKShapeNode] = [:]
    var order: [(id: Int, rect: CGRect)] = []       // Front to back (SpriteKit coords)
    var prevWindows: [Int: (rect: CGRect, time: TimeInterval)] = [:]
    var isOverlayHidden = false
    var lastCount = -1

    // Clumps falling when window moves
    var clumps: [Clump] = []

    // Snowballs & Interaction
    var balls: [Snowball] = []
    var draggedBall: Snowball? = nil
    var lastMousePos: CGPoint = .zero
    var dragVelocity: CGPoint = .zero
    var lastDragTime: TimeInterval = 0

    // Overlay control
    weak var overlayWindow: NSWindow?

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        addChild(world)
        applySeason(season)
    }

    /// Rebuilds everything for a season: clears particles, clumps, balls and piles
    func applySeason(_ newSeason: Season) {
        season = newSeason
        tex = makeParticleTexture(season.shape)
        if newSeason.name == "autumn" && leafTextures.isEmpty {
            leafTextures = loadAutumnLeafTextures()
        }
        if newSeason.name == "spring" && springLeafTextures.isEmpty {
            springLeafTextures = loadSpringLeafTextures()
        }
        ballTex = (season.pileMax > 0) ? makeBallTexture(season: season) : nil
        specksTex = (season.pileMax > 0) ? makeSpecksTexture(season: season) : nil

        // Remove all flakes & pool
        for f in flakes { f.node.removeFromParent() }
        for f in pool { f.node.removeFromParent() }
        flakes.removeAll()
        pool.removeAll()

        // Remove all clumps
        for c in clumps { c.node.removeFromParent() }
        clumps.removeAll()

        // Remove all snowballs
        for b in balls { b.node.removeFromParent() }
        balls.removeAll()
        draggedBall = nil

        // Recreate ground
        ground?.remove()
        ground = nil
        if season.groundMax > 0 {
            ground = Pile(minX: 0, topY: 0, width: size.width, maxH: season.groundMax, rounded: false,
                          parent: world, top: season.pileTop, shadeColor: season.pileShade)
        }

        // Recreate window piles
        for p in piles.values { p.remove() }
        piles.removeAll()
        if season.pileMax > 0 {
            for item in order {
                piles[item.id] = newPile(for: item.rect)
            }
        }

        // Reset particle ramp-up: start with NO particles on screen
        targetFlakeCount = Int(CGFloat(season.count) * amountMultiplier)
        spawnAcc = 0
        t = 0
        lastT = 0
    }

    func setAmount(_ multiplier: CGFloat) {
        amountMultiplier = multiplier
        targetFlakeCount = Int(CGFloat(season.count) * amountMultiplier)
        if flakes.count > targetFlakeCount {
            while flakes.count > targetFlakeCount {
                recycle(at: flakes.count - 1)
            }
        }
    }

    func clearSnow() {
        for p in piles.values {
            p.h = Array(repeating: 0, count: p.count)
            p.dirty = true
            p.redraw()
        }
        if let g = ground {
            g.h = Array(repeating: 0, count: g.count)
            g.dirty = true
            g.redraw()
        }
        for b in balls { b.node.removeFromParent() }
        balls.removeAll()
        draggedBall = nil
        for c in clumps { c.node.removeFromParent() }
        clumps.removeAll()
    }

    func obtain() -> Flake {
        let f = pool.popLast() ?? Flake(texture: tex ?? SKTexture())
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

    /// Spawns particle above the top edge (no burst)
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

        if season.name == "autumn" && !leafTextures.isEmpty {
            let leafTex = leafTextures.randomElement()!
            f.node.texture = leafTex
            f.node.color = .white
            f.node.colorBlendFactor = 0
            let texSize = leafTex.size()
            // Layer-based sizes: small (14-20), medium (20-27), and slightly bigger (27-36):
            let leafSize: CGFloat = (li == 2 ? rnd(27, Cfg.leafMaxDim) : (li == 1 ? rnd(20, 27) : rnd(Cfg.leafMinDim, 20)))
            let aspect = texSize.width / max(1, texSize.height)
            if aspect >= 1.0 {
                f.node.size = CGSize(width: leafSize, height: leafSize / aspect)
            } else {
                f.node.size = CGSize(width: leafSize * aspect, height: leafSize)
            }
        } else if season.name == "spring" && !springLeafTextures.isEmpty {
            let leafTex = springLeafTextures.randomElement()!
            f.node.texture = leafTex
            f.node.color = .white
            f.node.colorBlendFactor = 0
            let texSize = leafTex.size()
            let leafSize: CGFloat = (li == 2 ? rnd(27, Cfg.leafMaxDim) : (li == 1 ? rnd(20, 27) : rnd(Cfg.leafMinDim, 20)))
            let aspect = texSize.width / max(1, texSize.height)
            if aspect >= 1.0 {
                f.node.size = CGSize(width: leafSize, height: leafSize / aspect)
            } else {
                f.node.size = CGSize(width: leafSize * aspect, height: leafSize)
            }
        } else {
            f.node.texture = tex
            f.node.color = season.palette.randomElement() ?? .white
            f.node.colorBlendFactor = 1
            f.node.size = CGSize(width: s * 2.2, height: s * 2.2)
        }

        f.node.blendMode = season.additive ? .add : .alpha
        f.node.alpha = f.baseAlpha
        f.node.zRotation = (season.name == "autumn" || season.name == "spring") ? rnd(-0.2, 0.2) : (season.spin > 0 ? rnd(0, 6.28) : 0)
        f.node.xScale = 1
        f.node.zPosition = L.z
        f.node.position = CGPoint(x: rnd(-40, size.width + 40),
                                  y: y ?? size.height + rnd(2, 30))
    }

    // MARK: Window Detection & Snow Falling Off

    func pollWindows() {
        let H = size.height
        var newOrder: [(id: Int, rect: CGRect)] = []
        let now = CACurrentMediaTime()

        if let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                 kCGNullWindowID) as? [[String: Any]] {
            for w in info {
                guard let layerN = w[kCGWindowLayer as String] as? NSNumber, layerN.intValue == 0,
                      let pidN = w[kCGWindowOwnerPID as String] as? NSNumber, pidN.int32Value != myPID,
                      let numN = w[kCGWindowNumber as String] as? NSNumber,
                      let bd = w[kCGWindowBounds as String] as? NSDictionary,
                      let b = CGRect(dictionaryRepresentation: bd as CFDictionary) else { continue }
                let alpha = (w[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
                if alpha < 0.05 || b.width < 80 || b.height < 40 { continue }
                newOrder.append((id: numN.intValue,
                                 rect: CGRect(x: b.minX, y: H - b.maxY, width: b.width, height: b.height)))
            }
        }
        order = newOrder
        if Cfg.hideInFullscreen { updateFullscreen() }

        if newOrder.count != lastCount {
            lastCount = newOrder.count
        }

        updatePiles(now: now)
        computeOcclusion()
        for p in piles.values { p.redraw() }
        ground?.redraw()
        if Cfg.showDebugOutlines { updateOutlines() }
    }

    func updateFullscreen() {
        let screenW = size.width, screenH = size.height
        let topInset = view?.window?.screen?.safeAreaInsets.top ?? 0
        let full = order.contains { item in
            let r = item.rect
            return r.width >= screenW - 1
                && r.minY <= 1
                && (screenH - r.maxY) <= topInset + 2
        }
        if full != isOverlayHidden {
            isOverlayHidden = full
            view?.window?.alphaValue = full ? 0 : 1
        }
    }

    func updatePiles(now: TimeInterval) {
        guard season.pileMax > 0 else { return }
        let alive = Set(order.map { $0.id })

        // 1. Closed or minimized windows: shed snow as falling clumps
        for (id, pile) in piles where !alive.contains(id) {
            spawnFallingClumps(from: pile, vx: 0, vy: -30, windowId: id)
            pile.remove()
            piles[id] = nil
            prevWindows[id] = nil
        }

        // 2. Active windows: detect movement or resize
        for item in order {
            let r = item.rect
            if let pile = piles[item.id], let prev = prevWindows[item.id] {
                let dx = r.minX - prev.rect.minX
                let dy = r.maxY - prev.rect.maxY
                let dw = r.width - prev.rect.width
                let dt = CGFloat(max(0.01, now - prev.time))
                let vx = dx / dt
                let vy = dy / dt

                // If window moved significantly, dragged, or resized: snow falls off!
                if abs(dx) > 2.0 || abs(dy) > 2.0 || abs(dw) > 2.0 {
                    spawnFallingClumps(from: pile, vx: vx, vy: vy, windowId: item.id)
                    pile.remove()
                    piles[item.id] = newPile(for: r)
                }
            } else if piles[item.id] == nil {
                piles[item.id] = newPile(for: r)
            }
            prevWindows[item.id] = (rect: r, time: now)
        }
    }

    func newPile(for r: CGRect) -> Pile {
        Pile(minX: r.minX, topY: r.maxY, width: r.width, maxH: season.pileMax,
             parent: world, top: season.pileTop, shadeColor: season.pileShade)
    }

    /// Spawns falling clumps along the old pile shape inheriting 20-30% of window velocity
    func spawnFallingClumps(from pile: Pile, vx: CGFloat, vy: CGFloat, windowId: Int) {
        guard pile.total > 0.5 else { return }
        let budgetLeft = max(0, Cfg.maxClumps - clumps.count)
        guard budgetLeft > 0 else { return }

        // Also detach any snowballs on this pile so they fall
        for b in balls where b.currentPileWindowId == windowId && !b.isHeld && !b.isFalling {
            b.isFalling = true
            b.currentPileWindowId = nil
            b.vx = vx * rnd(0.20, 0.30)
            b.vy = vy * rnd(0.20, 0.30)
            if let stacked = b.stackedAbove {
                stacked.stackedOn = nil
                stacked.isFalling = true
                b.stackedAbove = nil
                b.removeCharacterDecorations()
            }
        }

        var spawned = 0
        for c in 0..<pile.count {
            let h = pile.h[c]
            guard h > 0.6 else { continue }
            let clumpCount = min(3, max(1, Int(h / 3.5)))
            for _ in 0..<clumpCount {
                if spawned >= budgetLeft { break }
                let px = pile.colX(c) + rnd(-Cfg.colW * 0.5, Cfg.colW * 0.5)
                let py = pile.topY + rnd(0, h)
                let cvx = vx * rnd(0.20, 0.30) + rnd(-12, 12)
                let cvy = vy * rnd(0.20, 0.30) + rnd(-15, 0)
                let clump = Clump(pos: CGPoint(x: px, y: py), vx: cvx, vy: cvy,
                                  sourcePileId: windowId, color: season.pileTop)
                world.addChild(clump.node)
                clumps.append(clump)
                spawned += 1
            }
        }
    }

    func computeOcclusion() {
        for (k, item) in order.enumerated() {
            guard let pile = piles[item.id] else { continue }
            for c in 0..<pile.count {
                let pt = CGPoint(x: pile.colX(c), y: pile.topY + 1)
                var occCol = false
                for j in 0..<k where order[j].rect.contains(pt) { occCol = true; break }
                if pile.occ[c] != occCol {
                    pile.occ[c] = occCol
                    pile.dirty = true
                }
            }
        }
    }

    /// Check if a falling point/particle crossed a pile surface
    func landingSpot(x: CGFloat, from top: CGFloat, to bottom: CGFloat, ignoreWindowId: Int? = nil) -> (pile: Pile, col: Int)? {
        if season.pileMax > 0 {
            for item in order {
                if let ign = ignoreWindowId, item.id == ign { continue }
                guard let pile = piles[item.id], let c = pile.col(at: x), !pile.occ[c] else { continue }
                let s = pile.surface(c)
                if top >= s && bottom < s { return (pile, c) }
            }
        }
        if let g = ground, let c = g.col(at: x), bottom < g.surface(c) {
            return (g, c)
        }
        return nil
    }

    func isPointOccluded(_ pt: CGPoint) -> Bool {
        for item in order {
            if item.rect.contains(pt) { return true }
        }
        return false
    }

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

    // MARK: - 6. Snowball Hover Rolling & Physics

    func handleHoverRolling(mousePos: CGPoint, mouseDx: CGFloat) {
        guard season.pileMax > 0, !isPaused, abs(mouseDx) > 0.4 else { return }

        // Find candidate piles under cursor
        var candidatePiles: [(pile: Pile, winId: Int?, isGround: Bool)] = []
        for item in order {
            if let p = piles[item.id], mousePos.x >= p.minX && mousePos.x <= p.minX + p.width {
                candidatePiles.append((pile: p, winId: item.id, isGround: false))
            }
        }
        if let g = ground, mousePos.x >= g.minX && mousePos.x <= g.minX + g.width {
            candidatePiles.append((pile: g, winId: nil, isGround: true))
        }

        for candidate in candidatePiles {
            let p = candidate.pile
            guard let c = p.col(at: mousePos.x), !p.occ[c] else { continue }
            let s = p.surface(c)
            // Cursor within hover zone: just under surface to a bit above it
            guard mousePos.y >= s - 12 && mousePos.y <= s + 36 else { continue }

            // Find existing ball near cursor on this pile
            let existing = balls.first { b in
                let samePile = (b.isGround && candidate.isGround) || (b.currentPileWindowId == candidate.winId)
                return samePile && !b.isHeld && !b.isFalling && abs(b.pos.x - mousePos.x) <= b.radius + 18
            }

            let rollingBall: Snowball
            if let ex = existing {
                rollingBall = ex
            } else if p.h[c] > 0.8 && balls.count < Cfg.maxBalls {
                guard let bTex = ballTex, let sTex = specksTex else { continue }
                let newBall = Snowball(at: CGPoint(x: mousePos.x, y: s + Cfg.ballMinRadius),
                                       radius: Cfg.ballMinRadius, bodyTex: bTex, specksTex: sTex)
                newBall.currentPileWindowId = candidate.winId
                newBall.isGround = candidate.isGround
                world.addChild(newBall.node)
                balls.append(newBall)
                rollingBall = newBall
            } else {
                continue
            }

            // The bottom ball of a stack cannot be rolled or pushed
            guard !rollingBall.isBottomStacked else { continue }

            // Roll ball along pile following cursor x
            let oldX = rollingBall.pos.x
            let targetX = mousePos.x
            let stepX = min(max(targetX - oldX, -16), 16)
            let newX = oldX + stepX

            // Collect snow from columns passed over
            if abs(stepX) > 0.1 && rollingBall.radius < Cfg.ballMaxRadius {
                let minColX = min(oldX, newX) - rollingBall.radius
                let maxColX = max(oldX, newX) + rollingBall.radius
                let c0 = max(0, p.col(at: minColX) ?? 0)
                let c1 = min(p.count - 1, p.col(at: maxColX) ?? (p.count - 1))

                var areaAdded: CGFloat = 0
                let curArea = CGFloat.pi * pow(rollingBall.radius, 2)
                let maxArea = CGFloat.pi * pow(Cfg.ballMaxRadius, 2)

                for ci in c0...c1 where !p.occ[ci] && p.h[ci] > 0 {
                    let take = min(p.h[ci], max(0, (maxArea - (curArea + areaAdded)) / Cfg.colW))
                    if take > 0.02 {
                        p.h[ci] -= take
                        areaAdded += take * Cfg.colW
                        p.dirty = true
                    }
                }
                if areaAdded > 0 {
                    rollingBall.radius = min(Cfg.ballMaxRadius, sqrt((curArea + areaAdded) / .pi))
                }
            }

            rollingBall.pos.x = newX
            if let newCol = p.col(at: newX) {
                rollingBall.pos.y = p.surface(newCol) + rollingBall.radius
            }
            rollingBall.rotation -= (newX - oldX) / max(rollingBall.radius, 1)

            // Pushing chain: push other balls on this pile
            pushChain(ball: rollingBall, pile: p)

            // If ball pushed past edge of surface, it falls
            if newX < p.minX - rollingBall.radius || newX > p.minX + p.width + rollingBall.radius {
                rollingBall.isFalling = true
                rollingBall.currentPileWindowId = nil
                rollingBall.isGround = false
                rollingBall.vx = stepX * 10
                rollingBall.vy = 0
            }
            break
        }
    }

    func pushChain(ball: Snowball, pile: Pile) {
        let samePileBalls = balls.filter {
            $0 !== ball && !$0.isHeld && !$0.isFalling &&
            (($0.isGround && ball.isGround) || ($0.currentPileWindowId == ball.currentPileWindowId))
        }.sorted { $0.pos.x < $1.pos.x }

        // Push to the right
        var leader = ball
        for b in samePileBalls where b.pos.x > leader.pos.x {
            let overlap = (leader.pos.x + leader.radius + b.radius) - b.pos.x
            if overlap > 0 {
                guard !b.isBottomStacked else {
                    // Cannot push bottom ball of a stack; leader stops
                    leader.pos.x -= overlap
                    break
                }
                b.pos.x += overlap
                b.rotation -= overlap / b.radius
                if let c = pile.col(at: b.pos.x) { b.pos.y = pile.surface(c) + b.radius }
                if b.pos.x > pile.minX + pile.width + b.radius {
                    b.isFalling = true; b.currentPileWindowId = nil; b.isGround = false; b.vx = 40
                }
                leader = b
            }
        }

        // Push to the left
        leader = ball
        for b in samePileBalls.reversed() where b.pos.x < leader.pos.x {
            let overlap = (b.pos.x + b.radius + leader.radius) - leader.pos.x
            if overlap > 0 {
                guard !b.isBottomStacked else {
                    leader.pos.x += overlap
                    break
                }
                b.pos.x -= overlap
                b.rotation += overlap / b.radius
                if let c = pile.col(at: b.pos.x) { b.pos.y = pile.surface(c) + b.radius }
                if b.pos.x < pile.minX - b.radius {
                    b.isFalling = true; b.currentPileWindowId = nil; b.isGround = false; b.vx = -40
                }
                leader = b
            }
        }
    }

    // MARK: - 7. Drag, Drop & Stacking

    func handleMouseDown(at pt: CGPoint) {
        guard season.pileMax > 0 else { return }
        // Pick up nearest ball
        if let ball = balls.reversed().first(where: { hypot($0.pos.x - pt.x, $0.pos.y - pt.y) <= $0.radius + 6 }) {
            draggedBall = ball
            ball.isHeld = true
            ball.isFalling = false
            ball.node.zPosition = 18

            // Anything stacked on it falls off!
            if let upper = ball.stackedAbove {
                upper.stackedOn = nil
                upper.isFalling = true
                upper.vy = -30
                ball.stackedAbove = nil
                ball.removeCharacterDecorations()
                upper.removeCharacterDecorations()
            }
            if let lower = ball.stackedOn {
                lower.stackedAbove = nil
                ball.stackedOn = nil
                lower.removeCharacterDecorations()
                ball.removeCharacterDecorations()
            }

            lastDragTime = CACurrentMediaTime()
            dragVelocity = .zero
        }
    }

    func handleMouseDragged(to pt: CGPoint) {
        guard let ball = draggedBall else { return }
        let now = CACurrentMediaTime()
        let dt = CGFloat(max(0.005, now - lastDragTime))
        let dx = pt.x - ball.pos.x
        let dy = pt.y - ball.pos.y
        dragVelocity = CGPoint(x: dx / dt, y: dy / dt)
        lastDragTime = now

        ball.pos = pt
        ball.rotation -= dx / max(ball.radius, 1)
    }

    func handleMouseUp(at pt: CGPoint) {
        guard let ball = draggedBall else { return }
        draggedBall = nil
        ball.isHeld = false
        ball.node.zPosition = 10

        // Check if dropped just above another ball (within about 0.9 of lower radius horizontally)
        let otherBall = balls.first { other in
            other !== ball && !other.isHeld && !other.isFalling && other.stackedAbove == nil &&
            abs(ball.pos.x - other.pos.x) <= Cfg.stackHorizontalTolerance * other.radius &&
            ball.pos.y >= other.pos.y + other.radius - 8 &&
            ball.pos.y <= other.pos.y + other.radius + ball.radius + 35
        }

        if let base = otherBall {
            // Stacks and sits slightly sunk in
            ball.pos.x = base.pos.x
            ball.pos.y = base.pos.y + base.radius + ball.radius - 3
            ball.stackedOn = base
            base.stackedAbove = ball
            ball.isFalling = false
            ball.currentPileWindowId = base.currentPileWindowId
            ball.isGround = base.isGround

            checkForCharacterStack()
        } else {
            // Falls with throw velocity
            ball.isFalling = true
            ball.currentPileWindowId = nil
            ball.isGround = false
            ball.vx = min(max(dragVelocity.x * 0.45, -450), 450)
            ball.vy = min(max(dragVelocity.y * 0.45, -400), 500)
        }
    }

    /// Check for 3 stacked balls and decorate into character
    func checkForCharacterStack() {
        // Clear all decorations first
        for b in balls { b.removeCharacterDecorations() }

        // Find bottom balls of 3-stacks
        for bottom in balls where bottom.stackedOn == nil {
            guard let middle = bottom.stackedAbove, let top = middle.stackedAbove else { continue }
            // Three stacked balls!
            bottom.buildCharacter(seasonName: season.name, role: .bottomBase)
            middle.buildCharacter(seasonName: season.name, role: .middleTorso)
            top.buildCharacter(seasonName: season.name, role: .topHead)
        }
    }

    /// Landing of a falling ball: returns snow smoothly to pile + spawns a few clumps
    func landBall(_ ball: Snowball, on hit: (pile: Pile, col: Int)) {
        let p = hit.pile
        let centerCol = hit.col
        let ballArea = CGFloat.pi * pow(ball.radius, 2)
        let totalVol = ballArea / Cfg.colW
        let spread = max(2, Int(ball.radius / Cfg.colW * 1.4))

        // Return snow as smooth mound over several columns
        for o in -spread...spread {
            let ci = centerCol + o
            guard ci >= 0, ci < p.count, !p.occ[ci] else { continue }
            let w = cos(CGFloat(o) / CGFloat(spread) * (.pi / 2))
            p.h[ci] = min(p.caps[ci], p.h[ci] + (totalVol / CGFloat(spread * 2)) * w)
        }
        p.dirty = true

        // Plus a few small clumps that drop straight down and settle
        let clumpCount = min(6, max(3, Int(ball.radius / 5)))
        for _ in 0..<clumpCount {
            if clumps.count < Cfg.maxClumps {
                let px = ball.pos.x + rnd(-ball.radius * 0.6, ball.radius * 0.6)
                let clump = Clump(pos: CGPoint(x: px, y: ball.pos.y + rnd(0, 8)),
                                  vx: rnd(-10, 10), vy: -rnd(40, 120),
                                  sourcePileId: -1, color: season.pileTop)
                world.addChild(clump.node)
                clumps.append(clump)
            }
        }

        // Remove ball
        ball.node.removeFromParent()
        if let idx = balls.firstIndex(where: { $0 === ball }) {
            balls.remove(at: idx)
        }
    }

    // MARK: - 8. Per-Frame Update

    override func update(_ currentTime: TimeInterval) {
        if lastT == 0 { lastT = currentTime }
        let dt = CGFloat(min(currentTime - lastT, 1.0 / 20.0))
        lastT = currentTime
        t += dt

        // Window polling
        pollAcc += dt
        if pollAcc >= Cfg.pollInterval {
            pollAcc = 0
            pollWindows()
        }

        // Mouse hover tracking & event click-through management
        let mouseLoc = NSEvent.mouseLocation
        let screenRect = view?.window?.screen?.frame ?? view?.window?.frame ?? CGRect(origin: .zero, size: size)
        let mouseScene = CGPoint(x: mouseLoc.x - screenRect.minX, y: mouseLoc.y - screenRect.minY)
        let mouseDx = mouseScene.x - lastMousePos.x

        // Check if mouse is hovering over any ball or currently dragging one
        let isOverBall = balls.contains { b in
            hypot(mouseScene.x - b.pos.x, mouseScene.y - b.pos.y) <= b.radius + 6
        }
        let shouldCaptureMouse = isOverBall || (draggedBall != nil)
        if let win = overlayWindow, win.ignoresMouseEvents != (!shouldCaptureMouse) {
            win.ignoresMouseEvents = !shouldCaptureMouse
        }

        handleHoverRolling(mousePos: mouseScene, mouseDx: mouseDx)
        lastMousePos = mouseScene

        if isOverlayHidden { return }

        // Update clumps falling under gravity (900 px/s^2)
        var ci = clumps.count - 1
        while ci >= 0 {
            let c = clumps[ci]
            c.vy -= Cfg.clumpGravity * dt
            c.pos.x += c.vx * dt
            c.pos.y += c.vy * dt
            c.age += dt
            c.node.position = c.pos

            // Check landing on piles below
            let ignId = (c.age < Cfg.clumpIgnoreDuration) ? c.sourcePileId : nil
            if let hit = landingSpot(x: c.pos.x, from: c.pos.y + 6, to: c.pos.y - 4, ignoreWindowId: ignId) {
                hit.pile.add(at: hit.col, amount: c.amount)
                c.node.removeFromParent()
                clumps.swapAt(ci, clumps.count - 1)
                clumps.removeLast()
                ci -= 1
                continue
            }
            if c.pos.y < -20 || c.pos.x < -40 || c.pos.x > size.width + 40 {
                c.node.removeFromParent()
                clumps.swapAt(ci, clumps.count - 1)
                clumps.removeLast()
            }
            ci -= 1
        }

        // Update falling balls
        var bi = balls.count - 1
        while bi >= 0 {
            let b = balls[bi]
            if b.isFalling && !b.isHeld {
                let prevY = b.pos.y
                b.vy -= Cfg.ballGravity * dt
                b.pos.x += b.vx * dt
                b.pos.y += b.vy * dt
                b.rotation -= (b.vx * dt) / max(b.radius, 1)

                if let hit = landingSpot(x: b.pos.x, from: prevY, to: b.pos.y) {
                    landBall(b, on: hit)
                } else if b.pos.y < -30 {
                    b.node.removeFromParent()
                    balls.swapAt(bi, balls.count - 1)
                    balls.removeLast()
                }
            } else if !b.isHeld {
                // Occlusion: Hide a ball sitting on a column that is covered by a window in front
                let occluded = isPointOccluded(CGPoint(x: b.pos.x, y: b.pos.y))
                b.node.isHidden = occluded
            }
            bi -= 1
        }

        // Staggered ramp-up: spawn particles just above top edge over rampUpSeconds
        if flakes.count < targetFlakeCount {
            let spawnRate = CGFloat(targetFlakeCount) / Cfg.rampUpSeconds
            spawnAcc += dt * spawnRate
            while spawnAcc >= 1.0 && flakes.count < targetFlakeCount {
                spawnAcc -= 1.0
                spawnFlake()
            }
        }

        let wind = sin(t * 0.15) * 12 + 8
        let canLand = season.pileMax > 0 || season.groundMax > 0

        var fi = flakes.count - 1
        while fi >= 0 {
            let f = flakes[fi]
            let prevY = f.node.position.y
            let sway = cos(t * f.swayFreq + f.phase) * f.swayAmp
            var p = f.node.position
            p.x += (sway + wind * f.windFactor) * dt
            p.y -= f.fallSpeed * dt
            if p.x > size.width + 40 { p.x = -40 }
            if p.x < -40 { p.x = size.width + 40 }
            f.node.position = p

            // Landed on a window top or ground: add to pile and respawn at top
            if canLand, let hit = landingSpot(x: p.x, from: prevY, to: p.y) {
                let gain: CGFloat = (hit.pile === ground) ? Cfg.groundGain : 1
                hit.pile.add(at: hit.col, amount: season.pileAmount * gain * rnd(0.6, 1.4))
                recycle(at: fi)
                spawnFlake()
                fi -= 1
                continue
            }

            if season.name == "autumn" || season.name == "spring" {
                // Smooth slight banking rotation that sways with the wind and lateral motion
                let swayTilt = -cos(t * f.swayFreq + f.phase) * 0.22
                let windTilt = -(wind * f.windFactor) * 0.007
                f.node.zRotation = swayTilt + windTilt
            } else {
                if season.spin > 0 { f.node.zRotation += f.spinRate * dt }
                if season.flip {
                    f.node.xScale = 0.25 + 0.75 * abs(cos(t * f.flipFreq + f.phase))
                }
            }
            if season.twinkle {
                f.node.alpha = f.baseAlpha * (0.35 + 0.65 * (0.5 + 0.5 * sin(t * f.flipFreq + f.phase)))
            }

            if p.y < -20 {
                recycle(at: fi)
                spawnFlake()
            }
            fi -= 1
        }
    }
}

// MARK: - 9. Custom View for First Mouse & Event Forwarding

@MainActor final class OverlaySKView: SKView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    override func mouseDown(with event: NSEvent) {
        guard let scene = scene as? SeasonScene else { return }
        let pt = scene.convertPoint(fromView: convert(event.locationInWindow, from: nil))
        scene.handleMouseDown(at: pt)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let scene = scene as? SeasonScene else { return }
        let pt = scene.convertPoint(fromView: convert(event.locationInWindow, from: nil))
        scene.handleMouseDragged(to: pt)
    }

    override func mouseUp(with event: NSEvent) {
        guard let scene = scene as? SeasonScene else { return }
        let pt = scene.convertPoint(fromView: convert(event.locationInWindow, from: nil))
        scene.handleMouseUp(at: pt)
    }
}

// MARK: - 10. App Delegate, Status Bar & Menu

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var window: NSWindow!
    var scene: SeasonScene!
    var autoTimer: Timer?

    // Menu references for live state toggles
    var winterItem: NSMenuItem!
    var autumnItem: NSMenuItem!
    var springItem: NSMenuItem!
    var summerItem: NSMenuItem!
    var autoItem: NSMenuItem!
    var lightItem: NSMenuItem!
    var medItem: NSMenuItem!
    var heavyItem: NSMenuItem!
    var pauseItem: NSMenuItem!
    var enableItem: NSMenuItem!
    var launchAtLoginItem: NSMenuItem!
    var accessNoteItem: NSMenuItem!
    var accessActionItem: NSMenuItem!

    // Wallpaper menu items
    var wallpaperItem: NSMenuItem!
    var chooseFolderItem: NSMenuItem!
    var restoreWallpaperItem: NSMenuItem!

    // UserDefaults keys
    let kSeason = "seasons_season"
    let kAuto = "seasons_auto"
    let kAmount = "seasons_amount"
    let kEnabled = "seasons_enabled"
    let kWallpaperEnabled = "seasons_wallpaper_enabled"
    let kWallpaperFolder = "seasons_wallpaper_folder"
    let kOrigWallpapers = "seasons_orig_wallpapers"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Primary display selection (monitor with menu bar)
        let primaryScreen = NSScreen.screens.first ?? NSScreen.main!
        let screenFrame = primaryScreen.frame

        // Window setup
        window = NSWindow(contentRect: screenFrame,
                          styleMask: .borderless,
                          backing: .buffered,
                          defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .statusBar
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let skView = OverlaySKView(frame: screenFrame)
        skView.allowsTransparency = true
        scene = SeasonScene(size: screenFrame.size)
        scene.scaleMode = .resizeFill
        scene.overlayWindow = window
        skView.presentScene(scene)

        window.contentView = skView
        window.makeKeyAndOrderFront(nil)

        // Restore persisted settings with optional CLI override
        let savedAuto = UserDefaults.standard.object(forKey: kAuto) as? Bool ?? false
        var currentSeasonName = UserDefaults.standard.string(forKey: kSeason) ?? "winter"
        if let cliArg = CommandLine.arguments.dropFirst().first, let _ = makeSeason(cliArg) {
            currentSeasonName = cliArg.lowercased()
        }

        let savedAmount = UserDefaults.standard.string(forKey: kAmount) ?? "medium"
        let savedEnabled = UserDefaults.standard.object(forKey: kEnabled) as? Bool ?? true

        // Status Item setup
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        buildMenu()

        // Wallpaper state: enabled by default so wallpapers change with season automatically
        let savedWallpaper = UserDefaults.standard.object(forKey: kWallpaperEnabled) as? Bool ?? true
        wallpaperItem.state = savedWallpaper ? .on : .off
        UserDefaults.standard.set(savedWallpaper, forKey: kWallpaperEnabled)
        if savedWallpaper {
            saveOriginalWallpapersIfNeeded()
        }

        // Apply settings
        applySeasonByName(currentSeasonName, isManualChoice: false)
        setAutoCalendar(savedAuto)
        setAmountByName(savedAmount)
        setEnabled(savedEnabled)

        // Ensure wallpaper changes to the current season whenever the application starts
        if savedWallpaper {
            applyWallpaperForSeason(scene.season.name)
        }

        // Start hourly auto-calendar check
        autoTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.hourlyCalendarCheck()
            }
        }
    }

    func checkAccessibility(prompt: Bool = false) -> Bool {
        // Window tracking uses CGWindowListCopyWindowInfo (Quartz) which reads window
        // geometries directly without needing AXUIElement accessibility permissions.
        return true
    }

    func buildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        // 1. Season selection items
        winterItem = NSMenuItem(title: "Winter (❄︎)", action: #selector(chooseWinter), keyEquivalent: "")
        autumnItem = NSMenuItem(title: "Autumn (🍂)", action: #selector(chooseAutumn), keyEquivalent: "")
        springItem = NSMenuItem(title: "Spring (🌸)", action: #selector(chooseSpring), keyEquivalent: "")
        summerItem = NSMenuItem(title: "Summer (✺)", action: #selector(chooseSummer), keyEquivalent: "")
        for it in [winterItem!, autumnItem!, springItem!, summerItem!] {
            it.target = self
            menu.addItem(it)
        }

        menu.addItem(NSMenuItem.separator())

        // 2. Auto calendar follow
        autoItem = NSMenuItem(title: "Auto (follow the calendar)", action: #selector(toggleAuto), keyEquivalent: "")
        autoItem.target = self
        menu.addItem(autoItem)

        // 3. Amount submenu
        let amountMenu = NSMenu()
        lightItem = NSMenuItem(title: "Light (0.5x)", action: #selector(chooseLight), keyEquivalent: "")
        medItem = NSMenuItem(title: "Medium (1.0x)", action: #selector(chooseMedium), keyEquivalent: "")
        heavyItem = NSMenuItem(title: "Heavy (1.8x)", action: #selector(chooseHeavy), keyEquivalent: "")
        for it in [lightItem!, medItem!, heavyItem!] {
            it.target = self
            amountMenu.addItem(it)
        }
        let amountSub = NSMenuItem(title: "Amount", action: nil, keyEquivalent: "")
        amountSub.submenu = amountMenu
        menu.addItem(amountSub)

        menu.addItem(NSMenuItem.separator())

        // 4. Wallpaper per season
        wallpaperItem = NSMenuItem(title: "Change wallpaper with season", action: #selector(toggleWallpaperEnabled), keyEquivalent: "")
        wallpaperItem.target = self
        menu.addItem(wallpaperItem)

        chooseFolderItem = NSMenuItem(title: "Choose wallpaper folder...", action: #selector(chooseWallpaperFolder), keyEquivalent: "")
        chooseFolderItem.target = self
        menu.addItem(chooseFolderItem)

        restoreWallpaperItem = NSMenuItem(title: "Restore original wallpaper", action: #selector(restoreOriginalWallpaperAction), keyEquivalent: "")
        restoreWallpaperItem.target = self
        menu.addItem(restoreWallpaperItem)

        menu.addItem(NSMenuItem.separator())

        // 5. Pause / Resume
        pauseItem = NSMenuItem(title: "Pause", action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)

        // 5. Clear Snow
        let clearItem = NSMenuItem(title: "Clear Snow", action: #selector(clearSnow), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        // 6. Enable Overlay
        enableItem = NSMenuItem(title: "Enable Overlay", action: #selector(toggleEnable), keyEquivalent: "")
        enableItem.target = self
        menu.addItem(enableItem)

        // 7. Launch at Login
        launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        launchAtLoginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(launchAtLoginItem)

        menu.addItem(NSMenuItem.separator())

        // 8. Accessibility items
        accessNoteItem = NSMenuItem(title: "⚠️ Accessibility required for window tracking", action: nil, keyEquivalent: "")
        accessNoteItem.isEnabled = false
        menu.addItem(accessNoteItem)

        accessActionItem = NSMenuItem(title: "Open Accessibility Settings...", action: #selector(openAccessibility), keyEquivalent: "")
        accessActionItem.target = self
        menu.addItem(accessActionItem)

        menu.addItem(NSMenuItem.separator())

        // 9. Quit
        let quitItem = NSMenuItem(title: "Quit SeasonsIsComing", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        let trusted = checkAccessibility(prompt: false)
        accessNoteItem.isHidden = trusted
        accessActionItem.isHidden = trusted
        launchAtLoginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        wallpaperItem.state = UserDefaults.standard.bool(forKey: kWallpaperEnabled) ? .on : .off
    }

    // MARK: Season Switching

    func applySeasonByName(_ name: String, isManualChoice: Bool = true) {
        guard let s = makeSeason(name) else { return }
        scene.applySeason(s)
        statusItem.button?.title = s.symbol

        winterItem.state = (name == "winter") ? .on : .off
        autumnItem.state = (name == "autumn") ? .on : .off
        springItem.state = (name == "spring") ? .on : .off
        summerItem.state = (name == "summer") ? .on : .off

        UserDefaults.standard.set(name, forKey: kSeason)
        if isManualChoice {
            setAutoCalendar(false)
        }

        if wallpaperItem != nil && wallpaperItem.state == .on {
            applyWallpaperForSeason(name)
        }
    }

    @objc func chooseWinter() { applySeasonByName("winter") }
    @objc func chooseAutumn() { applySeasonByName("autumn") }
    @objc func chooseSpring() { applySeasonByName("spring") }
    @objc func chooseSummer() { applySeasonByName("summer") }

    // MARK: Auto (Calendar) Following

    func setAutoCalendar(_ enabled: Bool) {
        autoItem.state = enabled ? .on : .off
        UserDefaults.standard.set(enabled, forKey: kAuto)
        if enabled { hourlyCalendarCheck() }
    }

    @objc func toggleAuto() {
        let newState = (autoItem.state != .on)
        setAutoCalendar(newState)
    }

    func seasonForCurrentMonth() -> String {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 12, 1, 2: return "winter"
        case 3, 4, 5:  return "spring"
        case 6, 7, 8:  return "summer"
        default:       return "autumn"
        }
    }

    func hourlyCalendarCheck() {
        guard autoItem.state == .on else { return }
        let currentSeason = seasonForCurrentMonth()
        if scene.season.name != currentSeason {
            applySeasonByName(currentSeason, isManualChoice: false)
        }
    }

    // MARK: Amount Settings

    func setAmountByName(_ name: String) {
        lightItem.state = (name == "light") ? .on : .off
        medItem.state = (name == "medium") ? .on : .off
        heavyItem.state = (name == "heavy") ? .on : .off
        let mult: CGFloat = (name == "light") ? 0.5 : ((name == "heavy") ? 1.8 : 1.0)
        scene.setAmount(mult)
        UserDefaults.standard.set(name, forKey: kAmount)
    }

    @objc func chooseLight()  { setAmountByName("light") }
    @objc func chooseMedium() { setAmountByName("medium") }
    @objc func chooseHeavy()  { setAmountByName("heavy") }

    // MARK: Control Toggles

    @objc func togglePause() {
        let isPaused = !scene.isPaused
        scene.isPaused = isPaused
        pauseItem.title = isPaused ? "Resume" : "Pause"
    }

    @objc func clearSnow() {
        scene.clearSnow()
    }

    func setEnabled(_ enabled: Bool) {
        enableItem.state = enabled ? .on : .off
        window.alphaValue = enabled ? 1.0 : 0.0
        scene.isPaused = !enabled
        UserDefaults.standard.set(enabled, forKey: kEnabled)
    }

    @objc func toggleEnable() {
        setEnabled(enableItem.state != .on)
    }

    @objc func toggleLaunchAtLogin() {
        let enable = (launchAtLoginItem.state != .on)
        do {
            if enable {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            launchAtLoginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        } catch {
            print("Launch at login error: \(error.localizedDescription)")
            launchAtLoginItem.state = .off
        }
    }

    @objc func openAccessibility() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Wallpaper Per Season

    func screenKey(for screen: NSScreen, index: Int) -> String {
        if let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return "display_\(num.intValue)"
        }
        return "screen_\(index)"
    }

    func saveOriginalWallpapersIfNeeded() {
        guard UserDefaults.standard.dictionary(forKey: kOrigWallpapers) == nil else { return }
        var dict: [String: String] = [:]
        for (i, screen) in NSScreen.screens.enumerated() {
            if let url = NSWorkspace.shared.desktopImageURL(for: screen) {
                let key = screenKey(for: screen, index: i)
                dict[key] = url.absoluteString
                dict["screen_\(i)"] = url.absoluteString
            }
        }
        if !dict.isEmpty {
            UserDefaults.standard.set(dict, forKey: kOrigWallpapers)
        }
    }

    func restoreOriginalWallpapers() {
        guard let dict = UserDefaults.standard.dictionary(forKey: kOrigWallpapers) as? [String: String] else {
            print("No original wallpapers recorded to restore.")
            return
        }
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
            .allowClipping: true
        ]
        for (i, screen) in NSScreen.screens.enumerated() {
            let key = screenKey(for: screen, index: i)
            if let urlStr = dict[key] ?? dict["screen_\(i)"], let url = URL(string: urlStr) {
                do {
                    try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: options)
                } catch {
                    print("Failed to restore wallpaper for screen \(i): \(error.localizedDescription)")
                }
            }
        }
        UserDefaults.standard.removeObject(forKey: kOrigWallpapers)
    }

    func findWallpaperURL(for seasonName: String, in folder: URL) -> URL? {
        let target = seasonName.lowercased()
        let extensions = ["jpg", "jpeg", "png", "heic"]
        let fm = FileManager.default

        // Direct check first
        for ext in extensions {
            let candidate = folder.appendingPathComponent("\(target).\(ext)")
            if fm.fileExists(atPath: candidate.path) {
                return candidate
            }
            let capCandidate = folder.appendingPathComponent("\(target.capitalized).\(ext)")
            if fm.fileExists(atPath: capCandidate.path) {
                return capCandidate
            }
        }

        // Case-insensitive directory listing search
        if let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
            for file in files {
                let ext = file.pathExtension.lowercased()
                let base = file.deletingPathExtension().lastPathComponent.lowercased()
                if base == target && extensions.contains(ext) {
                    return file
                }
            }
        }
        return nil
    }

    func resolveWallpaperFolder() -> URL? {
        let fm = FileManager.default

        // 1. User-chosen folder from UserDefaults
        if let savedPath = UserDefaults.standard.string(forKey: kWallpaperFolder), !savedPath.isEmpty {
            if fm.fileExists(atPath: savedPath) {
                return URL(fileURLWithPath: savedPath)
            }
        }

        // 2. Candidate folders (Resources bundle, local working directory, parent directory)
        var candidateDirs: [URL] = []
        if let resUrl = Bundle.main.resourceURL {
            candidateDirs.append(resUrl.appendingPathComponent("wallpapers"))
        }
        candidateDirs.append(URL(fileURLWithPath: "wallpapers"))
        candidateDirs.append(Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("wallpapers"))

        for dir in candidateDirs {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue {
                UserDefaults.standard.set(dir.path, forKey: kWallpaperFolder)
                return dir
            }
        }
        return nil
    }

    func applyWallpaperForSeason(_ seasonName: String) {
        guard wallpaperItem != nil && wallpaperItem.state == .on else { return }
        guard let folderURL = resolveWallpaperFolder() else {
            print("Wallpaper folder not set. Please choose a wallpaper folder.")
            return
        }
        guard let fileURL = findWallpaperURL(for: seasonName, in: folderURL) else {
            print("Wallpaper file for season '\(seasonName)' not found in \(folderURL.path).")
            return
        }

        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
            .allowClipping: true
        ]

        for (i, screen) in NSScreen.screens.enumerated() {
            do {
                try NSWorkspace.shared.setDesktopImageURL(fileURL, for: screen, options: options)
            } catch {
                print("Failed to set desktop image for screen \(i): \(error.localizedDescription)")
            }
        }
    }

    func setWallpaperEnabled(_ enabled: Bool) {
        wallpaperItem.state = enabled ? .on : .off
        UserDefaults.standard.set(enabled, forKey: kWallpaperEnabled)
        if enabled {
            saveOriginalWallpapersIfNeeded()
            applyWallpaperForSeason(scene.season.name)
        } else {
            restoreOriginalWallpapers()
        }
    }

    @objc func toggleWallpaperEnabled() {
        let newState = (wallpaperItem.state != .on)
        setWallpaperEnabled(newState)
    }

    @objc func chooseWallpaperFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Wallpaper Folder"
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        if let currentFolder = resolveWallpaperFolder() {
            panel.directoryURL = currentFolder
        }
        NSApp.activate(ignoringOtherApps: true)
        let response = panel.runModal()
        if response == .OK, let url = panel.url {
            UserDefaults.standard.set(url.path, forKey: kWallpaperFolder)
            if wallpaperItem.state == .on {
                applyWallpaperForSeason(scene.season.name)
            }
        }
    }

    @objc func restoreOriginalWallpaperAction() {
        restoreOriginalWallpapers()
        wallpaperItem.state = .off
        UserDefaults.standard.set(false, forKey: kWallpaperEnabled)
    }

    @objc func quitApp() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        NSApp.terminate(nil)
    }
}

// MARK: - 11. Application Entry Point

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
