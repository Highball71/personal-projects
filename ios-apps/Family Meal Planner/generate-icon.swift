#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let width = size
let height = size

// Create RGB color space (no alpha for App Store)
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

// Create bitmap context - noneSkipLast fills alpha channel with 0xFF (opaque)
let context = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: width * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
)!

// Enable antialiasing
context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)
context.interpolationQuality = .high

let w = CGFloat(width)
let h = CGFloat(height)

// MARK: - Helper

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [r, g, b, a])!
}

// Seed random for reproducible grain
srand48(42)

func seededRandom(_ min: CGFloat, _ max: CGFloat) -> CGFloat {
    return min + CGFloat(drand48()) * (max - min)
}

// MARK: - Step 1: Warm Radial Gradient Background

do {
    let colors = [
        color(1.0, 0.75, 0.30),    // bright warm amber center
        color(0.96, 0.56, 0.22),   // warm orange mid
        color(0.80, 0.30, 0.12),   // deep burnt orange edge
    ] as CFArray

    let locations: [CGFloat] = [0.0, 0.55, 1.0]

    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: colors,
        locations: locations
    )!

    // Offset center upper-left for natural light source
    let center = CGPoint(x: w * 0.42, y: h * 0.58)
    let radius = w * 0.78

    context.drawRadialGradient(
        gradient,
        startCenter: center,
        startRadius: 0,
        endCenter: center,
        endRadius: radius,
        options: [.drawsAfterEndLocation]
    )
}

// MARK: - Step 2: Draw the Wooden Spoon

// Save state before transforming for the spoon
context.saveGState()

// Rotate ~30° for dynamic diagonal composition
context.translateBy(x: w / 2, y: h / 2)
context.rotate(by: -30.0 * .pi / 180.0)
context.translateBy(x: -w / 2, y: -h / 2)

// Spoon dimensions — tall egg-shaped bowl aligned WITH the handle axis
// Bowl is ~1.8x taller than wide, widest point in upper third
let spoonCenterX = w * 0.50
let bowlCenterY = h * 0.73        // bowl in upper portion
let bowlWidth: CGFloat = 170       // bowl narrow side-to-side
let bowlHeight: CGFloat = 305      // bowl tall egg shape (~1.8x ratio)
let handleWidth: CGFloat = 52      // thin handle
let handleTipWidth: CGFloat = 44   // subtle taper at end
let handleBottomY = h * 0.06       // long handle

// The bowl bottom smoothly tapers into the handle — no hard junction
let bowlTop = bowlCenterY + bowlHeight * 0.50
let bowlBottom = bowlCenterY - bowlHeight * 0.50

// Build the spoon path as one continuous shape
let spoonPath = CGMutablePath()

// Start at top center of bowl (the rounded tip of the spoon head)
spoonPath.move(to: CGPoint(x: spoonCenterX, y: bowlTop))

// Right side of bowl — rounded top curving to widest point (in upper third)
spoonPath.addCurve(
    to: CGPoint(x: spoonCenterX + bowlWidth * 0.52, y: bowlCenterY + bowlHeight * 0.18),
    control1: CGPoint(x: spoonCenterX + bowlWidth * 0.38, y: bowlTop + 3),
    control2: CGPoint(x: spoonCenterX + bowlWidth * 0.56, y: bowlCenterY + bowlHeight * 0.34)
)

// Right side — widest point tapering longer distance down to handle
spoonPath.addCurve(
    to: CGPoint(x: spoonCenterX + handleWidth * 0.52, y: bowlBottom + 20),
    control1: CGPoint(x: spoonCenterX + bowlWidth * 0.46, y: bowlCenterY - bowlHeight * 0.08),
    control2: CGPoint(x: spoonCenterX + bowlWidth * 0.22, y: bowlBottom + 55)
)

