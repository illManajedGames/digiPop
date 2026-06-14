import Foundation
import UIKit

enum UITheme: String, CaseIterable {
    case night = "night"
    case dark  = "dark"
    case red   = "red"
    case light = "light"

    var displayName: String {
        switch self {
        case .night: return "Night"
        case .dark:  return "Dark"
        case .red:   return "Red"
        case .light: return "250th"
        }
    }

    var unlockPops: Int {
        switch self {
        case .night: return 0
        case .dark:  return 425
        case .red:   return 1250
        case .light: return 2850
        }
    }
}

struct ThemePalette {
    let bgColor:       UIColor
    let darkText:      UIColor
    let muteText:      UIColor
    let dimText:       UIColor
    let btnFill:       UIColor
    let btnStroke:     UIColor
    let accentColor:   UIColor
    let cardFill:      UIColor
    let cardStroke:    UIColor
    let cardCurrent:   UIColor
    let currentStroke: UIColor
    let dividerColor:  UIColor
    let overlayBase:   UIColor  // white for dark themes, black for light themes

    static let dark = ThemePalette(
        bgColor:       UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1),
        darkText:      UIColor(red: 0.50, green: 0.78, blue: 0.95, alpha: 1),
        muteText:      UIColor(red: 0.50, green: 0.78, blue: 0.95, alpha: 0.58),
        dimText:       UIColor(red: 0.50, green: 0.78, blue: 0.95, alpha: 0.32),
        btnFill:       UIColor(red: 0.14, green: 0.14, blue: 0.18, alpha: 1),
        btnStroke:     UIColor(red: 0.50, green: 0.78, blue: 0.95, alpha: 0.25),
        accentColor:   UIColor(red: 0.50, green: 0.78, blue: 0.95, alpha: 1),
        cardFill:      UIColor(red: 0.14, green: 0.14, blue: 0.18, alpha: 1),
        cardStroke:    UIColor(red: 0.50, green: 0.78, blue: 0.95, alpha: 0.20),
        cardCurrent:   UIColor(red: 0.50, green: 0.78, blue: 0.95, alpha: 0.18),
        currentStroke: UIColor(red: 0.50, green: 0.78, blue: 0.95, alpha: 0.70),
        dividerColor:  UIColor(red: 0.50, green: 0.78, blue: 0.95, alpha: 0.25),
        overlayBase:   .white
    )

    static let night = ThemePalette(
        bgColor:       UIColor(red: 0.12, green: 0.08, blue: 0.22, alpha: 1),
        darkText:      UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1),
        muteText:      UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 0.65),
        dimText:       UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 0.40),
        btnFill:       UIColor(red: 0.20, green: 0.14, blue: 0.34, alpha: 1),
        btnStroke:     UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 0.30),
        accentColor:   UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1),
        cardFill:      UIColor(red: 0.18, green: 0.12, blue: 0.30, alpha: 1),
        cardStroke:    UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 0.22),
        cardCurrent:   UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 0.18),
        currentStroke: UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 0.70),
        dividerColor:  UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 0.30),
        overlayBase:   .white
    )

    static let light = ThemePalette(
        bgColor:       UIColor(red: 0.97, green: 0.97, blue: 0.99, alpha: 1),
        darkText:      UIColor(red: 0.14, green: 0.26, blue: 0.82, alpha: 1),
        muteText:      UIColor(red: 0.14, green: 0.26, blue: 0.82, alpha: 0.60),
        dimText:       UIColor(red: 0.14, green: 0.26, blue: 0.82, alpha: 0.35),
        btnFill:       UIColor(red: 0.92, green: 0.92, blue: 0.96, alpha: 1),
        btnStroke:     UIColor(red: 0.14, green: 0.26, blue: 0.82, alpha: 0.30),
        accentColor:   UIColor(red: 0.88, green: 0.07, blue: 0.17, alpha: 1),
        cardFill:      UIColor(red: 0.93, green: 0.93, blue: 0.97, alpha: 1),
        cardStroke:    UIColor(red: 0.14, green: 0.26, blue: 0.82, alpha: 0.22),
        cardCurrent:   UIColor(red: 0.14, green: 0.26, blue: 0.82, alpha: 0.14),
        currentStroke: UIColor(red: 0.14, green: 0.26, blue: 0.82, alpha: 0.72),
        dividerColor:  UIColor(red: 0.14, green: 0.26, blue: 0.82, alpha: 0.20),
        overlayBase:   .black
    )

    static let red = ThemePalette(
        bgColor:       UIColor(red: 0.58, green: 0.06, blue: 0.06, alpha: 1),
        darkText:      UIColor(red: 1.00, green: 0.90, blue: 0.00, alpha: 1),
        muteText:      UIColor(red: 1.00, green: 0.90, blue: 0.00, alpha: 0.72),
        dimText:       UIColor(red: 1.00, green: 0.90, blue: 0.00, alpha: 0.45),
        btnFill:       UIColor(red: 0.48, green: 0.05, blue: 0.05, alpha: 1),
        btnStroke:     UIColor(red: 1.00, green: 0.90, blue: 0.00, alpha: 0.40),
        accentColor:   UIColor(red: 1.00, green: 0.90, blue: 0.00, alpha: 1),
        cardFill:      UIColor(red: 0.50, green: 0.05, blue: 0.05, alpha: 1),
        cardStroke:    UIColor(red: 1.00, green: 0.90, blue: 0.00, alpha: 0.30),
        cardCurrent:   UIColor(red: 1.00, green: 0.90, blue: 0.00, alpha: 0.20),
        currentStroke: UIColor(red: 1.00, green: 0.90, blue: 0.00, alpha: 0.75),
        dividerColor:  UIColor(red: 1.00, green: 0.90, blue: 0.00, alpha: 0.35),
        overlayBase:   .white
    )
}

