import Foundation

enum UnlockEvent {
    case board(BoardShape)
    case sound(SoundProfile)
    case colorScheme(UITheme)
    case boardDesign(BoardTheme)
}

enum Achievement: String, CaseIterable {
    // Pop milestones
    case firstPop, crackle, snapping, rhythm, machinePop, legend
    // Board actions
    case firstClear, fiveClear, flipper
    // Board unlocks
    case firstNewBoard, hexUnlock, fiveBoards, droidUnlock, allBoards
    // Sound unlocks
    case xyloUnlock, droidSound, softUnlock
    // Color scheme unlocks
    case darkUnlock, redUnlock, lightUnlock
    // Board design unlocks
    case frostUnlock, embersUnlock, pearlUnlock
    // Meta
    case completionist

    var title: String {
        switch self {
        case .firstPop:      return "First Pop"
        case .crackle:       return "Crackle"
        case .snapping:      return "Snapping"
        case .rhythm:        return "Rhythm"
        case .machinePop:    return "Machine Pop"
        case .legend:        return "Legend"
        case .firstClear:    return "Clean Sweep"
        case .fiveClear:     return "Board Hopper"
        case .flipper:       return "Flip Side"
        case .firstNewBoard: return "Collector"
        case .hexUnlock:     return "Honeycomb"
        case .fiveBoards:    return "Shape Shifter"
        case .droidUnlock:   return "Droid Mode"
        case .allBoards:     return "Full Set"
        case .xyloUnlock:    return "Xylo"
        case .droidSound:    return "Beep Boop"
        case .softUnlock:    return "March On"
        case .darkUnlock:    return "Dark Mode"
        case .redUnlock:     return "Red Alert"
        case .lightUnlock:   return "250th"
        case .frostUnlock:   return "Frost Bite"
        case .embersUnlock:  return "Ember Glow"
        case .pearlUnlock:   return "All-American"
        case .completionist: return "Completionist"
        }
    }

    var blurb: String {
        switch self {
        case .firstPop:      return "Pop your first bubble"
        case .crackle:       return "Pop 50 bubbles"
        case .snapping:      return "Pop 250 bubbles"
        case .rhythm:        return "Pop 1,000 bubbles"
        case .machinePop:    return "Pop 2,500 bubbles"
        case .legend:        return "Pop 5,000 bubbles"
        case .firstClear:    return "Clear all bubbles on a board"
        case .fiveClear:     return "Clear 5 different boards"
        case .flipper:       return "Use the flip feature"
        case .firstNewBoard: return "Unlock a new board shape"
        case .hexUnlock:     return "Unlock the Hexagonal board"
        case .fiveBoards:    return "Unlock 5 different boards"
        case .droidUnlock:   return "Unlock the Droid board"
        case .allBoards:     return "Unlock all boards"
        case .xyloUnlock:    return "Unlock the Xylo sounds"
        case .droidSound:    return "Unlock the Droid sounds"
        case .softUnlock:    return "Unlock the 250th sounds"
        case .darkUnlock:    return "Unlock the Dark color scheme"
        case .redUnlock:     return "Unlock the Red color scheme"
        case .lightUnlock:   return "Unlock the 250th color scheme"
        case .frostUnlock:   return "Unlock the Frost board design"
        case .embersUnlock:  return "Unlock the Embers board design"
        case .pearlUnlock:   return "Unlock the 250th board design"
        case .completionist: return "Unlock all achievements"
        }
    }

