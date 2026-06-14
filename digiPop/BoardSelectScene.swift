import SpriteKit

class BoardSelectScene: SKScene {

    private var palette: ThemePalette { SettingsManager.shared.palette }

    private var shapes:       [BoardShape] = []
    private var currentIndex  = 0
    private var virtualIndex  = 0
    private var isAnimating   = false

    private var nameLabel:   SKLabelNode!
    private var statusLabel: SKLabelNode!
    private var countLabel:  SKLabelNode!

    private var carouselContainer: SKNode!
    private var boardNodes: [Int: SKNode] = [:]
    private var cardSpacing: CGFloat = 0

    private var pendingUnwrapShapes: Set<String> = []

    private var pipNodes:      [SKShapeNode] = []
    private var pipsContainer: SKNode!

    private var dragStartX:          CGFloat = 0
    private var dragStartContainerX: CGFloat = 0
    private var isDragging = false

    // Card dimensions derived from scene/layout metrics
    private var cardW:       CGFloat { size.width * 0.72 }
    private var cardH:       CGFloat { carouselAvailH * 0.82 }
    private var cardHeaderH: CGFloat { max(cardH * 0.18, 44) }
    private var cardCornerR: CGFloat { 16 }

    // MARK: - Setup

    override func sceneDidLoad() {
        anchorPoint     = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = palette.bgColor
        shapes          = BoardShape.allCases.sorted { $0.unlockPops < $1.unlockPops }
        currentIndex    = shapes.firstIndex(of: GameProgress.shared.currentBoardShape) ?? 0
        virtualIndex    = currentIndex
        cardSpacing     = size.width * 0.80

        let progress = GameProgress.shared
        for shape in shapes where shape.unlockPops > 0 {
            if progress.isUnlocked(shape) && !progress.hasSeenUnlockAnimation(for: shape) {
                pendingUnwrapShapes.insert(shape.rawValue)
            }
        }

        addSheenLayer()
        setupInfoArea()
        setupCarousel()
        setupPips()
        addBackButton()
        refreshInfo(animated: false)
        startBubbleAnimation(for: virtualIndex)
    }

    // MARK: - Background

    private func addSheenLayer() {
        let grainSize = CGSize(width: 256, height: 256)
        let grainImage = UIGraphicsImageRenderer(size: grainSize).image { ctx in
            let gc = ctx.cgContext
            for _ in 0..<2800 {
                let x = CGFloat.random(in: 0..<grainSize.width)
                let y = CGFloat.random(in: 0..<grainSize.height)
                let a = CGFloat.random(in: 0.0...0.055)
                gc.setFillColor(palette.overlayBase.withAlphaComponent(a).cgColor)
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
            let colors = [palette.overlayBase.withAlphaComponent(0.10).cgColor,
                          palette.overlayBase.withAlphaComponent(0.00).cgColor] as CFArray
            let locs: [CGFloat] = [0, 1]
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors, locations: locs) {
                gc.drawRadialGradient(g, startCenter: center, startRadius: 0,
                                      endCenter: center, endRadius: radius,
                                      options: [.drawsAfterEndLocation])
            }
        }
        let sheenNode = SKSpriteNode(texture: SKTexture(image: sheenImage), size: size)
        sheenNode.zPosition = -10
        addChild(sheenNode)
    }

    // MARK: - Info area

    private func setupInfoArea() {
        let topY = size.height / 2 - 108

        let header = SKLabelNode(fontNamed: "AvenirNext-Bold")
        header.text                    = "BOARDS"
        header.fontSize                = 11
        header.fontColor               = palette.muteText
        header.horizontalAlignmentMode = .center
        header.position                = CGPoint(x: 0, y: size.height / 2 - 64)
        header.zPosition               = 10
        addChild(header)

        nameLabel = SKLabelNode(fontNamed: "Futura-CondensedExtraBold")
        nameLabel.fontSize   = 36
        nameLabel.fontColor  = palette.darkText
        nameLabel.horizontalAlignmentMode = .center
        nameLabel.position   = CGPoint(x: 0, y: topY)
        nameLabel.zPosition  = 10
        addChild(nameLabel)

        statusLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        statusLabel.fontSize  = 16
        statusLabel.fontColor = palette.muteText
        statusLabel.horizontalAlignmentMode = .center
        statusLabel.position  = CGPoint(x: 0, y: topY - 40)
        statusLabel.zPosition = 10
        addChild(statusLabel)

        countLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        countLabel.fontSize   = 12
        countLabel.fontColor  = palette.muteText.withAlphaComponent(0.40)
        countLabel.horizontalAlignmentMode = .center
        countLabel.position   = CGPoint(x: 0, y: topY - 62)
        countLabel.zPosition  = 10
        addChild(countLabel)
    }

