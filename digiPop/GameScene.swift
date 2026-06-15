import SpriteKit

class GameScene: SKScene {

    private var board: Board?
    private var flipBtn: SKNode!
    private var resetBtn: SKNode!
    private var boardsBtn: SKNode!
    private var boardNameLabel: SKLabelNode!
    private var boardPopsLabel: SKLabelNode!
    private var totalPopsLabel: SKLabelNode!

    private var palette: ThemePalette { SettingsManager.shared.palette }
    private var isDraggingBoard = false
    private var unlockBannerNode: SKNode?
    private var pendingUnlockEvent: UnlockEvent?
    private var achievementToastNode: SKNode?
    private var pendingAchievementToasts: [Achievement] = []
    private var firstClearTooltipsNode: SKNode?

    // Track themes used to build the current scene so we can detect changes on return
    private var builtUITheme: UITheme = SettingsManager.shared.uiTheme
    private var builtBoardTheme: BoardTheme = SettingsManager.shared.boardTheme

    // Height reserved for the large anchored adaptive banner ad sitting just above the dashboard
    static let adBannerHeight: CGFloat = 90

    override func willMove(from view: SKView) {
        board?.pauseEffects()
    }

    override func didMove(to view: SKView) {
        let newUI    = SettingsManager.shared.uiTheme
        let newBoard = SettingsManager.shared.boardTheme
        if newUI != builtUITheme {
            builtUITheme    = newUI
            builtBoardTheme = newBoard
            sceneDidLoad()
        } else if newBoard != builtBoardTheme {
            builtBoardTheme = newBoard
            loadBoard()
        } else {
            board?.resumeEffects()
        }
    }

    override func sceneDidLoad() {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        removeAllChildren()
        backgroundColor = palette.bgColor
        addSheenLayer(overlayBase: palette.overlayBase)
        setupUI()
        loadBoard()
    }

    // MARK: - UI setup

    private func setupUI() {
        // Anchor the button to the visible corner, above the home-indicator safe zone.
        // legV shrinks by the safe area so the fold line fills the visible dashboard corner exactly.
        let safeBottom = view?.safeAreaInsets.bottom ?? 34
        let legV = max(50, 90 - safeBottom)
        let legH = legV
        flipBtn = makeCornerFlipButton(legH: legH, legV: legV, safeBottom: safeBottom)
        flipBtn.position = CGPoint(x: size.width / 2, y: -size.height / 2 + safeBottom)
        flipBtn.zPosition = 10
        addChild(flipBtn)

        let topBtnW = (size.width - 24) / 4
        let topBtnY = size.height / 2 - 45
        let topBtnEdge = size.width / 2 - topBtnW / 2 - 34

        resetBtn = makeIconButton(symbol: "arrow.counterclockwise", name: "reset", width: topBtnW)
        resetBtn.position = CGPoint(x: -topBtnEdge, y: topBtnY)
        addChild(resetBtn)

        boardsBtn = makeIconButton(symbol: "square.grid.2x2", name: "boards", width: topBtnW)
        boardsBtn.position = CGPoint(x: topBtnEdge, y: topBtnY)
        addChild(boardsBtn)

        setupMenuBar()
        setupAdBannerPlaceholder()
        setupDashboard()
        updateDashboard()
    }

    private func setupMenuBar() {
        let barH: CGFloat  = 90   // visible height, enough to frame the 44pt buttons
        let extra: CGFloat = 24   // bleeds above screen so the top edge is never visible
        let totalH = barH + extra

        // Left side flush with screen edge; right side inset 8pt (mirroring dashboard left margin)
        let bLeft: CGFloat   = -(size.width / 2 + 2)   // bleed past left screen edge
        let bRight: CGFloat  =   size.width / 2 - 8
        let bTop: CGFloat    =   CGFloat(totalH) / 2
        let bBottom: CGFloat = -CGFloat(totalH) / 2
        let bR: CGFloat      = 18

        let barPath = CGMutablePath()
        barPath.move(to: CGPoint(x: bLeft, y: bBottom))
        barPath.addLine(to: CGPoint(x: bRight - bR, y: bBottom))
        barPath.addArc(tangent1End: CGPoint(x: bRight, y: bBottom),
                       tangent2End: CGPoint(x: bRight, y: bBottom + bR), radius: bR)
        barPath.addLine(to: CGPoint(x: bRight, y: bTop))
        barPath.addLine(to: CGPoint(x: bLeft, y: bTop))
        barPath.closeSubpath()

        let bar = SKShapeNode(path: barPath)
        bar.fillColor   = palette.btnFill.withAlphaComponent(0.92)
        bar.strokeColor = palette.accentColor.withAlphaComponent(0.6)
        bar.lineWidth   = 2
        // Center: top of bar at size.height/2 + extra, bottom at size.height/2 - barH
        bar.position    = CGPoint(x: 0, y: size.height / 2 - barH + totalH / 2)
        bar.zPosition   = -1
        addChild(bar)

    }

    private func setupAdBannerPlaceholder() {
        let dashH: CGFloat = 90
        let bannerH = Self.adBannerHeight
        let bannerY = -size.height / 2 + dashH + bannerH / 2 + 15

        let slot = SKShapeNode(rectOf: CGSize(width: size.width - 16, height: bannerH), cornerRadius: 8)
        slot.fillColor   = GameViewController.screenshotMode ? .clear : palette.cardFill.withAlphaComponent(0.80)
        slot.strokeColor = .clear
        slot.lineWidth   = 0
        slot.position    = CGPoint(x: 0, y: bannerY)
        slot.zPosition   = 1
        addChild(slot)

        if !GameViewController.screenshotMode {
            let label = SKLabelNode(fontNamed: "AvenirNext-Regular")
            label.text      = "ADVERTISEMENT"
            label.fontSize  = 10
            label.fontColor = palette.muteText.withAlphaComponent(0.40)
            label.verticalAlignmentMode   = .center
            label.horizontalAlignmentMode = .center
            label.position  = CGPoint(x: 0, y: bannerY)
            label.zPosition = 2
            addChild(label)
        }
    }

