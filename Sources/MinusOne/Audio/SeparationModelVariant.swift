import Foundation

/// Demucs v4 weight variants for Neural mode. Each maps to a distinct HTDemucs checkpoint.
enum SeparationModelVariant: String, CaseIterable, Codable, Identifiable {
    /// Default v4 — fast 4-stem separation, good balance of speed and quality.
    case balanced = "htdemucs"
    /// Fine-tuned 4-stem bag — best vocal separation, ~4× slower inference.
    case fineTuned = "htdemucs_ft"
    /// Experimental 6-stem — adds isolated guitar and piano stems.
    case sixStem = "htdemucs_6s"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .balanced:
            return "Balanced"
        case .fineTuned:
            return "Fine-Tuned"
        case .sixStem:
            return "Six-Stem"
        }
    }

    var detailText: String {
        switch self {
        case .balanced:
            return "Default Demucs v4, 4 stems — fast, ~8–9 dB vocals SDR"
        case .fineTuned:
            return "Fine-tuned 4-stem bag — best quality, ~4× slower"
        case .sixStem:
            return "6 stems (+ guitar, piano) — experimental, lower per-stem quality"
        }
    }

    var stemCount: Int {
        switch self {
        case .balanced, .fineTuned:
            return 4
        case .sixStem:
            return 6
        }
    }

    /// Whether a CoreML `.mlpackage` / `.mlmodelc` build exists for this variant today.
    var hasCoreMLRelease: Bool {
        switch self {
        case .balanced:
            return true
        case .fineTuned, .sixStem:
            return false
        }
    }

    /// Hugging Face repo that hosts the CoreML package (nil if not downloadable yet).
    var huggingFaceRepoID: String? {
        switch self {
        case .balanced:
            return "dexxdean/htdemucs-coreml"
        case .fineTuned, .sixStem:
            return nil
        }
    }

    /// Folder name inside the HF repo to download (installed on disk as `packageFileName`).
    var huggingFaceSourcePackageName: String? {
        switch self {
        case .balanced:
            return "HTDemucs_CoreML_FP16.mlpackage"
        case .fineTuned, .sixStem:
            return nil
        }
    }

    var approximateDownloadSizeText: String {
        switch self {
        case .balanced:
            return "~200 MB"
        case .fineTuned, .sixStem:
            return "Coming soon"
        }
    }

    /// Short origin blurb for the onboarding info popover.
    var sourceAttributionText: String {
        switch self {
        case .balanced:
            return """
            Based on Meta’s Demucs v4 (htdemucs) — open-source music source separation.

            The CoreML package MinusOne downloads is published on Hugging Face by dexxdean (dexxdean/htdemucs-coreml), converted for Apple Silicon.
            """
        case .fineTuned:
            return """
            Based on Meta’s Demucs v4 fine-tuned bag (htdemucs_ft) — same 4 stems as Balanced, trained for higher quality at slower speed.

            A CoreML build is not available to download in MinusOne yet.
            """
        case .sixStem:
            return """
            Based on Meta’s Demucs 6-stem model (htdemucs_6s) — adds guitar and piano stems.

            A CoreML build is not available to download in MinusOne yet.
            """
        }
    }

    var sourcePageURL: URL? {
        switch self {
        case .balanced:
            return URL(string: "https://huggingface.co/dexxdean/htdemucs-coreml")
        case .fineTuned, .sixStem:
            return URL(string: "https://github.com/facebookresearch/demucs")
        }
    }

    var onboardingChoiceTitle: String {
        switch self {
        case .balanced:
            return "\(displayName) (\(approximateDownloadSizeText))"
        case .fineTuned, .sixStem:
            return "\(displayName) — \(approximateDownloadSizeText)"
        }
    }

    /// Primary on-disk package name (Demucs checkpoint id).
    var packageFileName: String {
        "\(rawValue).mlpackage"
    }

    var compiledFileName: String {
        "\(rawValue).mlmodelc"
    }

    var demucsIdentifier: String { rawValue }

    /// Legacy balanced install from early MinusOne builds.
    static let legacyBalancedPackage = "HTDemucs_CoreML.mlpackage"
    static let legacyBalancedCompiled = "HTDemucs_CoreML.mlmodelc"

    /// Stem indices to sum for instrumental output (CoreML `sources` tensor, vocals excluded).
    var instrumentalStemIndices: [Int] {
        switch self {
        case .balanced, .fineTuned:
            // dexxdean CoreML order: vocals, drums, bass, other
            return [1, 2, 3]
        case .sixStem:
            // Demucs 6s order: drums, bass, other, vocals, guitar, piano
            return [0, 1, 2, 4, 5]
        }
    }

    static func fromPersisted(_ raw: String) -> SeparationModelVariant? {
        if let variant = SeparationModelVariant(rawValue: raw) {
            return variant
        }
        switch raw {
        case "HTDemucs_CoreML", "balanced":
            return .balanced
        default:
            return nil
        }
    }
}