    // MARK: - Layout helpers

    private var infoAreaBottom: CGFloat {
        (size.height / 2 - 108 - 62) - 8
    }

    private var backButtonTop: CGFloat {
        -size.height / 2 + 260
    }

    private var carouselCenterY: CGFloat {
        (infoAreaBottom + backButtonTop) / 2
    }

    private var carouselAvailH: CGFloat {
        infoAreaBottom - backButtonTop
    }

    private var pipRowY: CGFloat {
        let carouselBottom = carouselCenterY - cardH / 2
        return (carouselBottom + backButtonTop) / 2
    }

    private func shape(at virtual: Int) -> BoardShape {
        let n = shapes.count
        return shapes[((virtual % n) + n) % n]
    }

    // MARK: - Carousel setup

    private func setupCarousel() {
        carouselContainer          = SKNode()
        carouselContainer.position = CGPoint(x: 0, y: carouselCenterY)
        addChild(carouselContainer)

        for vi in [virtualIndex - 1, virtualIndex, virtualIndex + 1] {
            addCardNode(at: vi)
        }
        carouselContainer.position.x = -CGFloat(virtualIndex) * cardSpacing
        updateCardTransforms(animated: false)
    }

    private func addCardNode(at virtual: Int) {
        guard boardNodes[virtual] == nil else { return }
        let node = makeCardNode(for: shape(at: virtual))
        node.position = CGPoint(x: CGFloat(virtual) * cardSpacing, y: 0)
        carouselContainer.addChild(node)
        boardNodes[virtual] = node
    }

    // MARK: - Dot page indicator

    private func setupPips() {
        pipsContainer          = SKNode()
        pipsContainer.zPosition = 10
        addChild(pipsContainer)

        let spacing: CGFloat = 10
        let count    = shapes.count
        let startX   = -CGFloat(count - 1) * spacing / 2

        for i in 0..<count {
            let pip = SKShapeNode()
            pip.fillColor   = palette.accentColor
            pip.strokeColor = .clear
            pip.position    = CGPoint(x: startX + CGFloat(i) * spacing, y: pipRowY)
            pipsContainer.addChild(pip)
            pipNodes.append(pip)
        }

        updatePips(animated: false)
    }

    private func updatePips(animated: Bool) {
        for (i, pip) in pipNodes.enumerated() {
            let isActive     = i == currentIndex
            let targetAlpha: CGFloat = isActive ? 1.0 : 0.28
            let newPath: CGPath = isActive
                ? CGPath(roundedRect: CGRect(x: -6, y: -3, width: 12, height: 6),
                         cornerWidth: 3, cornerHeight: 3, transform: nil)
                : CGPath(ellipseIn: CGRect(x: -3, y: -3, width: 6, height: 6), transform: nil)

            pip.path = newPath
            if animated {
                pip.run(SKAction.fadeAlpha(to: targetAlpha, duration: 0.20))
            } else {
                pip.alpha = targetAlpha
            }
        }
    }

    // MARK: - Card builders

    private func makeCardNode(for shape: BoardShape) -> SKNode {
        let container = SKNode()
        container.name = shape.rawValue
        let unlocked    = GameProgress.shared.isUnlocked(shape)
        let showPackage = !unlocked || pendingUnwrapShapes.contains(shape.rawValue)

        if showPackage {
            let r = packagedBubbleRadius(for: shape)
            container.addChild(makePackagingCard(
                shape: shape, radius: r,
                isPendingUnwrap: unlocked
            ))
        } else {
            let r = spotlightBubbleRadius(for: shape)
            container.addChild(makeSpotlightCard(shape: shape, radius: r))
        }
        return container
    }

    private func clampedBubbleRadius(shape: BoardShape, availW: CGFloat, availH: CGFloat) -> CGFloat {
        let tmp: CGFloat = 40
        let positions = shape.bubblePositions(bubbleSize: tmp * 2)
        let xs = positions.map { $0.x }
        let ys = positions.map { $0.y }
        let boardW = (xs.max()! - xs.min()!) + tmp * 2
        let boardH = (ys.max()! - ys.min()!) + tmp * 2
        return min(tmp * min(availW / boardW, availH / boardH), 46)
    }