    private func setupDashboard() {
        let dashH: CGFloat = 90
        let panelH = dashH + 30
        let left: CGFloat   = -(size.width - 16) / 2
        let right: CGFloat  =  size.width / 2 + 2   // flush with right screen edge (+ stroke bleed)
        let top: CGFloat    =  CGFloat(panelH) / 2
        let bottom: CGFloat = -CGFloat(panelH) / 2
        let r: CGFloat      = 20

        let panelPath = CGMutablePath()
        panelPath.move(to: CGPoint(x: left, y: bottom + r))
        panelPath.addArc(tangent1End: CGPoint(x: left, y: bottom),
                         tangent2End: CGPoint(x: left + r, y: bottom), radius: r)
        panelPath.addLine(to: CGPoint(x: right, y: bottom))
        panelPath.addLine(to: CGPoint(x: right, y: top))
        panelPath.addLine(to: CGPoint(x: left + r, y: top))
        panelPath.addArc(tangent1End: CGPoint(x: left, y: top),
                         tangent2End: CGPoint(x: left, y: top - r), radius: r)
        panelPath.closeSubpath()

        let panel = SKShapeNode(path: panelPath)
        panel.fillColor   = palette.btnFill.withAlphaComponent(0.92)
        panel.strokeColor = palette.accentColor.withAlphaComponent(0.6)
        panel.lineWidth   = 2
        panel.position    = CGPoint(x: 0, y: -size.height / 2 + dashH - panelH / 2)
        panel.zPosition   = 1
        addChild(panel)


        // ── Column anchor points ────────────────────────────────────────────
        // gearX is chosen so the 44pt button always clears the 90pt flip triangle
        // regardless of screen width: at mid-dashboard height the hypotenuse is
        // at size.width/2 - 90 + 23, giving ≥11pt clearance for the button's right edge.
        let col1X  = -size.width / 2 + 20          // THIS BOARD (left-aligned)
        let div1X  = -size.width / 2 + size.width * 0.38
        let col2X  = div1X + 12                     // ALL TIME (left-aligned)
        let gearX  = size.width / 2 - 100           // gear column centre
        let div2X  = gearX - 28                     // divider before gear

        let score1CenterX = (col1X + div1X) / 2
        let score2CenterX = (col2X + div2X) / 2

        let numY   = -size.height / 2 + 20
        let capY   = -size.height / 2 + 59
        let divTop = -size.height / 2 + 74
        let divBot = -size.height / 2 + 20

        // ── THIS BOARD ──────────────────────────────────────────────────────
        boardNameLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        boardNameLabel.fontSize  = 15
        boardNameLabel.fontColor = palette.darkText
        boardNameLabel.horizontalAlignmentMode = .center
        boardNameLabel.position  = CGPoint(x: 0, y: size.height / 2 - 75)
        boardNameLabel.zPosition = 0
        addChild(boardNameLabel)

        let boardCaption = SKLabelNode(fontNamed: "AvenirNext-Bold")
        boardCaption.text      = "T H I S  B O A R D"
        boardCaption.fontSize  = 12
        boardCaption.fontColor = palette.muteText
        boardCaption.horizontalAlignmentMode = .center
        boardCaption.position  = CGPoint(x: score1CenterX, y: capY)
        boardCaption.zPosition = 2
        addChild(boardCaption)

        boardPopsLabel = SKLabelNode(fontNamed: "Futura-CondensedExtraBold")
        boardPopsLabel.fontSize  = 28
        boardPopsLabel.fontColor = palette.accentColor
        boardPopsLabel.horizontalAlignmentMode = .center
        boardPopsLabel.position  = CGPoint(x: score1CenterX, y: numY)
        boardPopsLabel.zPosition = 2
        addChild(boardPopsLabel)

        // ── Divider 1 ───────────────────────────────────────────────────────
        let d1 = CGMutablePath()
        d1.move(to: CGPoint(x: div1X, y: divBot))
        d1.addLine(to: CGPoint(x: div1X, y: divTop))
        let div1 = SKShapeNode(path: d1)
        div1.strokeColor = palette.dividerColor
        div1.lineWidth   = 1
        div1.zPosition   = 2
        addChild(div1)

        // ── ALL TIME ────────────────────────────────────────────────────────
        let totalCaption = SKLabelNode(fontNamed: "AvenirNext-Bold")
        totalCaption.text      = "A L L  T I M E"
        totalCaption.fontSize  = 12
        totalCaption.fontColor = palette.muteText
        totalCaption.horizontalAlignmentMode = .center
        totalCaption.position  = CGPoint(x: score2CenterX, y: capY)
        totalCaption.zPosition = 2
        addChild(totalCaption)

        totalPopsLabel = SKLabelNode(fontNamed: "Futura-CondensedExtraBold")
        totalPopsLabel.fontSize  = 28
        totalPopsLabel.fontColor = palette.accentColor
        totalPopsLabel.horizontalAlignmentMode = .center
        totalPopsLabel.position  = CGPoint(x: score2CenterX, y: numY)
        totalPopsLabel.zPosition = 2
        addChild(totalPopsLabel)

        // ── Divider 2 ───────────────────────────────────────────────────────
        let d2 = CGMutablePath()
        d2.move(to: CGPoint(x: div2X, y: divBot))
        d2.addLine(to: CGPoint(x: div2X, y: divTop))
        let div2 = SKShapeNode(path: d2)
        div2.strokeColor = palette.dividerColor
        div2.lineWidth   = 1
        div2.zPosition   = 2
        addChild(div2)

        // ── Settings gear ────────────────────────────────────────────────────
        let gearNode = SKNode()
        gearNode.name = "settings"

        let gearCfg = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        if let base = UIImage(systemName: "gearshape", withConfiguration: gearCfg) {
            let fmt = UIGraphicsImageRendererFormat(); fmt.opaque = false
            let accent = palette.accentColor
            let img = UIGraphicsImageRenderer(size: base.size, format: fmt).image { _ in
                base.withTintColor(accent, renderingMode: .alwaysOriginal).draw(at: .zero)
            }
            let iconH: CGFloat = 26
            let icon = SKSpriteNode(texture: SKTexture(image: img),
                                    size: CGSize(width: iconH * base.size.width / base.size.height, height: iconH))
            icon.name = "settings"
            gearNode.addChild(icon)
        }

        // Transparent 44pt hit circle so the touch target meets minimum guidelines
        let hitCircle = SKShapeNode(circleOfRadius: 22)
        hitCircle.fillColor   = .clear
        hitCircle.strokeColor = .clear
        hitCircle.name        = "settings"
        gearNode.addChild(hitCircle)
        gearNode.position = CGPoint(x: gearX + 25, y: -size.height / 2 + 59)
        gearNode.zPosition = 2
        addChild(gearNode)
    }

