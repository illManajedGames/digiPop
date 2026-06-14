import SpriteKit

class SplashScene: SKScene {

    private static let bgColor  = UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1)
    private static let darkText = UIColor(red: 0.95, green: 0.92, blue: 0.88, alpha: 1)
    private static let muteText = UIColor(red: 0.95, green: 0.92, blue: 0.88, alpha: 0.50)

    // Pre-built during the splash so the transition is instant
    private var prebuiltGame: GameScene?

    override func sceneDidLoad() {
        anchorPoint    = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = Self.bgColor
        addSheenLayer()
        setupTitle()
        scheduleTransition()
    }

    override func didMove(to view: SKView) {
        // Pre-warm heavy singletons and build GameScene 0.4s after the splash appears so the
        // logo animation renders its first frames before the main thread is briefly blocked.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self else { return }
            _ = SoundManager.shared   // triggers audio engine startup + PCM buffer synthesis
            let game = GameScene(size: self.size)
            game.scaleMode = self.scaleMode
            self.prebuiltGame = game
        }
    }

    // MARK: - Background

    private func addSheenLayer() {
        let grainSize  = CGSize(width: 256, height: 256)
        let grainImage = UIGraphicsImageRenderer(size: grainSize).image { ctx in
            let gc = ctx.cgContext
            for _ in 0..<2800 {
                let x = CGFloat.random(in: 0..<grainSize.width)
                let y = CGFloat.random(in: 0..<grainSize.height)
                let a = CGFloat.random(in: 0.0...0.055)
                let v = CGFloat.random(in: 0.0...1.0)
                gc.setFillColor(UIColor(white: v, alpha: a).cgColor)
                gc.fill(CGRect(x: x, y: y, width: 1.5, height: 1.5))
            }
        }
        let grainNode = SKSpriteNode(texture: SKTexture(image: grainImage), size: size)
        grainNode.zPosition = -11
        addChild(grainNode)

        let sheenImage = UIGraphicsImageRenderer(size: size).image { ctx in
            let gc     = ctx.cgContext
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = max(size.width, size.height) * 0.65
            let colors = [UIColor.white.withAlphaComponent(0.10).cgColor,
                          UIColor.white.withAlphaComponent(0.00).cgColor] as CFArray
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

    // MARK: - Title

    private func setupTitle() {
        let logo = SKNode()
        logo.alpha = 0

        // "digi" — light, airy, slightly muted
        let digiLabel = SKLabelNode(fontNamed: "AvenirNext-UltraLight")
        digiLabel.text      = "digi"
        digiLabel.fontSize  = 48
        digiLabel.fontColor = Self.darkText.withAlphaComponent(0.70)
        digiLabel.horizontalAlignmentMode = .center
        digiLabel.position  = CGPoint(x: 0, y: 28)
        logo.addChild(digiLabel)

        // "POP" — heavy, large, pops forward
        let popLabel = SKLabelNode(fontNamed: "Futura-CondensedExtraBold")
        popLabel.text      = "POP"
        popLabel.fontSize  = 88
        popLabel.fontColor = Self.darkText
        popLabel.horizontalAlignmentMode = .center
        popLabel.position  = CGPoint(x: 0, y: -62)
        logo.addChild(popLabel)

        // Tagline
        let tagLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        tagLabel.text      = "a digital fidget pop toy"
        tagLabel.fontSize  = 14
        tagLabel.fontColor = Self.muteText
        tagLabel.horizontalAlignmentMode = .center
        tagLabel.position  = CGPoint(x: 0, y: -96)
        logo.addChild(tagLabel)

        addChild(logo)

        // Studio attribution — fades in separately, anchored to bottom of screen
        let studioLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        studioLabel.text      = "illManajed Games"
        studioLabel.fontSize  = 12
        studioLabel.fontColor = Self.muteText.withAlphaComponent(0.70)
        studioLabel.horizontalAlignmentMode = .center
        studioLabel.position  = CGPoint(x: 0, y: -size.height / 2 + 48)
        studioLabel.alpha     = 0
        addChild(studioLabel)
        studioLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.3),
            SKAction.fadeIn(withDuration: 0.55)
        ]))

        // Fade + subtle rise in
        logo.position = CGPoint(x: 0, y: -12)
        let fadeIn = SKAction.group([
            SKAction.fadeIn(withDuration: 0.55),
            SKAction.moveBy(x: 0, y: 12, duration: 0.55)
        ])
        fadeIn.timingMode = .easeOut
        logo.run(fadeIn)
    }

    // MARK: - Transition

    private func scheduleTransition() {
        run(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.run { [weak self] in
                guard let self, let view = self.view else { return }
                // Use the pre-built scene if ready; fall back to building synchronously
                let game = self.prebuiltGame ?? {
                    let g = GameScene(size: self.size)
                    g.scaleMode = self.scaleMode
                    return g
                }()
                // fade(with:) passes through solid black — never exposes the UIKit background
                view.presentScene(game, transition: SKTransition.fade(with: .black, duration: 0.5))
                NotificationCenter.default.post(name: .splashDidFinish, object: nil)
            }
        ]))
    }
}