enum SoundProfile: String, CaseIterable {
    case classic = "classic"
    case xylo    = "xylo"
    case droid   = "droid"
    case soft    = "soft"

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .xylo:    return "Xylo"
        case .droid:   return "Droid"
        case .soft:    return "250th"
        }
    }

    var unlockPops: Int {
        switch self {
        case .classic: return 0
        case .xylo:    return 250
        case .droid:   return 975
        case .soft:    return 2225
        }
    }
}

enum BoardTheme: String, CaseIterable {
    case rainbow = "rainbow"
    case frost   = "frost"
    case embers  = "embers"
    case pearl   = "pearl"

    var displayName: String {
        switch self {
        case .rainbow: return "Rainbow"
        case .frost:   return "Frost"
        case .embers:  return "Embers"
        case .pearl:   return "250th"
        }
    }

    var unlockPops: Int {
        switch self {
        case .rainbow: return 0
        case .frost:   return 700
        case .embers:  return 1725
        case .pearl:   return 3550
        }
    }
}

class SettingsManager {
    static let shared = SettingsManager()

    private enum Keys {
        static let popInVolume        = "popInVolume"
        static let popOutVolume       = "popOutVolume"
        static let popInMuted         = "popInMuted"
        static let popOutMuted        = "popOutMuted"
        static let boardTheme         = "boardTheme"
        static let uiTheme            = "uiTheme"
        static let soundProfile       = "soundProfile"
        static let boardEffectsEnabled = "boardEffectsEnabled"
    }

    var popInVolume: Float {
        get { UserDefaults.standard.object(forKey: Keys.popInVolume) as? Float ?? 1.0 }
        set { UserDefaults.standard.set(newValue, forKey: Keys.popInVolume)
              SoundManager.shared.applySettings() }
    }

    var popOutVolume: Float {
        get { UserDefaults.standard.object(forKey: Keys.popOutVolume) as? Float ?? 1.0 }
        set { UserDefaults.standard.set(newValue, forKey: Keys.popOutVolume)
              SoundManager.shared.applySettings() }
    }

    var popInMuted: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.popInMuted) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.popInMuted)
              SoundManager.shared.applySettings() }
    }

    var popOutMuted: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.popOutMuted) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.popOutMuted)
              SoundManager.shared.applySettings() }
    }

    var effectivePopInVolume:  Float { popInMuted  ? 0 : popInVolume  }
    var effectivePopOutVolume: Float { popOutMuted ? 0 : popOutVolume }

    var uiTheme: UITheme {
        get { UITheme(rawValue: UserDefaults.standard.string(forKey: Keys.uiTheme) ?? "") ?? .night }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.uiTheme)
            NotificationCenter.default.post(name: .uiThemeDidChange, object: nil)
        }
    }

    var boardTheme: BoardTheme {
        get { BoardTheme(rawValue: UserDefaults.standard.string(forKey: Keys.boardTheme) ?? "") ?? .frost }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.boardTheme) }
    }

    var soundProfile: SoundProfile {
        get { SoundProfile(rawValue: UserDefaults.standard.string(forKey: Keys.soundProfile) ?? "") ?? .classic }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.soundProfile)
              SoundManager.shared.reloadBuffers() }
    }

    var boardEffectsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Keys.boardEffectsEnabled) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.boardEffectsEnabled) }
    }

    var palette: ThemePalette {
        switch uiTheme {
        case .dark:     return .dark
        case .red:      return .red
        case .light:    return .light
        case .night: return .night
        }
    }

    private init() {
        UserDefaults.standard.register(defaults: [
            Keys.soundProfile: SoundProfile.classic.rawValue,
            Keys.uiTheme:      UITheme.night.rawValue,
            Keys.boardTheme:   BoardTheme.rainbow.rawValue,
            Keys.popInVolume:  Float(1.0),
            Keys.popOutVolume: Float(1.0),
            Keys.popInMuted:   false,
            Keys.popOutMuted:  false,
            Keys.boardEffectsEnabled: true,
        ])
    }
}

extension Notification.Name {
    static let uiThemeDidChange = Notification.Name("digiPop.uiThemeDidChange")
}
