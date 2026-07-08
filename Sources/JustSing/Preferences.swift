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
        static let processingMode = "processingMode"
        static let separationModelVariant = "separationModelVariant"
        static let preferencesSchemaVersion = "preferencesSchemaVersion"
    }

    private static let currentSchemaVersion = 6

    private let defaults: UserDefaults

    init(defaults: UserDefaults? = nil) {
        let resolved = defaults ?? UserDefaults(suiteName: "com.justsing.app") ?? .standard
        self.defaults = resolved
        self.defaults.register(defaults: [
            Key.targetIntensity: Double(Self.defaultTargetIntensity),
            Key.makeupGainDecibels: Double(Self.defaultMakeupGainDecibels),
            Key.rampDurationMilliseconds: Double(Self.defaultRampDurationMilliseconds),
            Key.lastReductionEnabled: false,
            Key.hasCompletedOnboarding: false,
            Key.processingMode: ProcessingMode.centerVocalCut.rawValue,
            Key.separationModelVariant: SeparationModelVariant.balanced.rawValue
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
        if defaults.object(forKey: Key.processingMode) == nil {
            defaults.set(ProcessingMode.centerVocalCut.rawValue, forKey: Key.processingMode)
        }
        if defaults.object(forKey: Key.separationModelVariant) == nil {
            defaults.set(SeparationModelVariant.balanced.rawValue, forKey: Key.separationModelVariant)
        }
    }

    private func migrateIfNeeded() {
        let version = defaults.integer(forKey: Key.preferencesSchemaVersion)
        guard version < Self.currentSchemaVersion else { return }

        if version < 3 {
            makeupGainDecibels = Self.defaultMakeupGainDecibels
        }

        if version < 5,
           let raw = defaults.string(forKey: Key.processingMode),
           let migrated = ProcessingMode.fromPersisted(raw),
           migrated.rawValue != raw {
            defaults.set(migrated.rawValue, forKey: Key.processingMode)
        }

        if version < 6,
           defaults.object(forKey: Key.separationModelVariant) == nil {
            defaults.set(SeparationModelVariant.balanced.rawValue, forKey: Key.separationModelVariant)
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

    var processingMode: ProcessingMode {
        get {
            guard let raw = defaults.string(forKey: Key.processingMode),
                  let mode = ProcessingMode.fromPersisted(raw) else {
                return .centerVocalCut
            }
            return mode
        }
        set { defaults.set(newValue.rawValue, forKey: Key.processingMode) }
    }

    var separationModelVariant: SeparationModelVariant {
        get {
            guard let raw = defaults.string(forKey: Key.separationModelVariant),
                  let variant = SeparationModelVariant.fromPersisted(raw) else {
                return .balanced
            }
            return variant
        }
        set { defaults.set(newValue.rawValue, forKey: Key.separationModelVariant) }
    }
}

private func clamp<T: Comparable>(_ value: T, _ lower: T, _ upper: T) -> T {
    min(max(value, lower), upper)
}