    private func packagedBubbleRadius(for shape: BoardShape) -> CGFloat {
        let badgeH:  CGFloat = 36
        let padding: CGFloat = 24
        let availW = cardW - padding
        let availH = cardH - cardHeaderH - badgeH - padding * 2
        return clampedBubbleRadius(shape: shape, availW: availW, availH: max(availH, 40))
    }

    private func spotlightBubbleRadius(for shape: BoardShape) -> CGFloat {
        let padding: CGFloat = 36
        return clampedBubbleRadius(shape: shape, availW: cardW - padding, availH: cardH - padding)
    }

    // Blister-pack card for locked / pending-unwrap boards
    private func makePackagingCard(shape: BoardShape, radius r: CGFloat, isPendingUnwrap: Bool) -> SKNode {
        let packaging = SKNode()
        packaging.name = "packaging"

        let cW = cardW
        let cH = cardH
        let hH = cardHeaderH
        let cr = cardCornerR

        // Card background
        let bg = SKShapeNode(rectOf: CGSize(width: cW, height: cH), cornerRadius: cr)
        bg.fillColor   = palette.cardFill
        bg.strokeColor = isPendingUnwrap
            ? palette.accentColor.withAlphaComponent(0.55)
            : palette.cardStroke
        bg.lineWidth   = isPendingUnwrap ? 1.5 : 1.0
        bg.zPosition   = 0
        packaging.addChild(bg)

        // Header strip clipped to card's rounded corners
        let cropNode  = SKCropNode()
        cropNode.zPosition = 1
        let cropMask = SKShapeNode(rectOf: CGSize(width: cW, height: cH), cornerRadius: cr)
        cropMask.fillColor   = .white
        cropMask.strokeColor = .clear
        cropNode.maskNode    = cropMask

        if isPendingUnwrap {
            let headerFill = SKShapeNode(rectOf: CGSize(width: cW + 2, height: hH))
            headerFill.fillColor   = palette.accentColor
            headerFill.strokeColor = .clear
            headerFill.position    = CGPoint(x: 0, y: cH / 2 - hH / 2)
            cropNode.addChild(headerFill)
        } else {
            let progress = shape.unlockPops > 0
                ? min(CGFloat(GameProgress.shared.totalPops) / CGFloat(shape.unlockPops), 1.0)
                : 1.0
            let totalW   = cW + 2
            let headerY  = cH / 2 - hH / 2

            // Faint track — full width
            let track = SKShapeNode(rectOf: CGSize(width: totalW, height: hH))
            track.fillColor   = palette.accentColor.withAlphaComponent(0.12)
            track.strokeColor = .clear
            track.position    = CGPoint(x: 0, y: headerY)
            cropNode.addChild(track)

            // Progress fill — left to right
            if progress > 0.01 {
                let fillW = totalW * progress
                let fill  = SKShapeNode(rectOf: CGSize(width: fillW, height: hH))
                fill.fillColor   = unlockProgressColor(progress).withAlphaComponent(0.70)
                fill.strokeColor = .clear
                fill.position    = CGPoint(x: -totalW / 2 + fillW / 2, y: headerY)
                cropNode.addChild(fill)
            }
        }
        packaging.addChild(cropNode)

        // Badge pill positioned in the header
        let badgeH: CGFloat = 36
        let badge = SKNode()
        badge.zPosition = 3
        badge.position  = CGPoint(x: 0, y: cH / 2 - hH / 2)

        let badgeBg = SKShapeNode(
            rectOf: CGSize(width: cW - 56, height: badgeH),
            cornerRadius: badgeH / 2
        )
        let badgeText: String
        if isPendingUnwrap {
            badgeText           = "NEWLY UNLOCKED"
            badgeBg.fillColor   = UIColor.white.withAlphaComponent(0.22)
            badgeBg.strokeColor = UIColor.white.withAlphaComponent(0.50)
            badgeBg.lineWidth   = 1
        } else {
            badgeText           = "UNLOCK AT \(shape.unlockPops) POPS"
            badgeBg.fillColor   = UIColor.white.withAlphaComponent(0.15)
            badgeBg.strokeColor = UIColor.white.withAlphaComponent(0.35)
            badgeBg.lineWidth   = 1
        }
        badge.addChild(badgeBg)

        let badgeLbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        badgeLbl.text                    = badgeText
        badgeLbl.fontSize                = 11
        badgeLbl.fontColor               = palette.bgColor
        badgeLbl.horizontalAlignmentMode = .center
        badgeLbl.verticalAlignmentMode   = .center
        badge.addChild(badgeLbl)
        packaging.addChild(badge)

        // Dimmed bubble preview centred in the full space below the header
        let topEdge:    CGFloat = cH / 2 - hH
        let bottomEdge: CGFloat = -cH / 2 + 16
        let contentCY   = (topEdge + bottomEdge) / 2
        let bubbles = makeBubblePreview(shape: shape, radius: r)
        bubbles.alpha     = isPendingUnwrap ? 0.32 : 0.22
        bubbles.position  = CGPoint(x: 0, y: contentCY)
        bubbles.zPosition = 2
        packaging.addChild(bubbles)

        return packaging
    }

