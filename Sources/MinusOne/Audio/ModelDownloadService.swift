import CoreML
import Foundation

/// Downloads Demucs CoreML packages from Hugging Face into Application Support and compiles them.
enum ModelDownloadService {
    enum DownloadError: Error, LocalizedError {
        case badResponse(URL, Int)
        case invalidTree
        case emptyPackage
        case compileFailed(String)

        var errorDescription: String? {
            switch self {
            case .badResponse(let url, let code):
                return "Download failed (\(code)) for \(url.lastPathComponent)."
            case .invalidTree:
                return "Could not list model files from Hugging Face."
            case .emptyPackage:
                return "Downloaded model package was empty."
            case .compileFailed(let message):
                return "Failed to compile model: \(message)"
            }
        }
    }

    private struct TreeEntry: Decodable {
        let type: String
        let path: String
        let size: Int?
    }

    private struct RemoteFile {
        let relativePath: String
        let size: Int
    }

    static func modelsDirectory() throws -> URL {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw DownloadError.invalidTree
        }
        let dir = appSupport.appendingPathComponent(
            SeparationModelFactory.modelsDirectoryName,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func stagingDirectory(for variant: SeparationModelVariant) throws -> URL {
        try modelsDirectory().appendingPathComponent(".\(variant.rawValue).download", isDirectory: true)
    }

    /// Removes an in-progress staging folder, if any.
    static func cleanupStaging(for variant: SeparationModelVariant) {
        guard let staging = try? stagingDirectory(for: variant),
              FileManager.default.fileExists(atPath: staging.path) else { return }
        try? FileManager.default.removeItem(at: staging)
    }

    /// Downloads (if needed) and compiles `variant`. Reports progress 0…1 on the main queue.
    static func install(
        _ variant: SeparationModelVariant,
        progress: @escaping @MainActor (Double, String) -> Void
    ) async throws {
        let repoID = variant.huggingFaceRepoID
        let sourcePackage = variant.huggingFaceSourcePackageName

        if SeparationModelFactory.isAvailable(variant) {
            await MainActor.run { progress(1, "Already installed") }
            return
        }

        let modelsDir = try modelsDirectory()
        let packageURL = modelsDir.appendingPathComponent(variant.packageFileName, isDirectory: true)
        let compiledURL = modelsDir.appendingPathComponent(variant.compiledFileName, isDirectory: true)

        if !FileManager.default.fileExists(atPath: packageURL.path) {
            await MainActor.run { progress(0.02, "Fetching file list…") }
            let remoteFiles = try await listPackageFiles(repoID: repoID, packageName: sourcePackage)
            guard !remoteFiles.isEmpty else { throw DownloadError.emptyPackage }

            let staging = try stagingDirectory(for: variant)
            if FileManager.default.fileExists(atPath: staging.path) {
                try FileManager.default.removeItem(at: staging)
            }
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)

            let totalBytes = max(remoteFiles.reduce(0) { $0 + max($1.size, 0) }, 1)
            var completedBytes = 0

            for (index, file) in remoteFiles.enumerated() {
                try Task.checkCancellation()
                let remote = try resolveURL(repoID: repoID, path: "\(sourcePackage)/\(file.relativePath)")
                let local = staging.appendingPathComponent(file.relativePath)
                try FileManager.default.createDirectory(
                    at: local.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )

                let fileLabel = file.relativePath.split(separator: "/").last.map(String.init) ?? file.relativePath
                let fileIndex = index + 1
                let fileCount = remoteFiles.count
                let expectedFileBytes = max(file.size, 1)

                try await downloadFile(from: remote, to: local) { written, expected in
                    let fileExpected = expected > 0 ? expected : Int64(expectedFileBytes)
                    let clampedWritten = min(written, fileExpected)
                    let overall = Double(completedBytes) + Double(clampedWritten)
                    let fraction = 0.05 + 0.80 * (overall / Double(totalBytes))
                    let receivedMB = Double(clampedWritten) / 1_048_576
                    let totalMB = Double(fileExpected) / 1_048_576
                    let message: String
                    if fileExpected > 1_048_576 {
                        message = String(
                            format: "Downloading %@ (%d/%d) — %.0f / %.0f MB",
                            fileLabel, fileIndex, fileCount, receivedMB, totalMB
                        )
                    } else {
                        message = "Downloading \(fileLabel) (\(fileIndex)/\(fileCount))…"
                    }
                    progress(min(fraction, 0.84), message)
                }

                completedBytes += expectedFileBytes
            }

            try Task.checkCancellation()
            if FileManager.default.fileExists(atPath: packageURL.path) {
                try FileManager.default.removeItem(at: packageURL)
            }
            try FileManager.default.moveItem(at: staging, to: packageURL)
        }

        try Task.checkCancellation()
        await MainActor.run { progress(0.88, "Compiling model (one-time, ~20 s)…") }
        do {
            let temporaryCompiled = try await Task.detached(priority: .userInitiated) {
                try Task.checkCancellation()
                return try MLModel.compileModel(at: packageURL)
            }.value
            try Task.checkCancellation()
            if FileManager.default.fileExists(atPath: compiledURL.path) {
                try FileManager.default.removeItem(at: compiledURL)
            }
            try FileManager.default.moveItem(at: temporaryCompiled, to: compiledURL)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw DownloadError.compileFailed(error.localizedDescription)
        }

        await MainActor.run { progress(1, "Ready") }
        AppLogger.shared.info("Installed separation model \(variant.rawValue) at \(compiledURL.path)")
    }

