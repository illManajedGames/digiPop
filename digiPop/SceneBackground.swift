import SpriteKit

extension SKScene {

    /// Adds the shared soft-grain + radial-sheen background layers used by the
    /// palette-themed scenes (game, board select, settings).
    /// - Parameter overlayBase: white for dark themes, black for light themes.
    func addSheenLayer(overlayBase: UIColor) {
        // Soft grain — 256×256 source stretched to screen; bilinear blur creates soothing fabric feel
        let grainSize = CGSize(width: 256, height: 256)
        let grainImage = UIGraphicsImageRenderer(size: grainSize).image { ctx in
            let gc = ctx.cgContext
            for _ in 0..<2800 {
                let x = CGFloat.random(in: 0..<grainSize.width)
                let y = CGFloat.random(in: 0..<grainSize.height)
                let a = CGFloat.random(in: 0.0...0.055)
                gc.setFillColor(overlayBase.withAlphaComponent(a).cgColor)
                gc.fill(CGRect(x: x, y: y, width: 1.5, height: 1.5))
            }
        }
        let grainNode = SKSpriteNode(texture: SKTexture(image: grainImage), size: size)
        grainNode.zPosition = -11
        addChild(grainNode)

        // Radial sheen — lighter centre fading outward
        let sheenImage = UIGraphicsImageRenderer(size: size).image { ctx in
            let gc     = ctx.cgContext
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = max(size.width, size.height) * 0.65
            let colors = [overlayBase.withAlphaComponent(0.10).cgColor,
                          overlayBase.withAlphaComponent(0.00).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors, locations: [0, 1] as [CGFloat]) {
                gc.drawRadialGradient(g, startCenter: center, startRadius: 0,
                                      endCenter: center, endRadius: radius,
                                      options: [.drawsAfterEndLocation])
            }
        }
        let sheenNode = SKSpriteNode(texture: SKTexture(image: sheenImage), size: size)
        sheenNode.zPosition = -10
        addChild(sheenNode)
    }
}