    // Interpolates blue → orange → accent as progress approaches 1.
    private func unlockProgressColor(_ progress: CGFloat) -> UIColor {
        let low  = UIColor(hue: 0.60, saturation: 0.70, brightness: 0.85, alpha: 1)
        let mid  = UIColor(hue: 0.11, saturation: 0.90, brightness: 0.95, alpha: 1)
        let high = palette.accentColor

        func lerp(_ a: UIColor, _ b: UIColor, _ t: CGFloat) -> UIColor {
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0
            var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0
            a.getRed(&r1, green: &g1, blue: &b1, alpha: nil)
            b.getRed(&r2, green: &g2, blue: &b2, alpha: nil)
            let t = max(0, min(1, t))
            return UIColor(red: r1 + (r2-r1)*t, green: g1 + (g2-g1)*t, blue: b1 + (b2-b1)*t, alpha: 1)
        }

        return progress < 0.5
            ? lerp(low, mid, progress * 2)
            : lerp(mid, high, (progress - 0.5) * 2)
    }

    // Frosted-glass card for fully-revealed unlocked boards
    private func makeSpotlightCard(shape: BoardShape, radius r: CGFloat) -> SKNode {
        let card = SKNode()
        card.name = "spotlight"

        let cW = cardW
        let cH = cardH
        let cr = cardCornerR

        // Drop shadow (slightly larger dark shape offset below)
        let shadow = SKShapeNode(rectOf: CGSize(width: cW + 8, height: cH + 4), cornerRadius: cr + 2)
        shadow.fillColor   = UIColor.black.withAlphaComponent(0.22)
        shadow.strokeColor = .clear
        shadow.position    = CGPoint(x: 0, y: -5)
        shadow.zPosition   = 0
        card.addChild(shadow)

        // Card background
        let bg = SKShapeNode(rectOf: CGSize(width: cW, height: cH), cornerRadius: cr)
        bg.fillColor   = palette.cardFill
        bg.strokeColor = palette.accentColor.withAlphaComponent(0.40)
        bg.lineWidth   = 1.5
        bg.zPosition   = 1
        card.addChild(bg)

        // Subtle top-edge glass highlight
        let hlCrop = SKCropNode()
        hlCrop.zPosition = 2
        let hlMask = SKShapeNode(rectOf: CGSize(width: cW, height: cH), cornerRadius: cr)
        hlMask.fillColor   = .white
        hlMask.strokeColor = .clear
        hlCrop.maskNode    = hlMask
        let hlBar = SKShapeNode(rectOf: CGSize(width: cW - 32, height: 2))
        hlBar.fillColor   = palette.overlayBase.withAlphaComponent(0.18)
        hlBar.strokeColor = .clear
        hlBar.position    = CGPoint(x: 0, y: cH / 2 - 9)
        hlCrop.addChild(hlBar)
        card.addChild(hlCrop)

        // Full-brightness bubble preview centered in card
        let bubbles = makeBubblePreview(shape: shape, radius: r)
        bubbles.name      = "bubbles"
        bubbles.zPosition = 3
        card.addChild(bubbles)

        return card
    }