// Right side of handle — long run down to tip
spoonPath.addCurve(
    to: CGPoint(x: spoonCenterX + handleTipWidth * 0.50, y: handleBottomY + 35),
    control1: CGPoint(x: spoonCenterX + handleWidth * 0.52, y: bowlBottom - 80),
    control2: CGPoint(x: spoonCenterX + handleTipWidth * 0.52, y: handleBottomY + 150)
)

// Rounded bottom of handle
spoonPath.addCurve(
    to: CGPoint(x: spoonCenterX - handleTipWidth * 0.50, y: handleBottomY + 35),
    control1: CGPoint(x: spoonCenterX + handleTipWidth * 0.30, y: handleBottomY),
    control2: CGPoint(x: spoonCenterX - handleTipWidth * 0.30, y: handleBottomY)
)

// Left side of handle — mirror, long run back up
spoonPath.addCurve(
    to: CGPoint(x: spoonCenterX - handleWidth * 0.52, y: bowlBottom + 20),
    control1: CGPoint(x: spoonCenterX - handleTipWidth * 0.52, y: handleBottomY + 150),
    control2: CGPoint(x: spoonCenterX - handleWidth * 0.52, y: bowlBottom - 80)
)

// Left side — handle flaring into bowl widest point (upper third)
spoonPath.addCurve(
    to: CGPoint(x: spoonCenterX - bowlWidth * 0.52, y: bowlCenterY + bowlHeight * 0.18),
    control1: CGPoint(x: spoonCenterX - bowlWidth * 0.22, y: bowlBottom + 55),
    control2: CGPoint(x: spoonCenterX - bowlWidth * 0.46, y: bowlCenterY - bowlHeight * 0.08)
)

// Left side of bowl — widest point curving back to top
spoonPath.addCurve(
    to: CGPoint(x: spoonCenterX, y: bowlTop),
    control1: CGPoint(x: spoonCenterX - bowlWidth * 0.56, y: bowlCenterY + bowlHeight * 0.34),
    control2: CGPoint(x: spoonCenterX - bowlWidth * 0.38, y: bowlTop + 3)
)

spoonPath.closeSubpath()

// Define handleTopY for use by texture/lighting code (where bowl meets handle)
let handleTopY = bowlBottom + 20

// -- Drop shadow beneath spoon --
context.saveGState()
context.setShadow(
    offset: CGSize(width: 10, height: -14),
    blur: 35,
    color: color(0.12, 0.06, 0.01, 0.55)
)

// Fill with base wood color (rich honey brown)
context.addPath(spoonPath)
context.setFillColor(color(0.82, 0.60, 0.30))
context.fillPath()

context.restoreGState()  // Remove shadow

// MARK: - Step 3: Wood Grain Texture

// Clip to spoon for all texture/lighting
context.saveGState()
context.addPath(spoonPath)
context.clip()

// Warm wood base tint for depth
do {
    context.setFillColor(color(0.72, 0.50, 0.22, 0.12))
    context.fill(CGRect(x: 0, y: 0, width: w, height: h))
}

// Color variation bands (subtle alternating warm/cool tones)
do {
    let bandCount = 9
    for i in 0..<bandCount {
        let t = CGFloat(i) / CGFloat(bandCount)
        let bandY = handleBottomY + t * (bowlTop - handleBottomY)
        let bandH = (bowlTop - handleBottomY) / CGFloat(bandCount)

        // Alternate between slightly lighter and darker bands
        if i % 2 == 0 {
            context.setFillColor(color(0.82, 0.62, 0.36, 0.10))
        } else {
            context.setFillColor(color(0.65, 0.45, 0.24, 0.10))
        }
        context.fill(CGRect(x: 0, y: bandY, width: w, height: bandH))
    }
}

