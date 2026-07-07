import Foundation

final class Preferences {
    static let defaultTargetIntensity: Float = 1.0
    static let defaultMakeupGainDecibels: Float = 4.5
    static let defaultRampDurationMilliseconds: Float = 50.0

    private enum Key {
        static let targetIntensity = "targetIntensity"
        static let makeupGainDecibels = "makeupGainDecibels"
        static let rampDurationMilliseconds = "rampDurationMilliseconds"
        static let lastReductionEnabled = "lastReductionEnabled"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let preferencesSchemaVersion = "preferencesSchemaVersion"
    }

    private static let currentSchemaVersion = 3

    private let defaults: UserDefaults

    init(defaults: UserDefaults? = nil) {
        let resolved = defaults ?? UserDefaults(suiteName: "com.justsing.app") ?? .standard
        self.defaults = resolved
        self.defaults.register(defaults: [
            Key.targetIntensity: Double(Self.defaultTargetIntensity),
            Key.makeupGainDecibels: Double(Self.defaultMakeupGainDecibels),
            Key.rampDurationMilliseconds: Double(Self.defaultRampDurationMilliseconds),
            Key.lastReductionEnabled: false,
            Key.hasCompletedOnboarding: false
        ])
        seedDefaultsIfNeeded()
        migrateIfNeeded()
    }

    private func seedDefaultsIfNeeded() {
        if defaults.object(forKey: Key.targetIntensity) == nil {
            defaults.set(Double(Self.defaultTargetIntensity), forKey: Key.targetIntensity)
        }
        if defaults.object(forKey: Key.makeupGainDecibels) == nil {
            defaults.set(Double(Self.defaultMakeupGainDecibels), forKey: Key.makeupGainDecibels)
        }
        if defaults.object(forKey: Key.rampDurationMilliseconds) == nil {
            defaults.set(Double(Self.defaultRampDurationMilliseconds), forKey: Key.rampDurationMilliseconds)
        }
        if defaults.object(forKey: Key.lastReductionEnabled) == nil {
            defaults.set(false, forKey: Key.lastReductionEnabled)
        }
        if defaults.object(forKey: Key.hasCompletedOnboarding) == nil {
            defaults.set(false, forKey: Key.hasCompletedOnboarding)
        }
    }

    private func migrateIfNeeded() {
        let version = defaults.integer(forKey: Key.preferencesSchemaVersion)
        guard version < Self.currentSchemaVersion else { return }

        if version < 3 {
            makeupGainDecibels = Self.defaultMakeupGainDecibels
        }

        defaults.set(Self.currentSchemaVersion, forKey: Key.preferencesSchemaVersion)
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

    var lastReductionEnabled: Bool {
        get { defaults.bool(forKey: Key.lastReductionEnabled) }
        set { defaults.set(newValue, forKey: Key.lastReductionEnabled) }
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Key.hasCompletedOnboarding) }
    }
}

private func clamp<T: Comparable>(_ value: T, _ lower: T, _ upper: T) -> T {
    min(max(value, lower), upper)
}