    private func makeIconButton(symbol: String, name: String, width: CGFloat = 44) -> SKNode {
        let node = SKNode()
        node.name = name

        let bg = SKShapeNode(rectOf: CGSize(width: width, height: 44), cornerRadius: 12)
        bg.fillColor   = palette.btnFill
        bg.strokeColor = palette.btnStroke
        bg.lineWidth   = 1
        bg.name = "\(name)_bg"
        node.addChild(bg)

        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        if let base = UIImage(systemName: symbol, withConfiguration: config) {
            let fmt = UIGraphicsImageRendererFormat(); fmt.opaque = false
            let accent = palette.accentColor
            let img = UIGraphicsImageRenderer(size: base.size, format: fmt).image { _ in
                base.withTintColor(accent, renderingMode: .alwaysOriginal).draw(at: .zero)
            }
            let aspectRatio = base.size.width / base.size.height
            let iconH: CGFloat = 22
            let icon = SKSpriteNode(texture: SKTexture(image: img),
                                    size: CGSize(width: iconH * aspectRatio, height: iconH))
            icon.name = name
            node.addChild(icon)
        }
        return node
    }

    private func makeCornerFlipButton(legH: CGFloat, legV: CGFloat, safeBottom: CGFloat = 0) -> SKNode {
        let node = SKNode()

        // Right-angle at true screen corner (0, -safeBottom), fills the full visible corner
        let totalLeg = legV + safeBottom   // always equals dashH (90)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: -safeBottom))
        path.addLine(to: CGPoint(x: -totalLeg, y: -safeBottom))
        path.addLine(to: CGPoint(x: 0, y: legV))
        path.closeSubpath()

        // Transparent hit area matching the exact triangle — avoids oversized bounding-box of parent SKNode
        let hitArea = SKShapeNode(path: path)
        hitArea.fillColor   = .clear
        hitArea.strokeColor = .clear
        hitArea.name        = "flip"
        hitArea.zPosition   = 10
        node.addChild(hitArea)

        // ── 2. Main face ────────────────────────────────────────────────
        let face = SKShapeNode(path: path)
        face.fillColor   = palette.btnFill
        face.strokeColor = .clear
        face.zPosition   = 0
        face.name        = "flip_bg"
        node.addChild(face)

        // ── 4. Fold-thickness strip (page edge visible at the curl) ─────
        // Inward normal toward (0,0): (legV, -legH) / hypLen
        let hypLen = hypot(legH, legV)
        let sdx    =  5 * legV / hypLen
        let sdy    =  5 * legH / hypLen
        // Extend the strip down through the safe area to the true screen bottom
        let thickPath = CGMutablePath()
        thickPath.move(to:    CGPoint(x: -legH - safeBottom,        y: -safeBottom))
        thickPath.addLine(to: CGPoint(x: 0,                          y: legV))
        thickPath.addLine(to: CGPoint(x:  sdx,                       y: legV - sdy))
        thickPath.addLine(to: CGPoint(x: -legH - safeBottom + sdx,  y: -safeBottom - sdy))
        thickPath.closeSubpath()
        let thickStrip = SKShapeNode(path: thickPath)
        thickStrip.fillColor   = palette.btnFill.darkened(by: 0.22)
        thickStrip.strokeColor = .clear
        thickStrip.zPosition   = 1
        thickStrip.name        = "flip"
        node.addChild(thickStrip)

        // ── 5. Bright highlight along the fold edge ─────────────────────
        // Extend the fold line down through the safe area to the true screen bottom
        let foldLine = CGMutablePath()
        foldLine.move(to:    CGPoint(x: -legH - safeBottom, y: -safeBottom))
        foldLine.addLine(to: CGPoint(x: 0,                   y: legV))
        let foldHighlight = SKShapeNode(path: foldLine)
        foldHighlight.strokeColor = palette.accentColor
        foldHighlight.lineWidth   = 1.5
        foldHighlight.zPosition   = 2
        foldHighlight.name        = "flip"
        node.addChild(foldHighlight)

        // ── 6. Icon at centroid of the visible triangle ──────────────────
        // Render as white so colorBlendFactor can tint it reliably in SpriteKit
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        if let base = UIImage(systemName: "rectangle.2.swap", withConfiguration: config) {
            let fmt = UIGraphicsImageRendererFormat(); fmt.opaque = false
            let white = UIGraphicsImageRenderer(size: base.size, format: fmt).image { _ in
                base.withTintColor(.white, renderingMode: .alwaysOriginal).draw(at: .zero)
            }
            let iconH: CGFloat = 22
            let icon = SKSpriteNode(texture: SKTexture(image: white),
                                    size: CGSize(width: iconH * base.size.width / base.size.height, height: iconH))
            icon.color            = palette.accentColor
            icon.colorBlendFactor = 1.0
            icon.name             = "flip"
            icon.position         = CGPoint(x: -legV / 3 - 9, y: legV / 3 - 21)
            icon.zPosition        = 3
            node.addChild(icon)
        }
        return node
    }

