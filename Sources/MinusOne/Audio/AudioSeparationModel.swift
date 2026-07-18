import Foundation

struct SeparationResult {
    let instrumentalLeft: [Float]
    let instrumentalRight: [Float]
}

protocol AudioSeparationModel: AnyObject {
    var variant: SeparationModelVariant { get }
    var name: String { get }
    var modelSampleRate: Double { get }
    var preferredWindowSeconds: Double { get }

    func separate(
        left: UnsafePointer<Float>,
        right: UnsafePointer<Float>,
        frameCount: Int,
        sampleRate: Double
    ) throws -> SeparationResult
}

extension AudioSeparationModel {
    func separate(left: [Float], right: [Float], sampleRate: Double) throws -> SeparationResult {
        try left.withUnsafeBufferPointer { leftPtr in
            try right.withUnsafeBufferPointer { rightPtr in
                try separate(
                    left: leftPtr.baseAddress!,
                    right: rightPtr.baseAddress!,
                    frameCount: left.count,
                    sampleRate: sampleRate
                )
            }
        }
    }
}

enum SeparationModelError: Error, LocalizedError {
    case modelNotFound(String)
    case variantUnavailable(SeparationModelVariant)
    case compileFailed(String)
    case inferenceFailed(String)
    case unsupportedSampleRate(Double)

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let path):
            return "Separation model not found at \(path). Run Scripts/download-model.sh."
        case .variantUnavailable(let variant):
            if variant.hasCoreMLRelease {
                return "\(variant.displayName) is not installed. Run Scripts/download-model.sh \(variant.rawValue)."
            }
            return "\(variant.displayName) has no CoreML build yet — use Balanced, or watch for a future update."
        case .compileFailed(let message):
            return "Failed to compile separation model: \(message)"
        case .inferenceFailed(let message):
            return "Separation inference failed: \(message)"
        case .unsupportedSampleRate(let rate):
            return "Unsupported sample rate \(rate) Hz for separation model."
        }
    }
}

enum SeparationModelFactory {
    static let modelsDirectoryName = "MinusOne/Models"

    static let modelInstallHint = """
        Download a Neural model from the welcome screen, or run Scripts/download-model.sh.
        """

    static func isAvailable(_ variant: SeparationModelVariant) -> Bool {
        !modelSearchPaths(for: variant).isEmpty
    }

    static var isAnyAvailable: Bool {
        SeparationModelVariant.allCases.contains { isAvailable($0) }
    }

    static func loadModel(variant: SeparationModelVariant, captureSampleRate: Double = 48_000) throws -> AudioSeparationModel {
        guard isAvailable(variant) else {
            if !variant.hasCoreMLRelease {
                throw SeparationModelError.variantUnavailable(variant)
            }
            throw SeparationModelError.modelNotFound(
                modelSearchPaths(for: variant).map(\.path).joined(separator: ", ")
            )
        }
        let model = try CoreMLSeparationModel(variant: variant, captureSampleRate: captureSampleRate)
        AppLogger.shared.info("Loaded CoreML separation model: \(model.name) (\(variant.rawValue))")
        return model
    }

    static func modelSearchPaths(for variant: SeparationModelVariant) -> [URL] {
        var paths: [URL] = []

        if let bundledCompiled = Bundle.main.url(
            forResource: variant.rawValue,
            withExtension: "mlmodelc"
        ) {
            paths.append(bundledCompiled)
        }
        if let bundledPackage = Bundle.main.url(
            forResource: variant.rawValue,
            withExtension: "mlpackage"
        ) {
            paths.append(bundledPackage)
        }

        if variant == .balanced {
            if let legacyCompiled = Bundle.main.url(
                forResource: "HTDemucs_CoreML",
                withExtension: "mlmodelc"
            ) {
                paths.append(legacyCompiled)
            }
            if let legacyPackage = Bundle.main.url(
                forResource: "HTDemucs_CoreML",
                withExtension: "mlpackage"
            ) {
                paths.append(legacyPackage)
            }
        }

        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return paths.filter { FileManager.default.fileExists(atPath: $0.path) }
        }

        let modelsDir = appSupport.appendingPathComponent(modelsDirectoryName, isDirectory: true)
        paths.append(modelsDir.appendingPathComponent(variant.compiledFileName, isDirectory: true))
        paths.append(modelsDir.appendingPathComponent(variant.packageFileName, isDirectory: true))

        if variant == .balanced {
            paths.append(
                modelsDir.appendingPathComponent(SeparationModelVariant.legacyBalancedCompiled, isDirectory: true)
            )
            paths.append(
                modelsDir.appendingPathComponent(SeparationModelVariant.legacyBalancedPackage, isDirectory: true)
            )
        }

        return paths.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func compiledModelURL(adjacentTo packageURL: URL, variant: SeparationModelVariant) -> URL {
        packageURL.deletingLastPathComponent().appendingPathComponent(variant.compiledFileName, isDirectory: true)
    }
}
