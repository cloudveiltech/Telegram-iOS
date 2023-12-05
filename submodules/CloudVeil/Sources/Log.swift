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
    private static var logFile: URL? = { () -> URL? in
        guard let bundleId = Bundle.main.bundleIdentifier else { return nil }
        let appGroupRoot = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.\(bundleId)")
        let url = appGroupRoot?
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("CVLogs", isDirectory: true)
            .appendingPathComponent("current.log", isDirectory: false)
        return url
    }()

    @available(iOS 14, *)
    private static var iso8601 = {
        var result = ISO8601DateFormatter()
        result.formatOptions = .withInternetDateTime
        result.timeZone = TimeZone.autoupdatingCurrent
        return result
    }()

    @available(iOS 14, *)
    private static let maxLogSize = 50 * 1024 * 1024

    private static func coordWrite(
        _ file: URL, _ options: NSFileCoordinator.WritingOptions, _ write: (URL) throws -> Void
    ) throws {
        let fc = NSFileCoordinator(filePresenter: nil)
        var nserror: NSError? = nil
        var error1: Error? = nil
        fc.coordinate(
            writingItemAt: file,
            options: options,
            error: &nserror,
            byAccessor: { file in
                do {
                    try write(file)
                } catch {
                    error1 = error
                }
            }
        )
        if let error = error1 {
            throw error
        }
        if let error = nserror {
            throw error
        }
    }

    public static func log(_ tag: String, _ what: String) {
        guard #available(iOS 14, *) else {
            return
        }
        #if DEBUG
        Self.tglogs.log("CloudVeilMessenger: [\(tag, privacy: .public)] \(what, privacy: .public)")
        #endif
        #if CLOUDVEIL_SHIPLOGS
        guard let logFile = self.logFile else {
            Self.os.warning("log message dropped: logFile is nil")
            return
        }
        do {
            try self.coordWrite(logFile, [.forReplacing], { logFile in
                // rotate logs if necessary
                let rvals = try? logFile.resourceValues(forKeys: [.fileSizeKey])
                if let logSize = rvals?.fileSize, logSize > Self.maxLogSize {
                    self.doRotate(logFile)
                }

                // make log file
                do {
                    try FileManager.default.createDirectory(
                        at: logFile.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    // APPLE'S APIS ARE GARBAGE!!!
                    try Data().write(to: logFile, options: [
                        .withoutOverwriting, .noFileProtection,
                    ])
                } catch {
                }

                // write to log file
                let logHandle = try FileHandle.init(forWritingTo: logFile)
                try logHandle.seekToEnd()
                // Date.formatted requires IOS 15
                let data = """
                    [\(tag)] \(self.iso8601.string(from: Date())) \(what)\n
                    """.data(using: .utf8)
                guard let data = data else {
                    Self.os.error("writing log message failed: encoding as utf-8 failed")
                    return
                }
                try logHandle.write(contentsOf: data)
            })
        } catch {
            Self.os.error("writing log message failed: \(error)")
        }
        #endif
    }

    @available(iOS 14, *)
    private static func doRotate(_ logFile: URL) {
        let now = Int(Date().timeIntervalSince1970)
        let archiveName = "archive-\(now).log"
        guard let archiveFile = URL.init(string: archiveName, relativeTo: logFile) else {
            Self.os.info("log rotation canceled: archiveFile is nil")
            return
        }
        do {
            try FileManager.default.moveItem(at: logFile, to: archiveFile)
            Self.os.info("log rotated to \(archiveFile)")
        } catch {
            Self.os.error("log rotation failed: \(error)")
        }
    }

    @available(iOS 14, *)
    public static func rotate() {
        guard let logFile = self.logFile else {
            Self.os.info("log rotation canceled: logFile is nil")
            return
        }
        do {
            try self.coordWrite(logFile, [.forReplacing], self.doRotate)
        } catch {
            Self.os.error("log rotation failed: \(error)")
        }
    }

    @available(iOS 14, *)
    public static func deleteArchive(_ file: URL) {
        do {
            try self.coordWrite(file, [.forDeleting], { file in
                try FileManager.default.removeItem(at: file)
                Self.os.info("removed local copy of uploaded log: \(file)")
            })
        } catch {
            Self.os.error("removing local copy of uploaded log failed: \(error)")
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