    // MARK: - Board loading

    private func loadBoard() {
        board?.removeFromParent()
        clearAllPoppedHighlight()

        let shape = GameProgress.shared.currentBoardShape
        let newBoard = Board(shape: shape, bubbleRadius: bubbleRadius(for: shape))
        let topBoundary    =  size.height / 2 - 130  // menu bar separator line + 40pt gap
        let bottomBoundary = -size.height / 2 + 275  // bottom of board space
        newBoard.position = CGPoint(x: 0, y: (topBoundary + bottomBoundary) / 2)
        newBoard.onBubblePop = { [weak self] in self?.handlePop() }
        newBoard.onAllPopped = { [weak self] in
            guard let self else { return }
            self.showAllPoppedHighlight()
            GameProgress.shared.recordBoardClear(for: GameProgress.shared.currentBoardShape)
            self.queueAchievementToasts(GameProgress.shared.drainPendingAchievements())
        }
        addChild(newBoard)
        board = newBoard
        updateDashboard()
    }

    private func bubbleRadius(for shape: BoardShape) -> CGFloat {
        let hPad: CGFloat = 20
        let vPad: CGFloat = 0
        let borderW: CGFloat = 10  // 5pt lineWidth each side
        let playW = size.width  - hPad * 2 - borderW
        let playH = size.height - 365 - vPad * 2 - borderW
        let tmp: CGFloat = 40
        let positions = shape.bubblePositions(bubbleSize: tmp * 2)
        let xs = positions.map { $0.x }
        let ys = positions.map { $0.y }
        // 2.7 = 2 * 1.35 (background pad radius used in buildBackground)
        let boardW = (xs.max()! - xs.min()!) + tmp * 2.7
        let boardH = (ys.max()! - ys.min()!) + tmp * 2.7
        let r = tmp * min(playW / boardW, playH / boardH)
        let maxR: CGFloat = (shape == .grid4x4 || shape == .grid4x5 || shape == .grid4x6) ? 40 : 52
        return min(r, maxR)
    }

    // MARK: - Callbacks

    private func handlePop() {
        let event = GameProgress.shared.recordPop(for: GameProgress.shared.currentBoardShape)
        updateDashboard()
        if let event { showUnlockBanner(for: event) }
        queueAchievementToasts(GameProgress.shared.drainPendingAchievements())
    }

