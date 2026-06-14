import SpriteKit

class AchievementsScene: SKScene {

    var sourceScene: SKScene?

    private var palette: ThemePalette { SettingsManager.shared.palette }

    // Grid geometry — computed dynamically in buildPages()
    private var cellW:      CGFloat = 148
    private var cellH:      CGFloat = 64
    private let colGap:     CGFloat = 8
    private let rowGap:     CGFloat = 8
    private let rowsPerPage  = 4        // 2 cols × 4 rows = 8 per page
    private let perPage      = 8
    private let cellSizeRows = 5        // cell height derived from 5-row fit
    private var pageCount   = 3

    // Paging state
    private var currentPage    = 0
    private var pagesHost:     SKNode!
    private var dotNodes:      [SKShapeNode] = []

    // Drag state
    private var dragStartX:     CGFloat = 0
    private var dragStartHostX: CGFloat = 0
    private var isDragging      = false

    // MARK: - Lifecycle

    // Fixed dark space color used for bg and footer panel
    private let spaceBg = UIColor(red: 0.05, green: 0.04, blue: 0.12, alpha: 1)

    override func sceneDidLoad() {
        anchorPoint     = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = spaceBg
        addStarBackground()
        addHeader()
        buildPages()
        addBackButton()
    }

    // MARK: - Background

    private func addStarBackground() {
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let gc = ctx.cgContext

            // Many tiny stars — varied size and brightness
            for _ in 0..<380 {
                let x    = CGFloat.random(in: 0..<size.width)
                let y    = CGFloat.random(in: 0..<size.height)
                let r    = CGFloat.random(in: 0.3...1.1)
                let a    = CGFloat.random(in: 0.20...0.80)
                let blue = CGFloat.random(in: 0.0...0.20)
                gc.setFillColor(UIColor(red: 0.88, green: 0.90 + blue * 0.05,
                                        blue: 1.0, alpha: a).cgColor)
                gc.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }

            // ~20 brighter stars with a soft glow halo
            for _ in 0..<20 {
                let x = CGFloat.random(in: 0..<size.width)
                let y = CGFloat.random(in: 0..<size.height)
                let r = CGFloat.random(in: 1.4...2.6)
                let a = CGFloat.random(in: 0.55...0.95)
                // Glow
                gc.setFillColor(UIColor(red: 0.60, green: 0.75, blue: 1.0,
                                        alpha: a * 0.18).cgColor)
                gc.fillEllipse(in: CGRect(x: x - r * 3, y: y - r * 3,
                                          width: r * 6, height: r * 6))
                // Core
                gc.setFillColor(UIColor(red: 0.94, green: 0.96, blue: 1.0, alpha: a).cgColor)
                gc.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }

            // Subtle nebula-like radial glow at centre
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = max(size.width, size.height) * 0.60
            let colors = [UIColor(red: 0.25, green: 0.15, blue: 0.45, alpha: 0.18).cgColor,
                          UIColor(red: 0.05, green: 0.04, blue: 0.12, alpha: 0.00).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors, locations: [0, 1] as [CGFloat]) {
                gc.drawRadialGradient(g, startCenter: centre, startRadius: 0,
                                      endCenter: centre, endRadius: radius,
                                      options: [.drawsAfterEndLocation])
            }
        }