// Prominent grain lines
do {
    context.setLineCap(.round)

    // Darker grain lines
    for i in 0..<50 {
        let t = CGFloat(i) / 50.0
        let y = handleBottomY + t * (bowlTop - handleBottomY)
        let opacity = seededRandom(0.06, 0.18)
        let lineWidth = seededRandom(0.8, 2.5)

        // Mix of dark and light grain lines
        if i % 3 == 0 {
            context.setStrokeColor(color(0.50, 0.32, 0.14, opacity))
        } else {
            context.setStrokeColor(color(0.40, 0.25, 0.10, opacity * 0.7))
        }
        context.setLineWidth(lineWidth)

        let grainPath = CGMutablePath()
        grainPath.move(to: CGPoint(x: w * 0.15, y: y))

        // Wavy grain with bezier curves for smoother look
        let segments = 10
        for j in 1...segments {
            let segX = w * 0.15 + CGFloat(j) * (w * 0.70) / CGFloat(segments)
            let wobble = seededRandom(-8, 8)
            let cpX = segX - (w * 0.70) / CGFloat(segments) * 0.5
            let cpWobble = seededRandom(-5, 5)
            grainPath.addQuadCurve(
                to: CGPoint(x: segX, y: y + wobble),
                control: CGPoint(x: cpX, y: y + cpWobble)
            )
        }

        context.addPath(grainPath)
        context.strokePath()
    }

    // A few bold "knot" grain curves for character
    for k in 0..<3 {
        let knotY = handleBottomY + CGFloat(k + 1) * (bowlTop - handleBottomY) / 4.0
        let knotPath = CGMutablePath()
        knotPath.move(to: CGPoint(x: w * 0.30, y: knotY - 15))
        knotPath.addQuadCurve(
            to: CGPoint(x: w * 0.70, y: knotY + 10),
            control: CGPoint(x: w * 0.50, y: knotY + seededRandom(15, 30))
        )
        context.setStrokeColor(color(0.45, 0.28, 0.12, 0.12))
        context.setLineWidth(3.0)
        context.addPath(knotPath)
        context.strokePath()
    }
}

// MARK: - Step 4: 3D Lighting

// Main lighting gradient: light upper-left → dark lower-right
do {
    let lightColors = [
        color(1.0, 0.95, 0.82, 0.30),  // warm highlight
        color(1.0, 1.0, 1.0, 0.0),      // transparent
        color(0.18, 0.10, 0.03, 0.30),  // dark shadow
    ] as CFArray

    let locations: [CGFloat] = [0.0, 0.40, 1.0]

    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: lightColors,
        locations: locations
    )!

    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: w * 0.20, y: bowlTop + 60),
        end: CGPoint(x: w * 0.80, y: handleBottomY - 40),
        options: []
    )
}

// Handle cylindrical highlight (left-to-right gradient across the handle width)
do {
    // Clip to just the handle region
    let handleRegion = CGMutablePath()
    handleRegion.addRect(CGRect(
        x: spoonCenterX - handleWidth * 0.55,
        y: handleBottomY,
        width: handleWidth * 1.1,
        height: handleTopY - handleBottomY
    ))

    context.saveGState()
    context.addPath(handleRegion)
    context.clip()

    let hColors = [
        color(0.30, 0.18, 0.06, 0.15),   // dark left edge
        color(1.0, 0.95, 0.85, 0.12),     // bright center
        color(0.30, 0.18, 0.06, 0.18),    // dark right edge
    ] as CFArray

    let hLocs: [CGFloat] = [0.0, 0.42, 1.0]

    let hGrad = CGGradient(colorsSpace: colorSpace, colors: hColors, locations: hLocs)!
    context.drawLinearGradient(
        hGrad,
        start: CGPoint(x: spoonCenterX - handleWidth * 0.5, y: h * 0.5),
        end: CGPoint(x: spoonCenterX + handleWidth * 0.5, y: h * 0.5),
        options: []
    )
    context.restoreGState()
}

