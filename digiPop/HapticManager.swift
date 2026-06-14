import UIKit

class HapticManager {
    static let shared = HapticManager()

    private let heavy  = UIImpactFeedbackGenerator(style: .heavy)
    private let rigid  = UIImpactFeedbackGenerator(style: .rigid)
    private let soft   = UIImpactFeedbackGenerator(style: .soft)
    private let medium = UIImpactFeedbackGenerator(style: .medium)

    private init() {
        heavy.prepare()
        rigid.prepare()
        soft.prepare()
        medium.prepare()
    }

    func pop() {
        switch SettingsManager.shared.soundProfile {
        case .classic:
            heavy.impactOccurred(intensity: 1.0)
            heavy.prepare()
        case .droid:
            rigid.impactOccurred(intensity: 1.0)
            rigid.prepare()
        case .soft:
            soft.impactOccurred(intensity: 0.85)
            soft.prepare()
        case .xylo:
            heavy.impactOccurred(intensity: 0.90)
            heavy.prepare()
        }
    }

    func flip() {
        medium.impactOccurred(intensity: 1.0)
        medium.prepare()
    }
}
