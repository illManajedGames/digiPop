import SpriteKit

class SettingsScene: SKScene {

    var sourceScene: SKScene?

    private var palette: ThemePalette { SettingsManager.shared.palette }

    // MARK: - Slider geometry

    private let trackH: CGFloat = 4
    private let thumbR: CGFloat = 11

    private struct SliderInfo {
        let id: String
        let trackLeft: CGFloat
        let trackRight: CGFloat
        let trackY: CGFloat
        let trackWidth: CGFloat
        let fillNode: SKShapeNode
        let thumbNode: SKShapeNode
        let valueLabel: SKLabelNode
        let muteContainer: SKNode
    }

    private var sliders: [SliderInfo] = []
    private var draggingSlider: SliderInfo?

    // MARK: - Lifecycle

    override func sceneDidLoad() {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = palette.bgColor
        addSheenLayer(overlayBase: palette.overlayBase)
        buildLayout()
        SoundManager.shared.applySettings()
    }

    // MARK: - Layout

    private func buildLayout() {
        let contentTop    = size.height / 2 - 60    // below Dynamic Island / safe area
        let contentBottom = -size.height / 2 + 335  // clear of banner + bottom chrome

        let cardH:      CGFloat = 64
        let headerH:    CGFloat = 16
        let totalFixed: CGFloat = headerH * 2 + cardH * 6  // 416
        let avail = contentTop - contentBottom
        let g = max(4, min(32, (avail - totalFixed) / 7))
        let blockH = totalFixed + g * 7
        var y = contentTop - max(0, (avail - blockH) / 2)

        addSectionHeader("SOUND", y: y - headerH + 4)
        y -= headerH + g

        addVolumeCard(label: "POP IN",  id: "popIn",
                      volume: SettingsManager.shared.popInVolume,
                      muted:  SettingsManager.shared.popInMuted,
                      y: y - cardH / 2)
        y -= cardH + g

        addVolumeCard(label: "POP OUT", id: "popOut",
                      volume: SettingsManager.shared.popOutVolume,
                      muted:  SettingsManager.shared.popOutMuted,
                      y: y - cardH / 2)
        y -= cardH + g

        addSectionHeader("THEMES", y: y - headerH + 4)
        y -= headerH + g

        addSoundProfileCard(y: y - cardH / 2)
        y -= cardH + g

        addUIThemeCard(y: y - cardH / 2)
        y -= cardH + g

        addBoardThemeCard(y: y - cardH / 2)
        y -= cardH + g

        addEffectsCard(y: y - cardH / 2)

        addBackButton()
    }

    private func addSectionHeader(_ text: String, y: CGFloat) {
        let lbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        lbl.text      = text
        lbl.fontSize  = 11
        lbl.fontColor = palette.muteText
        lbl.horizontalAlignmentMode = .left
        lbl.position  = CGPoint(x: -size.width / 2 + 24, y: y)
        addChild(lbl)
    }

    // MARK: - Volume card