    private func makeBubblePreview(shape: BoardShape, radius r: CGFloat) -> SKNode {
        let theme     = SettingsManager.shared.boardTheme
        let node      = SKNode()
        let tmp: CGFloat = 40
        let positions = shape.bubblePositions(bubbleSize: tmp * 2)
        guard !positions.isEmpty else { return node }

        let xs     = positions.map { $0.x }
        let ys     = positions.map { $0.y }
        let scale  = r / tmp
        let xRange = xs.max()! - xs.min()!
        let yRange = ys.max()! - ys.min()!

        // Centre of bounding box (same shift Board.init applies)
        let centerX = (xs.min()! + xs.max()!) / 2
        let centerY = (ys.min()! + ys.max()!) / 2
        let bboxX   = centerX * scale
        let bboxY   = centerY * scale

        // Pre-compute maxDist for embers radial heat (uses centred positions)
        let maxDist = theme == .embers
            ? positions.map { hypot($0.x - centerX, $0.y - centerY) }.max() ?? 1
            : 1
        let estimatedColumns = Int((xRange / (tmp * 2.4)).rounded()) + 1

        for pos in positions {
            let t: CGFloat
            switch theme {
            case .embers:
                let cp = CGPoint(x: pos.x - centerX, y: pos.y - centerY)
                t = Board.embersHeat(at: cp, maxDist: maxDist)
            case .frost:
                t = yRange > 0 ? (pos.y - ys.min()!) / yRange : 0.5
            default:
                t = xRange > 0 ? (pos.x - xs.min()!) / xRange : 0.5
            }

            let color       = Board.bubbleColor(at: t, theme: theme,
                                                estimatedColumns: estimatedColumns)
            let strokeColor = theme == .embers
                ? UIColor(red: 0.82, green: 0.20, blue: 0.01, alpha: 0.88)
                : color.withAlphaComponent(0.50)

            let circle = SKShapeNode(circleOfRadius: r)
            circle.fillColor   = color
            circle.strokeColor = strokeColor
            circle.lineWidth   = max(r * 0.10, 0.8)
            circle.position    = CGPoint(x: pos.x * scale - bboxX, y: pos.y * scale - bboxY)
            circle.name        = shape.rawValue
            node.addChild(circle)
        }
        return node
    }

    // MARK: - Bubble breathe animation