    var iconSymbol: String {
        switch self {
        case .firstPop:      return "hand.tap.fill"
        case .crackle:       return "star.fill"
        case .snapping:      return "flame.fill"
        case .rhythm:        return "bolt.fill"
        case .machinePop:    return "sparkles"
        case .legend:        return "crown.fill"
        case .firstClear:    return "checkmark.circle.fill"
        case .fiveClear:     return "checkmark.seal.fill"
        case .flipper:       return "arrow.2.squarepath"
        case .firstNewBoard: return "lock.open.fill"
        case .hexUnlock:     return "hexagon.fill"
        case .fiveBoards:    return "square.stack.fill"
        case .droidUnlock:   return "memorychip"
        case .allBoards:     return "rectangle.badge.checkmark"
        case .xyloUnlock:    return "music.note"
        case .droidSound:    return "waveform"
        case .softUnlock:    return "music.mic"
        case .darkUnlock:    return "moon.fill"
        case .redUnlock:     return "flame.circle.fill"
        case .lightUnlock:   return "rosette"
        case .frostUnlock:   return "snowflake"
        case .embersUnlock:  return "aqi.high"
        case .pearlUnlock:   return "flag.fill"
        case .completionist: return "trophy.fill"
        }
    }
}

class GameProgress {
    static let shared = GameProgress()

    private enum Keys {
        static let totalPops               = "totalPops"
        static let currentBoard            = "currentBoard"
        static let boardPopsPrefix         = "boardPops_"
        static let unlockAnimPrefix        = "unlockAnim_"
        static let achievementPrefix       = "ach_"
        static let clearedBoards           = "clearedBoards"
        static let flipCount               = "flipCount"
        static let firstClearTooltipShown  = "firstClearTooltipShown"
    }

    #if DEBUG
    private let debugTotalPops = Int.random(in: 5001...9999)
    private let debugBoardPops = Int.random(in: 501...999)
    #endif