    private func showAllPoppedHighlight() {
        let half: CGFloat = 0.38
        let fillColor   = palette.btnFill
        let accentColor = palette.accentColor

        let scaleUp   = SKAction.scale(to: 1.13, duration: Double(half))
        scaleUp.timingMode   = .easeInEaseOut
        let scaleDown = SKAction.scale(to: 1.00, duration: Double(half))
        scaleDown.timingMode = .easeInEaseOut
        let scalePulse = SKAction.repeatForever(SKAction.sequence([scaleUp, scaleDown]))

        resetBtn.run(scalePulse, withKey: "allPopped")
        flipBtn.run(scalePulse,  withKey: "allPopped")

        // Color flash — synced to scale pulse, smooth interpolation
        func colorPulse(bgName: String) -> SKAction {
            let toAccent = SKAction.customAction(withDuration: Double(half)) { node, elapsed in
                guard let shape = node as? SKShapeNode else { return }
                shape.fillColor = GameScene.lerpColor(fillColor, accentColor, t: elapsed / half)
            }
            let toNormal = SKAction.customAction(withDuration: Double(half)) { node, elapsed in
                guard let shape = node as? SKShapeNode else { return }
                shape.fillColor = GameScene.lerpColor(accentColor, fillColor, t: elapsed / half)
            }
            return SKAction.repeatForever(SKAction.sequence([toAccent, toNormal]))
        }

        if let bg = resetBtn.childNode(withName: "reset_bg") as? SKShapeNode {
            bg.run(colorPulse(bgName: "reset_bg"), withKey: "allPoppedColor")
        }
        if let face = flipBtn.childNode(withName: "flip_bg") as? SKShapeNode {
            face.run(colorPulse(bgName: "flip_bg"), withKey: "allPoppedColor")
        }

        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.8),
            SKAction.run { [weak self] in self?.showFirstClearTooltips() }
        ]))
    }

    private func clearAllPoppedHighlight() {
        for btn in [resetBtn, flipBtn] {
            guard let btn else { continue }
            btn.removeAction(forKey: "allPopped")
            btn.run(SKAction.scale(to: 1.0, duration: 0.15))
        }
        let fill = palette.btnFill
        if let bg = resetBtn.childNode(withName: "reset_bg") as? SKShapeNode {
            bg.removeAction(forKey: "allPoppedColor")
            bg.fillColor = fill
        }
        if let face = flipBtn.childNode(withName: "flip_bg") as? SKShapeNode {
            face.removeAction(forKey: "allPoppedColor")
            face.fillColor = fill
        }
    }

    private static func lerpColor(_ a: UIColor, _ b: UIColor, t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: nil)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: nil)
        let t = max(0, min(1, t))
        return UIColor(red:   r1 + (r2 - r1) * t,
                       green: g1 + (g2 - g1) * t,
                       blue:  b1 + (b2 - b1) * t,
                       alpha: 1)
    }

    private func updateDashboard() {
        let shape = GameProgress.shared.currentBoardShape
        let spaced = shape.displayName
            .split(separator: " ", omittingEmptySubsequences: false)
            .map { $0.map(String.init).joined(separator: " ") }
            .joined(separator: "  ")
        boardNameLabel.text = spaced
        boardPopsLabel.text  = "\(GameProgress.shared.pops(for: shape))"
        totalPopsLabel.text  = "\(GameProgress.shared.totalPops)"
    }

    // MARK: - Unlock banner

    private func showUnlockBanner(for event: UnlockEvent) {
        dismissUnlockBanner()
        pendingUnlockEvent = event

        let headline: String
        let itemName: String
        switch event {
        case .board(let s):       headline = "NEW BOARD UNLOCKED";        itemName = s.displayName.uppercased()
        case .sound(let s):       headline = "NEW SOUND UNLOCKED";        itemName = s.displayName.uppercased()
        case .colorScheme(let t): headline = "NEW COLOR SCHEME UNLOCKED"; itemName = t.displayName.uppercased()
        case .boardDesign(let t): headline = "NEW BOARD DESIGN UNLOCKED"; itemName = t.displayName.uppercased()
        }

        let cardW  = size.width - 40
        let cardH: CGFloat = 96
        let btnW   = (cardW - 52) / 2
        let btnH: CGFloat = 28

        let banner = SKNode()
        banner.name      = "unlockBanner"
        banner.zPosition = 20

        let bg = SKShapeNode(rectOf: CGSize(width: cardW, height: cardH), cornerRadius: 16)
        bg.fillColor   = palette.btnFill
        bg.strokeColor = palette.accentColor
        bg.lineWidth   = 1.5
        bg.name        = "unlockBanner"
        banner.addChild(bg)

        let topLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        topLabel.text                    = headline
        topLabel.fontSize                = 11
        topLabel.fontColor               = palette.accentColor
        topLabel.horizontalAlignmentMode = .center
        topLabel.position                = CGPoint(x: 0, y: 28)
        topLabel.name                    = "unlockBanner"
        banner.addChild(topLabel)

        let nameLabel = SKLabelNode(fontNamed: "Futura-CondensedExtraBold")
        nameLabel.text                    = itemName
        nameLabel.fontSize                = 22
        nameLabel.fontColor               = palette.darkText
        nameLabel.horizontalAlignmentMode = .center
        nameLabel.position                = CGPoint(x: 0, y: 6)
        nameLabel.name                    = "unlockBanner"
        banner.addChild(nameLabel)

        // SWITCH button — accented
        let switchX = -(btnW / 2 + 8)
        let switchBg = SKShapeNode(rectOf: CGSize(width: btnW, height: btnH), cornerRadius: 9)
        switchBg.fillColor   = palette.accentColor.withAlphaComponent(0.18)
        switchBg.strokeColor = palette.accentColor
        switchBg.lineWidth   = 1.5
        switchBg.name        = "unlock_switch"
        switchBg.position    = CGPoint(x: switchX, y: -26)
        banner.addChild(switchBg)

        let switchLbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        switchLbl.text                    = "SWITCH"
        switchLbl.fontSize                = 12
        switchLbl.fontColor               = palette.accentColor
        switchLbl.verticalAlignmentMode   = .center
        switchLbl.horizontalAlignmentMode = .center
        switchLbl.name                    = "unlock_switch"
        switchLbl.position                = CGPoint(x: switchX, y: -26)
        banner.addChild(switchLbl)

        // STAY button — muted
        let stayX = btnW / 2 + 8
        let stayBg = SKShapeNode(rectOf: CGSize(width: btnW, height: btnH), cornerRadius: 9)
        stayBg.fillColor   = palette.cardFill
        stayBg.strokeColor = palette.cardStroke
        stayBg.lineWidth   = 1
        stayBg.name        = "unlock_stay"
        stayBg.position    = CGPoint(x: stayX, y: -26)
        banner.addChild(stayBg)

        let stayLbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        stayLbl.text                    = "STAY"
        stayLbl.fontSize                = 12
        stayLbl.fontColor               = palette.muteText
        stayLbl.verticalAlignmentMode   = .center
        stayLbl.horizontalAlignmentMode = .center
        stayLbl.name                    = "unlock_stay"
        stayLbl.position                = CGPoint(x: stayX, y: -26)
        banner.addChild(stayLbl)

        let finalY  = size.height / 2 - 90 - cardH / 2 - 12
        banner.position = CGPoint(x: 0, y: finalY + cardH + 20)
        addChild(banner)
        unlockBannerNode = banner

        let slideIn = SKAction.moveTo(y: finalY, duration: 0.35)
        slideIn.timingMode = .easeOut
        banner.run(slideIn)

        banner.run(SKAction.sequence([
            SKAction.wait(forDuration: 5.5),
            SKAction.fadeOut(withDuration: 0.4),
            SKAction.removeFromParent()
        ]), withKey: "autoDismiss")
    }

    private func dismissUnlockBanner() {
        guard let banner = unlockBannerNode else { return }
        banner.removeAction(forKey: "autoDismiss")
        banner.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.removeFromParent()
        ]))
        unlockBannerNode   = nil
        pendingUnlockEvent = nil
    }

    // MARK: - Achievement toasts

    private func queueAchievementToasts(_ achievements: [Achievement]) {
        guard !achievements.isEmpty else { return }
        pendingAchievementToasts.append(contentsOf: achievements)
        if achievementToastNode == nil { showNextAchievementToast() }
    }

    private func showNextAchievementToast() {
        guard !pendingAchievementToasts.isEmpty else { return }
        let achievement = pendingAchievementToasts.removeFirst()
        showAchievementToast(for: achievement)
    }

    private func showAchievementToast(for achievement: Achievement) {
        achievementToastNode?.removeFromParent()

        let toastW: CGFloat = size.width - 64
        let toastH: CGFloat = 52

        let toast = SKNode()
        toast.zPosition = 18

        let bg = SKShapeNode(rectOf: CGSize(width: toastW, height: toastH), cornerRadius: toastH / 2)
        bg.fillColor   = palette.btnFill.withAlphaComponent(0.96)
        bg.strokeColor = palette.accentColor.withAlphaComponent(0.45)
        bg.lineWidth   = 1
        toast.addChild(bg)

        let config = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        if let img = UIImage(systemName: achievement.iconSymbol, withConfiguration: config)?
            .withTintColor(palette.accentColor, renderingMode: .alwaysOriginal) {
            let iconH: CGFloat = 15
            let icon = SKSpriteNode(
                texture: SKTexture(image: img),
                size: CGSize(width: iconH * img.size.width / img.size.height, height: iconH)
            )
            icon.position = CGPoint(x: -(toastW / 2 - 24), y: 0)
            toast.addChild(icon)
        }

        let titleNode = SKLabelNode(fontNamed: "AvenirNext-Bold")
        titleNode.text                    = achievement.title.uppercased()
        titleNode.fontSize                = 11
        titleNode.fontColor               = palette.accentColor
        titleNode.verticalAlignmentMode   = .center
        titleNode.horizontalAlignmentMode = .center
        titleNode.position                = CGPoint(x: 8, y: 9)
        toast.addChild(titleNode)

        let blurbNode = SKLabelNode(fontNamed: "AvenirNext-Regular")
        blurbNode.text                    = achievement.blurb
        blurbNode.fontSize                = 9
        blurbNode.fontColor               = palette.muteText
        blurbNode.verticalAlignmentMode   = .center
        blurbNode.horizontalAlignmentMode = .center
        blurbNode.position                = CGPoint(x: 8, y: -9)
        toast.addChild(blurbNode)

        let toastY = size.height / 2 - 90 - toastH / 2 - 8
        toast.position = CGPoint(x: 0, y: toastY + toastH + 20)
        toast.setScale(0.88)
        addChild(toast)
        achievementToastNode = toast

        // Slide in and bounce to full size
        let slideIn = SKAction.moveTo(y: toastY, duration: 0.22)
        slideIn.timingMode = .easeOut
        let scaleUp = SKAction.scale(to: 1.08, duration: 0.18)
        scaleUp.timingMode = .easeOut
        let scaleDown = SKAction.scale(to: 1.00, duration: 0.12)
        scaleDown.timingMode = .easeInEaseOut
        toast.run(SKAction.group([slideIn, SKAction.sequence([scaleUp, scaleDown])]))

        // Border glow pulse — 3 quick flashes then settle
        let accent     = palette.accentColor
        let glowOn     = SKAction.customAction(withDuration: 0.12) { node, _ in
            (node as? SKShapeNode)?.strokeColor = accent.withAlphaComponent(1.0)
            (node as? SKShapeNode)?.lineWidth   = 2.0
        }
        let glowOff    = SKAction.customAction(withDuration: 0.12) { node, _ in
            (node as? SKShapeNode)?.strokeColor = accent.withAlphaComponent(0.45)
            (node as? SKShapeNode)?.lineWidth   = 1.0
        }
        let pulse      = SKAction.sequence([glowOn, glowOff])
        bg.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.18),
            SKAction.repeat(pulse, count: 3)
        ]))

        toast.run(SKAction.sequence([
            SKAction.wait(forDuration: 2.4),
            SKAction.fadeOut(withDuration: 0.28),
            SKAction.removeFromParent(),
            SKAction.run { [weak self] in
                self?.achievementToastNode = nil
                self?.showNextAchievementToast()
            }
        ]), withKey: "toastDismiss")
    }

    // MARK: - First-clear tooltips

    private func showFirstClearTooltips() {
        guard !GameProgress.shared.hasShownFirstClearTooltip else { return }
        GameProgress.shared.hasShownFirstClearTooltip = true

        let safeBottom   = view?.safeAreaInsets.bottom ?? 34
        let topBtnW      = (size.width - 24) / 4
        let topBtnY      = size.height / 2 - 45
        let topBtnEdge   = size.width / 2 - topBtnW / 2 - 34
        let resetBtnX    = -topBtnEdge

        let overlay = SKNode()
        overlay.name      = "firstClearTooltips"
        overlay.zPosition = 30
        overlay.alpha     = 0
        addChild(overlay)
        firstClearTooltipsNode = overlay

        let dim = SKShapeNode(rectOf: size)
        dim.fillColor   = UIColor.black.withAlphaComponent(0.50)
        dim.strokeColor = .clear
        overlay.addChild(dim)

        // Reset tooltip — below the reset button, arrow pointing up toward it
        let tipW: CGFloat = 175
        let tipX = min(max(resetBtnX, -size.width / 2 + tipW / 2 + 8),
                       size.width / 2 - tipW / 2 - 8)
        let resetTip = makeTooltipBubble(
            symbol: "arrow.counterclockwise",
            title:  "Reset Board",
            body:   "Start this board fresh",
            arrowSide:   "top",
            arrowOffset: resetBtnX - tipX
        )
        resetTip.position = CGPoint(x: tipX, y: topBtnY - 74)
        overlay.addChild(resetTip)

        // Flip tooltip — centered on the bottom dashboard (below the UIKit banner, above the safe area)
        // Arrow points down-right toward the flip corner triangle
        let dashH: CGFloat = 90
        let flipTip = makeTooltipBubble(
            symbol: "rectangle.2.swap",
            title:  "Flip Board",
            body:   "Pop from the other side",
            arrowSide:   "right",
            arrowOffset: 0
        )
        flipTip.position = CGPoint(x: 10, y: -size.height / 2 + dashH / 2 + safeBottom / 2 - 15)
        overlay.addChild(flipTip)

        let hint = SKLabelNode(fontNamed: "AvenirNext-Regular")
        hint.text                    = "tap anywhere to dismiss"
        hint.fontSize                = 20
        hint.fontColor               = UIColor.white.withAlphaComponent(0.45)
        hint.horizontalAlignmentMode = .center
        hint.position                = CGPoint(x: 0, y: 0)
        overlay.addChild(hint)

        overlay.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.2),
            SKAction.fadeIn(withDuration: 0.30)
        ]))
    }

    private func dismissFirstClearTooltips() {
        guard let node = firstClearTooltipsNode else { return }
        firstClearTooltipsNode = nil
        node.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.20),
            SKAction.removeFromParent()
        ]))
    }

    private func makeTooltipBubble(symbol: String, title: String, body: String,
                                    arrowSide: String, arrowOffset: CGFloat) -> SKNode {
        let node   = SKNode()
        let cardW: CGFloat = 175
        let cardH: CGFloat = 56

        let bg = SKShapeNode(path: makeTooltipPath(w: cardW, h: cardH, r: 12,
                                                    arrowSize: 10, arrowSide: arrowSide,
                                                    arrowOffset: arrowOffset))
        bg.fillColor   = palette.btnFill.withAlphaComponent(0.97)
        bg.strokeColor = palette.accentColor.withAlphaComponent(0.70)
        bg.lineWidth   = 1.5
        node.addChild(bg)

        let config = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        if let img = UIImage(systemName: symbol, withConfiguration: config)?
            .withTintColor(palette.accentColor, renderingMode: .alwaysOriginal) {
            let iconH: CGFloat = 14
            let icon = SKSpriteNode(
                texture: SKTexture(image: img),
                size: CGSize(width: iconH * img.size.width / img.size.height, height: iconH)
            )
            icon.position = CGPoint(x: -cardW / 2 + 20, y: 10)
            node.addChild(icon)
        }

        let titleNode = SKLabelNode(fontNamed: "AvenirNext-Bold")
        titleNode.text                    = title
        titleNode.fontSize                = 13
        titleNode.fontColor               = palette.darkText
        titleNode.verticalAlignmentMode   = .center
        titleNode.horizontalAlignmentMode = .left
        titleNode.position                = CGPoint(x: -cardW / 2 + 36, y: 10)
        node.addChild(titleNode)

        let bodyNode = SKLabelNode(fontNamed: "AvenirNext-Regular")
        bodyNode.text                    = body
        bodyNode.fontSize                = 10
        bodyNode.fontColor               = palette.muteText
        bodyNode.verticalAlignmentMode   = .center
        bodyNode.horizontalAlignmentMode = .left
        bodyNode.position                = CGPoint(x: -cardW / 2 + 16, y: -12)
        node.addChild(bodyNode)

        return node
    }

    private func makeTooltipPath(w: CGFloat, h: CGFloat, r: CGFloat,
                                  arrowSize: CGFloat, arrowSide: String,
                                  arrowOffset: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let hw   = w / 2
        let hh   = h / 2
        let aw   = arrowSize * 1.2   // arrow base width

        if arrowSide == "top" {
            path.move(to: CGPoint(x: -hw, y: hh - r))
            path.addArc(tangent1End: CGPoint(x: -hw, y:  hh), tangent2End: CGPoint(x: -hw + r, y:  hh), radius: r)
            path.addLine(to: CGPoint(x: arrowOffset - aw / 2, y:  hh))
            path.addLine(to: CGPoint(x: arrowOffset,           y:  hh + arrowSize))
            path.addLine(to: CGPoint(x: arrowOffset + aw / 2, y:  hh))
            path.addLine(to: CGPoint(x:  hw - r,               y:  hh))
            path.addArc(tangent1End: CGPoint(x:  hw, y:  hh), tangent2End: CGPoint(x:  hw, y:  hh - r), radius: r)
            path.addLine(to: CGPoint(x:  hw, y: -hh + r))
            path.addArc(tangent1End: CGPoint(x:  hw, y: -hh), tangent2End: CGPoint(x:  hw - r, y: -hh), radius: r)
            path.addLine(to: CGPoint(x: -hw + r, y: -hh))
            path.addArc(tangent1End: CGPoint(x: -hw, y: -hh), tangent2End: CGPoint(x: -hw, y: -hh + r), radius: r)
            path.closeSubpath()

        } else if arrowSide == "right" {
            let clampedOffset = max(-(hh - r - aw / 2), min(hh - r - aw / 2, arrowOffset))
            path.move(to: CGPoint(x: -hw, y: hh - r))
            path.addArc(tangent1End: CGPoint(x: -hw, y:  hh), tangent2End: CGPoint(x: -hw + r, y:  hh), radius: r)
            path.addLine(to: CGPoint(x:  hw - r, y:  hh))
            path.addArc(tangent1End: CGPoint(x:  hw, y:  hh), tangent2End: CGPoint(x:  hw, y:  hh - r), radius: r)
            path.addLine(to: CGPoint(x:  hw, y: clampedOffset + aw / 2))
            path.addLine(to: CGPoint(x:  hw + arrowSize, y: clampedOffset))
            path.addLine(to: CGPoint(x:  hw, y: clampedOffset - aw / 2))
            path.addLine(to: CGPoint(x:  hw, y: -hh + r))
            path.addArc(tangent1End: CGPoint(x:  hw, y: -hh), tangent2End: CGPoint(x:  hw - r, y: -hh), radius: r)
            path.addLine(to: CGPoint(x: -hw + r, y: -hh))
            path.addArc(tangent1End: CGPoint(x: -hw, y: -hh), tangent2End: CGPoint(x: -hw, y: -hh + r), radius: r)
            path.closeSubpath()

        } else if arrowSide == "bottom" {
            let clampedOffset = max(-(hw - r - aw / 2), min(hw - r - aw / 2, arrowOffset))
            path.move(to: CGPoint(x: -hw, y: hh - r))
            path.addArc(tangent1End: CGPoint(x: -hw, y:  hh), tangent2End: CGPoint(x: -hw + r, y:  hh), radius: r)
            path.addLine(to: CGPoint(x:  hw - r, y:  hh))
            path.addArc(tangent1End: CGPoint(x:  hw, y:  hh), tangent2End: CGPoint(x:  hw, y:  hh - r), radius: r)
            path.addLine(to: CGPoint(x:  hw, y: -hh + r))
            path.addArc(tangent1End: CGPoint(x:  hw, y: -hh), tangent2End: CGPoint(x:  hw - r, y: -hh), radius: r)
            path.addLine(to: CGPoint(x: clampedOffset + aw / 2, y: -hh))
            path.addLine(to: CGPoint(x: clampedOffset,           y: -hh - arrowSize))
            path.addLine(to: CGPoint(x: clampedOffset - aw / 2, y: -hh))
            path.addLine(to: CGPoint(x: -hw + r, y: -hh))
            path.addArc(tangent1End: CGPoint(x: -hw, y: -hh), tangent2End: CGPoint(x: -hw, y: -hh + r), radius: r)
            path.closeSubpath()

        } else {
            path.addRoundedRect(in: CGRect(x: -hw, y: -hh, width: w, height: h),
                                cornerWidth: r, cornerHeight: r)
        }

        return path
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let hit = nodes(at: location)

        if firstClearTooltipsNode != nil {
            dismissFirstClearTooltips()
            return
        }

        if hit.contains(where: { $0.name == "unlock_switch" }) {
            if let event = pendingUnlockEvent {
                dismissUnlockBanner()
                switch event {
                case .board(let s):
                    GameProgress.shared.currentBoardShape = s
                    loadBoard()
                case .sound(let s):
                    SettingsManager.shared.soundProfile = s
                case .colorScheme(let t):
                    SettingsManager.shared.uiTheme = t
                    builtUITheme    = t
                    builtBoardTheme = SettingsManager.shared.boardTheme
                    sceneDidLoad()
                case .boardDesign(let t):
                    SettingsManager.shared.boardTheme = t
                    builtBoardTheme = t
                    loadBoard()
                }
            }
            return
        }

        if hit.contains(where: { $0.name == "unlock_stay" }) {
            dismissUnlockBanner()
            return
        }

        if hit.contains(where: { $0.name == "unlockBanner" }) {
            return
        }

        if hit.contains(where: { $0.name == "settings" }) {
            let scene = SettingsScene(size: size)
            scene.scaleMode = scaleMode
            scene.sourceScene = self
            view?.presentScene(scene, transition: SKTransition.push(with: .up, duration: 0.35))
            return
        }

        if hit.contains(where: { $0.name == "flip" }) {
            clearAllPoppedHighlight()
            board?.flip()
            GameProgress.shared.recordFlip()
            queueAchievementToasts(GameProgress.shared.drainPendingAchievements())
            return
        }

        if hit.contains(where: { $0.name == "reset" }) {
            board?.resetBoard { [weak self] in
                guard let self else { return }
                self.clearAllPoppedHighlight()
                self.updateDashboard()
            }
            return
        }

        if hit.contains(where: { $0.name == "boards" }) {
            let scene = BoardSelectScene(size: size)
            scene.scaleMode = scaleMode
            view?.presentScene(scene, transition: SKTransition.push(with: .up, duration: 0.35))
            return
        }

        isDraggingBoard = true
        board?.tryPop(at: location)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDraggingBoard, board?.isFlipped == true else { return }
        for touch in touches {
            board?.tryPop(at: touch.location(in: self))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDraggingBoard = false
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDraggingBoard = false
    }
}
