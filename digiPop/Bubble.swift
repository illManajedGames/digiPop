import SpriteKit
import UIKit

class Bubble: SKNode {

    let radius: CGFloat
    private let baseColor: UIColor

    private var domeSprite: SKSpriteNode!
    private var isBottomSide = false

    // Pre-baked textures for both sides and both states
    private let raisedTopTexture:     SKTexture
    private let pressedTopTexture:    SKTexture
    private let raisedBottomTexture:  SKTexture
    private let pressedBottomTexture: SKTexture

    var isRaised: Bool = true {
        didSet { guard oldValue != isRaised else { return }; applyAppearance() }
    }

    init(radius: CGFloat, color: UIColor, theme: BoardTheme = .rainbow) {
        self.radius = radius
        self.baseColor = color
        raisedTopTexture     = Bubble.buildTexture(radius: radius, color: color, raised: true,  bottom: false, theme: theme)
        pressedTopTexture    = Bubble.buildTexture(radius: radius, color: color, raised: false, bottom: false, theme: theme)
        raisedBottomTexture  = Bubble.buildTexture(radius: radius, color: color, raised: true,  bottom: true,  theme: theme)
        pressedBottomTexture = Bubble.buildTexture(radius: radius, color: color, raised: false, bottom: true,  theme: theme)
        super.init()
        setupNodes()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupNodes() {
        domeSprite = SKSpriteNode(texture: raisedTopTexture,
                                  size: CGSize(width: radius * 2, height: radius * 2))
        addChild(domeSprite)
    }

    // MARK: - Side switching

    func setBottomSide(_ bottom: Bool) {
        isBottomSide = bottom
        applyAppearance()
    }

    // MARK: - Interaction

    func pop() {
        guard isRaised else { return }
        isRaised = false
        let squish = SKAction.scale(to: 0.86, duration: 0.06)
        squish.timingMode = .easeIn
        let bounce = SKAction.scale(to: 1.0, duration: 0.09)
        bounce.timingMode = .easeOut
        run(SKAction.sequence([squish, bounce]))
        SoundManager.shared.playPopIn()
        HapticManager.shared.pop()
    }

    func popBackToTop() {
        guard isRaised else { return }
        isRaised = false
        let squish = SKAction.scale(to: 0.86, duration: 0.06)
        squish.timingMode = .easeIn
        let bounce = SKAction.scale(to: 1.0, duration: 0.09)
        bounce.timingMode = .easeOut
        run(SKAction.sequence([squish, bounce]))
        SoundManager.shared.playPopOut()
        HapticManager.shared.pop()
    }

    func resetPop(playPopIn: Bool = false) {
        guard !isRaised else { return }
        isRaised = true
        let expand = SKAction.scale(to: 1.08, duration: 0.05)
        expand.timingMode = .easeOut
        let settle = SKAction.scale(to: 1.0,  duration: 0.07)
        settle.timingMode = .easeIn
        run(SKAction.sequence([expand, settle]))
        if playPopIn { SoundManager.shared.playPopIn() } else { SoundManager.shared.playPopOut() }
        HapticManager.shared.pop()
    }

    // MARK: - Appearance

    private func applyAppearance() {
        domeSprite.texture = isBottomSide
            ? (isRaised ? raisedBottomTexture  : pressedBottomTexture)
            : (isRaised ? raisedTopTexture     : pressedTopTexture)
    }

    // MARK: - Texture generation

    private static func buildTexture(radius r: CGFloat, color: UIColor,
                                     raised: Bool, bottom: Bool,
                                     theme: BoardTheme = .rainbow) -> SKTexture {
        let d = r * 2
        let cx = r, cy = r
        let circleRect = CGRect(x: 0, y: 0, width: d, height: d)

        // Unsaturated colors get a fallback so they read on the board.
        // Pearl's white stripe uses a warm off-white; other unsaturated colors get grey-blue.
        var r0: CGFloat = 0, g0: CGFloat = 0, b0: CGFloat = 0
        color.getRed(&r0, green: &g0, blue: &b0, alpha: nil)
        let isColored = max(r0, g0, b0) - min(r0, g0, b0) > 0.15
        let base: UIColor
        if isColored {
            base = color
        } else if theme == .pearl {
            base = UIColor(red: 0.94, green: 0.94, blue: 0.92, alpha: 1)
        } else {
            base = UIColor(red: 0.55, green: 0.75, blue: 0.95, alpha: 1)
        }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: d, height: d))
        let image = renderer.image { ctx in
            let gc = ctx.cgContext
            gc.addEllipse(in: circleRect)
            gc.clip()

            if !bottom {
                // ── TOP SIDE ────────────────────────────────────────────────────
                if raised {
                    gc.setFillColor(base.cgColor)
                    gc.fill(circleRect)

                    // Bottom rim shadow
                    drawLinear(gc, colors: [clear, k(0.24)], locs: [0, 1],
                               start: CGPoint(x: cx, y: r * 1.05), end: CGPoint(x: cx, y: d))

                    // Cartoon gloss crescent at top-left (enlarged + brighter for frost)
                    let isFrost = theme == .frost
                    let glossW  = isFrost ? d * 0.78 : d * 0.66
                    let glossH  = isFrost ? r * 0.64 : r * 0.52
                    let glossA  = isFrost ? CGFloat(0.92) : CGFloat(0.78)
                    let glossEnd = isFrost ? r * 0.70 : r * 0.56
                    clipEllipse(gc, rect: CGRect(x: cx * 0.06, y: cy * 0.05,
                                                 width: glossW, height: glossH)) {
                        drawLinear(gc, colors: [w(glossA), w(0)], locs: [0, 1],
                                   start: CGPoint(x: cx, y: 0),
                                   end:   CGPoint(x: cx, y: glossEnd))
                    }
                    // Frost-only: secondary specular pinpoint for wet-ice look
                    if isFrost {
                        gc.setFillColor(UIColor.white.withAlphaComponent(0.88).cgColor)
                        gc.fillEllipse(in: CGRect(x: cx * 0.22, y: r * 0.07,
                                                  width: r * 0.16, height: r * 0.10))
                    }

                    // Bold cartoon outline (lineWidth straddles the clip edge — only inside half shows)
                    gc.addEllipse(in: circleRect.insetBy(dx: 0.5, dy: 0.5))
                    gc.setStrokeColor((theme == .embers
                        ? UIColor(red: 0.82, green: 0.20, blue: 0.01, alpha: 0.88)
                        : UIColor(white: 0.06, alpha: 0.82)).cgColor)
                    gc.setLineWidth(r * 0.16)
                    gc.strokePath()

                } else {
                    gc.setFillColor(base.darkened(by: 0.22).cgColor)
                    gc.fill(circleRect)

                    // Inner shadow at top (pressed concavity)
                    drawLinear(gc, colors: [k(0.32), clear], locs: [0, 1],
                               start: CGPoint(x: cx, y: 0),
                               end:   CGPoint(x: cx, y: r * 1.2))

                    // Rim shadow
                    drawRadial(gc, colors: [clear, k(0.22)], locs: [0.55, 1.0],
                               center: CGPoint(x: cx, y: cy), r0: 0, r1: r)

                    // Small shine dot at bottom
                    gc.setFillColor(UIColor.white.withAlphaComponent(0.24).cgColor)
                    gc.fillEllipse(in: CGRect(x: cx - r*0.20, y: d - r*0.36,
                                              width: r*0.40, height: r*0.18))

                    // Bold cartoon outline
                    gc.addEllipse(in: circleRect.insetBy(dx: 0.5, dy: 0.5))
                    gc.setStrokeColor((theme == .embers
                        ? UIColor(red: 0.82, green: 0.20, blue: 0.01, alpha: 0.88)
                        : UIColor(white: 0.06, alpha: 0.82)).cgColor)
                    gc.setLineWidth(r * 0.16)
                    gc.strokePath()
                }

            } else {
                // ── BOTTOM SIDE ──────────────────────────────────────────────────
                if raised {
                    gc.setFillColor(base.darkened(by: 0.08).cgColor)
                    gc.fill(circleRect)

                    drawRadial(gc, colors: [w(0.12), clear, k(0.20)], locs: [0, 0.42, 1.0],
                               center: CGPoint(x: cx * 0.66, y: cy * 0.50), r0: 0, r1: r * 1.05)

                    clipEllipse(gc, rect: CGRect(x: cx*0.16, y: cy*0.06,
                                                 width: d*0.68, height: r*0.46)) {
                        drawLinear(gc, colors: [w(0.48), clear], locs: [0, 1],
                                   start: CGPoint(x: cx, y: 0),
                                   end:   CGPoint(x: cx, y: r * 0.52))
                    }

                    gc.addEllipse(in: circleRect.insetBy(dx: 0.5, dy: 0.5))
                    gc.setStrokeColor((theme == .embers
                        ? UIColor(red: 0.82, green: 0.20, blue: 0.01, alpha: 0.88)
                        : UIColor(white: 0.06, alpha: 0.82)).cgColor)
                    gc.setLineWidth(r * 0.16)
                    gc.strokePath()

                } else {
                    gc.setFillColor(base.darkened(by: 0.34).cgColor)
                    gc.fill(circleRect)
                    drawLinear(gc, colors: [k(0.38), clear], locs: [0, 1],
                               start: CGPoint(x: cx, y: d), end: CGPoint(x: cx, y: r * 0.80))
                    drawRadial(gc, colors: [clear, k(0.22)], locs: [0.52, 1.0],
                               center: CGPoint(x: cx, y: cy), r0: 0, r1: r)

                    gc.addEllipse(in: circleRect.insetBy(dx: 0.5, dy: 0.5))
                    gc.setStrokeColor((theme == .embers
                        ? UIColor(red: 0.82, green: 0.20, blue: 0.01, alpha: 0.88)
                        : UIColor(white: 0.06, alpha: 0.82)).cgColor)
                    gc.setLineWidth(r * 0.16)
                    gc.strokePath()
                }

                // Concentric molding rings
                gc.setStrokeColor(UIColor.black.withAlphaComponent(0.20).cgColor)
                gc.setLineWidth(0.9)
                for i in 1...3 {
                    let rr = r * CGFloat(i) / 3.8
                    gc.addEllipse(in: CGRect(x: cx-rr, y: cy-rr, width: rr*2, height: rr*2))
                    gc.strokePath()
                }
            }
        }
        return SKTexture(image: image)
    }

    // MARK: - CG helpers

    private static func drawRadial(_ gc: CGContext,
                                   colors: [CGColor], locs: [CGFloat],
                                   center: CGPoint, r0: CGFloat, r1: CGFloat) {
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: colors as CFArray, locations: locs) else { return }
        gc.drawRadialGradient(g, startCenter: center, startRadius: r0,
                              endCenter: center, endRadius: r1, options: .drawsAfterEndLocation)
    }

    private static func drawLinear(_ gc: CGContext,
                                   colors: [CGColor], locs: [CGFloat],
                                   start: CGPoint, end: CGPoint) {
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: colors as CFArray, locations: locs) else { return }
        gc.drawLinearGradient(g, start: start, end: end, options: [])
    }

    private static func clipEllipse(_ gc: CGContext, rect: CGRect, draw: () -> Void) {
        gc.saveGState()
        gc.addEllipse(in: rect)
        gc.clip()
        draw()
        gc.restoreGState()
    }

    private static func sq(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> CGRect {
        CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
    }

    private static func w(_ a: CGFloat) -> CGColor {
        UIColor.white.withAlphaComponent(a).cgColor
    }
    private static func k(_ a: CGFloat) -> CGColor {
        UIColor.black.withAlphaComponent(a).cgColor
    }
    private static var clear: CGColor { UIColor.clear.cgColor }
}

// MARK: - UIColor helpers

extension UIColor {
    func darkened(by amount: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: s, brightness: max(0, b - amount), alpha: a)
    }
}