    var totalPops: Int {
        get {
            #if DEBUG
            return debugTotalPops
            #else
            return UserDefaults.standard.integer(forKey: Keys.totalPops)
            #endif
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.totalPops) }
    }

    var currentBoardShape: BoardShape {
        get {
            let raw = UserDefaults.standard.string(forKey: Keys.currentBoard) ?? ""
            return BoardShape(rawValue: raw) ?? .grid4x4
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.currentBoard) }
    }

    func pops(for shape: BoardShape) -> Int {
        #if DEBUG
        return debugBoardPops
        #else
        return UserDefaults.standard.integer(forKey: Keys.boardPopsPrefix + shape.rawValue)
        #endif
    }

    @discardableResult
    func recordPop(for shape: BoardShape) -> UnlockEvent? {
        let prev = totalPops
        UserDefaults.standard.set(pops(for: shape) + 1, forKey: Keys.boardPopsPrefix + shape.rawValue)
        totalPops += 1

        var unlockEvent: UnlockEvent?

        if let s = BoardShape.allCases.first(where: {
            $0.unlockPops > 0 && prev < $0.unlockPops && totalPops >= $0.unlockPops
        }) { unlockEvent = .board(s) }
        else if let s = SoundProfile.allCases.first(where: {
            $0.unlockPops > 0 && prev < $0.unlockPops && totalPops >= $0.unlockPops
        }) { unlockEvent = .sound(s) }
        else if let t = UITheme.allCases.first(where: {
            $0.unlockPops > 0 && prev < $0.unlockPops && totalPops >= $0.unlockPops
        }) { unlockEvent = .colorScheme(t) }
        else if let t = BoardTheme.allCases.first(where: {
            $0.unlockPops > 0 && prev < $0.unlockPops && totalPops >= $0.unlockPops
        }) { unlockEvent = .boardDesign(t) }

        checkAchievementsAfterPop()
        return unlockEvent
    }

    func recordBoardClear(for shape: BoardShape) {
        var cleared = clearedBoardSet
        cleared.insert(shape.rawValue)
        UserDefaults.standard.set(Array(cleared), forKey: Keys.clearedBoards)
        earnAchievement(.firstClear)
        if cleared.count >= 5 { earnAchievement(.fiveClear) }
        checkCompletionist()
    }

    func recordFlip() {
        let count = UserDefaults.standard.integer(forKey: Keys.flipCount) + 1
        UserDefaults.standard.set(count, forKey: Keys.flipCount)
        earnAchievement(.flipper)
        checkCompletionist()
    }

    // MARK: - Unlock checks

    func isUnlocked(_ shape: BoardShape)      -> Bool {
        #if DEBUG
        return true
        #else
        return totalPops >= shape.unlockPops
        #endif
    }
    func isUnlocked(_ sound: SoundProfile)    -> Bool {
        #if DEBUG
        return true
        #else
        return totalPops >= sound.unlockPops
        #endif
    }
    func isUnlocked(_ theme: UITheme)         -> Bool {
        #if DEBUG
        return true
        #else
        return totalPops >= theme.unlockPops
        #endif
    }
    func isUnlocked(_ boardTheme: BoardTheme) -> Bool {
        #if DEBUG
        return true
        #else
        return totalPops >= boardTheme.unlockPops
        #endif
    }

    var hasShownFirstClearTooltip: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.firstClearTooltipShown) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.firstClearTooltipShown) }
    }

    func hasSeenUnlockAnimation(for shape: BoardShape) -> Bool {
        UserDefaults.standard.bool(forKey: Keys.unlockAnimPrefix + shape.rawValue)
    }

    func markUnlockAnimationSeen(for shape: BoardShape) {
        UserDefaults.standard.set(true, forKey: Keys.unlockAnimPrefix + shape.rawValue)
    }

    // MARK: - Achievements

    func isEarned(_ achievement: Achievement) -> Bool {
        #if DEBUG
        return true
        #else
        return UserDefaults.standard.bool(forKey: Keys.achievementPrefix + achievement.rawValue)
        #endif
    }

    var earnedCount: Int { Achievement.allCases.filter { isEarned($0) }.count }

    private(set) var pendingAchievements: [Achievement] = []

    func drainPendingAchievements() -> [Achievement] {
        let result = pendingAchievements
        pendingAchievements = []
        return result
    }

    private func earnAchievement(_ achievement: Achievement) {
        guard !isEarned(achievement) else { return }
        UserDefaults.standard.set(true, forKey: Keys.achievementPrefix + achievement.rawValue)
        pendingAchievements.append(achievement)
    }

    private var clearedBoardSet: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Keys.clearedBoards) ?? [])
    }

    private func checkAchievementsAfterPop() {
        let t = totalPops
        if t >= 1    { earnAchievement(.firstPop) }
        if t >= 50   { earnAchievement(.crackle) }
        if t >= 250  { earnAchievement(.snapping) }
        if t >= 1000 { earnAchievement(.rhythm) }
        if t >= 2500 { earnAchievement(.machinePop) }
        if t >= 5000 { earnAchievement(.legend) }

        let nonDefault = BoardShape.allCases.filter { $0.unlockPops > 0 }
        if nonDefault.contains(where: { isUnlocked($0) })          { earnAchievement(.firstNewBoard) }
        if isUnlocked(BoardShape.hexagon)                           { earnAchievement(.hexUnlock) }
        if nonDefault.filter({ isUnlocked($0) }).count >= 4         { earnAchievement(.fiveBoards) }
        if isUnlocked(BoardShape.droid)                             { earnAchievement(.droidUnlock) }
        if BoardShape.allCases.allSatisfy({ isUnlocked($0) })       { earnAchievement(.allBoards) }

        if isUnlocked(SoundProfile.xylo)   { earnAchievement(.xyloUnlock) }
        if isUnlocked(SoundProfile.droid)  { earnAchievement(.droidSound) }
        if isUnlocked(SoundProfile.soft)   { earnAchievement(.softUnlock) }

        if isUnlocked(UITheme.dark)        { earnAchievement(.darkUnlock) }
        if isUnlocked(UITheme.red)         { earnAchievement(.redUnlock) }
        if isUnlocked(UITheme.light)       { earnAchievement(.lightUnlock) }

        if isUnlocked(BoardTheme.frost)    { earnAchievement(.frostUnlock) }
        if isUnlocked(BoardTheme.embers)   { earnAchievement(.embersUnlock) }
        if isUnlocked(BoardTheme.pearl)    { earnAchievement(.pearlUnlock) }

        checkCompletionist()
    }

    private func checkCompletionist() {
        if Achievement.allCases.filter({ $0 != .completionist }).allSatisfy({ isEarned($0) }) {
            earnAchievement(.completionist)
        }
    }

    private init() {}
}