    private static func listPackageFiles(repoID: String, packageName: String) async throws -> [RemoteFile] {
        var files: [RemoteFile] = []
        try await collectFiles(
            repoID: repoID,
            path: packageName,
            pathPrefixToStrip: packageName + "/",
            into: &files
        )
        return files.sorted { $0.relativePath < $1.relativePath }
    }

    private static func collectFiles(
        repoID: String,
        path: String,
        pathPrefixToStrip: String,
        into files: inout [RemoteFile]
    ) async throws {
        try Task.checkCancellation()
        let encodedPath = path.split(separator: "/").map {
            $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0)
        }.joined(separator: "/")
        let api = URL(string: "https://huggingface.co/api/models/\(repoID)/tree/main/\(encodedPath)")!
        let (data, response) = try await URLSession.shared.data(from: api)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw DownloadError.badResponse(api, code)
        }
        let entries = try JSONDecoder().decode([TreeEntry].self, from: data)
        for entry in entries {
            if entry.type == "directory" {
                try await collectFiles(
                    repoID: repoID,
                    path: entry.path,
                    pathPrefixToStrip: pathPrefixToStrip,
                    into: &files
                )
            } else if entry.type == "file" {
                var relative = entry.path
                if relative.hasPrefix(pathPrefixToStrip) {
                    relative = String(relative.dropFirst(pathPrefixToStrip.count))
                }
                files.append(RemoteFile(relativePath: relative, size: entry.size ?? 0))
            }
        }
    }

    private static func resolveURL(repoID: String, path: String) throws -> URL {
        let encoded = path.split(separator: "/").map {
            $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0)
        }.joined(separator: "/")
        guard let url = URL(string: "https://huggingface.co/\(repoID)/resolve/main/\(encoded)?download=true") else {
            throw DownloadError.invalidTree
        }
        return url
    }

    private static func downloadFile(
        from remote: URL,
        to local: URL,
        onBytes: @escaping @MainActor (_ written: Int64, _ expected: Int64) -> Void
    ) async throws {
        try Task.checkCancellation()
        var request = URLRequest(url: remote)
        request.timeoutInterval = 600

        let delegate = DownloadProgressDelegate()
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                delegate.continuation = continuation
                delegate.onProgress = { written, expected in
                    Task { @MainActor in
                        onBytes(written, expected)
                    }
                }
                let task = session.downloadTask(with: request)
                delegate.task = task
                task.resume()
            }
        } onCancel: {
            delegate.task?.cancel()
        }

        guard let tempURL = delegate.finishedLocation else {
            throw DownloadError.invalidTree
        }
        if FileManager.default.fileExists(atPath: local.path) {
            try FileManager.default.removeItem(at: local)
        }
        try FileManager.default.moveItem(at: tempURL, to: local)
    }
}

private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    var continuation: CheckedContinuation<Void, Error>?
    var onProgress: ((Int64, Int64) -> Void)?
    weak var task: URLSessionDownloadTask?
    private(set) var finishedLocation: URL?
    private var lastReported: Int64 = 0

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        if totalBytesWritten - lastReported >= 512 * 1024 || totalBytesWritten == totalBytesExpectedToWrite {
            lastReported = totalBytesWritten
            onProgress?(totalBytesWritten, totalBytesExpectedToWrite)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("MinusOne-\(UUID().uuidString).download")
        do {
            try FileManager.default.copyItem(at: location, to: temp)
            finishedLocation = temp
        } catch {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                continuation?.resume(throwing: CancellationError())
            } else {
                continuation?.resume(throwing: error)
            }
            continuation = nil
            return
        }
        if let http = task.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            continuation?.resume(
                throwing: ModelDownloadService.DownloadError.badResponse(
                    task.originalRequest?.url ?? URL(fileURLWithPath: "/"),
                    http.statusCode
                )
            )
            continuation = nil
            return
        }
        continuation?.resume()
        continuation = nil
    }
}