    private func addVolumeCard(label: String, id: String, volume: Float, muted: Bool, y: CGFloat) {
        let cardW = size.width - 32

        let card = SKShapeNode(rectOf: CGSize(width: cardW, height: 64), cornerRadius: 12)
        card.fillColor   = palette.cardFill
        card.strokeColor = palette.cardStroke
        card.lineWidth   = 1
        card.position    = CGPoint(x: 0, y: y)
        card.zPosition   = 1
        addChild(card)

        let nameLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        nameLabel.text      = label
        nameLabel.fontSize  = 13
        nameLabel.fontColor = palette.muteText
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.verticalAlignmentMode   = .center
        nameLabel.position  = CGPoint(x: -size.width / 2 + 32, y: y)
        nameLabel.zPosition = 2
        addChild(nameLabel)

        // Track bounds (scene space)
        let muteX      = size.width / 2 - 40
        let trackLeft  = -size.width / 2 + 110
        let trackRight = muteX - 32
        let trackWidth = trackRight - trackLeft

        let trackBg = SKShapeNode(rectOf: CGSize(width: trackWidth, height: trackH), cornerRadius: trackH / 2)
        trackBg.fillColor   = palette.overlayBase.withAlphaComponent(0.12)
        trackBg.strokeColor = .clear
        trackBg.position    = CGPoint(x: (trackLeft + trackRight) / 2, y: y)
        trackBg.zPosition   = 2
        addChild(trackBg)

        // Fill — origin at trackLeft, path drawn rightward from local (0,0)
        let fill = SKShapeNode()
        fill.fillColor   = muted ? palette.overlayBase.withAlphaComponent(0.20) : palette.accentColor
        fill.strokeColor = .clear
        fill.position    = CGPoint(x: trackLeft, y: y)
        fill.zPosition   = 3
        let fillW = max(CGFloat(volume) * trackWidth, trackH)
        fill.path = CGPath(roundedRect: CGRect(x: 0, y: -trackH / 2, width: fillW, height: trackH),
                           cornerWidth: trackH / 2, cornerHeight: trackH / 2, transform: nil)
        addChild(fill)

        // Thumb
        let thumbX = trackLeft + CGFloat(volume) * trackWidth
        let thumb = SKShapeNode(circleOfRadius: thumbR)
        thumb.fillColor   = muted ? palette.overlayBase.withAlphaComponent(0.35) : palette.accentColor
        thumb.strokeColor = palette.overlayBase.withAlphaComponent(0.25)
        thumb.lineWidth   = 1.5
        thumb.position    = CGPoint(x: thumbX, y: y)
        thumb.zPosition   = 4
        addChild(thumb)

        // Value label shown above the thumb
        let valLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        valLabel.text      = muted ? "—" : "\(Int(volume * 100))%"
        valLabel.fontSize  = 10
        valLabel.fontColor = palette.muteText
        valLabel.horizontalAlignmentMode = .center
        valLabel.verticalAlignmentMode   = .center
        valLabel.position  = CGPoint(x: thumbX, y: y + 18)
        valLabel.zPosition = 4
        addChild(valLabel)

        // Mute button
        let muteContainer = makeMuteButton(id: id, muted: muted)
        muteContainer.position = CGPoint(x: muteX, y: y)
        muteContainer.zPosition = 2
        addChild(muteContainer)

        sliders.append(SliderInfo(
            id: id,
            trackLeft: trackLeft,
            trackRight: trackRight,
            trackY: y,
            trackWidth: trackWidth,
            fillNode: fill,
            thumbNode: thumb,
            valueLabel: valLabel,
            muteContainer: muteContainer
        ))
    }

    private func makeMuteButton(id: String, muted: Bool) -> SKNode {
        let node = SKNode()
        node.name = "mute_\(id)"

        let bg = SKShapeNode(circleOfRadius: 18)
        bg.fillColor   = muted ? palette.accentColor.withAlphaComponent(0.22) : palette.overlayBase.withAlphaComponent(0.08)
        bg.strokeColor = muted ? palette.accentColor.withAlphaComponent(0.55) : palette.overlayBase.withAlphaComponent(0.15)
        bg.lineWidth   = 1
        bg.name        = "bg"
        node.addChild(bg)

        addMuteIcon(to: node, muted: muted)
        return node
    }

    private func addMuteIcon(to node: SKNode, muted: Bool) {
        let symbol = muted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        guard let img = UIImage(systemName: symbol, withConfiguration: config)?
                .withTintColor(muted ? palette.accentColor : palette.darkText,
                               renderingMode: .alwaysOriginal) else { return }
        let iconH: CGFloat = 15
        let icon = SKSpriteNode(texture: SKTexture(image: img),
                                size: CGSize(width: iconH * img.size.width / img.size.height, height: iconH))
        icon.name = "icon"
        node.addChild(icon)
    }

    // MARK: - Sound profile card

