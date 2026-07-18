import Foundation
import os

final class AppLogger {
    static let shared = AppLogger()

    private let logger = Logger(subsystem: "com.minusone.app", category: "MinusOne")
    private let queue = DispatchQueue(label: "com.minusone.app.log-file")
    private let fileURL: URL

    private init() {
        let baseURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("MinusOne", isDirectory: true)
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        fileURL = baseURL.appendingPathComponent("MinusOne.log")
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        append("INFO", message)
    }

    func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
        append("WARN", message)
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        append("ERROR", message)
    }

    private func append(_ level: String, _ message: String) {
        queue.async { [fileURL] in
            let line = "\(Self.timestamp()) [\(level)] \(message)\n"
            guard let data = line.data(using: .utf8) else { return }

            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let handle = try? FileHandle(forWritingTo: fileURL) {
                    _ = try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: fileURL, options: .atomic)
            }
        }
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