        let node = SKSpriteNode(texture: SKTexture(image: img), size: size)
        node.zPosition = -10
        addChild(node)
    }

    // MARK: - Header

    private func addHeader() {
        let titleY = size.height / 2 - 56

        let titleLbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        titleLbl.text      = "ACHIEVEMENTS"
        titleLbl.fontSize  = 14
        titleLbl.fontColor = palette.muteText
        titleLbl.horizontalAlignmentMode = .left
        titleLbl.position  = CGPoint(x: -size.width / 2 + 24, y: titleY)
        titleLbl.zPosition = 5
        addChild(titleLbl)

        let earned   = GameProgress.shared.earnedCount
        let total    = Achievement.allCases.count
        let countLbl = SKLabelNode(fontNamed: "AvenirNext-Regular")
        countLbl.text      = "\(earned) / \(total)"
        countLbl.fontSize  = 12
        countLbl.fontColor = palette.dimText
        countLbl.horizontalAlignmentMode = .right
        countLbl.position  = CGPoint(x: size.width / 2 - 24, y: titleY)
        countLbl.zPosition = 5
        addChild(countLbl)

        let sepPath = CGMutablePath()
        sepPath.move(to: CGPoint(x: -size.width / 2 + 16, y: titleY - 16))
        sepPath.addLine(to: CGPoint(x: size.width / 2 - 16, y: titleY - 16))
        let sep = SKShapeNode(path: sepPath)
        sep.strokeColor = palette.dividerColor
        sep.lineWidth   = 1
        sep.zPosition   = 5
        addChild(sep)
    }

    // MARK: - Pages

    private func buildPages() {
        let achievements  = Achievement.allCases
        pageCount = Int(ceil(Double(achievements.count) / Double(perPage)))

        // Compute cell dimensions to fill available space
        let hPad:         CGFloat = 16
        cellW = (size.width - 2 * hPad - colGap) / 2

        let contentTopY:  CGFloat = size.height / 2 - 84
        let contentBotY:  CGFloat = -(size.height / 2 - 120)
        let dotsAreaH:    CGFloat = 28
        let availH = contentTopY - contentBotY - dotsAreaH - 16   // 16pt breathing room
        cellH = (availH - CGFloat(cellSizeRows - 1) * rowGap) / CGFloat(cellSizeRows)

        let gridH:     CGFloat = CGFloat(rowsPerPage) * (cellH + rowGap) - rowGap
        let gridTopY           = contentTopY - 4
        let gridCenterY        = gridTopY - gridH / 2
        let dotsY              = gridTopY - gridH - 10

        // Crop node clips cells at horizontal edges during page slide
        let maskShape = SKShapeNode(rectOf: CGSize(width: size.width, height: gridH + 12))
        maskShape.fillColor   = .white
        maskShape.strokeColor = .clear

        let cropNode = SKCropNode()
        cropNode.maskNode = maskShape
        cropNode.position  = CGPoint(x: 0, y: gridCenterY)
        cropNode.zPosition = 1
        addChild(cropNode)

        pagesHost = SKNode()
        cropNode.addChild(pagesHost)

        // Place all cells — page P offset by P * size.width on x-axis
        for (i, achievement) in achievements.enumerated() {
            let p      = i / perPage
            let localI = i % perPage
            let col    = localI % 2
            let row    = localI / 2
            let pageX  = CGFloat(p) * size.width
            let colX   = col == 0 ? -(cellW / 2 + colGap / 2) : (cellW / 2 + colGap / 2)
            let rowY   = gridH / 2 - CGFloat(row) * (cellH + rowGap) - cellH / 2

            let cell = makeCell(for: achievement)
            cell.position = CGPoint(x: pageX + colX, y: rowY)
            pagesHost.addChild(cell)
        }

        // Page indicator dots
        let dotSpacing: CGFloat = 12
        let startX = -CGFloat(pageCount - 1) * dotSpacing / 2
        for p in 0..<pageCount {
            let dot = SKShapeNode()
            dot.fillColor   = palette.accentColor
            dot.strokeColor = .clear
            dot.position    = CGPoint(x: startX + CGFloat(p) * dotSpacing, y: dotsY)
            dot.zPosition   = 2
            addChild(dot)
            dotNodes.append(dot)
        }
        updateDots(animated: false)
    }

    private func makeCell(for achievement: Achievement) -> SKNode {
        let earned = GameProgress.shared.isEarned(achievement)
        let style  = achievement.earnedStyle

        let container = SKNode()

        let bg = SKShapeNode(rectOf: CGSize(width: cellW, height: cellH), cornerRadius: 10)
        bg.fillColor   = earned ? style.bg     : palette.cardFill
        bg.strokeColor = earned ? style.stroke : palette.cardStroke
        bg.lineWidth   = earned ? 1.5 : 1.0
        container.addChild(bg)

        // Dynamic sizes based on cell dimensions
        let iconH:     CGFloat = max(16, min(28, cellH * 0.18))
        let titleSize: CGFloat = max(12, min(20, cellH * 0.155))
        let descSize:  CGFloat = max(9,  min(15, cellH * 0.105))
        let gapIT:     CGFloat = cellH * 0.05
        let gapTD:     CGFloat = cellH * 0.035
        let descLineH: CGFloat = descSize * 1.25
        let totalH = iconH + gapIT + titleSize + gapTD + descLineH * 2
        let blockTop = totalH / 2

        let symbol = earned ? achievement.iconSymbol : "lock.fill"
        let config = UIImage.SymbolConfiguration(pointSize: iconH * 0.8, weight: .medium)
        let iconColor = earned ? style.icon : palette.dimText
        if let img = UIImage(systemName: symbol, withConfiguration: config)?
            .withTintColor(iconColor, renderingMode: .alwaysOriginal) {
            let icon = SKSpriteNode(
                texture: SKTexture(image: img),
                size: CGSize(width: iconH * img.size.width / img.size.height, height: iconH)
            )
            icon.position = CGPoint(x: 0, y: blockTop - iconH / 2)
            container.addChild(icon)
        }

        let titleLbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        titleLbl.text                    = earned ? achievement.title : "???"
        titleLbl.fontSize                = titleSize
        titleLbl.fontColor               = earned ? style.title : palette.dimText
        titleLbl.horizontalAlignmentMode = .center
        titleLbl.verticalAlignmentMode   = .center
        titleLbl.position                = CGPoint(x: 0, y: blockTop - iconH - gapIT - titleSize / 2)
        container.addChild(titleLbl)

        let descLbl = SKLabelNode(fontNamed: "AvenirNext-Regular")
        descLbl.text                    = earned ? achievement.blurb : "Keep playing..."
        descLbl.fontSize                = descSize
        descLbl.fontColor               = earned ? style.desc : palette.dimText.withAlphaComponent(0.60)
        descLbl.horizontalAlignmentMode = .center
        descLbl.verticalAlignmentMode   = .top
        descLbl.numberOfLines           = 2
        descLbl.preferredMaxLayoutWidth = cellW - 16
        descLbl.position                = CGPoint(x: 0, y: blockTop - iconH - gapIT - titleSize - gapTD)
        container.addChild(descLbl)

        if !earned { container.alpha = 0.40 }
        return container
    }

    // MARK: - Page navigation

    private func navigateToPage(_ page: Int) {
        currentPage = max(0, min(pageCount - 1, page))
        let targetX = -CGFloat(currentPage) * size.width
        let slide   = SKAction.moveTo(x: targetX, duration: 0.32)
        slide.timingMode = .easeInEaseOut
        pagesHost.run(slide)
        updateDots(animated: true)
        HapticManager.shared.flip()
    }

    private func snapToCurrentPage() {
        let targetX = -CGFloat(currentPage) * size.width
        let snap    = SKAction.moveTo(x: targetX, duration: 0.22)
        snap.timingMode = .easeOut
        pagesHost.run(snap)
    }

    private func updateDots(animated: Bool) {
        for (i, dot) in dotNodes.enumerated() {
            let active      = i == currentPage
            let targetAlpha: CGFloat = active ? 1.0 : 0.28
            let newPath: CGPath = active
                ? CGPath(roundedRect: CGRect(x: -7, y: -3, width: 14, height: 6),
                         cornerWidth: 3, cornerHeight: 3, transform: nil)
                : CGPath(ellipseIn: CGRect(x: -4, y: -4, width: 8, height: 8), transform: nil)
            dot.path = newPath
            if animated {
                dot.run(SKAction.fadeAlpha(to: targetAlpha, duration: 0.20))
            } else {
                dot.alpha = targetAlpha
            }
        }
    }

    // MARK: - Back button

    private func addBackButton() {
        let footerH: CGFloat = 120
        let footer = SKSpriteNode(color: spaceBg,
                                  size: CGSize(width: size.width, height: footerH))
        footer.position  = CGPoint(x: 0, y: -size.height / 2 + footerH / 2)
        footer.zPosition = 3
        addChild(footer)

        let divPath = CGMutablePath()
        divPath.move(to: CGPoint(x: -size.width / 2 + 16, y: -size.height / 2 + footerH))
        divPath.addLine(to: CGPoint(x: size.width / 2 - 16, y: -size.height / 2 + footerH))
        let div = SKShapeNode(path: divPath)
        div.strokeColor = palette.dividerColor
        div.lineWidth   = 1
        div.zPosition   = 4
        addChild(div)

        let node = SKNode()
        node.name = "back"

        let bg = SKShapeNode(rectOf: CGSize(width: 100, height: 44), cornerRadius: 12)
        bg.name        = "back"
        bg.fillColor   = palette.btnFill
        bg.strokeColor = palette.btnStroke
        bg.lineWidth   = 1

        let lbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        lbl.name                  = "back"
        lbl.text                  = "Back"
        lbl.fontSize              = 16
        lbl.fontColor             = palette.accentColor
        lbl.verticalAlignmentMode = .center

        node.addChild(bg)
        node.addChild(lbl)
        node.position  = CGPoint(x: 0, y: -(size.height / 2 - 50))
        node.zPosition = 5
        addChild(node)
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc        = touch.location(in: self)
        isDragging     = true
        dragStartX     = loc.x
        dragStartHostX = pagesHost.position.x
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDragging, let touch = touches.first else { return }
        let dx     = touch.location(in: self).x - dragStartX
        let target = dragStartHostX + dx
        let minX   = -CGFloat(pageCount - 1) * size.width
        // Soft resist past first page; hard clamp past last page
        if target > 0 {
            pagesHost.position.x = target * 0.25
        } else {
            pagesHost.position.x = max(minX, target)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { isDragging = false; return }
        let loc = touch.location(in: self)
        isDragging = false

        let dx = loc.x - dragStartX

        if abs(dx) < 10 {
            if nodes(at: loc).contains(where: { $0.name == "back" }) {
                navigateBack()
            }
            return
        }

        if dx < -(size.width * 0.18) {
            navigateToPage(currentPage + 1)
        } else if dx > (size.width * 0.18) {
            navigateToPage(currentPage - 1)
        } else {
            snapToCurrentPage()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDragging = false
        snapToCurrentPage()
    }

    // MARK: - Navigation

    private func navigateBack() {
        if let src = sourceScene {
            view?.presentScene(src, transition: SKTransition.push(with: .down, duration: 0.35))
        } else {
            let fresh = SettingsScene(size: size)
            fresh.scaleMode = scaleMode
            view?.presentScene(fresh, transition: SKTransition.push(with: .down, duration: 0.35))
        }
    }
}

// MARK: - Per-achievement tile styling

private extension Achievement {
    struct TileStyle {
        let bg: UIColor
        let stroke: UIColor
        let icon: UIColor
        let title: UIColor
        let desc: UIColor
    }

    var earnedStyle: TileStyle {
        func s(_ bg: UIColor, _ accent: UIColor, title: UIColor? = nil) -> TileStyle {
            let t = title ?? accent
            return TileStyle(bg: bg, stroke: accent.withAlphaComponent(0.55),
                             icon: accent, title: t, desc: t.withAlphaComponent(0.60))
        }
        switch self {
        // Pop milestones — ascending heat scale
        case .firstPop:
            return s(UIColor(white: 0.18, alpha: 1), UIColor(white: 0.92, alpha: 1))
        case .crackle:
            return s(UIColor(red: 0.16, green: 0.14, blue: 0.04, alpha: 1),
                     UIColor(red: 1.00, green: 0.88, blue: 0.10, alpha: 1))
        case .snapping:
            return s(UIColor(red: 0.17, green: 0.10, blue: 0.03, alpha: 1),
                     UIColor(red: 1.00, green: 0.55, blue: 0.10, alpha: 1))
        case .rhythm:
            return s(UIColor(red: 0.18, green: 0.05, blue: 0.09, alpha: 1),
                     UIColor(red: 1.00, green: 0.25, blue: 0.45, alpha: 1))
        case .machinePop:
            return s(UIColor(red: 0.11, green: 0.07, blue: 0.22, alpha: 1),
                     UIColor(red: 0.76, green: 0.38, blue: 1.00, alpha: 1))
        case .legend:
            return s(UIColor(red: 0.14, green: 0.11, blue: 0.02, alpha: 1),
                     UIColor(red: 1.00, green: 0.82, blue: 0.08, alpha: 1))
        // Board clears — green family
        case .firstClear:
            return s(UIColor(red: 0.06, green: 0.16, blue: 0.08, alpha: 1),
                     UIColor(red: 0.20, green: 0.90, blue: 0.40, alpha: 1))
        case .fiveClear:
            return s(UIColor(red: 0.05, green: 0.14, blue: 0.14, alpha: 1),
                     UIColor(red: 0.10, green: 0.85, blue: 0.75, alpha: 1))
        case .flipper:
            return s(UIColor(red: 0.07, green: 0.10, blue: 0.20, alpha: 1),
                     UIColor(red: 0.30, green: 0.65, blue: 1.00, alpha: 1))
        // Board shape unlocks — warm amber/gold
        case .firstNewBoard:
            return s(UIColor(red: 0.17, green: 0.13, blue: 0.04, alpha: 1),
                     UIColor(red: 1.00, green: 0.72, blue: 0.10, alpha: 1))
        case .hexUnlock:
            return s(UIColor(red: 0.16, green: 0.13, blue: 0.03, alpha: 1),
                     UIColor(red: 0.98, green: 0.80, blue: 0.20, alpha: 1))
        case .fiveBoards:
            return s(UIColor(red: 0.09, green: 0.10, blue: 0.20, alpha: 1),
                     UIColor(red: 0.55, green: 0.65, blue: 1.00, alpha: 1))
        case .droidUnlock:
            return s(UIColor(red: 0.06, green: 0.15, blue: 0.09, alpha: 1),
                     UIColor(red: 0.24, green: 0.87, blue: 0.52, alpha: 1))
        case .allBoards:
            return s(UIColor(red: 0.13, green: 0.11, blue: 0.03, alpha: 1),
                     UIColor(red: 1.00, green: 0.90, blue: 0.30, alpha: 1))
        // Sound unlocks
        case .xyloUnlock:
            return s(UIColor(red: 0.18, green: 0.10, blue: 0.04, alpha: 1),
                     UIColor(red: 0.96, green: 0.65, blue: 0.35, alpha: 1))
        case .droidSound:
            return s(UIColor(red: 0.05, green: 0.14, blue: 0.08, alpha: 1),
                     UIColor(red: 0.24, green: 0.87, blue: 0.52, alpha: 1))
        case .softUnlock:
            return s(UIColor(red: 0.13, green: 0.08, blue: 0.20, alpha: 1),
                     UIColor(red: 0.83, green: 0.65, blue: 1.00, alpha: 1))
        // Color scheme unlocks — each tile mirrors its own theme palette
        case .darkUnlock:
            let a = UIColor(red: 0.20, green: 0.88, blue: 1.00, alpha: 1)
            return TileStyle(bg: UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1),
                             stroke: a.withAlphaComponent(0.55), icon: a, title: a,
                             desc: a.withAlphaComponent(0.58))
        case .redUnlock:
            let a = UIColor(red: 1.00, green: 0.90, blue: 0.00, alpha: 1)
            return TileStyle(bg: UIColor(red: 0.50, green: 0.05, blue: 0.05, alpha: 1),
                             stroke: a.withAlphaComponent(0.55), icon: a, title: a,
                             desc: a.withAlphaComponent(0.70))
        case .lightUnlock:
            let t = UIColor(red: 0.14, green: 0.26, blue: 0.82, alpha: 1)
            let a = UIColor(red: 0.88, green: 0.07, blue: 0.17, alpha: 1)
            return TileStyle(bg: UIColor(red: 0.93, green: 0.93, blue: 0.97, alpha: 1),
                             stroke: a.withAlphaComponent(0.50), icon: a, title: t,
                             desc: t.withAlphaComponent(0.60))
        // Board design unlocks — each tile mirrors its design palette
        case .frostUnlock:
            let a = UIColor(red: 0.55, green: 0.85, blue: 1.00, alpha: 1)
            return TileStyle(bg: UIColor(red: 0.07, green: 0.12, blue: 0.22, alpha: 1),
                             stroke: a.withAlphaComponent(0.55), icon: a, title: a,
                             desc: a.withAlphaComponent(0.60))
        case .embersUnlock:
            let a = UIColor(red: 1.00, green: 0.45, blue: 0.10, alpha: 1)
            return TileStyle(bg: UIColor(red: 0.18, green: 0.06, blue: 0.02, alpha: 1),
                             stroke: a.withAlphaComponent(0.55), icon: a, title: a,
                             desc: a.withAlphaComponent(0.60))
        case .pearlUnlock:
            let t = UIColor(red: 0.10, green: 0.20, blue: 0.75, alpha: 1)
            let a = UIColor(red: 0.80, green: 0.08, blue: 0.15, alpha: 1)
            return TileStyle(bg: UIColor(red: 0.90, green: 0.90, blue: 0.95, alpha: 1),
                             stroke: a.withAlphaComponent(0.50), icon: a, title: t,
                             desc: t.withAlphaComponent(0.60))
        // Meta
        case .completionist:
            let a = UIColor(red: 1.00, green: 0.84, blue: 0.14, alpha: 1)
            return TileStyle(bg: UIColor(red: 0.13, green: 0.10, blue: 0.02, alpha: 1),
                             stroke: a.withAlphaComponent(0.65), icon: a, title: a,
                             desc: a.withAlphaComponent(0.65))
        }
    }
}
