#!/bin/zsh
set -e

# make_icon.sh
# Generates a default 1024x1024 icon.png if not present (white snowflake on blue rounded square)
# and builds AppIcon.icns using sips and iconutil.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [[ ! -f "icon.png" ]]; then
    echo "Creating default icon.png..."
    mkdir -p /tmp/swift-cache
    cat << 'EOF' > /tmp/gen_icon.swift
import Cocoa

let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
    guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

    // Blue gradient background
    let bgRect = CGRect(x: 64, y: 64, width: size - 128, height: size - 128)
    let corner: CGFloat = 190
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: corner, cornerHeight: corner, transform: nil)
    ctx.addPath(bgPath)
    ctx.clip()

    let colors = [
        CGColor(red: 0.12, green: 0.45, blue: 0.95, alpha: 1.0),
        CGColor(red: 0.05, green: 0.20, blue: 0.60, alpha: 1.0)
    ] as CFArray
    let locs: [CGFloat] = [0.0, 1.0]
    guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locs) else { return false }
    ctx.drawLinearGradient(grad, start: CGPoint(x: 512, y: 960), end: CGPoint(x: 512, y: 64), options: [])

    // Snowflake arms
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
    ctx.setLineCap(.round)
    ctx.setLineWidth(32)

    let center = CGPoint(x: 512, y: 512)
    for i in 0..<6 {
        let angle = CGFloat(i) * (.pi / 3.0)
        let armLen: CGFloat = 260
        let ex = center.x + cos(angle) * armLen
        let ey = center.y + sin(angle) * armLen
        ctx.move(to: center)
        ctx.addLine(to: CGPoint(x: ex, y: ey))
        ctx.strokePath()

        // Branch V
        let bx = center.x + cos(angle) * (armLen * 0.65)
        let by = center.y + sin(angle) * (armLen * 0.65)
        let bLen: CGFloat = 75
        let bAngle1 = angle + .pi / 4.0
        let bAngle2 = angle - .pi / 4.0
        ctx.move(to: CGPoint(x: bx, y: by))
        ctx.addLine(to: CGPoint(x: bx + cos(bAngle1) * bLen, y: by + sin(bAngle1) * bLen))
        ctx.move(to: CGPoint(x: bx, y: by))
        ctx.addLine(to: CGPoint(x: bx + cos(bAngle2) * bLen, y: by + sin(bAngle2) * bLen))
        ctx.strokePath()
    }

    // Center crystal circle
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
    ctx.fillEllipse(in: CGRect(x: 512 - 36, y: 512 - 36, width: 72, height: 72))

    return true
}

if let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
    if let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: "icon.png"))
        print("Generated icon.png (1024x1024)")
    }
}
EOF
    swiftc -module-cache-path /tmp/swift-cache -Xcc -fmodules-cache-path=/tmp/swift-cache /tmp/gen_icon.swift -o /tmp/gen_icon
    /tmp/gen_icon
    rm -f /tmp/gen_icon /tmp/gen_icon.swift
fi

echo "Building AppIcon.icns from icon.png..."
ICONSET="AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

sips -z 16 16     icon.png --out "$ICONSET/icon_16x16.png" > /dev/null
sips -z 32 32     icon.png --out "$ICONSET/icon_16x16@2x.png" > /dev/null
sips -z 32 32     icon.png --out "$ICONSET/icon_32x32.png" > /dev/null
sips -z 64 64     icon.png --out "$ICONSET/icon_32x32@2x.png" > /dev/null
sips -z 128 128   icon.png --out "$ICONSET/icon_128x128.png" > /dev/null
sips -z 256 256   icon.png --out "$ICONSET/icon_128x128@2x.png" > /dev/null
sips -z 256 256   icon.png --out "$ICONSET/icon_256x256.png" > /dev/null
sips -z 512 512   icon.png --out "$ICONSET/icon_256x256@2x.png" > /dev/null
sips -z 512 512   icon.png --out "$ICONSET/icon_512x512.png" > /dev/null
sips -z 1024 1024 icon.png --out "$ICONSET/icon_512x512@2x.png" > /dev/null

iconutil -c icns "$ICONSET" -o AppIcon.icns
rm -rf "$ICONSET"
echo "Successfully created AppIcon.icns!"