    private func addSoundProfileCard(y: CGFloat) {
        let cardW   = size.width - 32
        let current = SettingsManager.shared.soundProfile

        let card = SKShapeNode(rectOf: CGSize(width: cardW, height: 64), cornerRadius: 12)
        card.fillColor   = palette.cardFill
        card.strokeColor = palette.cardStroke
        card.lineWidth   = 1
        card.position    = CGPoint(x: 0, y: y)
        card.zPosition   = 1
        addChild(card)

        let titleLbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        titleLbl.text      = "Sounds"
        titleLbl.fontSize  = 13
        titleLbl.fontColor = palette.muteText
        titleLbl.horizontalAlignmentMode = .left
        titleLbl.verticalAlignmentMode   = .center
        titleLbl.position  = CGPoint(x: -size.width / 2 + 32, y: y + 16)
        titleLbl.zPosition = 2
        addChild(titleLbl)

        let chipW:   CGFloat = 64
        let chipH:   CGFloat = 28
        let chipGap: CGFloat = 6
        let count    = SoundProfile.allCases.count
        let totalW   = CGFloat(count) * chipW + CGFloat(count - 1) * chipGap
        let startX   = -totalW / 2 + chipW / 2

        for (i, profile) in SoundProfile.allCases.enumerated() {
            let isActive  = profile == current
            let isLocked  = !GameProgress.shared.isUnlocked(profile)
            let chipX     = startX + CGFloat(i) * (chipW + chipGap)

            let chip = SKNode()
            chip.name = "sndprofile_\(profile.rawValue)"

            let chipBg = SKShapeNode(rectOf: CGSize(width: chipW, height: chipH), cornerRadius: 8)
            chipBg.fillColor   = isActive ? palette.accentColor.withAlphaComponent(0.20) : palette.overlayBase.withAlphaComponent(0.06)
            chipBg.strokeColor = isActive ? palette.accentColor.withAlphaComponent(0.70) : palette.overlayBase.withAlphaComponent(0.15)
            chipBg.lineWidth   = 1
            chipBg.name        = "sndpbg_\(profile.rawValue)"
            chip.addChild(chipBg)

            let chipLbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
            chipLbl.text                    = isLocked ? "?" : profile.displayName
            chipLbl.fontSize                = 12
            chipLbl.fontColor               = isActive ? palette.accentColor : palette.muteText
            chipLbl.verticalAlignmentMode   = .center
            chipLbl.horizontalAlignmentMode = .center
            chipLbl.name = "sndplbl_\(profile.rawValue)"
            chip.addChild(chipLbl)

            if isLocked { chip.alpha = 0.30 }
            chip.position  = CGPoint(x: chipX, y: y - 8)
            chip.zPosition = 2
            addChild(chip)
        }
    }

    private func selectSoundProfile(_ profile: SoundProfile) {
        SettingsManager.shared.soundProfile = profile
        for p in SoundProfile.allCases {
            let isActive = p == profile
            if let bg = childNode(withName: "//sndpbg_\(p.rawValue)") as? SKShapeNode {
                bg.fillColor   = isActive ? palette.accentColor.withAlphaComponent(0.20) : palette.overlayBase.withAlphaComponent(0.06)
                bg.strokeColor = isActive ? palette.accentColor.withAlphaComponent(0.70) : palette.overlayBase.withAlphaComponent(0.15)
            }
            if let lbl = childNode(withName: "//sndplbl_\(p.rawValue)") as? SKLabelNode {
                lbl.fontColor = isActive ? palette.accentColor : palette.muteText
            }
        }
    }

    // MARK: - UI theme card

