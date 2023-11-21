import Foundation
import os

public final class CVLog {
    @available(iOS 14, *)
    private static let os = Logger(
        subsystem: "com.cloudveil.CloudVeilMessenger",
        category: "CVLog"
    )

    @available(iOS 14, *)
    private static let tglogs = Logger(
        subsystem: "com.cloudveil.CloudVeilMessenger",
        category: "tglogs"
    )

    @available(iOS 14, *)
    private static let logQueue = DispatchQueue(
        label: "com.cloudveil.CloudVeilMessenger.log", qos: .utility
    )

    @available(iOS 14, *)
    private static var logFile: URL? = {
        var url = try? FileManager.default
            .url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        // iOS 16 or later:
        // return url?.appending(path: "cvlogs/current.log")
        url?.appendPathComponent("cvlogs", isDirectory: true)
        return url?.appendingPathComponent("current.log", isDirectory: false)
    }()

    @available(iOS 14, *)
    private static var logHandle: FileHandle?

    @available(iOS 14, *)
    private static var iso8601 = {
        var result = ISO8601DateFormatter()
        result.formatOptions = .withInternetDateTime
        result.timeZone = TimeZone.autoupdatingCurrent
        return result
    }()

    @available(iOS 14, *)
    private static let maxLogSize = 50 * 1024 * 1024

    public static func log(_ tag: String, _ what: String) {
        guard #available(iOS 14, *) else {
            return
        }
        #if targetEnvironment(simulator)
        Self.tglogs.info("[\(tag, privacy: .public)] \(what, privacy: .public)")
        #endif
        self.logQueue.async {
            guard let logFile = self.logFile else {
                Self.os.info("log message dropped: logFile is nil")
                return
            }
            let rvals = try? logFile.resourceValues(forKeys: [.fileSizeKey])
            if let logSize = rvals?.fileSize, logSize > Self.maxLogSize {
                Self.os.info("log size triggered log rotation: \(logSize) > \(Self.maxLogSize)")
                self.rotate()
            }
            if self.logHandle == nil {
                do {
                    Self.os.info("opening log file")
                    try FileManager.default.createDirectory(
                        at: logFile.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    do {
                        // APPLE'S APIS ARE GARBAGE!!!
                        try Data().write(to: logFile, options: [
                            .withoutOverwriting, .noFileProtection,
                        ])
                    } catch {}
                    self.logHandle = try FileHandle.init(forWritingTo: logFile)
                    try self.logHandle?.seekToEnd()
                } catch {
                    Self.os.error("opening log file failed: \(error, privacy: .public)")
                }
            }
            guard let logHandle = self.logHandle else {
                Self.os.info("log message dropped: logHandle is nil")
                return
            }
            // Date.formatted requires IOS 15
            let data = "[\(tag)] \(self.iso8601.string(from: Date())) \(what)\n".data(using: .utf8)
            guard let data = data else {
                Self.os.info("log message dropped: encoding failed")
                return
            }
            do {
                try logHandle.write(contentsOf: data)
            } catch {
                Self.os.error("writing log message failed: \(error, privacy: .public)")
                self.logHandle = nil
            }
        }
    }

    @available(iOS 14, *)
    public static func rotate() {
        Self.os.info("log rotation requested")
        self.logQueue.async {
            Self.os.info("log rotation begun")
            guard let logFile = self.logFile else {
                Self.os.info("log rotation canceled: logFile is nil")
                return
            }
            logHandle = nil
            let now = Int(Date().timeIntervalSince1970)
            let archiveName = "archive-\(now).log"
            guard let archiveFile = URL.init(string: archiveName, relativeTo: logFile) else {
                Self.os.info("log rotation canceled: archiveFile is nil")
                return
            }
            do {
                try FileManager.default.moveItem(at: logFile, to: archiveFile)
                Self.os.info("log rotated to \(archiveFile, privacy: .public)")
            } catch {
                Self.os.error("log rotation failed: \(error, privacy: .public)")
            }
        }
    }

    @available(iOS 14, *)
    public static func getArchives() -> [(URL, String)] {
        Self.os.info("archive list requested")
        guard let logFile = self.logFile else {
            Self.os.info("archive list empty: logFile is nil")
            return []
        }
        let logDir = logFile.deletingLastPathComponent()
        let logFiles: [URL]
        do {
            logFiles = try FileManager.default
                .contentsOfDirectory(at: logDir, includingPropertiesForKeys: nil)
        } catch {
            Self.os.info("archive list failed: \(error, privacy: .public)")
            return []
        }
        return logFiles.compactMap { file in
            var name = file.lastPathComponent
            guard name.hasPrefix("archive-") else {
                return nil
            }
            guard name.hasSuffix(".log") else {
                return nil
            }
            name.removeFirst("archive-".count)
            name.removeLast(".log".count)
            return (file, name)
        }
    }
}
