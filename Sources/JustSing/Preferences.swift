import Foundation

final class Preferences {
    private enum Key {
        static let targetIntensity = "targetIntensity"
        static let makeupGainDecibels = "makeupGainDecibels"
        static let rampDurationMilliseconds = "rampDurationMilliseconds"
        static let preferredOutputDeviceUID = "preferredOutputDeviceUID"
        static let launchAtLogin = "launchAtLogin"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.targetIntensity: 1.0,
            Key.makeupGainDecibels: 0.0,
            Key.rampDurationMilliseconds: 50.0,
            Key.launchAtLogin: false
        ])
    }

    var targetIntensity: Float {
        get { clamp(Float(defaults.double(forKey: Key.targetIntensity)), 0, 1) }
        set { defaults.set(Double(clamp(newValue, 0, 1)), forKey: Key.targetIntensity) }
    }

    var makeupGainDecibels: Float {
        get { clamp(Float(defaults.double(forKey: Key.makeupGainDecibels)), 0, 12) }
        set { defaults.set(Double(clamp(newValue, 0, 12)), forKey: Key.makeupGainDecibels) }
    }

    var rampDurationMilliseconds: Float {
        get { clamp(Float(defaults.double(forKey: Key.rampDurationMilliseconds)), 30, 80) }
        set { defaults.set(Double(clamp(newValue, 30, 80)), forKey: Key.rampDurationMilliseconds) }
    }

    var preferredOutputDeviceUID: String? {
        get { defaults.string(forKey: Key.preferredOutputDeviceUID) }
        set { defaults.set(newValue, forKey: Key.preferredOutputDeviceUID) }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Key.launchAtLogin) }
        set { defaults.set(newValue, forKey: Key.launchAtLogin) }
    }
}

private func clamp<T: Comparable>(_ value: T, _ lower: T, _ upper: T) -> T {
    min(max(value, lower), upper)
}