    private func startBubbleAnimation(for virtualIdx: Int) {
        guard let container  = boardNodes[virtualIdx],
              let spotlight  = container.childNode(withName: "spotlight"),
              let bubblesNode = spotlight.childNode(withName: "bubbles") else { return }

        let circles = bubblesNode.children
        let maxDist = circles.map { hypot($0.position.x, $0.position.y) }.max() ?? 1

        let scaleUp   = SKAction.scale(to: 1.07, duration: 0.46)
        let scaleDown = SKAction.scale(to: 1.00, duration: 0.46)
        scaleUp.timingMode   = .easeInEaseOut
        scaleDown.timingMode = .easeInEaseOut
        let breathe = SKAction.repeatForever(SKAction.sequence([scaleUp, scaleDown]))

        for circle in circles {
            // Stagger by radial distance — creates an outward ripple from center
            let dist  = hypot(circle.position.x, circle.position.y)
            let delay = maxDist > 0 ? Double(dist / maxDist) * 0.55 : 0
            circle.removeAction(forKey: "breathe")
            circle.run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                breathe
            ]), withKey: "breathe")
        }
    }

    private func stopBubbleAnimation(for virtualIdx: Int) {
        guard let container  = boardNodes[virtualIdx],
              let spotlight  = container.childNode(withName: "spotlight"),
              let bubblesNode = spotlight.childNode(withName: "bubbles") else { return }

        for circle in bubblesNode.children {
            circle.removeAction(forKey: "breathe")
            circle.run(SKAction.scale(to: 1.0, duration: 0.18))
        }
    }

    // MARK: - Lazy-susan transforms

    private func applyTransform(to node: SKNode, offset: CGFloat, animated: Bool) {
        let absOff = abs(offset)

        let targetScale: CGFloat = max(1.0 - absOff * 0.30, 0.40)
        let xFactor:     CGFloat = cos(offset * 0.60)
        let zRot:        CGFloat = offset * -0.08
        let alpha:       CGFloat = max(1.0 - absOff * 0.50, 0.20)

        if animated {
            let dur: Double = 0.38
            let toXScale = targetScale * xFactor
            let toYScale = targetScale
            let fromX    = node.xScale
            let fromY    = node.yScale
            let scaleAct = SKAction.customAction(withDuration: dur) { n, elapsed in
                let t = min(elapsed / CGFloat(dur), 1.0)
                let e = t < 0.5 ? 2*t*t : -1 + (4 - 2*t)*t
                n.xScale = fromX + (toXScale - fromX) * e
                n.yScale = fromY + (toYScale - fromY) * e
            }
            node.run(SKAction.group([
                scaleAct,
                SKAction.fadeAlpha(to: alpha, duration: dur),
                SKAction.rotate(toAngle: zRot, duration: dur, shortestUnitArc: true)
            ]))
        } else {
            node.xScale    = targetScale * xFactor
            node.yScale    = targetScale
            node.alpha     = alpha
            node.zRotation = zRot
        }
    }

    private func updateCardTransforms(animated: Bool) {
        for (vi, node) in boardNodes {
            applyTransform(to: node, offset: CGFloat(vi - virtualIndex), animated: animated)
        }
    }

    // MARK: - Navigation

    private func navigate(by delta: Int) {
        guard !isAnimating else { return }
        let prevVirtualIndex = virtualIndex
        isAnimating   = true
        virtualIndex += delta
        currentIndex  = ((virtualIndex % shapes.count) + shapes.count) % shapes.count

        addCardNode(at: virtualIndex - 1)
        addCardNode(at: virtualIndex + 1)

        let targetX = -CGFloat(virtualIndex) * cardSpacing
        let slide   = SKAction.moveTo(x: targetX, duration: 0.38)
        slide.timingMode = .easeInEaseOut
        carouselContainer.run(slide) { [weak self] in
            guard let self else { return }
            self.stopBubbleAnimation(for: prevVirtualIndex)
            self.isAnimating = false
            self.pruneDistantCards()
            self.startBubbleAnimation(for: self.virtualIndex)
            let shape = self.shapes[self.currentIndex]
            if self.pendingUnwrapShapes.contains(shape.rawValue) {
                self.pendingUnwrapShapes.remove(shape.rawValue)
                self.playUnwrapAnimation(at: self.virtualIndex)
            }
        }
        updateCardTransforms(animated: true)
        updatePips(animated: true)
        refreshInfo(animated: true)
        HapticManager.shared.flip()
    }

    private func snapToCurrentCard() {
        let targetX = -CGFloat(virtualIndex) * cardSpacing
        let snap    = SKAction.moveTo(x: targetX, duration: 0.28)
        snap.timingMode = .easeOut
        carouselContainer.run(snap)
        updateCardTransforms(animated: true)
    }

    private func pruneDistantCards() {
        for (vi, node) in boardNodes where abs(vi - virtualIndex) > 1 {
            node.removeFromParent()
            boardNodes.removeValue(forKey: vi)
        }
    }

    // MARK: - Unwrap animation

    private func playUnwrapAnimation(at virtualIdx: Int) {
        guard let container = boardNodes[virtualIdx] else { return }
        let shape = self.shape(at: virtualIdx)
        GameProgress.shared.markUnlockAnimationSeen(for: shape)

        guard let packaging = container.childNode(withName: "packaging") else { return }

        let r = spotlightBubbleRadius(for: shape)
        let spotlightCard = makeSpotlightCard(shape: shape, radius: r)
        spotlightCard.alpha    = 0
        spotlightCard.xScale   = 0.88
        spotlightCard.yScale   = 0.88
        spotlightCard.zPosition = -1
        container.addChild(spotlightCard)

        let pause: Double = 0.25

        // Packaging tears upward and fades out
        let lift = SKAction.moveBy(x: 0, y: 95, duration: 0.50)
        lift.timingMode = .easeIn
        packaging.run(SKAction.sequence([
            SKAction.wait(forDuration: pause),
            SKAction.group([lift, SKAction.fadeOut(withDuration: 0.45)]),
            SKAction.removeFromParent()
        ]))

        // Spotlight blooms in with a gentle spring scale
        let bloomDur = 0.52
        let bloomScale = SKAction.customAction(withDuration: bloomDur) { n, elapsed in
            let t = min(elapsed / CGFloat(bloomDur), 1.0)
            let e = t < 0.5 ? 2*t*t : -1 + (4-2*t)*t
            let s = 0.88 + 0.12 * e
            n.xScale = s
            n.yScale = s
        }
        spotlightCard.run(SKAction.sequence([
            SKAction.wait(forDuration: pause + 0.18),
            SKAction.group([SKAction.fadeAlpha(to: 1.0, duration: bloomDur), bloomScale])
        ]))

        // Haptic + bubble breathe after bloom completes
        run(SKAction.sequence([
            SKAction.wait(forDuration: pause + 0.30),
            SKAction.run { HapticManager.shared.flip() }
        ]))
        run(SKAction.sequence([
            SKAction.wait(forDuration: pause + 0.18 + bloomDur),
            SKAction.run { [weak self] in self?.startBubbleAnimation(for: virtualIdx) }
        ]))
    }

    // MARK: - Info labels

    private func refreshInfo(animated: Bool) {
        let shape     = shapes[currentIndex]
        let progress  = GameProgress.shared
        let unlocked  = progress.isUnlocked(shape)
        let isCurrent = progress.currentBoardShape == shape

        let newName   = shape.displayName.uppercased()
        let newStatus: String
        let statusColor: UIColor
        if isCurrent {
            newStatus   = "Currently active"
            statusColor = palette.accentColor
        } else if unlocked {
            newStatus   = "Tap to select"
            statusColor = palette.muteText
        } else {
            newStatus   = "Unlock at \(shape.unlockPops) pops"
            statusColor = palette.dimText
        }
        let newCount = "\(currentIndex + 1)  /  \(shapes.count)"

        if animated {
            let half = 0.10
            for (lbl, text) in [(nameLabel!, newName), (statusLabel!, newStatus), (countLabel!, newCount)] {
                lbl.run(SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.25, duration: half),
                    SKAction.run { lbl.text = text },
                    SKAction.fadeAlpha(to: 1.00, duration: half)
                ]))
            }
        } else {
            nameLabel.text   = newName
            statusLabel.text = newStatus
            countLabel.text  = newCount
        }

        nameLabel.fontColor   = unlocked ? palette.darkText : palette.muteText.withAlphaComponent(0.50)
        statusLabel.fontColor = statusColor
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)

        if nodes(at: loc).contains(where: { $0.name == "back" }) {
            navigateToGame(); return
        }

        isDragging          = true
        dragStartX          = loc.x
        dragStartContainerX = carouselContainer.position.x
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDragging, let touch = touches.first else { return }
        let dx = touch.location(in: self).x - dragStartX
        carouselContainer.position.x = dragStartContainerX + dx

        let frac = -carouselContainer.position.x / cardSpacing
        for (vi, node) in boardNodes {
            applyTransform(to: node, offset: CGFloat(vi) - frac, animated: false)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDragging, let touch = touches.first else { return }
        isDragging = false

        let dx = touch.location(in: self).x - dragStartX

        if abs(dx) < 12 {
            let shape = shapes[currentIndex]
            if GameProgress.shared.isUnlocked(shape) {
                GameProgress.shared.currentBoardShape = shape
                navigateToGame()
            } else {
                shakeCurrentCard()
                HapticManager.shared.flip()
            }
        } else if dx < -(cardSpacing * 0.18) {
            navigate(by: +1)
        } else if dx >  (cardSpacing * 0.18) {
            navigate(by: -1)
        } else {
            snapToCurrentCard()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDragging = false
        snapToCurrentCard()
    }

    private func shakeCurrentCard() {
        guard let node = boardNodes[virtualIndex] else { return }
        let shake = SKAction.sequence([
            SKAction.moveBy(x: -12, y: 0, duration: 0.05),
            SKAction.moveBy(x: 24,  y: 0, duration: 0.10),
            SKAction.moveBy(x: -12, y: 0, duration: 0.05)
        ])
        node.run(shake)
    }

    // MARK: - Back button

    private func addBackButton() {
        let node = SKNode()
        node.name = "back"

        let bg = SKShapeNode(rectOf: CGSize(width: 100, height: 44), cornerRadius: 12)
        bg.name        = "back"
        bg.fillColor   = palette.cardFill
        bg.strokeColor = palette.cardStroke
        bg.lineWidth   = 1

        let lbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        lbl.name                  = "back"
        lbl.text                  = "Back"
        lbl.fontSize              = 16
        lbl.fontColor             = palette.accentColor
        lbl.verticalAlignmentMode = .center

        node.addChild(bg)
        node.addChild(lbl)
        node.position = CGPoint(x: 0, y: -(size.height / 2 - 50))
        addChild(node)
    }

    private func navigateToGame() {
        let scene = GameScene(size: size)
        scene.scaleMode = scaleMode
        view?.presentScene(scene, transition: SKTransition.push(with: .down, duration: 0.35))
    }
}