// Bowl concavity — strong directional lighting to show depth
// Bright highlight on upper-left, deep shadow on lower-right
do {
    // Highlight side (upper-left of bowl) — bright warm light
    let hiColors = [
        color(1.0, 0.94, 0.80, 0.50),
        color(1.0, 0.94, 0.80, 0.0),
    ] as CFArray
    let hiLocs: [CGFloat] = [0.0, 1.0]
    let hiGrad = CGGradient(colorsSpace: colorSpace, colors: hiColors, locations: hiLocs)!

    let hiCenter = CGPoint(x: spoonCenterX - 18, y: bowlCenterY + bowlHeight * 0.12)
    context.drawRadialGradient(
        hiGrad,
        startCenter: hiCenter,
        startRadius: 0,
        endCenter: hiCenter,
        endRadius: bowlWidth * 0.32,
        options: []
    )

    // Shadow side (lower-right of bowl) — deeper, darker
    let shColors = [
        color(0.25, 0.14, 0.04, 0.45),
        color(0.25, 0.14, 0.04, 0.0),
    ] as CFArray
    let shLocs: [CGFloat] = [0.0, 1.0]
    let shGrad = CGGradient(colorsSpace: colorSpace, colors: shColors, locations: shLocs)!

    let shCenter = CGPoint(x: spoonCenterX + 18, y: bowlCenterY - bowlHeight * 0.06)
    context.drawRadialGradient(
        shGrad,
        startCenter: shCenter,
        startRadius: 0,
        endCenter: shCenter,
        endRadius: bowlWidth * 0.35,
        options: []
    )
}

// Bowl rim — oval matching the egg-shaped head (taller than wide)
do {
    context.saveGState()

    let rimRect = CGRect(
        x: spoonCenterX - bowlWidth * 0.32,
        y: bowlCenterY - bowlHeight * 0.14,
        width: bowlWidth * 0.64,
        height: bowlHeight * 0.38
    )

    let rimPath = CGMutablePath()
    rimPath.addEllipse(in: rimRect)

    context.setStrokeColor(color(1.0, 0.95, 0.82, 0.30))
    context.setLineWidth(2.5)
    context.addPath(rimPath)
    context.strokePath()

    context.restoreGState()
}

context.restoreGState()  // Remove spoon clip

// Subtle dark outline for clarity at small sizes
do {
    context.addPath(spoonPath)
    context.setStrokeColor(color(0.35, 0.20, 0.08, 0.22))
    context.setLineWidth(2.5)
    context.strokePath()
}

// Restore from rotation
context.restoreGState()

// MARK: - Step 5: Glossy Overlay (over entire icon)

// Subtle top-to-middle gradient for glossy "bubble" feel
do {
    let glossColors = [
        color(1.0, 1.0, 1.0, 0.15),
        color(1.0, 1.0, 1.0, 0.0),
    ] as CFArray

    let locations: [CGFloat] = [0.0, 1.0]

    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: glossColors,
        locations: locations
    )!

    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: w * 0.5, y: h),
        end: CGPoint(x: w * 0.5, y: h * 0.52),
        options: []
    )
}

// Specular highlight spot
do {
    let specColors = [
        color(1.0, 1.0, 1.0, 0.10),
        color(1.0, 1.0, 1.0, 0.0),
    ] as CFArray

    let locations: [CGFloat] = [0.0, 1.0]

    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: specColors,
        locations: locations
    )!

    let specCenter = CGPoint(x: w * 0.35, y: h * 0.72)
    context.drawRadialGradient(
        gradient,
        startCenter: specCenter,
        startRadius: 0,
        endCenter: specCenter,
        endRadius: w * 0.22,
        options: []
    )
}

// MARK: - Step 6: Export

let cgImage = context.makeImage()!

let outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("AppIcon-1024.png")

let dest = CGImageDestinationCreateWithURL(
    outputURL as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
)!

CGImageDestinationAddImage(dest, cgImage, nil)

if CGImageDestinationFinalize(dest) {
    print("Icon saved to: \(outputURL.path)")
} else {
    print("ERROR: Failed to save icon")
    exit(1)
}