    private func addUIThemeCard(y: CGFloat) {
        let cardW   = size.width - 32
        let current = SettingsManager.shared.uiTheme

        let card = SKShapeNode(rectOf: CGSize(width: cardW, height: 64), cornerRadius: 12)
        card.fillColor   = palette.cardFill
        card.strokeColor = palette.cardStroke
        card.lineWidth   = 1
        card.position    = CGPoint(x: 0, y: y)
        card.zPosition   = 1
        addChild(card)

        let titleLbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        titleLbl.text      = "Color Scheme"
        titleLbl.fontSize  = 13
        titleLbl.fontColor = palette.muteText
        titleLbl.horizontalAlignmentMode = .left
        titleLbl.verticalAlignmentMode   = .center
        titleLbl.position  = CGPoint(x: -size.width / 2 + 32, y: y + 16)
        titleLbl.zPosition = 2
        addChild(titleLbl)

        let chipW:   CGFloat = 64
        let chipH:   CGFloat = 28
        let chipGap: CGFloat = 6
        let count    = UITheme.allCases.count
        let totalW   = CGFloat(count) * chipW + CGFloat(count - 1) * chipGap
        let startX   = -totalW / 2 + chipW / 2

        for (i, theme) in UITheme.allCases.enumerated() {
            let isActive = theme == current
            let isLocked = !GameProgress.shared.isUnlocked(theme)
            let chipX    = startX + CGFloat(i) * (chipW + chipGap)

            let chip = SKNode()
            chip.name = "uitheme_\(theme.rawValue)"

            let chipBg = SKShapeNode(rectOf: CGSize(width: chipW, height: chipH), cornerRadius: 8)
            chipBg.fillColor   = isActive ? palette.accentColor.withAlphaComponent(0.20) : palette.overlayBase.withAlphaComponent(0.06)
            chipBg.strokeColor = isActive ? palette.accentColor.withAlphaComponent(0.70) : palette.overlayBase.withAlphaComponent(0.15)
            chipBg.lineWidth   = 1
            chipBg.name        = "uitbg_\(theme.rawValue)"
            chip.addChild(chipBg)

            let chipLbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
            chipLbl.text                    = isLocked ? "?" : theme.displayName
            chipLbl.fontSize                = 12
            chipLbl.fontColor               = isActive ? palette.accentColor : palette.muteText
            chipLbl.verticalAlignmentMode   = .center
            chipLbl.horizontalAlignmentMode = .center
            chipLbl.name = "uitlbl_\(theme.rawValue)"
            chip.addChild(chipLbl)

            if isLocked { chip.alpha = 0.30 }
            chip.position  = CGPoint(x: chipX, y: y - 8)
            chip.zPosition = 2
            addChild(chip)
        }
    }

    private func selectUITheme(_ theme: UITheme) {
        SettingsManager.shared.uiTheme = theme
        let fresh = SettingsScene(size: size)
        fresh.scaleMode  = scaleMode
        fresh.sourceScene = sourceScene
        view?.presentScene(fresh, transition: SKTransition.crossFade(withDuration: 0.20))
    }

    // MARK: - Board theme card

    private func addBoardThemeCard(y: CGFloat) {
        let cardW   = size.width - 32
        let current = SettingsManager.shared.boardTheme

        let card = SKShapeNode(rectOf: CGSize(width: cardW, height: 64), cornerRadius: 12)
        card.fillColor   = palette.cardFill
        card.strokeColor = palette.cardStroke
        card.lineWidth   = 1
        card.position    = CGPoint(x: 0, y: y)
        card.zPosition   = 1
        addChild(card)

        let titleLbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        titleLbl.text      = "Board Design"
        titleLbl.fontSize  = 13
        titleLbl.fontColor = palette.muteText
        titleLbl.horizontalAlignmentMode = .left
        titleLbl.verticalAlignmentMode   = .center
        titleLbl.position  = CGPoint(x: -size.width / 2 + 32, y: y + 16)
        titleLbl.zPosition = 2
        addChild(titleLbl)

        let chipW:   CGFloat = 64
        let chipH:   CGFloat = 28
        let chipGap: CGFloat = 6
        let count    = BoardTheme.allCases.count
        let totalW   = CGFloat(count) * chipW + CGFloat(count - 1) * chipGap
        let startX   = -totalW / 2 + chipW / 2

        for (i, theme) in BoardTheme.allCases.enumerated() {
            let isActive = theme == current
            let isLocked = !GameProgress.shared.isUnlocked(theme)
            let chipX    = startX + CGFloat(i) * (chipW + chipGap)

            let chip = SKNode()
            chip.name = "theme_\(theme.rawValue)"

            let chipBg = SKShapeNode(rectOf: CGSize(width: chipW, height: chipH), cornerRadius: 8)
            chipBg.fillColor   = isActive ? palette.accentColor.withAlphaComponent(0.20) : palette.overlayBase.withAlphaComponent(0.06)
            chipBg.strokeColor = isActive ? palette.accentColor.withAlphaComponent(0.70) : palette.overlayBase.withAlphaComponent(0.15)
            chipBg.lineWidth   = 1
            chipBg.name        = "themebg_\(theme.rawValue)"
            chip.addChild(chipBg)

            let chipLbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
            chipLbl.text                    = isLocked ? "?" : theme.displayName
            chipLbl.fontSize                = 12
            chipLbl.fontColor               = isActive ? palette.accentColor : palette.muteText
            chipLbl.verticalAlignmentMode   = .center
            chipLbl.horizontalAlignmentMode = .center
            chipLbl.name = "themelbl_\(theme.rawValue)"
            chip.addChild(chipLbl)

            if isLocked { chip.alpha = 0.30 }
            chip.position  = CGPoint(x: chipX, y: y - 8)
            chip.zPosition = 2
            addChild(chip)
        }
    }

