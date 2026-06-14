import SpriteKit
import UIKit

class Board: SKNode {

    let shape: BoardShape
    private(set) var bubbles: [Bubble] = []
    private(set) var isFlipped = false
    private var canInteract = true
    private let bubbleRadius: CGFloat
    private var boardSize: CGSize = .zero
    private let palette: [UIColor]
    private let theme: BoardTheme

    var onBubblePop: (() -> Void)?
    var onAllPopped: (() -> Void)?

    // Board background sprites swapped during flip
    private var boardContainer:    SKNode?
    private var topBoardSprite:    SKSpriteNode?
    private var bottomBoardSprite: SKSpriteNode?
    private var borderSprite:      SKSpriteNode?

    // MARK: - Per-theme colour palettes

    static func ombreColors(for theme: BoardTheme) -> [UIColor] {
        switch theme {
        case .frost:
            return [
                UIColor(red: 0.12, green: 0.26, blue: 0.55, alpha: 1),  // deep ice navy
                UIColor(red: 0.28, green: 0.55, blue: 0.82, alpha: 1),  // steel blue
                UIColor(red: 0.50, green: 0.78, blue: 0.95, alpha: 1),  // sky blue
                UIColor(red: 0.72, green: 0.90, blue: 0.98, alpha: 1),  // pale cyan
                UIColor(red: 0.90, green: 0.96, blue: 1.00, alpha: 1),  // near-white ice
            ]
        case .embers:
            return [
                UIColor(red: 0.22, green: 0.03, blue: 0.01, alpha: 1),  // charcoal black
                UIColor(red: 0.50, green: 0.06, blue: 0.02, alpha: 1),  // deep coal red
                UIColor(red: 0.90, green: 0.10, blue: 0.02, alpha: 1),  // cherry red
                UIColor(red: 0.72, green: 0.12, blue: 0.01, alpha: 1),  // dark ember
                UIColor(red: 0.86, green: 0.22, blue: 0.01, alpha: 1),  // red-hot coal
            ]
        case .pearl:
            return [
                UIColor(red: 0.88, green: 0.07, blue: 0.17, alpha: 1),  // flag red
                UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1),  // flag white
                UIColor(red: 0.14, green: 0.26, blue: 0.82, alpha: 1),  // flag blue
            ]
        case .rainbow:
            return [
                UIColor(red: 0.97, green: 0.23, blue: 0.18, alpha: 1),  // red
                UIColor(red: 1.00, green: 0.60, blue: 0.00, alpha: 1),  // orange
                UIColor(red: 0.99, green: 0.88, blue: 0.02, alpha: 1),  // yellow
                UIColor(red: 0.18, green: 0.80, blue: 0.22, alpha: 1),  // green
                UIColor(red: 0.13, green: 0.59, blue: 0.95, alpha: 1),  // blue
                UIColor(red: 0.58, green: 0.18, blue: 0.92, alpha: 1),  // violet
            ]
        }
    }

    static func ombreColor(at t: CGFloat, theme: BoardTheme) -> UIColor {
        let colors = ombreColors(for: theme)
        let scaled = t * CGFloat(colors.count - 1)
        let i = min(max(Int(scaled), 0), colors.count - 2)
        let f = scaled - CGFloat(i)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0
        colors[i].getRed(&r1,   green: &g1, blue: &b1, alpha: nil)
        colors[i+1].getRed(&r2, green: &g2, blue: &b2, alpha: nil)
        return UIColor(red:   r1 + (r2-r1)*f,
                       green: g1 + (g2-g1)*f,
                       blue:  b1 + (b2-b1)*f, alpha: 1)
    }

    // Pearl assigns flag colors by column band: left=red, middle=white, right=blue.
    static func bubbleColor(at t: CGFloat, theme: BoardTheme, estimatedColumns: Int = 4) -> UIColor {
        guard theme == .pearl else { return ombreColor(at: t, theme: theme) }
        let colors = ombreColors(for: .pearl)  // [red, white, blue]
        switch estimatedColumns {
        case 3:
            // 3-wide (key): left col red, centre col white, right col blue
            if t < 0.25 { return colors[0] }
            if t > 0.75 { return colors[2] }
            return colors[1]
        case 5:
            // 5-wide: left 2 cols red, centre col only white, right 2 cols blue
            if t < 0.375 { return colors[0] }
            if t > 0.625 { return colors[2] }
            return colors[1]
        default:
            // 4-wide: left 2 cols red, right 2 cols blue
            return t < 0.5 ? colors[0] : colors[2]
        }
    }

    // Radial heat: centre = hottest (t=1), outer edge = coolest (t=0).
    // A small noise term breaks the perfectly smooth rings so it reads
    // more like natural coal rather than a clean gradient.
    static func embersHeat(at pos: CGPoint, maxDist: CGFloat) -> CGFloat {
        let radial = maxDist > 0 ? 1.0 - hypot(pos.x, pos.y) / maxDist : 0.5
        // Deterministic per-bubble jitter ±0.12
        let ix = Int(pos.x.rounded())
        let iy = Int(pos.y.rounded())
        var h  = ix &* 374761393 &+ iy &* 668265263
        h = (h ^ (h >> 13)) &* 1274126177
        h = h ^ (h >> 16)
        let noise = (CGFloat(h & 0x7FFFFFFF) / CGFloat(0x7FFFFFFF)) * 0.24 - 0.12
        return max(0, min(1, radial + noise))
    }

    private static func isColored(_ colors: [UIColor]) -> Bool {
        guard let c = colors.first else { return false }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: nil)
        return max(r, g, b) - min(r, g, b) > 0.15
    }

    // MARK: - Init

    init(shape: BoardShape, bubbleRadius: CGFloat) {
        let theme         = SettingsManager.shared.boardTheme
        self.theme        = theme
        self.shape        = shape
        self.bubbleRadius = bubbleRadius
        self.palette      = Self.ombreColors(for: theme)
        super.init()

        let rawPositions = shape.bubblePositions(bubbleSize: bubbleRadius * 2)

        // Shift positions so the bounding-box centre lands on this node's origin.
        // This keeps the board visually centred for all shapes (incl. asymmetric ones
        // like droid) regardless of flip state or scene placement.
        let rawXs  = rawPositions.map { $0.x }
        let rawYs  = rawPositions.map { $0.y }
        let bboxCX = ((rawXs.min() ?? 0) + (rawXs.max() ?? 0)) / 2
        let bboxCY = ((rawYs.min() ?? 0) + (rawYs.max() ?? 0)) / 2
        let positions = rawPositions.map { CGPoint(x: $0.x - bboxCX, y: $0.y - bboxCY) }

        buildBackground(positions: positions)

        let minX    = positions.map { $0.x }.min() ?? 0
        let maxX    = positions.map { $0.x }.max() ?? 0
        let xRange  = maxX - minX
        let minY    = positions.map { $0.y }.min() ?? 0
        let maxY    = positions.map { $0.y }.max() ?? 0
        let yRange  = maxY - minY
        let maxDist     = positions.map { hypot($0.x, $0.y) }.max() ?? 1
        let estimatedColumns = Int((xRange / (bubbleRadius * 2.4)).rounded()) + 1

        for pos in positions {
            let t: CGFloat
            switch theme {
            case .embers:
                t = Self.embersHeat(at: pos, maxDist: maxDist)
            case .frost:
                // Vertical ombré bottom→top matches the board background gradient direction
                t = yRange > 0 ? (pos.y - minY) / yRange : 0.5
            default:
                t = xRange > 0 ? (pos.x - minX) / xRange : 0.5
            }
            let bubble = Bubble(radius: bubbleRadius,
                                color:  Self.bubbleColor(at: t, theme: theme,
                                                         estimatedColumns: estimatedColumns),
                                theme:  theme)
            bubble.position = pos
            bubbles.append(bubble)
            addChild(bubble)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Background

    private func buildBackground(positions: [CGPoint]) {
        let pad    = bubbleRadius * 1.35
        let xs     = positions.map { $0.x }
        let ys     = positions.map { $0.y }
        let minX   = (xs.min() ?? 0) - pad
        let maxX   = (xs.max() ?? 0) + pad
        let minY   = (ys.min() ?? 0) - pad
        let maxY   = (ys.max() ?? 0) + pad
        let bgSize = CGSize(width: maxX - minX, height: maxY - minY)
        let center = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        boardSize = bgSize

        // Silhouette shadow rendered as a flat texture so overlapping circles don't accumulate opacity
        let shadowTex    = makeShadowTexture(positions: positions, center: center, bgSize: bgSize, pad: pad)
        let shadowSize   = CGSize(width: bgSize.width + 20, height: bgSize.height + 20)
        let shadowSprite = SKSpriteNode(texture: shadowTex, size: shadowSize)
        shadowSprite.position  = center
        shadowSprite.alpha     = 0.28
        shadowSprite.zPosition = -4

        // Crop node with shape-following mask
        let crop = SKCropNode()
        crop.position  = center
        crop.zPosition = -2

        // Rasterised texture mask: all circles drawn in one fillPath() pass guarantees
        // pixel-level union with no tangency gaps between pad circles and gap fills.
        let maskTex    = makeMaskTexture(positions: positions, center: center, size: bgSize, pad: pad)
        let maskSprite = SKSpriteNode(texture: maskTex, size: bgSize)
        crop.maskNode  = maskSprite

        let topTex    = makeTopTexture(size: bgSize)
        let topSprite = SKSpriteNode(texture: topTex, size: bgSize)
        crop.addChild(topSprite)
        topBoardSprite = topSprite

        let botTex    = makeBottomTexture(size: bgSize)
        let botSprite = SKSpriteNode(texture: botTex, size: bgSize)
        botSprite.isHidden = true
        crop.addChild(botSprite)
        bottomBoardSprite = botSprite

        // Shape-following border outline rendered as a ring texture.
        // borderSize adds lineWidth on each side so the outer half of the ring isn't clipped.
        let lineWidth: CGFloat = 5.0
        // borderSize adds lineWidth on EACH side: ring sits entirely outside the board silhouette
        let borderSize = CGSize(width: bgSize.width + lineWidth * 2, height: bgSize.height + lineWidth * 2)
        let borderTex = makeBorderTexture(positions: positions, center: center,
                                           size: borderSize, pad: pad, lineWidth: lineWidth)
        let bSprite = SKSpriteNode(texture: borderTex, size: borderSize)
        bSprite.position  = center
        bSprite.zPosition = -1
        borderSprite = bSprite

        // Container wraps all background visuals so xScale can be flipped as a unit
        let container = SKNode()
        container.addChild(shadowSprite)
        container.addChild(crop)
        container.addChild(bSprite)
        addChild(container)
        boardContainer = container

        if SettingsManager.shared.boardEffectsEnabled {
            if theme == .embers  { startEmberSparks() }
            if theme == .pearl   { startFireworks()   }
            if theme == .frost   { startSnow()        }
            if theme == .rainbow { startRainbows()    }
        }
    }

    private func makeTopTexture(size: CGSize) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image    = renderer.image { ctx in
            let gc = ctx.cgContext
            if theme == .embers {
                // Vertical coal ombré: charcoal at bottom → deep red → cherry → ember orange → hot amber at top
                let embersCols: [CGColor] = [
                    UIColor(red: 0.22, green: 0.03, blue: 0.01, alpha: 1).cgColor,
                    UIColor(red: 0.50, green: 0.06, blue: 0.02, alpha: 1).cgColor,
                    UIColor(red: 0.90, green: 0.10, blue: 0.02, alpha: 1).cgColor,
                    UIColor(red: 0.72, green: 0.12, blue: 0.01, alpha: 1).cgColor,
                    UIColor(red: 0.86, green: 0.22, blue: 0.01, alpha: 1).cgColor,
                ]
                let embersLocs: [CGFloat] = [0, 0.25, 0.5, 0.75, 1.0]
                if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: embersCols as CFArray, locations: embersLocs) {
                    gc.drawLinearGradient(g,
                                         start: CGPoint(x: size.width / 2, y: size.height),
                                         end:   CGPoint(x: size.width / 2, y: 0),
                                         options: [])
                }

                // Glowing ember hot-spots — scattered radial glows in the lower coal zone
                let spots: [(CGFloat, CGFloat, CGFloat)] = [
                    (0.22, 0.62, 0.14), (0.50, 0.72, 0.16), (0.70, 0.60, 0.11),
                    (0.33, 0.84, 0.09), (0.60, 0.80, 0.13), (0.80, 0.74, 0.10),
                    (0.12, 0.90, 0.07), (0.86, 0.88, 0.08), (0.44, 0.52, 0.10),
                ]
                let side = min(size.width, size.height)
                for (ex, ey, er) in spots {
                    let cx = ex * size.width
                    let cy = ey * size.height
                    let r  = er * side
                    let spotCols = [UIColor(red: 0.88, green: 0.22, blue: 0.01, alpha: 0.42).cgColor,
                                    UIColor(red: 0.72, green: 0.08, blue: 0.00, alpha: 0.00).cgColor] as CFArray
                    if let sg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                          colors: spotCols, locations: [0, 1] as [CGFloat]) {
                        gc.drawRadialGradient(sg,
                                             startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
                                             endCenter:   CGPoint(x: cx, y: cy), endRadius:   r,
                                             options: [.drawsAfterEndLocation])
                    }
                }

            } else if theme == .pearl {
                gc.setFillColor(UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1).cgColor)
                gc.fill(CGRect(origin: .zero, size: size))
            } else if theme == .rainbow {
                // Full ombré rainbow gradient — matches bubble colors exactly
                let rainbowCols: [CGColor] = [
                    UIColor(red: 0.97, green: 0.23, blue: 0.18, alpha: 1).cgColor,
                    UIColor(red: 1.00, green: 0.60, blue: 0.00, alpha: 1).cgColor,
                    UIColor(red: 0.99, green: 0.88, blue: 0.02, alpha: 1).cgColor,
                    UIColor(red: 0.18, green: 0.80, blue: 0.22, alpha: 1).cgColor,
                    UIColor(red: 0.13, green: 0.59, blue: 0.95, alpha: 1).cgColor,
                    UIColor(red: 0.58, green: 0.18, blue: 0.92, alpha: 1).cgColor,
                ]
                let rainbowLocs: [CGFloat] = [0, 0.2, 0.4, 0.6, 0.8, 1.0]
                if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: rainbowCols as CFArray, locations: rainbowLocs) {
                    gc.drawLinearGradient(g,
                                         start: CGPoint(x: 0, y: size.height / 2),
                                         end:   CGPoint(x: size.width, y: size.height / 2),
                                         options: [])
                }
            } else if theme == .frost {
                // Vertical ice gradient: deep navy at bottom → pale ice-blue at top
                let frostCols: [CGColor] = [
                    UIColor(red: 0.08, green: 0.14, blue: 0.30, alpha: 1).cgColor,
                    UIColor(red: 0.12, green: 0.26, blue: 0.55, alpha: 1).cgColor,
                    UIColor(red: 0.30, green: 0.58, blue: 0.84, alpha: 1).cgColor,
                    UIColor(red: 0.55, green: 0.80, blue: 0.96, alpha: 1).cgColor,
                ]
                if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: frostCols as CFArray,
                                      locations: [0, 0.35, 0.70, 1.0]) {
                    gc.drawLinearGradient(g,
                                         start: CGPoint(x: size.width / 2, y: size.height),
                                         end:   CGPoint(x: size.width / 2, y: 0),
                                         options: [])
                }
                // Ice crystal overlays — faint snowflakes etched into the background
                // (cx, cy, radius, alpha, rotationOffset as fraction of π/6)
                let crystals: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
                    (0.18, 0.13, 0.13, 0.13, 0.00),
                    (0.76, 0.08, 0.09, 0.11, 0.15),
                    (0.50, 0.44, 0.17, 0.09, 0.25),
                    (0.09, 0.66, 0.09, 0.12, 0.10),
                    (0.88, 0.57, 0.11, 0.12, 0.30),
                    (0.33, 0.83, 0.10, 0.10, 0.05),
                    (0.81, 0.86, 0.14, 0.10, 0.20),
                    (0.61, 0.23, 0.07, 0.14, 0.08),
                    (0.42, 0.68, 0.08, 0.11, 0.18),
                ]
                let side = min(size.width, size.height)
                gc.setLineCap(.round)
                for (fx, fy, fr, fa, frot) in crystals {
                    let cx = fx * size.width
                    let cy = fy * size.height
                    let r  = fr * side
                    gc.setStrokeColor(UIColor.white.withAlphaComponent(fa).cgColor)
                    gc.setFillColor(UIColor.white.withAlphaComponent(fa * 1.4).cgColor)
                    gc.setLineWidth(max(0.5, r * 0.055))
                    for i in 0..<6 {
                        let angle = CGFloat(i) * .pi / 3 + frot * .pi / 6
                        let ex = cx + cos(angle) * r
                        let ey = cy + sin(angle) * r
                        gc.move(to: CGPoint(x: cx, y: cy))
                        gc.addLine(to: CGPoint(x: ex, y: ey))
                        // Two side branches per arm
                        for t: CGFloat in [0.38, 0.65] {
                            let bx  = cx + cos(angle) * r * t
                            let by  = cy + sin(angle) * r * t
                            let bl  = r * 0.28
                            let ba1 = angle + .pi / 3
                            let ba2 = angle - .pi / 3
                            gc.move(to: CGPoint(x: bx, y: by))
                            gc.addLine(to: CGPoint(x: bx + cos(ba1) * bl,
                                                   y: by + sin(ba1) * bl))
                            gc.move(to: CGPoint(x: bx, y: by))
                            gc.addLine(to: CGPoint(x: bx + cos(ba2) * bl,
                                                   y: by + sin(ba2) * bl))
                        }
                    }
                    gc.strokePath()
                    // Small centre dot
                    let dr = r * 0.07
                    gc.fillEllipse(in: CGRect(x: cx - dr, y: cy - dr,
                                              width: dr * 2, height: dr * 2))
                }
                // Radial vignette — dark navy at edges, clear at centre
                let vigCentre = CGPoint(x: size.width / 2, y: size.height / 2)
                let vigRadius = max(size.width, size.height) * 0.72
                let vigColors = [UIColor(red: 0.04, green: 0.08, blue: 0.22, alpha: 0.00).cgColor,
                                 UIColor(red: 0.04, green: 0.08, blue: 0.22, alpha: 0.55).cgColor] as CFArray
                if let vg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: vigColors, locations: [0, 1] as [CGFloat]) {
                    gc.drawRadialGradient(vg,
                                         startCenter: vigCentre, startRadius: 0,
                                         endCenter:   vigCentre, endRadius:   vigRadius,
                                         options: [.drawsAfterEndLocation])
                }
            } else if Self.isColored(palette) {
                let n      = palette.count
                let locs: [CGFloat] = (0..<n).map { CGFloat($0) / CGFloat(n - 1) }
                let cgColors = palette.map { $0.cgColor } as CFArray
                if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: cgColors, locations: locs) {
                    gc.drawLinearGradient(g,
                                         start: CGPoint(x: 0, y: size.height / 2),
                                         end:   CGPoint(x: size.width, y: size.height / 2),
                                         options: [])
                }
            } else {
                gc.setFillColor(UIColor(red: 0.18, green: 0.20, blue: 0.26, alpha: 1).cgColor)
                gc.fill(CGRect(origin: .zero, size: size))
            }
            // Cartoon gloss strip across the top
            let glossColors = [UIColor.white.withAlphaComponent(0.40).cgColor,
                               UIColor.white.withAlphaComponent(0.00).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: glossColors, locations: [0, 1] as [CGFloat]) {
                gc.drawLinearGradient(g,
                                     start: CGPoint(x: size.width / 2, y: 0),
                                     end:   CGPoint(x: size.width / 2, y: size.height * 0.32),
                                     options: [])
            }
        }
        return SKTexture(image: image)
    }

    private func makeBottomTexture(size: CGSize) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image    = renderer.image { ctx in
            let gc = ctx.cgContext
            if theme == .embers {
                // Coal back face — same palette as front, darkened
                let embersBack: [CGColor] = [
                    UIColor(red: 0.22, green: 0.03, blue: 0.01, alpha: 1).darkened(by: 0.18).cgColor,
                    UIColor(red: 0.50, green: 0.06, blue: 0.02, alpha: 1).darkened(by: 0.18).cgColor,
                    UIColor(red: 0.90, green: 0.10, blue: 0.02, alpha: 1).darkened(by: 0.20).cgColor,
                    UIColor(red: 0.72, green: 0.12, blue: 0.01, alpha: 1).darkened(by: 0.18).cgColor,
                    UIColor(red: 0.86, green: 0.22, blue: 0.01, alpha: 1).darkened(by: 0.18).cgColor,
                ]
                let embersLocs: [CGFloat] = [0, 0.25, 0.5, 0.75, 1.0]
                if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: embersBack as CFArray, locations: embersLocs) {
                    gc.drawLinearGradient(g,
                                         start: CGPoint(x: size.width / 2, y: size.height),
                                         end:   CGPoint(x: size.width / 2, y: 0),
                                         options: [])
                }
            } else if theme == .pearl {
                gc.setFillColor(UIColor(red: 0.82, green: 0.82, blue: 0.82, alpha: 1).cgColor)
                gc.fill(CGRect(origin: .zero, size: size))
            } else if theme == .rainbow {
                // Same direction as front — boardContainer.xScale = -1 mirrors it at flip time
                let rainbowBack: [CGColor] = [
                    UIColor(red: 0.97, green: 0.23, blue: 0.18, alpha: 1).darkened(by: 0.28).cgColor,
                    UIColor(red: 1.00, green: 0.60, blue: 0.00, alpha: 1).darkened(by: 0.28).cgColor,
                    UIColor(red: 0.99, green: 0.88, blue: 0.02, alpha: 1).darkened(by: 0.28).cgColor,
                    UIColor(red: 0.18, green: 0.80, blue: 0.22, alpha: 1).darkened(by: 0.28).cgColor,
                    UIColor(red: 0.13, green: 0.59, blue: 0.95, alpha: 1).darkened(by: 0.28).cgColor,
                    UIColor(red: 0.58, green: 0.18, blue: 0.92, alpha: 1).darkened(by: 0.28).cgColor,
                ]
                let rainbowLocs: [CGFloat] = [0, 0.2, 0.4, 0.6, 0.8, 1.0]
                if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: rainbowBack as CFArray, locations: rainbowLocs) {
                    gc.drawLinearGradient(g,
                                         start: CGPoint(x: 0,          y: size.height / 2),
                                         end:   CGPoint(x: size.width, y: size.height / 2),
                                         options: [])
                }
            } else if theme == .frost {
                let frostBack: [CGColor] = [
                    UIColor(red: 0.08, green: 0.14, blue: 0.30, alpha: 1).darkened(by: 0.22).cgColor,
                    UIColor(red: 0.12, green: 0.26, blue: 0.55, alpha: 1).darkened(by: 0.22).cgColor,
                    UIColor(red: 0.30, green: 0.58, blue: 0.84, alpha: 1).darkened(by: 0.22).cgColor,
                    UIColor(red: 0.55, green: 0.80, blue: 0.96, alpha: 1).darkened(by: 0.22).cgColor,
                ]
                if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: frostBack as CFArray,
                                      locations: [0, 0.35, 0.70, 1.0]) {
                    gc.drawLinearGradient(g,
                                         start: CGPoint(x: size.width / 2, y: size.height),
                                         end:   CGPoint(x: size.width / 2, y: 0),
                                         options: [])
                }
            } else if Self.isColored(palette) {
                let n         = palette.count
                let locs: [CGFloat] = (0..<n).map { CGFloat($0) / CGFloat(n - 1) }
                let darkColors = palette.map { $0.darkened(by: 0.38).cgColor } as CFArray
                if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: darkColors, locations: locs) {
                    gc.drawLinearGradient(g,
                                          start: CGPoint(x: 0,          y: size.height / 2),
                                          end:   CGPoint(x: size.width, y: size.height / 2),
                                          options: [])
                }
            } else {
                gc.setFillColor(UIColor(red: 0.10, green: 0.11, blue: 0.16, alpha: 1).cgColor)
                gc.fill(CGRect(origin: .zero, size: size))
            }

            let spacing = bubbleRadius * 0.82
            let rowH    = spacing * 0.866
            let dotR    = bubbleRadius * 0.055
            let rows    = Int(size.height / rowH) + 2
            let cols    = Int(size.width  / spacing) + 2
            gc.setFillColor(UIColor.white.withAlphaComponent(0.22).cgColor)
            for row in -1..<rows {
                let xOff = (row % 2 == 0) ? CGFloat(0) : spacing / 2
                for col in -1..<cols {
                    let x = CGFloat(col) * spacing + xOff
                    let y = CGFloat(row) * rowH
                    gc.fillEllipse(in: CGRect(x: x - dotR, y: y - dotR,
                                              width: dotR * 2, height: dotR * 2))
                }
            }
        }
        return SKTexture(image: image)
    }

    // Finds centroids of all enclosed triangles (hex) and quads (square grid) formed by adjacent bubbles.
    // A gap-fill circle placed at each centroid with radius gapR fills the interior pocket
    // without breaching the outer boundary defined by pad-radius circles at each bubble.
    private func interiorGapCenters(positions: [CGPoint]) -> [CGPoint] {
        let s   = bubbleRadius * 2.4
        let tol = s * 0.30
        var out  = [CGPoint]()
        var seen = Set<String>()

        func groupKey(_ ix: [Int]) -> String { ix.sorted().map(String.init).joined(separator: ",") }
        func adjacent(_ a: CGPoint, _ b: CGPoint) -> Bool { hypot(b.x-a.x, b.y-a.y) < s * 1.15 }

        for i in 0..<positions.count {
            let pi = positions[i]
            for j in (i+1)..<positions.count {
                let pj = positions[j]
                guard adjacent(pi, pj) else { continue }

                // Triangles: k adjacent to both i and j (hex packing)
                for k in (j+1)..<positions.count {
                    let pk = positions[k]
                    guard adjacent(pi, pk), adjacent(pj, pk) else { continue }
                    let gk = groupKey([i, j, k])
                    if seen.insert(gk).inserted {
                        out.append(CGPoint(x: (pi.x+pj.x+pk.x)/3, y: (pi.y+pj.y+pk.y)/3))
                    }
                }

                // Quads: perpendicular square arrangement (square-grid packing)
                let dx = pj.x - pi.x, dy = pj.y - pi.y
                for sign: CGFloat in [-1, 1] {
                    let kp = CGPoint(x: pi.x - sign*dy, y: pi.y + sign*dx)
                    let lp = CGPoint(x: pj.x - sign*dy, y: pj.y + sign*dx)
                    guard let ki = positions.firstIndex(where: { abs($0.x-kp.x) < tol && abs($0.y-kp.y) < tol }),
                          let li = positions.firstIndex(where: { abs($0.x-lp.x) < tol && abs($0.y-lp.y) < tol }),
                          ki != i, ki != j, li != i, li != j, ki != li else { continue }
                    let gk = groupKey([i, j, ki, li])
                    if seen.insert(gk).inserted {
                        out.append(CGPoint(
                            x: (pi.x + pj.x + positions[ki].x + positions[li].x) / 4,
                            y: (pi.y + pj.y + positions[ki].y + positions[li].y) / 4))
                    }
                }
            }
        }
        return out
    }

    private func makeMaskTexture(positions: [CGPoint], center: CGPoint,
                                 size: CGSize, pad: CGFloat) -> SKTexture {
        // gapR with a small overlap buffer so gap fills don't just tangentially touch pad circles
        let halfS = bubbleRadius * 1.2
        let gapR  = halfS - sqrt(max(0, pad*pad - halfS*halfS)) + bubbleRadius * 0.06
        let gaps  = interiorGapCenters(positions: positions)

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { ctx in
            let gc = ctx.cgContext
            gc.setFillColor(UIColor.white.cgColor)
            // All pad circles and gap fills in one pass → pixel-perfect union, no sub-pixel holes
            for pos in positions {
                let tx = size.width  / 2 + (pos.x - center.x)
                let ty = size.height / 2 - (pos.y - center.y)
                gc.addEllipse(in: CGRect(x: tx-pad, y: ty-pad, width: pad*2, height: pad*2))
            }
            for g in gaps {
                let tx = size.width  / 2 + (g.x - center.x)
                let ty = size.height / 2 - (g.y - center.y)
                gc.addEllipse(in: CGRect(x: tx-gapR, y: ty-gapR, width: gapR*2, height: gapR*2))
            }
            gc.fillPath()
        }
        return SKTexture(image: image)
    }

    private func makeShadowTexture(positions: [CGPoint], center: CGPoint,
                                    bgSize: CGSize, pad: CGFloat) -> SKTexture {
        let texSize = CGSize(width: bgSize.width + 20, height: bgSize.height + 20)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: texSize, format: format)
        let image = renderer.image { ctx in
            let gc = ctx.cgContext
            // Pass 1: draw shadow silhouette at offset (+6 right, +7 down in UIKit y-down coords)
            gc.setFillColor(UIColor.black.cgColor)
            for pos in positions {
                let tx = texSize.width  / 2 + (pos.x - center.x) + 6
                let ty = texSize.height / 2 - (pos.y - center.y) + 7
                gc.addEllipse(in: CGRect(x: tx - pad, y: ty - pad, width: pad * 2, height: pad * 2))
            }
            gc.fillPath()
            // Pass 2: punch out the original board silhouette so no shadow appears inside the board
            gc.setBlendMode(.clear)
            for pos in positions {
                let tx = texSize.width  / 2 + (pos.x - center.x)
                let ty = texSize.height / 2 - (pos.y - center.y)
                gc.addEllipse(in: CGRect(x: tx - pad, y: ty - pad, width: pad * 2, height: pad * 2))
            }
            gc.fillPath()
        }
        return SKTexture(image: image)
    }

    private func makeBorderTexture(positions: [CGPoint], center: CGPoint,
                                    size: CGSize, pad: CGFloat, lineWidth: CGFloat) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { ctx in
            let gc = ctx.cgContext
            // Ring sits entirely outside the board silhouette: outerR = pad + lineWidth, innerR = pad
            // This prevents any part of the ring from appearing inside the board interior
            let outerR = pad + lineWidth
            gc.setFillColor(UIColor(white: 0.08, alpha: 0.88).cgColor)
            for pos in positions {
                let tx = size.width  / 2 + (pos.x - center.x)
                let ty = size.height / 2 - (pos.y - center.y)
                gc.addEllipse(in: CGRect(x: tx - outerR, y: ty - outerR,
                                          width: outerR * 2, height: outerR * 2))
            }
            gc.fillPath()
            // Punch out exactly the board silhouette — ring is only visible outside the board edge
            gc.setBlendMode(.clear)
            for pos in positions {
                let tx = size.width  / 2 + (pos.x - center.x)
                let ty = size.height / 2 - (pos.y - center.y)
                gc.addEllipse(in: CGRect(x: tx - pad, y: ty - pad,
                                          width: pad * 2, height: pad * 2))
            }
            gc.fillPath()
        }
        return SKTexture(image: image)
    }

    // MARK: - Effects lifecycle

    func pauseEffects() {
        removeAction(forKey: "emberSparks")
        removeAction(forKey: "snow")
        removeAction(forKey: "fireworks")
        removeAction(forKey: "rainbows")
        children.filter { $0.zPosition == 0.5 || $0.zPosition == -5 || $0.name == "rainbow_fx" }
                .forEach { $0.removeFromParent() }
    }

    func resumeEffects() {
        guard SettingsManager.shared.boardEffectsEnabled else { return }
        pauseEffects()
        if theme == .embers  { startEmberSparks() }
        if theme == .pearl   { startFireworks()   }
        if theme == .frost   { startSnow()        }
        if theme == .rainbow { startRainbows()    }
    }

    // MARK: - Ember sparks

    private func startEmberSparks() {
        let spawn = SKAction.repeatForever(SKAction.sequence([
            SKAction.run { [weak self] in self?.spawnSpark() },
            SKAction.wait(forDuration: 0.30, withRange: 0.20),
        ]))
        run(spawn, withKey: "emberSparks")
    }

    private func spawnSpark() {
        let w = boardSize.width
        let h = boardSize.height
        guard w > 0, h > 0 else { return }

        // Start in the lower 60% of the board
        let sx = CGFloat.random(in: -w * 0.38 ... w * 0.38)
        let sy = CGFloat.random(in: -h * 0.45 ... h * 0.08)

        // Orange-to-yellow ember hue
        let t = CGFloat.random(in: 0...1)
        let color = UIColor(red: 1.0, green: 0.32 + t * 0.35, blue: t * 0.06, alpha: 1.0)

        let radius = CGFloat.random(in: 1.4 ... 3.2)
        let spark = SKShapeNode(circleOfRadius: radius)
        spark.fillColor = color
        spark.strokeColor = .clear
        spark.position   = CGPoint(x: sx, y: sy)
        spark.alpha      = 0
        spark.zPosition  = 0.5
        addChild(spark)

        let riseY  = CGFloat.random(in: 40 ... 85)
        let driftX = CGFloat.random(in: -14 ... 14)
        let dur    = Double.random(in: 1.3 ... 2.4)

        let rise    = SKAction.moveBy(x: driftX, y: riseY, duration: dur)
        let fadeIn  = SKAction.fadeAlpha(to: 0.92, duration: dur * 0.14)
        let hold    = SKAction.wait(forDuration: dur * 0.14)
        let fadeOut = SKAction.fadeOut(withDuration: dur * 0.72)

        spark.run(SKAction.sequence([
            SKAction.group([rise, SKAction.sequence([fadeIn, hold, fadeOut])]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Frost snow

    private func startSnow() {
        let spawn = SKAction.repeatForever(SKAction.sequence([
            SKAction.run { [weak self] in self?.spawnSnowflake() },
            SKAction.wait(forDuration: 0.38, withRange: 0.28),
        ]))
        run(spawn, withKey: "snow")
    }

    private func spawnSnowflake() {
        let w = boardSize.width
        let h = boardSize.height
        guard w > 0, h > 0 else { return }

        // Vary between tiny flurry dots and slightly larger flakes for depth
        let radius = CGFloat.random(in: 1.0 ... 3.2)
        let alpha  = CGFloat.random(in: 0.45 ... 0.88)

        // Pale white-to-ice-blue tint
        let tint = CGFloat.random(in: 0...1)
        let color = UIColor(
            red:   0.72 + tint * 0.28,
            green: 0.88 + tint * 0.10,
            blue:  1.00,
            alpha: alpha
        )

        let flake = SKShapeNode(circleOfRadius: radius)
        flake.fillColor   = color
        flake.strokeColor = .clear
        flake.position    = CGPoint(x: CGFloat.random(in: -w * 0.52 ... w * 0.52),
                                    y: h * 0.52)
        flake.zPosition   = 0.5   // above board, softly in front of bubbles
        addChild(flake)

        let fallDist = h * 1.10
        let dur      = Double.random(in: 2.2 ... 4.0)
        let driftX   = CGFloat.random(in: -18 ... 18)

        // Gentle sinusoidal horizontal sway via two moveBy hops
        let halfDur = dur / 2
        let sway1 = SKAction.moveBy(x:  driftX, y: -fallDist * 0.5, duration: halfDur)
        let sway2 = SKAction.moveBy(x: -driftX * 0.6, y: -fallDist * 0.5, duration: halfDur)
        sway1.timingMode = .easeInEaseOut
        sway2.timingMode = .easeInEaseOut

        let fadeIn  = SKAction.fadeAlpha(to: alpha, duration: dur * 0.12)
        let fadeOut = SKAction.fadeOut(withDuration: dur * 0.30)
        let hold    = SKAction.wait(forDuration: dur * 0.58)

        flake.alpha = 0
        flake.run(SKAction.sequence([
            SKAction.group([
                SKAction.sequence([sway1, sway2]),
                SKAction.sequence([fadeIn, hold, fadeOut])
            ]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Pearl fireworks

    private func startFireworks() {
        let launch = SKAction.repeatForever(SKAction.sequence([
            SKAction.run { [weak self] in self?.spawnFirework() },
            SKAction.wait(forDuration: 1.6, withRange: 0.8),
        ]))
        run(launch, withKey: "fireworks")
    }

    private func spawnFirework() {
        let w = boardSize.width  * 0.72
        let h = boardSize.height * 0.52

        // Shell starts from below-centre and travels to a burst point in upper area
        let startX = CGFloat.random(in: -w ... w)
        let startY = -boardSize.height * 0.55
        let burstX = CGFloat.random(in: -w ... w)
        let burstY = CGFloat.random(in: h * 0.25 ... h)

        let isRed = Int.random(in: 0...1) == 0
        let color: UIColor = isRed
            ? UIColor(red: 0.88, green: 0.07, blue: 0.17, alpha: 1)
            : UIColor(red: 0.14, green: 0.26, blue: 0.82, alpha: 1)

        let shell = SKShapeNode(circleOfRadius: 2.2)
        shell.fillColor   = color
        shell.strokeColor = .clear
        shell.position    = CGPoint(x: startX, y: startY)
        shell.zPosition   = -5
        addChild(shell)

        let travelDur = Double.random(in: 0.45 ... 0.80)
        let rise = SKAction.move(to: CGPoint(x: burstX, y: burstY), duration: travelDur)
        rise.timingMode = .easeOut

        shell.run(SKAction.sequence([
            rise,
            SKAction.run { [weak self] in
                self?.fireworkBurst(at: CGPoint(x: burstX, y: burstY), color: color)
            },
            SKAction.removeFromParent()
        ]))
    }

    private func fireworkBurst(at pos: CGPoint, color: UIColor) {
        // White flash
        let flash = SKShapeNode(circleOfRadius: 6)
        flash.fillColor   = .white
        flash.strokeColor = .clear
        flash.position    = pos
        flash.zPosition   = -5
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 3.0, duration: 0.14),
                SKAction.fadeOut(withDuration: 0.14)
            ]),
            SKAction.removeFromParent()
        ]))

        // Spark particles
        let count = 30
        for i in 0..<count {
            let angle  = CGFloat(i) / CGFloat(count) * 2 * .pi + CGFloat.random(in: -0.1 ... 0.1)
            let speed  = CGFloat.random(in: 45 ... 100)
            let dx     = cos(angle) * speed
            let dy     = sin(angle) * speed
            let radius = CGFloat.random(in: 1.4 ... 3.0)
            let dur    = Double.random(in: 0.9 ... 1.5)

            // Occasionally add a white star spark for texture
            let sparkColor: UIColor = Int.random(in: 0...5) == 0 ? .white : color

            let spark = SKShapeNode(circleOfRadius: radius)
            spark.fillColor   = sparkColor
            spark.strokeColor = .clear
            spark.position    = pos
            spark.zPosition   = -5
            addChild(spark)

            // Outward burst, then gravity pulls down
            let outMove = SKAction.moveBy(x: dx,       y: dy,              duration: dur * 0.38)
            let fallMove = SKAction.moveBy(x: dx * 0.08, y: -abs(dy) * 0.55 - 25, duration: dur * 0.62)
            outMove.timingMode  = .easeOut
            fallMove.timingMode = .easeIn

            spark.run(SKAction.sequence([
                SKAction.group([
                    SKAction.sequence([outMove, fallMove]),
                    SKAction.sequence([
                        SKAction.fadeAlpha(to: 1.0, duration: dur * 0.15),
                        SKAction.wait(forDuration: dur * 0.20),
                        SKAction.fadeOut(withDuration: dur * 0.65)
                    ])
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    // MARK: - Rainbow emoji

    private func startRainbows() {
        let spawn = SKAction.repeatForever(SKAction.sequence([
            SKAction.run { [weak self] in self?.spawnRainbow() },
            SKAction.wait(forDuration: 1.4, withRange: 1.0),
        ]))
        run(spawn, withKey: "rainbows")
    }

    private func spawnRainbow() {
        let w = boardSize.width
        let h = boardSize.height
        guard w > 0, h > 0 else { return }

        let fontSize = CGFloat.random(in: 28 ... 52)
        let tex      = makeRainbowEmojiTexture(fontSize: fontSize)
        let sprite   = SKSpriteNode(texture: tex)
        sprite.name      = "rainbow_fx"
        sprite.position  = CGPoint(x: CGFloat.random(in: -w * 0.52 ... w * 0.52),
                                   y: CGFloat.random(in: -h * 0.44 ... h * 0.44))
        sprite.zPosition = -3
        sprite.alpha     = 0
        sprite.zRotation = -.pi / 4  // 45° clockwise
        addChild(sprite)

        let dur      = Double.random(in: 3.0 ... 5.5)
        let maxAlpha = CGFloat.random(in: 0.40 ... 0.70)
        let drift    = SKAction.moveBy(x: CGFloat.random(in: -15 ... 15),
                                       y: CGFloat.random(in: 10 ... 35), duration: dur)
        drift.timingMode = .easeInEaseOut
        let rotateBy = CGFloat.random(in: -0.5 ... 0.5)  // up to ~28° either way
        let spin     = SKAction.rotate(byAngle: rotateBy, duration: dur)
        spin.timingMode = .easeInEaseOut

        sprite.run(SKAction.sequence([
            SKAction.group([
                drift,
                spin,
                SKAction.sequence([
                    SKAction.fadeAlpha(to: maxAlpha, duration: dur * 0.22),
                    SKAction.wait(forDuration: dur * 0.44),
                    SKAction.fadeOut(withDuration: dur * 0.34)
                ])
            ]),
            SKAction.removeFromParent()
        ]))
    }

    private func makeRainbowEmojiTexture(fontSize: CGFloat) -> SKTexture {
        let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: fontSize)]
        let str   = NSAttributedString(string: "🌈", attributes: attrs)
        let size  = str.size()
        let fmt   = UIGraphicsImageRendererFormat(); fmt.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            str.draw(at: .zero)
        }
        return SKTexture(image: image)
    }

    // MARK: - Helpers

    private static func posKey(_ p: CGPoint) -> String {
        "\(Int(p.x.rounded()))_\(Int(p.y.rounded()))"
    }

    // MARK: - Queries

    var allPopped: Bool  { bubbles.allSatisfy { !$0.isRaised } }
    var raisedCount: Int { bubbles.filter     {  $0.isRaised }.count }

    // MARK: - Interaction

    func tryPop(at scenePoint: CGPoint) {
        guard canInteract, let scene = self.scene else { return }
        let local = convert(scenePoint, from: scene)
        guard let bubble = bubbles.first(where: {
            hypot($0.position.x - local.x, $0.position.y - local.y) <= bubbleRadius
        }) else { return }

        if !isFlipped {
            guard bubble.isRaised else { return }
            bubble.pop()
            onBubblePop?()
            if allPopped { onAllPopped?() }
        } else {
            guard bubble.isRaised else { return }
            bubble.popBackToTop()
            onBubblePop?()
            if allPopped { onAllPopped?() }
        }
    }

    // MARK: - Reset

    func resetBoard(completion: (() -> Void)? = nil) {
        guard canInteract else { return }
        let pressed = bubbles.filter { !$0.isRaised }
        guard !pressed.isEmpty else { completion?(); return }
        canInteract = false

        for (i, bubble) in pressed.enumerated() {
            run(SKAction.sequence([
                SKAction.wait(forDuration: Double(i) * 0.05),
                SKAction.run { [weak self] in bubble.resetPop(playPopIn: self?.isFlipped == true) }
            ]))
        }

        let totalTime = Double(pressed.count - 1) * 0.05 + 0.20
        run(SKAction.sequence([
            SKAction.wait(forDuration: totalTime),
            SKAction.run { [weak self] in
                self?.canInteract = true
                completion?()
            }
        ]))
    }

    // MARK: - Flip

    func flip(completion: (() -> Void)? = nil) {
        guard canInteract else { return }
        canInteract = false
        HapticManager.shared.flip()

        let halfIn  = SKAction.scaleX(to: 0.01, duration: 0.14)
        halfIn.timingMode  = .easeIn
        let halfOut = SKAction.scaleX(to: 1.0,  duration: 0.14)
        halfOut.timingMode = .easeOut

        run(halfIn) { [weak self] in
            guard let self else { return }
            self.isFlipped.toggle()

            self.topBoardSprite?.isHidden    =  self.isFlipped
            self.bottomBoardSprite?.isHidden = !self.isFlipped
            self.borderSprite?.alpha = self.isFlipped ? 0.65 : 1.0
            // Mirror the background container so the silhouette matches the flipped bubble layout
            self.boardContainer?.xScale *= -1

            // X-mirror swap: horizontal flip maps position (x,y) → (-x,y).
            // Each position gets the inverted state of its mirror partner.
            var posToIdx = [String: Int]()
            for (i, b) in self.bubbles.enumerated() {
                posToIdx[Self.posKey(b.position)] = i
            }
            var done = Set<Int>()
            for (i, bubble) in self.bubbles.enumerated() {
                guard !done.contains(i) else { continue }
                let mKey = Self.posKey(CGPoint(x: -bubble.position.x, y: bubble.position.y))
                if let j = posToIdx[mKey], j != i {
                    let other = self.bubbles[j]
                    bubble.isRaised = !bubble.isRaised
                    other.isRaised = !other.isRaised
                    // Swap physical positions so colors and states appear at the mirrored location
                    let savedPos = bubble.position
                    bubble.position = other.position
                    other.position = savedPos
                    done.insert(j)
                } else {
                    bubble.isRaised = !bubble.isRaised
                    bubble.position = CGPoint(x: -bubble.position.x, y: bubble.position.y)
                }
                done.insert(i)
            }
            for bubble in self.bubbles {
                bubble.setBottomSide(self.isFlipped)
            }

            self.run(halfOut) { [weak self] in
                self?.canInteract = true
                completion?()
            }
        }
    }
}
