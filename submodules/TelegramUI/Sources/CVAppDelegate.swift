// CloudVeil added this entire file
import Foundation
import UIKit
import BackgroundTasks
import os

// for hexString
import TelegramCore

import Sentry
import CloudVeil
import CloudVeilSecurityManager

#if CLOUDVEIL_SHIPLOGS
fileprivate let CVM_SHIPLOGS = "com.cloudveil.CloudVeilMessenger.shiplogs"
#endif
fileprivate let CVM_UPLOAD = "com.cloudveil.CloudVeilMessenger.upload"

@objc(CVAppDelegate) class CVAppDelegate: AppDelegate {
    @available(iOS 14, *)
    private static let log = Logger(
        subsystem: "com.cloudveil.CloudVeilMessenger",
        category: "CVAppDelegate"
    )

    private static let logUploadInterval: TimeInterval = 4 * 60 * 60

    // We just need a dummy URLSession here. It will be set in the constructor.
    private var upload: URLSession = URLSession.shared

    override init (){
        let config = URLSessionConfiguration.background(withIdentifier: CVM_UPLOAD)
        config.networkServiceType = .background
        config.httpAdditionalHeaders = ["X-Log-Port-Project": "CloudVeilMessenger"]
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        if #available(iOS 13, *) {
            config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        } else {
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
        }
        config.isDiscretionary = true
        config.shouldUseExtendedBackgroundIdleMode = false
        if #available(iOS 13, *) {
            config.allowsConstrainedNetworkAccess = false
        } else {
            config.allowsCellularAccess = false
        }
        config.timeoutIntervalForResource = Self.logUploadInterval
        config.sessionSendsLaunchEvents = true
        super.init()
        // Yes, we are setting self.upload twice during initialization. The other options are worse.
        self.upload = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        CVLog.log("CVApp \(self.episodeId)", "CVAppDelegate()")
    }

    @available(iOS 14, *)
    private func scheduleLogUpload() {
        #if CLOUDVEIL_SHIPLOGS
        let when = Date(timeIntervalSinceNow: Self.logUploadInterval)
        let request = BGAppRefreshTaskRequest(identifier: CVM_SHIPLOGS)
        request.earliestBeginDate = when
        do {
            try BGTaskScheduler.shared.submit(request)
            Self.log.info("log upload scheduled for \(when, privacy: .public)")
        } catch {
            Self.log.error("log upload scheduling failed: \(error, privacy: .public)")
        }
        #endif
    }

    @available(iOS 14, *)
    private func startLogUpload(
        rotate: Bool = false,
        whenDone done: @escaping (_ succeeded: Bool) -> Void
    ) {
        #if CLOUDVEIL_SHIPLOGS
        Self.log.info("log upload requested")
        /* Disable log upload for now
        self.scheduleLogUpload()
        DispatchQueue.global(qos: .background).async {
            Self.log.info("log upload begun")
            guard let vfid = UIDevice.current.identifierForVendor?.uuidString else {
                Self.log.warning("log upload failed: VFID is nil")
                done(false)
                return
            }
            if rotate {
                Self.log.info("log upload triggered log rotation")
                CVLog.rotate()
            }
            let archives = CVLog.getArchives()
            if archives.count == 0 {
                Self.log.info("no logs to upload")
            }
            let logServerUrl = "ENTER_LOG_SERVER_URL_HERE"
            let url = URL(string: "")!
            for entry in archives {
                let (file, time) = entry
                var request = URLRequest(url: url)
                request.httpMethod = "PUT"
                request.setValue(vfid, forHTTPHeaderField: "X-Log-Port-VFID")
                request.setValue("unix \(time)", forHTTPHeaderField: "X-Log-Port-Time")
                request.setValue("cvlog", forHTTPHeaderField: "X-Log-Port-Source")
                request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
                let task = self.upload.uploadTask(with: request, fromFile: file)
                if let bmark = try? file.bookmarkData(options: .minimalBookmark) {
                    task.taskDescription = bmark.base64EncodedString()
                } else {
                    Self.log.warning("\(file, privacy: .public) could not be bookmarked in upload task")
                }
                task.resume()
            }
            Self.log.info("log upload tasks begun")
            */
            done(true)
        }
        #else
        done(true)
        #endif
    }

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOpts: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        CVLog.log("CVApp \(self.episodeId)", """
            application(didFinishLaunchingWithOptions:\(String(describing: launchOpts)))
            """)
        AppDelegate.shared = self
        SentrySDK.start { options in
            options.dsn = "https://18449652be1c40099b14b44e1b44904e@o1077369.ingest.sentry.io/6080242"
            options.debug = false // Helpful to see what's going on
        }
        CloudVeilSecurityController.shared.clearUserBlacklist()
        #if CLOUDVEIL_SHIPLOGS
        if #available(iOS 14, *) {
            Self.log.info("log upload background task registered")
            BGTaskScheduler.shared.register(forTaskWithIdentifier: CVM_SHIPLOGS, using: nil) { task in
                self.startLogUpload(rotate: true, whenDone: task.setTaskCompleted(success:))
            }
            self.startLogUpload(rotate: true, whenDone: { _ in })
        }
        #endif
        return super.application(application, didFinishLaunchingWithOptions: launchOpts)
    }

    private var uploadCompletionHandler: (() -> Void)?

    override func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        CVLog.log("CVApp \(self.episodeId)", """
            application(handleEventsForBackgroundURLSession:\(identifier))
            """)
        guard identifier == CVM_UPLOAD else {
            super.application(
                application, handleEventsForBackgroundURLSession: identifier,
                completionHandler: completionHandler
            )
            return
        }
        if #available(iOS 14, *) {
            Self.log.info("application(handleEventsForBackgroundURLSession:\"\(identifier, privacy: .public)\")")
        }
        uploadCompletionHandler = completionHandler
    }

    override func application(
        _ app: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken token: Data
    ) {
        CVLog.log("CVApp \(self.episodeId)", """
            application(didRegisterForRemoteNotificationsWithDeviceToken:\(hexString(token)))
            """)
        super.application(app, didRegisterForRemoteNotificationsWithDeviceToken: token)
    }

    override func application(
        _ app: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        CVLog.log("CVApp \(self.episodeId)", """
            application(didFailToRegisterForRemoteNotificationsWithError:\(error))
            """)
        super.application(app, didFailToRegisterForRemoteNotificationsWithError: error)
    }

    @available(iOS 14, *)
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        CVLog.log("CVApp \(self.episodeId)", """
            urlSessionDidFinishEvents(forBackgroundURLSession:\
            \(String(describing: session.configuration.identifier)))
            """)
        guard session.configuration.identifier == upload.configuration.identifier else {
            //super.urlSessionDidFinishEvents(forBackgroundURLSession: session)
            return
        }
        Self.log.info("urlSessionDidFinishEvents(forBackgroundURLSession:)")
        DispatchQueue.main.async {
            guard let appDelegate = UIApplication.shared.delegate as? CVAppDelegate else {
                return
            }
            guard let uploadCompletionHandler = appDelegate.uploadCompletionHandler else {
                return
            }
            uploadCompletionHandler()
        }
    }

    override func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        CVLog.log("CVApp \(self.episodeId)", """
            urlSession(session:\(String(describing: session.configuration.identifier)),\
            task:\(task.taskIdentifier),\
            didCompleteWithError:\(String(describing: error)))
            """)
        guard session.configuration.identifier == upload.configuration.identifier else {
            super.urlSession(session, task: task, didCompleteWithError: error)
            return
        }
        guard #available(iOS 14, *) else {
            return
        }
        Self.log.info("urlSession(didCompleteWithError:\(error, privacy: .public))")
        if error != nil {
            return
        }
        guard (task.response as? HTTPURLResponse)?.statusCode == 201 else {
            Self.log.info("not removing uploaded file: upload response not 201")
            return
        }
        guard let desc = task.taskDescription else {
            Self.log.warning("not removing uploaded file: bookmark not saved")
            return
        }
        guard let bookmark = Data(base64Encoded: desc, options: .ignoreUnknownCharacters) else {
            Self.log.warning("not removing uploaded file: bookmark data invalid")
            return
        }
        var idontcare = false
        do {
            let file = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &idontcare)
            CVLog.deleteArchive(file)
        } catch {
            Self.log.error("removing local copy of uploaded log failed: \(error)")
        }
    }
}