    private func selectBoardTheme(_ theme: BoardTheme) {
        SettingsManager.shared.boardTheme = theme
        for t in BoardTheme.allCases {
            let isActive = t == theme
            if let bg = childNode(withName: "//themebg_\(t.rawValue)") as? SKShapeNode {
                bg.fillColor   = isActive ? palette.accentColor.withAlphaComponent(0.20) : palette.overlayBase.withAlphaComponent(0.06)
                bg.strokeColor = isActive ? palette.accentColor.withAlphaComponent(0.70) : palette.overlayBase.withAlphaComponent(0.15)
            }
            if let lbl = childNode(withName: "//themelbl_\(t.rawValue)") as? SKLabelNode {
                lbl.fontColor = isActive ? palette.accentColor : palette.muteText
            }
        }
    }

    // MARK: - Effects toggle card

    private func addEffectsCard(y: CGFloat) {
        let cardW   = size.width - 32
        let enabled = SettingsManager.shared.boardEffectsEnabled

        let card = SKShapeNode(rectOf: CGSize(width: cardW, height: 64), cornerRadius: 12)
        card.fillColor   = palette.cardFill
        card.strokeColor = palette.cardStroke
        card.lineWidth   = 1
        card.position    = CGPoint(x: 0, y: y)
        card.zPosition   = 1
        addChild(card)

        let titleLbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        titleLbl.text      = "Effects"
        titleLbl.fontSize  = 13
        titleLbl.fontColor = palette.muteText
        titleLbl.horizontalAlignmentMode = .left
        titleLbl.verticalAlignmentMode   = .center
        titleLbl.position  = CGPoint(x: -size.width / 2 + 32, y: y + 10)
        titleLbl.zPosition = 2
        addChild(titleLbl)

        let subLbl = SKLabelNode(fontNamed: "AvenirNext-Regular")
        subLbl.text      = "Snow, sparks, fireworks & rainbows"
        subLbl.fontSize  = 11
        subLbl.fontColor = palette.dimText
        subLbl.horizontalAlignmentMode = .left
        subLbl.verticalAlignmentMode   = .center
        subLbl.position  = CGPoint(x: -size.width / 2 + 32, y: y - 10)
        subLbl.zPosition = 2
        addChild(subLbl)

        let toggle = makeEffectsToggle(enabled: enabled)
        toggle.position  = CGPoint(x: size.width / 2 - 56, y: y)
        toggle.zPosition = 2
        addChild(toggle)
    }

    private func makeEffectsToggle(enabled: Bool) -> SKNode {
        let node    = SKNode()
        node.name   = "effects_toggle"
        let pillW:  CGFloat = 46
        let pillH:  CGFloat = 26

        let pill = SKShapeNode(rectOf: CGSize(width: pillW, height: pillH), cornerRadius: pillH / 2)
        pill.fillColor   = enabled ? palette.accentColor.withAlphaComponent(0.85) : palette.overlayBase.withAlphaComponent(0.15)
        pill.strokeColor = enabled ? palette.accentColor : palette.overlayBase.withAlphaComponent(0.25)
        pill.lineWidth   = 1
        pill.name        = "effects_pill"
        node.addChild(pill)

        let thumbR: CGFloat = pillH * 0.38
        let thumbX: CGFloat = enabled ? pillW / 2 - pillH * 0.5 : -(pillW / 2 - pillH * 0.5)
        let thumb = SKShapeNode(circleOfRadius: thumbR)
        thumb.fillColor   = enabled ? .white : palette.overlayBase.withAlphaComponent(0.50)
        thumb.strokeColor = .clear
        thumb.position    = CGPoint(x: thumbX, y: 0)
        thumb.name        = "effects_thumb"
        node.addChild(thumb)

        return node
    }

    private func toggleEffects() {
        SettingsManager.shared.boardEffectsEnabled.toggle()
        let enabled = SettingsManager.shared.boardEffectsEnabled
        let pillW:  CGFloat = 46
        let pillH:  CGFloat = 26

        if let pill = childNode(withName: "//effects_pill") as? SKShapeNode {
            pill.fillColor   = enabled ? palette.accentColor.withAlphaComponent(0.85) : palette.overlayBase.withAlphaComponent(0.15)
            pill.strokeColor = enabled ? palette.accentColor : palette.overlayBase.withAlphaComponent(0.25)
        }
        if let thumb = childNode(withName: "//effects_thumb") as? SKShapeNode {
            let thumbX: CGFloat = enabled ? pillW / 2 - pillH * 0.5 : -(pillW / 2 - pillH * 0.5)
            thumb.position.x  = thumbX
            thumb.fillColor   = enabled ? .white : palette.overlayBase.withAlphaComponent(0.50)
        }
    }

    // MARK: - Bottom buttons

    private func addBackButton() {
        let bottomY = -(size.height / 2 - 50)

        // Achievements button (left)
        let achNode = SKNode()
        achNode.name = "achievements"

        let achBg = SKShapeNode(rectOf: CGSize(width: 170, height: 44), cornerRadius: 12)
        achBg.name        = "achievements"
        achBg.fillColor   = palette.cardFill
        achBg.strokeColor = palette.cardStroke
        achBg.lineWidth   = 1

        let earned = GameProgress.shared.earnedCount
        let total  = Achievement.allCases.count

        let achLbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        achLbl.name                  = "achievements"
        achLbl.text                  = "Achievements  \(earned)/\(total)"
        achLbl.fontSize              = 13
        achLbl.fontColor             = palette.accentColor
        achLbl.verticalAlignmentMode = .center

        achNode.addChild(achBg)
        achNode.addChild(achLbl)
        achNode.position = CGPoint(x: -size.width / 2 + 109, y: bottomY)
        addChild(achNode)

        // Back button (right)
        let node = SKNode()
        node.name = "back"

        let bg = SKShapeNode(rectOf: CGSize(width: 90, height: 44), cornerRadius: 12)
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
        node.position = CGPoint(x: size.width / 2 - 69, y: bottomY)
        addChild(node)
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)

        // Sound profile chips
        for node in nodes(at: loc) {
            guard let name = node.name, name.hasPrefix("sndprofile_") else { continue }
            let rawValue = String(name.dropFirst("sndprofile_".count))
            if let profile = SoundProfile(rawValue: rawValue),
               GameProgress.shared.isUnlocked(profile) {
                selectSoundProfile(profile)
                return
            }
        }

        // UI theme chips
        for node in nodes(at: loc) {
            guard let name = node.name, name.hasPrefix("uitheme_") else { continue }
            let rawValue = String(name.dropFirst("uitheme_".count))
            if let theme = UITheme(rawValue: rawValue),
               GameProgress.shared.isUnlocked(theme) {
                selectUITheme(theme)
                return
            }
        }

        // Board theme chips
        for node in nodes(at: loc) {
            guard let name = node.name, name.hasPrefix("theme_") else { continue }
            let rawValue = String(name.dropFirst("theme_".count))
            if let theme = BoardTheme(rawValue: rawValue),
               GameProgress.shared.isUnlocked(theme) {
                selectBoardTheme(theme)
                return
            }
        }

        // Effects toggle
        if nodes(at: loc).contains(where: {
            $0.name == "effects_toggle" || $0.name == "effects_pill" || $0.name == "effects_thumb"
        }) {
            toggleEffects()
            return
        }

        // Mute button — checked by proximity to button center
        for info in sliders {
            let mp = info.muteContainer.position
            if hypot(loc.x - mp.x, loc.y - mp.y) < 22 {
                toggleMute(id: info.id)
                return
            }
        }

        // Slider track — 44pt tall touch zone
        for info in sliders {
            if abs(loc.y - info.trackY) < 22,
               loc.x >= info.trackLeft - thumbR,
               loc.x <= info.trackRight + thumbR {
                draggingSlider = info
                applySliderDrag(info: info, x: loc.x)
                return
            }
        }

        // Achievements button
        if nodes(at: loc).contains(where: { $0.name == "achievements" }) {
            let scene = AchievementsScene(size: size)
            scene.scaleMode  = scaleMode
            scene.sourceScene = self
            view?.presentScene(scene, transition: SKTransition.push(with: .up, duration: 0.35))
            return
        }

        // Back button
        if nodes(at: loc).contains(where: { $0.name == "back" }) {
            navigateBack()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let info = draggingSlider else { return }
        applySliderDrag(info: info, x: touch.location(in: self).x)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?)    { draggingSlider = nil }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { draggingSlider = nil }

    // MARK: - Slider update

    private func applySliderDrag(info: SliderInfo, x: CGFloat) {
        let clamped = max(info.trackLeft, min(info.trackRight, x))
        let value   = Float((clamped - info.trackLeft) / info.trackWidth)

        if info.id == "popIn" {
            SettingsManager.shared.popInVolume  = value
        } else {
            SettingsManager.shared.popOutVolume = value
        }

        let fillW = max(CGFloat(value) * info.trackWidth, trackH)
        info.fillNode.path = CGPath(
            roundedRect: CGRect(x: 0, y: -trackH / 2, width: fillW, height: trackH),
            cornerWidth: trackH / 2, cornerHeight: trackH / 2, transform: nil)

        info.thumbNode.position.x  = clamped
        info.valueLabel.position.x = clamped
        info.valueLabel.text = isMuted(id: info.id) ? "—" : "\(Int(value * 100))%"
    }

    // MARK: - Mute toggle

    private func toggleMute(id: String) {
        if id == "popIn" {
            SettingsManager.shared.popInMuted.toggle()
        } else {
            SettingsManager.shared.popOutMuted.toggle()
        }
        guard let info = sliders.first(where: { $0.id == id }) else { return }
        let muted  = isMuted(id: id)
        let volume = id == "popIn" ? SettingsManager.shared.popInVolume : SettingsManager.shared.popOutVolume

        info.fillNode.fillColor  = muted ? palette.overlayBase.withAlphaComponent(0.20) : palette.accentColor
        info.thumbNode.fillColor = muted ? palette.overlayBase.withAlphaComponent(0.35) : palette.accentColor
        info.valueLabel.text     = muted ? "—" : "\(Int(volume * 100))%"

        if let bg = info.muteContainer.childNode(withName: "bg") as? SKShapeNode {
            bg.fillColor   = muted ? palette.accentColor.withAlphaComponent(0.22) : palette.overlayBase.withAlphaComponent(0.08)
            bg.strokeColor = muted ? palette.accentColor.withAlphaComponent(0.55) : palette.overlayBase.withAlphaComponent(0.15)
        }
        info.muteContainer.childNode(withName: "icon")?.removeFromParent()
        addMuteIcon(to: info.muteContainer, muted: muted)
    }

    private func isMuted(id: String) -> Bool {
        id == "popIn" ? SettingsManager.shared.popInMuted : SettingsManager.shared.popOutMuted
    }

    // MARK: - Navigation

    private func navigateBack() {
        let target: SKScene
        if let src = sourceScene {
            target = src
        } else {
            let fresh = GameScene(size: size)
            fresh.scaleMode = scaleMode
            target = fresh
        }
        view?.presentScene(target, transition: SKTransition.push(with: .down, duration: 0.35))
    }
}
