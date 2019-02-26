import UIKit
import SwiftSignalKit
import Display
import TelegramCore
import TelegramUI
import UserNotifications
import Intents
import HockeySDK
import Postbox
import PushKit
import AsyncDisplayKit
import CloudKit
import CloudVeilSecurityManager

private let handleVoipNotifications = false

private func encodeText(_ string: String, _ key: Int) -> String {
    var result = ""
    for c in string.unicodeScalars {
        result.append(Character(UnicodeScalar(UInt32(Int(c.value) + key))!))
    }
    return result
}

private let statusBarRootViewClass: AnyClass = NSClassFromString("UIStatusBar")!
private let cutoutStatusBarForegroundClass: AnyClass? = NSClassFromString("_UIStatusBar")
private let keyboardViewClass: AnyClass? = NSClassFromString(encodeText("VJJoqvuTfuIptuWjfx", -1))!
private let keyboardViewContainerClass: AnyClass? = NSClassFromString(encodeText("VJJoqvuTfuDpoubjofsWjfx", -1))!

private let keyboardWindowClass: AnyClass? = {
    if #available(iOS 9.0, *) {
        return NSClassFromString(encodeText("VJSfnpufLfzcpbseXjoepx", -1))
    } else {
        return NSClassFromString(encodeText("VJUfyuFggfdutXjoepx", -1))
    }
}()

private class ApplicationStatusBarHost: StatusBarHost {
    private let application = UIApplication.shared
    
    var statusBarFrame: CGRect {
        return self.application.statusBarFrame
    }
    var statusBarStyle: UIStatusBarStyle {
        get {
            return self.application.statusBarStyle
        } set(value) {
            self.application.setStatusBarStyle(value, animated: false)
        }
    }
    var statusBarWindow: UIView? {
        return self.application.value(forKey: "statusBarWindow") as? UIView
    }
    
    var statusBarView: UIView? {
        guard let containerView = self.statusBarWindow?.subviews.first else {
            return nil
        }
        
        if containerView.isKind(of: statusBarRootViewClass) {
            return containerView
        }
        
        for subview in containerView.subviews {
            if let cutoutStatusBarForegroundClass = cutoutStatusBarForegroundClass, subview.isKind(of: cutoutStatusBarForegroundClass) {
                return subview
            }
        }
        return nil
    }
    
    var keyboardWindow: UIWindow? {
        guard let keyboardWindowClass = keyboardWindowClass else {
            return nil
        }
        
        for window in UIApplication.shared.windows {
            if window.isKind(of: keyboardWindowClass) {
                return window
            }
        }
        return nil
    }
    
    var keyboardView: UIView? {
        guard let keyboardWindow = self.keyboardWindow, let keyboardViewContainerClass = keyboardViewContainerClass, let keyboardViewClass = keyboardViewClass else {
            return nil
        }
        
        for view in keyboardWindow.subviews {
            if view.isKind(of: keyboardViewContainerClass) {
                for subview in view.subviews {
                    if subview.isKind(of: keyboardViewClass) {
                        return subview
                    }
                }
            }
        }
        return nil
    }
    
    var handleVolumeControl: Signal<Bool, NoError> {
        return MediaManager.globalAudioSession.isPlaybackActive()
    }
}

private func legacyDocumentsPath() -> String {
    return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/legacy"
}

protocol SupportedStartCallIntent {
    @available(iOS 10.0, *)
    var contacts: [INPerson]? { get }
}

@available(iOS 10.0, *)
extension INStartAudioCallIntent: SupportedStartCallIntent {}

private enum QueuedWakeup: Int32 {
    case call
    case backgroundLocation
}

@objc(AppDelegate) class AppDelegate: UIResponder, UIApplicationDelegate, PKPushRegistryDelegate, BITHockeyManagerDelegate, UNUserNotificationCenterDelegate, UIAlertViewDelegate {
    @objc var window: UIWindow?
    var nativeWindow: (UIWindow & WindowHost)?
    var mainWindow: Window1!
    private var dataImportSplash: LegacyDataImportSplash?
    
    let episodeId = arc4random()
    
    private let isInForegroundPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    private var isInForegroundValue = false
    private let isActivePromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    private var isActiveValue = false
    let hasActiveAudioSession = Promise<Bool>(false)
    
    private let accountManagerPromise = Promise<AccountManager>()
    private let watchCommunicationManagerPromise = Promise<WatchCommunicationManager?>()
    
    private var contextValue: ApplicationContext?
    private let context = Promise<ApplicationContext?>()
    private let contextDisposable = MetaDisposable()
    
    private let openChatWhenReadyDisposable = MetaDisposable()
    private let openUrlWhenReadyDisposable = MetaDisposable()
    
    private let badgeDisposable = MetaDisposable()
    private let quickActionsDisposable = MetaDisposable()
    
    private var pushRegistry: PKPushRegistry?
    
    private let notificationAuthorizationDisposable = MetaDisposable()
    
    private var replyFromNotificationsDisposables = DisposableSet()
    
    private var replyFromNotificationsTokensValue = Set<Int32>() {
        didSet {
            assert(Queue.mainQueue().isCurrent())
            self.replyFromNotificationsTokensPromise.set(.single(self.replyFromNotificationsTokensValue))
        }
    }
    private let replyFromNotificationsTokensPromise = Promise<Set<Int32>>(Set())
    private var nextToken: Int32 = 0
    private func takeNextToken() -> Int32 {
        let value = self.nextToken
        self.nextToken = value + 1
        return value
    }
    private func addReplyFromNotificationsToken() -> Int32 {
        let token = self.takeNextToken()
        var value = self.replyFromNotificationsTokensValue
        value.insert(token)
        self.replyFromNotificationsTokensValue = value
        return token
    }
    private func removeReplyFromNotificationsToken(_ token: Int32) {
        var value = self.replyFromNotificationsTokensValue
        value.remove(token)
        self.replyFromNotificationsTokensValue = value
    }
    
    private var _notificationTokenPromise: Promise<Data>?
    private let voipTokenPromise = Promise<Data>()
    
    private var notificationTokenPromise: Promise<Data> {
        if let current = self._notificationTokenPromise {
            return current
        } else {
            let promise = Promise<Data>()
            self._notificationTokenPromise = promise
            
            return promise
        }
    }
    
    private var queuedNotifications: [PKPushPayload] = []
    private var queuedNotificationRequests: [(String, String, String?, NotificationManagedNotificationRequestId)] = []
    private var queuedMutePolling = false
    private var queuedAnnouncements: [String] = []
    private var queuedWakeups = Set<QueuedWakeup>()
    private var clearNotificationsManager: ClearNotificationsManager?
    
    private let idleTimerExtensionSubscribers = Bag<Void>()
    
    private var alertActions: (primary: (() -> Void)?, other: (() -> Void)?)?
    
    func alertView(_ alertView: UIAlertView, clickedButtonAt buttonIndex: Int) {
        if buttonIndex == alertView.firstOtherButtonIndex {
            self.alertActions?.other?()
        } else {
            self.alertActions?.primary?()
        }
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]? = nil) -> Bool {
        let statusBarHost = ApplicationStatusBarHost()
        let (window, hostView) = nativeWindowHostView()
        self.mainWindow = Window1(hostView: hostView, statusBarHost: statusBarHost)
        window.backgroundColor = UIColor.white
        self.window = window
        self.nativeWindow = window
        
        self.clearNotificationsManager = ClearNotificationsManager(getNotificationIds: { completion in
            if #available(iOS 10.0, *) {
                UNUserNotificationCenter.current().getDeliveredNotifications(completionHandler: { notifications in
                    var result: [(String, NotificationManagedNotificationRequestId)] = []
                    for notification in notifications {
                        if let requestId = NotificationManagedNotificationRequestId(string: notification.request.identifier) {
                            result.append((notification.request.identifier, requestId))
                        } else {
                            let payload = notification.request.content.userInfo
                            var notificationRequestId: NotificationManagedNotificationRequestId?
                            
                            var peerId: PeerId?
                            if let fromId = payload["from_id"] {
                                let fromIdValue = fromId as! NSString
                                peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: Int32(fromIdValue.intValue))
                            } else if let fromId = payload["chat_id"] {
                                let fromIdValue = fromId as! NSString
                                peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: Int32(fromIdValue.intValue))
                            } else if let fromId = payload["channel_id"] {
                                let fromIdValue = fromId as! NSString
                                peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: Int32(fromIdValue.intValue))
                            }
                            
                            if let msgId = payload["msg_id"] {
                                let msgIdValue = msgId as! NSString
                                if let peerId = peerId {
                                    notificationRequestId = .messageId(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(msgIdValue.intValue)))
                                }
                            }
                            
                            if let notificationRequestId = notificationRequestId {
                                result.append((notification.request.identifier, notificationRequestId))
                            }
                        }
                    }
                    completion.f(result)
                })
            } else {
                var result: [(String, NotificationManagedNotificationRequestId)] = []
                if let notifications = UIApplication.shared.scheduledLocalNotifications {
                    for notification in notifications {
                        if let userInfo = notification.userInfo, let id = userInfo["id"] as? String {
                            if let requestId = NotificationManagedNotificationRequestId(string: id) {
                                result.append((id, requestId))
                            }
                        }
                    }
                }
                completion.f(result)
            }
        }, removeNotificationIds: { ids in
            if #available(iOS 10.0, *) {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
            } else {
                if let notifications = UIApplication.shared.scheduledLocalNotifications {
                    for notification in notifications {
                        if let userInfo = notification.userInfo, let id = userInfo["id"] as? String {
                            if ids.contains(id) {
                                UIApplication.shared.cancelLocalNotification(notification)
                            }
                        }
                    }
                }
            }
        }, getPendingNotificationIds: { completion in
            if #available(iOS 10.0, *) {
                UNUserNotificationCenter.current().getPendingNotificationRequests(completionHandler: { requests in
                    var result: [(String, NotificationManagedNotificationRequestId)] = []
                    for request in requests {
                        if let requestId = NotificationManagedNotificationRequestId(string: request.identifier) {
                            result.append((request.identifier, requestId))
                        }
                    }
                    completion.f(result)
                })
            } else {
                var result: [(String, NotificationManagedNotificationRequestId)] = []
                if let notifications = UIApplication.shared.scheduledLocalNotifications {
                    for notification in notifications {
                        if let userInfo = notification.userInfo, let id = userInfo["id"] as? String {
                            if let requestId = NotificationManagedNotificationRequestId(string: id) {
                                result.append((id, requestId))
                            }
                        }
                    }
                }
                completion.f(result)
            }
        }, removePendingNotificationIds: { ids in
            if #available(iOS 10.0, *) {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
            } else {
                if let notifications = UIApplication.shared.scheduledLocalNotifications {
                    for notification in notifications {
                        if let userInfo = notification.userInfo, let id = userInfo["id"] as? String {
                            if ids.contains(id) {
                                UIApplication.shared.cancelLocalNotification(notification)
                            }
                        }
                    }
                }
            }
        })
        
        #if DEBUG
        for argument in ProcessInfo.processInfo.arguments {
            if argument.hasPrefix("snapshot:") {
                GlobalExperimentalSettings.isAppStoreBuild = true
                
                guard let dataPath = ProcessInfo.processInfo.environment["snapshot-data-path"] else {
                    preconditionFailure()
                }
                setupSnapshotData(dataPath)
                switch String(argument[argument.index(argument.startIndex, offsetBy: "snapshot:".count)...]) {
                    case "chat-list":
                        snapshotChatList(application: application, mainWindow: self.window!, window: self.mainWindow, statusBarHost: statusBarHost)
                    case "secret-chat":
                        snapshotSecretChat(application: application, mainWindow: self.window!, window: self.mainWindow, statusBarHost: statusBarHost)
                    case "settings":
                        snapshotSettings(application: application, mainWindow: self.window!, window: self.mainWindow, statusBarHost: statusBarHost)
                    case "appearance-settings":
                        snapshotAppearanceSettings(application: application, mainWindow: self.window!, window: self.mainWindow, statusBarHost: statusBarHost)
                    default:
                        break
                }
                self.window?.makeKeyAndVisible()
                return true
            }
        }
        #endif
        
        let apiId: Int32 = BuildConfig.shared().apiId
        let languagesCategory = "ios"
        
        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
        
        let networkArguments = NetworkInitializationArguments(apiId: apiId, languagesCategory: languagesCategory, appVersion: appVersion, voipMaxLayer: PresentationCallManager.voipMaxLayer)
        
        let appGroupName = "group.\(Bundle.main.bundleIdentifier!)"
        let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
        
        guard let appGroupUrl = maybeAppGroupUrl else {
            UIAlertView(title: nil, message: "Error 2", delegate: nil, cancelButtonTitle: "OK").show()
            return true
        }
        
        var isDebugConfiguration = false
        #if DEBUG
        isDebugConfiguration = true
        #endif
        
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            isDebugConfiguration = true
        }
        
        if isDebugConfiguration || BuildConfig.shared().isInternalBuild {
            LoggingSettings.defaultSettings = LoggingSettings(logToFile: true, logToConsole: false, redactSensitiveData: true)
        } else {
            LoggingSettings.defaultSettings = LoggingSettings(logToFile: false, logToConsole: false, redactSensitiveData: true)
        }
        
        let rootPath = rootPathForBasePath(appGroupUrl.path)
        performAppGroupUpgrades(appGroupPath: appGroupUrl.path, rootPath: rootPath)
        
        TempBox.initializeShared(basePath: rootPath, processType: "app", launchSpecificId: arc4random64())
        
        let logsPath = rootPath + "/logs"
        let _ = try? FileManager.default.createDirectory(atPath: logsPath, withIntermediateDirectories: true, attributes: nil)
        Logger.setSharedLogger(Logger(basePath: logsPath))
        
        if let contents = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: rootPath + "/accounts-metadata"), includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants]) {
            for url in contents {
                Logger.shared.log("App \(self.episodeId)", "metadata: \(url.path)")
            }
        }
        
        if let contents = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: rootPath), includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants]) {
            for url in contents {
                Logger.shared.log("App \(self.episodeId)", "root: \(url.path)")
                if url.lastPathComponent.hasPrefix("account-") {
                    if let subcontents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants]) {
                        for suburl in subcontents {
                            Logger.shared.log("App \(self.episodeId)", "account \(url.lastPathComponent): \(suburl.path)")
                        }
                    }
                }
            }
        }
        
        ASDisableLogging()
        
        initializeLegacyComponents(application: application, currentSizeClassGetter: {
            return UIUserInterfaceSizeClass.compact
        }, currentHorizontalClassGetter: {
            return UIUserInterfaceSizeClass.compact
        }, documentsPath: legacyDocumentsPath(), currentApplicationBounds: {
            return UIScreen.main.bounds
        }, canOpenUrl: { url in
            return UIApplication.shared.canOpenURL(url)
        }, openUrl: { url in
            UIApplication.shared.openURL(url)
        })
        
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
        }
        
        telegramUIDeclareEncodables()
        
        GlobalExperimentalSettings.isAppStoreBuild = BuildConfig.shared().isAppStoreBuild
        
        GlobalExperimentalSettings.enableFeed = false
        #if DEBUG
            //GlobalExperimentalSettings.enableFeed = true
            #if targetEnvironment(simulator)
                //GlobalTelegramCoreConfiguration.readMessages = false
            #endif
        #endif
        
        self.window?.makeKeyAndVisible()
        
        self.hasActiveAudioSession.set(MediaManager.globalAudioSession.isActive())
        
        initializeAccountManagement()
        self.accountManagerPromise.set(accountManager(basePath: rootPath + "/accounts-metadata")
        |> mapToSignal { accountManager -> Signal<(AccountManager, LoggingSettings), NoError> in
            return accountManager.transaction { transaction -> (AccountManager, LoggingSettings) in
                return (accountManager, transaction.getSharedData(SharedDataKeys.loggingSettings) as? LoggingSettings ?? LoggingSettings.defaultSettings)
            }
        }
        |> mapToSignal { accountManager, loggingSettings -> Signal<AccountManager, NoError> in
            Logger.shared.logToFile = loggingSettings.logToFile
            Logger.shared.logToConsole = loggingSettings.logToConsole
            Logger.shared.redactSensitiveData = loggingSettings.redactSensitiveData
            
            return importedLegacyAccount(basePath: appGroupUrl.path, accountManager: accountManager, present: { controller in
                self.window?.rootViewController?.present(controller, animated: true, completion: nil)
            })
            |> `catch` { _ -> Signal<ImportedLegacyAccountEvent, NoError> in
                return Signal { subscriber in
                    let alertView = UIAlertView(title: "", message: "An error occured while trying to upgrade application data. Would you like to logout?", delegate: self, cancelButtonTitle: "No", otherButtonTitles: "Yes")
                    self.alertActions = (primary: {
                        let statusPath = appGroupUrl.path + "/Documents/importcompleted"
                        let _ = try? FileManager.default.createDirectory(atPath: appGroupUrl.path + "/Documents", withIntermediateDirectories: true, attributes: nil)
                        let _ = try? Data().write(to: URL(fileURLWithPath: statusPath))
                        subscriber.putNext(.result(nil))
                        subscriber.putCompletion()
                    }, other: {
                        exit(0)
                    })
                    alertView.show()
                    
                    return EmptyDisposable
                } |> runOn(Queue.mainQueue())
            }
            |> mapToSignal { event -> Signal<AccountManager, NoError> in
                switch event {
                    case let .progress(type, value):
                        Queue.mainQueue().async {
                            if self.dataImportSplash == nil {
                                self.dataImportSplash = LegacyDataImportSplash()
                                self.dataImportSplash?.serviceAction = {
                                    self.debugPressed()
                                }
                                self.mainWindow.coveringView = self.dataImportSplash
                            }
                            self.dataImportSplash?.progress = (type, value)
                        }
                        return .complete()
                    case let .result(temporaryId):
                        Queue.mainQueue().async {
                            if let _ = self.dataImportSplash {
                                self.dataImportSplash = nil
                                self.mainWindow.coveringView = nil
                            }
                        }
                        if let temporaryId = temporaryId {
                            Queue.mainQueue().after(1.0, {
                                let statusPath = appGroupUrl.path + "/Documents/importcompleted"
                                let _ = try? FileManager.default.createDirectory(atPath: appGroupUrl.path + "/Documents", withIntermediateDirectories: true, attributes: nil)
                                let _ = try? Data().write(to: URL(fileURLWithPath: statusPath))
                            })
                            return accountManager.transaction { transaction -> AccountManager in
                                transaction.setCurrentId(temporaryId)
                                transaction.updateRecord(temporaryId, { record in
                                    if let record = record {
                                        return AccountRecord(id: record.id, attributes: record.attributes, temporarySessionId: nil)
                                    }
                                    return record
                                })
                                return accountManager
                            }
                        }
                        return .single(accountManager)
                }
            }
        })
        
        let _ = (self.accountManagerPromise.get()
        |> mapToSignal { manager in
            return managedCleanupAccounts(networkArguments: networkArguments, accountManager: manager, rootPath: rootPath, auxiliaryMethods: telegramAccountAuxiliaryMethods)
        }).start()
        
        let applicationBindings = TelegramApplicationBindings(isMainApp: true, containerPath: appGroupUrl.path, appSpecificScheme: BuildConfig.shared().appSpecificUrlScheme, openUrl: { url in
            var parsedUrl = URL(string: url)
            if let parsed = parsedUrl {
                if parsed.scheme == nil || parsed.scheme!.isEmpty {
                    parsedUrl = URL(string: "https://\(url)")
                }
                if parsed.scheme == "tg" {
                    return
                }
            }
            
            if let parsedUrl = parsedUrl {
                UIApplication.shared.openURL(parsedUrl)
            } else if let escapedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let parsedUrl = URL(string: escapedUrl) {
                UIApplication.shared.openURL(parsedUrl)
            }
        }, openUniversalUrl: { url, completion in
            if #available(iOS 10.0, *) {
                var parsedUrl = URL(string: url)
                if let parsed = parsedUrl {
                    if parsed.scheme == nil || parsed.scheme!.isEmpty {
                        parsedUrl = URL(string: "https://\(url)")
                    }
                }
                
                if let parsedUrl = parsedUrl {
                    return UIApplication.shared.open(parsedUrl, options: [UIApplicationOpenURLOptionUniversalLinksOnly: true as NSNumber], completionHandler: { value in
                        completion.completion(value)
                    })
                } else if let escapedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let parsedUrl = URL(string: escapedUrl) {
                    return UIApplication.shared.open(parsedUrl, options: [UIApplicationOpenURLOptionUniversalLinksOnly: true as NSNumber], completionHandler: { value in
                        completion.completion(value)
                    })
                } else {
                    completion.completion(false)
                }
            } else {
                completion.completion(false)
            }
        }, canOpenUrl: { url in
            var parsedUrl = URL(string: url)
            if let parsed = parsedUrl {
                if parsed.scheme == nil || parsed.scheme!.isEmpty {
                    parsedUrl = URL(string: "https://\(url)")
                }
            }
            if let parsedUrl = parsedUrl {
                return UIApplication.shared.canOpenURL(parsedUrl)
            } else if let escapedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let parsedUrl = URL(string: escapedUrl) {
                return UIApplication.shared.canOpenURL(parsedUrl)
            } else {
                return false
            }
        }, getTopWindow: {
            for window in application.windows.reversed() {
                if window === self.window || window === statusBarHost.keyboardWindow {
                    return window
                }
            }
            return application.windows.last
        }, displayNotification: { text in
        }, applicationInForeground: self.isInForegroundPromise.get(),
           applicationIsActive: self.isActivePromise.get(),
           clearMessageNotifications: { ids in
            for id in ids {
                self.clearNotificationsManager?.append(id)
            }
        }, pushIdleTimerExtension: {
            let disposable = MetaDisposable()
            Queue.mainQueue().async {
                let wasEmpty = self.idleTimerExtensionSubscribers.isEmpty
                let index = self.idleTimerExtensionSubscribers.add(Void())
                
                if wasEmpty {
                    application.isIdleTimerDisabled = true
                }
                
                disposable.set(ActionDisposable {
                    Queue.mainQueue().async {
                        self.idleTimerExtensionSubscribers.remove(index)
                        if self.idleTimerExtensionSubscribers.isEmpty {
                            application.isIdleTimerDisabled = false
                        }
                    }
                })
            }
            
            return disposable
        }, openSettings: {
            if let url = URL(string: UIApplicationOpenSettingsURLString) {
                UIApplication.shared.openURL(url)
            }
        }, openAppStorePage: {
            let appStoreId = BuildConfig.shared().appStoreId
            if let url = URL(string: "itms-apps://itunes.apple.com/app/id\(appStoreId)") {
                UIApplication.shared.openURL(url)
            }
        }, registerForNotifications: { completion in
            let _ = (self.currentAuthorizedContext()
            |> take(1)
            |> deliverOnMainQueue).start(next: { context in
                if let context = context {
                    self.registerForNotifications(account: context.account, authorize: true, completion: completion)
                }
            })
        }, requestSiriAuthorization: { completion in
            if #available(iOS 10, *) {
                INPreferences.requestSiriAuthorization { status in
                    if case .authorized = status {
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
            } else {
                completion(false)
            }
        }, siriAuthorization: {
            if #available(iOS 10, *) {
                switch INPreferences.siriAuthorizationStatus() {
                    case .authorized:
                        return .allowed
                    case .denied, .restricted:
                        return .denied
                    case .notDetermined:
                        return .notDetermined
                }
            } else {
                return .denied
            }
        }, getWindowHost: {
            return self.nativeWindow
        }, presentNativeController: { controller in
            self.window?.rootViewController?.present(controller, animated: true, completion: nil)
        }, dismissNativeController: {
            self.window?.rootViewController?.dismiss(animated: true, completion: nil)
        })
        
        let watchManagerArgumentsPromise = Promise<WatchManagerArguments?>()
            
        self.context.set(self.accountManagerPromise.get()
        |> deliverOnMainQueue
        |> mapToSignal { accountManager -> Signal<ApplicationContext?, NoError> in
            let replyFromNotificationsActive = self.replyFromNotificationsTokensPromise.get()
            |> map {
                !$0.isEmpty
            }
            |> distinctUntilChanged
            return applicationContext(networkArguments: networkArguments, applicationBindings: applicationBindings, replyFromNotificationsActive: replyFromNotificationsActive, backgroundAudioActive: self.hasActiveAudioSession.get() |> distinctUntilChanged, watchManagerArguments: watchManagerArgumentsPromise.get(), accountManager: accountManager, rootPath: rootPath, legacyBasePath: appGroupUrl.path, mainWindow: self.mainWindow, reinitializedNotificationSettings: {
                let _ = (self.context.get()
                |> take(1)
                |> deliverOnMainQueue).start(next: { value in
                    if let value = value, case let .authorized(context) = value {
                        self.registerForNotifications(account: context.account, authorize: false)
                    }
                })
            })
        })
        
        self.contextDisposable.set(self.context.get().start(next: { context in
            assert(Queue.mainQueue().isCurrent())
            var network: Network?
            if let context = context {
                switch context {
                    case let .unauthorized(unauthorized):
                        network = unauthorized.account.network
                    case let .authorized(authorized):
                        network = authorized.account.network
                    default:
                        break
                }
            }
            
            Logger.shared.log("App \(self.episodeId)", "received context \(String(describing: context)) account \(String(describing: context?.accountId)) network \(String(describing: network))")
            
            if let contextValue = self.contextValue {
                (contextValue.account?.applicationContext as? TelegramApplicationContext)?.isCurrent = false
                switch contextValue {
                    case let .unauthorized(unauthorized):
                        unauthorized.account.shouldBeServiceTaskMaster.set(.single(.never))
                    case let .authorized(authorized):
                        authorized.account.shouldBeServiceTaskMaster.set(.single(.never))
                        authorized.account.shouldKeepOnlinePresence.set(.single(false))
                        authorized.account.shouldExplicitelyKeepWorkerConnections.set(.single(false))
                        authorized.account.shouldKeepBackgroundDownloadConnections.set(.single(false))
                    default:
                        break
                }
            }
            self.contextValue = context
            if let context = context {
                (context.account?.applicationContext as? TelegramApplicationContext)?.isCurrent = true
                updateLegacyComponentsAccount(context.account)
                self.mainWindow.viewController = context.rootController
                self.mainWindow.topLevelOverlayControllers = context.overlayControllers
                self.maybeDequeueNotificationPayloads()
                self.maybeDequeueNotificationRequests()
                self.maybeDequeueWakeups()
                switch context {
                    case let .authorized(context):
                        var authorizeNotifications = true
                        if #available(iOS 10.0, *) {
                            authorizeNotifications = false
                        }
                        self.registerForNotifications(account: context.account, authorize: authorizeNotifications)
                        context.account.notificationToken.set(self.notificationTokenPromise.get())
                        context.account.voipToken.set(self.voipTokenPromise.get())
                    case .unauthorized:
                        break
                    case .upgrading:
                        break
                }
            } else {
                self.mainWindow.viewController = nil
            }
        }))
        
        self.watchCommunicationManagerPromise.set(watchCommunicationManager(context: self.context))
        let _ = self.watchCommunicationManagerPromise.get().start(next: { manager in
            if let manager = manager {
                watchManagerArgumentsPromise.set(.single(manager.arguments))
            } else {
                watchManagerArgumentsPromise.set(.single(nil))
            }
        })
        
        let pushRegistry = PKPushRegistry(queue: .main)
        pushRegistry.desiredPushTypes = Set([.voIP])
        self.pushRegistry = pushRegistry
        pushRegistry.delegate = self
        
        self.badgeDisposable.set((self.context.get()
        |> mapToSignal { context -> Signal<Int32, NoError> in
            if let context = context {
                switch context {
                    case let .authorized(context):
                        return context.applicationBadge
                    case .unauthorized:
                        return .single(0)
                    case .upgrading:
                        return .single(0)
                }
            } else {
                return .never()
            }
        }
        |> deliverOnMainQueue).start(next: { count in
            UIApplication.shared.applicationIconBadgeNumber = Int(count)
        }))
        
        if #available(iOS 9.1, *) {
            self.quickActionsDisposable.set((self.context.get()
            |> mapToSignal { context -> Signal<[ApplicationShortcutItem], NoError> in
                if let context = context {
                    switch context {
                        case let .authorized(context):
                            let presentationData = context.account.telegramApplicationContext.currentPresentationData.with { $0 }
                            return .single(applicationShortcutItems(strings: presentationData.strings))
                        case .unauthorized:
                            return .single([])
                        case .upgrading:
                            return .single([])
                    }
                } else {
                    return .never()
                }
            }
            |> distinctUntilChanged
            |> deliverOnMainQueue).start(next: { items in
                if items.isEmpty {
                    UIApplication.shared.shortcutItems = nil
                } else {
                    UIApplication.shared.shortcutItems = items.map({ $0.shortcutItem() })
                }
            }))
        }
        
        let _ = self.isInForegroundPromise.get().start(next: { value in
            Logger.shared.log("App \(self.episodeId)", "isInForeground = \(value)")
        })
        let _ = self.isActivePromise.get().start(next: { value in
            Logger.shared.log("App \(self.episodeId)", "isActive = \(value)")
        })
        
        /*if let url = launchOptions?[.url] {
            if let url = url as? URL, url.scheme == "tg" {
                self.openUrlWhenReady(url: url.absoluteString)
            } else if let url = url as? String, url.lowercased().hasPrefix("tg://") {
                self.openUrlWhenReady(url: url)
            }
        }*/
        
        if application.applicationState == .active {
            self.isInForegroundValue = true
            self.isInForegroundPromise.set(true)
            self.isActiveValue = true
            self.isActivePromise.set(true)
        }
        
        BITHockeyBaseManager.setPresentAlert({ [weak self] alert in
            if let strongSelf = self, let alert = alert {
                var actions: [TextAlertAction] = []
                for action in alert.actions {
                    let isDefault = action.style == .default
                    actions.append(TextAlertAction(type: isDefault ? .defaultAction : .genericAction, title: action.title ?? "", action: {
                        if let action = action as? BITAlertAction {
                            action.invokeAction()
                        }
                    }))
                }
                if let contextValue = strongSelf.contextValue {
                    if case let .authorized(context) = contextValue {
                        let presentationData = context.applicationContext.currentPresentationData.with { $0 }
                        strongSelf.mainWindow.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: alert.title, text: alert.message ?? "", actions: actions), on: .root)
                    } else if case let .unauthorized(context) = contextValue {
                        strongSelf.mainWindow.present(standardTextAlertController(theme: AlertControllerTheme(authTheme: context.rootController.theme), title: alert.title, text: alert.message ?? "", actions: actions), on: .root)
                    }
                }
            }
        })
        
        BITHockeyBaseManager.setPresentView({ [weak self] controller in
            if let strongSelf = self, let controller = controller {
                let parent = LegacyController(presentation: .modal(animateIn: true), theme: nil)
                let navigationController = UINavigationController(rootViewController: controller)
                controller.navigation_setDismiss({ [weak parent] in
                    parent?.dismiss()
                }, rootController: nil)
                parent.bind(controller: navigationController)
                strongSelf.mainWindow.present(parent, on: .root)
            }
        })
        
        if !BuildConfig.shared().hockeyAppId.isEmpty {
            BITHockeyManager.shared().configure(withIdentifier: BuildConfig.shared().hockeyAppId, delegate: self)
            BITHockeyManager.shared().crashManager.crashManagerStatus = .alwaysAsk
            BITHockeyManager.shared().start()
            BITHockeyManager.shared().authenticator.authenticateInstallation()
        }
        
        //CloudVeil start
        var settings = AutomaticMediaDownloadSettings.defaultSettings
        settings.autoplayGifs = settings.autoplayGifs && !MainController.SecurityStaticSettings.disableAutoPlayGifs
        //CloudVeile end
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        self.isActiveValue = false
        self.isActivePromise.set(false)
        self.clearNotificationsManager?.commitNow()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        self.isInForegroundValue = false
        self.isInForegroundPromise.set(false)
        self.isActiveValue = false
        self.isActivePromise.set(false)
        
        var taskId: Int?
        taskId = application.beginBackgroundTask(withName: "lock", expirationHandler: {
            if let taskId = taskId {
                UIApplication.shared.endBackgroundTask(taskId)
            }
        })
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 5.0, execute: {
            if let taskId = taskId {
                UIApplication.shared.endBackgroundTask(taskId)
            }
        })
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        if self.isActiveValue {
            self.isInForegroundValue = true
            self.isInForegroundPromise.set(true)
        } else {
            if #available(iOSApplicationExtension 12.0, *) {
                DispatchQueue.main.async {
                    self.isInForegroundValue = true
                    self.isInForegroundPromise.set(true)
                }
            }
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        self.isInForegroundValue = true
        self.isInForegroundPromise.set(true)
        self.isActiveValue = true
        self.isActivePromise.set(true)
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        Logger.shared.log("App \(self.episodeId)", "terminating")
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        self.notificationTokenPromise.set(.single(deviceToken))
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        var redactedPayload = userInfo
        if var aps = redactedPayload["aps"] as? [AnyHashable: Any] {
            if Logger.shared.redactSensitiveData {
                if aps["alert"] != nil {
                    aps["alert"] = "[[redacted]]"
                }
                if aps["body"] != nil {
                    aps["body"] = "[[redacted]]"
                }
            }
            redactedPayload["aps"] = aps
        }
        
        
        Logger.shared.log("App \(self.episodeId)", "remoteNotification: \(redactedPayload)")
        completionHandler(UIBackgroundFetchResult.noData)
    }
    
    func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
        if (application.applicationState == .inactive) {
            Logger.shared.log("App \(self.episodeId)", "tap local notification \(String(describing: notification.userInfo)), applicationState \(application.applicationState)")
        }
    }

    public func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
        if case PKPushType.voIP = type {
            Logger.shared.log("App \(self.episodeId)", "pushRegistry credentials: \(credentials.token as NSData)")
            
            self.voipTokenPromise.set(.single(credentials.token))
        }
    }
    
    private var pushCnt = 0
    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        if case PKPushType.voIP = type {
            Logger.shared.log("App \(self.episodeId)", "pushRegistry payload: \(payload.dictionaryPayload)")
            /*#if DEBUG
            self.pushCnt += 1
            if self.pushCnt % 2 != 0 {
                Logger.shared.log("App \(self.episodeId)", "pushRegistry payload drop")
                return
            }
            #endif*/
            
            self.queuedNotifications.append(payload)
            self.maybeDequeueNotificationPayloads()
        }
    }
    
    private func processPushPayload(_ payload: PKPushPayload, account: Account) {
        let decryptedPayload: Signal<[AnyHashable: Any]?, NoError>
        if let _ = payload.dictionaryPayload["aps"] as? [AnyHashable: Any] {
            decryptedPayload = .single(payload.dictionaryPayload as [AnyHashable: Any])
        } else if var encryptedPayload = payload.dictionaryPayload["p"] as? String {
            encryptedPayload = encryptedPayload.replacingOccurrences(of: "-", with: "+")
            encryptedPayload = encryptedPayload.replacingOccurrences(of: "_", with: "/")
            while encryptedPayload.count % 4 != 0 {
                encryptedPayload.append("=")
            }
            if let data = Data(base64Encoded: encryptedPayload) {
                decryptedPayload = decryptedNotificationPayload(account: account, data: data)
                |> map { value -> [AnyHashable: Any]? in
                    if let value = value, let object = try? JSONSerialization.jsonObject(with: value, options: []) {
                        return object as? [AnyHashable: Any]
                    }
                    return nil
                }
            } else {
                decryptedPayload = .single(nil)
            }
        } else {
            decryptedPayload = .single(nil)
        }
        
        let _ = (decryptedPayload
        |> deliverOnMainQueue).start(next: { payload in
            guard let payload = payload else {
                return
            }
            
            var redactedPayload = payload
            if var aps = redactedPayload["aps"] as? [AnyHashable: Any] {
                if Logger.shared.redactSensitiveData {
                    if aps["alert"] != nil {
                        aps["alert"] = "[[redacted]]"
                    }
                    if aps["body"] != nil {
                        aps["body"] = "[[redacted]]"
                    }
                }
                redactedPayload["aps"] = aps
            }
            Logger.shared.log("Apns \(self.episodeId)", "\(redactedPayload)")
            
            let aps = payload["aps"] as? [AnyHashable: Any]
            
            if UIApplication.shared.applicationState == .background {
                var readMessageId: MessageId?
                var isCall = false
                var isAnnouncement = false
                var isLocationPolling = false
                var isMutePolling = false
                var title: String = ""
                var body: String?
                var apnsSound: String?
                var configurationUpdate: (Int32, String, Int32, Data?)?
                if let aps = aps, let alert = aps["alert"] as? String {
                    if let range = alert.range(of: ": ") {
                        title = String(alert[..<range.lowerBound])
                        body = String(alert[range.upperBound...])
                    } else {
                        body = alert
                    }
                } else if let aps = aps, let alert = aps["alert"] as? [AnyHashable: AnyObject] {
                    if let alertBody = alert["body"] as? String {
                        body = alertBody
                        if let alertTitle = alert["title"] as? String {
                            title = alertTitle
                        }
                    }
                    if let locKey = alert["loc-key"] as? String {
                        if locKey == "PHONE_CALL_REQUEST" {
                            isCall = true
                        } else if locKey == "GEO_LIVE_PENDING" {
                            isLocationPolling = true
                        } else if locKey == "MESSAGE_MUTED" {
                            isMutePolling = true
                        }
                        let string = NSLocalizedString(locKey, comment: "")
                        if !string.isEmpty {
                            if let locArgs = alert["loc-args"] as? [AnyObject] {
                                var args: [CVarArg] = []
                                var failed = false
                                for arg in locArgs {
                                    if let arg = arg as? CVarArg {
                                        args.append(arg)
                                    } else {
                                        failed = true
                                        break
                                    }
                                }
                                if failed {
                                    body = "\(string)"
                                } else {
                                    body = String(format: string, arguments: args)
                                }
                            } else {
                                body = "\(string)"
                            }
                        } else {
                            body = nil
                        }
                    } else {
                        body = nil
                    }
                }
                
                if let aps = aps, let address = aps["addr"] as? String, let datacenterId = aps["dc"] as? Int {
                    var host = address
                    var port: Int32 = 443
                    if let range = address.range(of: ":") {
                        host = String(address[address.startIndex ..< range.lowerBound])
                        if let portValue = Int(String(address[range.upperBound...])) {
                            port = Int32(portValue)
                        }
                    }
                    var secret: Data?
                    if let secretString = aps["sec"] as? String {
                        let data = dataWithHexString(secretString)
                        if data.count == 16 || data.count == 32 {
                            secret = data
                        }
                    }
                    configurationUpdate = (Int32(datacenterId), host, port, secret)
                }
                
                if let aps = aps, let sound = aps["sound"] as? String {
                    apnsSound = sound
                }
                
                if payload["call_id"] != nil {
                    isCall = true
                }
                
                if payload["announcement"] != nil {
                    isAnnouncement = true
                }
                
                if let body = body {
                    if isAnnouncement {
                        self.queuedAnnouncements.append(body)
                        self.maybeDequeueAnnouncements()
                    } else {
                        var peerId: PeerId?
                        var notificationRequestId: NotificationManagedNotificationRequestId?
                        
                        if let fromId = payload["from_id"] {
                            let fromIdValue = fromId as! NSString
                            peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: Int32(fromIdValue.intValue))
                        } else if let fromId = payload["chat_id"] {
                            let fromIdValue = fromId as! NSString
                            peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: Int32(fromIdValue.intValue))
                        } else if let fromId = payload["channel_id"] {
                            let fromIdValue = fromId as! NSString
                            peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: Int32(fromIdValue.intValue))
                        }
                        
                        if let msgId = payload["msg_id"] {
                            let msgIdValue = msgId as! NSString
                            if let peerId = peerId {
                                notificationRequestId = .messageId(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(msgIdValue.intValue)))
                            }
                        } else if let randomId = payload["random_id"] {
                            let randomIdValue = randomId as! NSString
                            var peerId: PeerId?
                            if let encryptionIdString = payload["encryption_id"] as? String, let encryptionId = Int32(encryptionIdString) {
                                peerId = PeerId(namespace: Namespaces.Peer.SecretChat, id: encryptionId)
                            }
                            notificationRequestId = .globallyUniqueId(randomIdValue.longLongValue, peerId)
                        } else {
                            isMutePolling = true
                        }
                        
                        if let notificationRequestId = notificationRequestId {
                            self.queuedNotificationRequests.append((title, body, apnsSound, notificationRequestId))
                            self.maybeDequeueNotificationRequests()
                        } else if isMutePolling {
                            self.queuedMutePolling = true
                            self.maybeDequeueNotificationRequests()
                        }
                    }
                } else if let _ = payload["max_id"] {
                    var peerId: PeerId?
                    
                    if let fromId = payload["from_id"] {
                        let fromIdValue = fromId as! NSString
                        peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: Int32(fromIdValue.intValue))
                    } else if let fromId = payload["chat_id"] {
                        let fromIdValue = fromId as! NSString
                        peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: Int32(fromIdValue.intValue))
                    } else if let fromId = payload["channel_id"] {
                        let fromIdValue = fromId as! NSString
                        peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: Int32(fromIdValue.intValue))
                    }
                    
                    if let peerId = peerId {
                        if let msgId = payload["max_id"] {
                            let msgIdValue = msgId as! NSString
                            if msgIdValue.intValue != 0 {
                                readMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(msgIdValue.intValue))
                            }
                        }
                    }
                }
                
                var addedWakeups = Set<QueuedWakeup>()
                if isCall {
                    addedWakeups.insert(.call)
                }
                if isLocationPolling {
                    addedWakeups.insert(.backgroundLocation)
                }
                if !addedWakeups.isEmpty {
                    self.queuedWakeups.formUnion(addedWakeups)
                    self.maybeDequeueWakeups()
                }
                if let readMessageId = readMessageId {
                    self.clearNotificationsManager?.append(readMessageId)
                    self.clearNotificationsManager?.commitNow()
                    
                    let signal = self.currentAuthorizedContext()
                    |> take(1)
                    |> mapToSignal { context -> Signal<Void, NoError> in
                        if let context = context {
                            return context.account.postbox.transaction (ignoreDisabled: true, { transaction -> Void in
                                transaction.applyIncomingReadMaxId(readMessageId)
                            })
                        } else {
                            return .complete()
                        }
                    }
                    let _ = signal.start()
                }
                
                if let (datacenterId, host, port, secret) = configurationUpdate {
                    let signal = self.currentAuthorizedContext()
                    |> take(1)
                    |> mapToSignal { context -> Signal<Void, NoError> in
                        if let context = context {
                            context.account.network.mergeBackupDatacenterAddress(datacenterId: datacenterId, host: host, port: port, secret: secret)
                        }
                        return .complete()
                    }
                    let _ = signal.start()
                }
            }
        })
    }
    
    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        Logger.shared.log("App \(self.episodeId)", "invalidated token for \(type)")
    }

    private func currentAuthorizedContext() -> Signal<AuthorizedApplicationContext?, NoError> {
        return self.context.get()
            |> take(1)
            |> mapToSignal { contextValue -> Signal<AuthorizedApplicationContext?, NoError> in
                if let contextValue = contextValue, case let .authorized(context) = contextValue {
                    return .single(context)
                } else {
                    return .single(nil)
                }
        }
    }
    
    private func authorizedContext() -> Signal<AuthorizedApplicationContext, NoError> {
        return self.context.get()
        |> mapToSignal { contextValue -> Signal<AuthorizedApplicationContext, NoError> in
            if let contextValue = contextValue, case let .authorized(context) = contextValue {
                return .single(context)
            } else {
                return .complete()
            }
        }
    }
    
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?) -> Bool {
        self.openUrl(url: url)
        return true
    }
    
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        self.openUrl(url: url)
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        self.openUrl(url: url)
        return true
    }
    
    func application(_ application: UIApplication, handleOpen url: URL) -> Bool {
        self.openUrl(url: url)
        return true
    }
    
    private func openUrl(url: URL) {
        let _ = (self.context.get()
        |> flatMap { $0 }
        |> filter { context in
            switch context {
                case .authorized, .unauthorized:
                    return true
                default:
                    return false
            }
        }
        |> take(1)
        |> deliverOnMainQueue).start(next: { contextValue in
            switch contextValue {
                case let .authorized(context):
                    context.openUrl(url)
                case let .unauthorized(context):
                    if let proxyData = parseProxyUrl(url) {
                        context.rootController.view.endEditing(true)
                        let strings = context.applicationContext.currentPresentationData.with({ $0 }).strings
                        let controller = ProxyServerActionSheetController(theme: defaultPresentationTheme, strings: strings, postbox: context.account.postbox, network: context.account.network, server: proxyData, presentationData: nil)
                        context.rootController.currentWindow?.present(controller, on: PresentationSurfaceLevel.root, blockInteraction: false, completion: {})
                    } else if let secureIdData = parseSecureIdUrl(url) {
                        let strings = context.applicationContext.currentPresentationData.with({ $0 }).strings
                        let theme = context.rootController.theme
                        context.rootController.currentWindow?.present(standardTextAlertController(theme: AlertControllerTheme(authTheme: theme), title: nil, text: strings.Passport_NotLoggedInMessage, actions: [TextAlertAction(type: .genericAction, title: strings.Calls_NotNow, action: {
                            if let callbackUrl = URL(string: secureIdCallbackUrl(with: secureIdData.callbackUrl, peerId: secureIdData.peerId, result: .cancel, parameters: [:])) {
                                UIApplication.shared.openURL(callbackUrl)
                            }
                        }), TextAlertAction(type: .defaultAction, title: strings.Common_OK, action: {})]), on: .root, blockInteraction: false, completion: {})
                    } else if let confirmationCode = parseConfirmationCodeUrl(url) {
                        context.rootController.applyConfirmationCode(confirmationCode)
                    }
                default:
                    break
            }
        })
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
        if #available(iOS 10.0, *) {
            if let startCallIntent = userActivity.interaction?.intent as? SupportedStartCallIntent {
                if let contact = startCallIntent.contacts?.first {
                    if let handle = contact.personHandle?.value {
                        if let userId = Int32(handle) {
                            if let contextValue = self.contextValue, case let .authorized(context) = contextValue {
                                let _ = context.applicationContext.callManager?.requestCall(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), endCurrentIfAny: false)
                            }
                        }
                    }
                }
            }
        }
        
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {
            self.openUrl(url: url)
        }
        
        return true
    }
    
    @available(iOS 9.0, *)
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        let _ = (self.context.get()
        |> mapToSignal { value -> Signal<ApplicationContext?, NoError> in
            if let value = value {
                if case let .authorized(context) = value {
                    return context.unlockedState
                    |> filter { $0 }
                    |> take(1)
                    |> map { _ -> ApplicationContext? in
                        return value
                    }
                } else {
                    return .single(nil)
                }
            } else {
                return .complete()
            }
        }
        |> take(1)
        |> deliverOnMainQueue).start(next: { contextValue in
            if let contextValue = contextValue, case let .authorized(context) = contextValue {
                if let type = ApplicationShortcutItemType(rawValue: shortcutItem.type) {
                    switch type {
                        case .search:
                            context.openRootSearch()
                        case .compose:
                            context.openRootCompose()
                        case .camera:
                            context.openRootCamera()
                        case .savedMessages:
                            self.openChatWhenReady(peerId: context.account.peerId)
                    }
                }
            }
        })
    }
    
    private func openChatWhenReady(peerId: PeerId, messageId: MessageId? = nil) {
        self.openChatWhenReadyDisposable.set((self.authorizedContext()
        |> take(1)
        |> deliverOnMainQueue).start(next: { context in
            context.openChatWithPeerId(peerId: peerId, messageId: messageId)
        }))
    }
    
    private func openUrlWhenReady(url: String) {
        self.openUrlWhenReadyDisposable.set((self.authorizedContext()
        |> take(1)
        |> deliverOnMainQueue).start(next: { context in
            let presentationData = context.account.telegramApplicationContext.currentPresentationData.with { $0 }
            openExternalUrl(account: context.account, url: url, presentationData: presentationData, applicationContext: context.account.telegramApplicationContext, navigationController: context.rootController, dismissInput: {
                
            })
        }))
    }
    
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            if let peerId = peerIdFromNotification(response.notification) {
                var messageId: MessageId? = nil
                if response.notification.request.content.categoryIdentifier == "watch" {
                    messageId = messageIdFromNotification(peerId: peerId, notification: response.notification)
                }
                self.openChatWhenReady(peerId: peerId, messageId: messageId)
            }
            completionHandler()
        } else if response.actionIdentifier == "reply", let peerId = peerIdFromNotification(response.notification) {
            if let response = response as? UNTextInputNotificationResponse, !response.userText.isEmpty {
                let text = response.userText
                let token = addReplyFromNotificationsToken()
                
                let signal = self.authorizedContext()
                |> take(1)
                |> mapToSignal { context -> Signal<Void, NoError> in
                    if let messageId = messageIdFromNotification(peerId: peerId, notification: response.notification) {
                        let _ = applyMaxReadIndexInteractively(postbox: context.account.postbox, stateManager: context.account.stateManager, index: MessageIndex(id: messageId, timestamp: 0)).start()
                    }
                    return enqueueMessages(account: context.account, peerId: peerId, messages: [EnqueueMessage.message(text: text, attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil)])
                    |> map { messageIds -> MessageId? in
                        if messageIds.isEmpty {
                            return nil
                        } else {
                            return messageIds[0]
                        }
                    }
                    |> mapToSignal { messageId -> Signal<Void, NoError> in
                        if let messageId = messageId {
                            return context.account.postbox.unsentMessageIdsView()
                            |> filter { view in
                                return !view.ids.contains(messageId)
                            }
                            |> take(1)
                            |> mapToSignal { _ -> Signal<Void, NoError> in
                                return .complete()
                            }
                        } else {
                            return .complete()
                        }
                    }
                }
                |> deliverOnMainQueue
                |> timeout(15.0, queue: Queue.mainQueue(), alternate: .complete() |> beforeCompleted {
                    /*let content = UNMutableNotificationContent()
                    content.body = "Please open the app to continue sending messages"
                    content.sound = UNNotificationSound.default()
                    content.categoryIdentifier = "error"
                    content.userInfo = ["peerId": peerId as NSNumber]
                    
                    let request = UNNotificationRequest(identifier: "reply-error", content: content, trigger: nil)
                    
                    let center = UNUserNotificationCenter.current()
                    center.add(request)*/
                })
                
                let disposable = MetaDisposable()
                disposable.set((signal
                |> afterDisposed { [weak disposable] in
                    Queue.mainQueue().async {
                        if let disposable = disposable {
                            self.replyFromNotificationsDisposables.remove(disposable)
                        }
                        self.removeReplyFromNotificationsToken(token)
                        completionHandler()
                    }
                }).start())
                self.replyFromNotificationsDisposables.add(disposable)
            } else {
                completionHandler()
            }
        } else {
            completionHandler()
        }
    }
    
    private func registerForNotifications(account: Account, authorize: Bool = true, completion: @escaping (Bool) -> Void = { _ in }) {
        let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        let _ = (account.postbox.transaction { transaction -> Bool in
            let settings = transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.inAppNotificationSettings) as? InAppNotificationSettings ?? InAppNotificationSettings.defaultSettings
            return settings.displayNameOnLockscreen
        }
        |> deliverOnMainQueue).start(next: { displayNames in
            self.registerForNotifications(replyString: presentationData.strings.Notification_Reply, messagePlaceholderString: presentationData.strings.Conversation_InputTextPlaceholder, hiddenContentString: presentationData.strings.Watch_MessageView_Title, includeNames: displayNames, authorize: authorize, completion: completion)
        })
    }
    
    
    private func registerForNotifications(replyString: String, messagePlaceholderString: String, hiddenContentString: String, includeNames: Bool, authorize: Bool = true, completion: @escaping (Bool) -> Void = { _ in }) {
        if #available(iOS 10.0, *) {
            let notificationCenter = UNUserNotificationCenter.current()
            notificationCenter.getNotificationSettings(completionHandler: { settings in
                switch (settings.authorizationStatus, authorize) {
                    case (.authorized, _), (.notDetermined, true):
                        notificationCenter.requestAuthorization(options: [.badge, .sound, .alert], completionHandler: { result, _ in
                            completion(result)
                            if result {
                                Queue.mainQueue().async {
                                    let reply = UNTextInputNotificationAction(identifier: "reply", title: replyString, options: [], textInputButtonTitle: replyString, textInputPlaceholder: messagePlaceholderString)
                                    
                                    let unknownMessageCategory: UNNotificationCategory
                                    let replyMessageCategory: UNNotificationCategory
                                    let replyLegacyMessageCategory: UNNotificationCategory
                                    let replyLegacyMediaMessageCategory: UNNotificationCategory
                                    let replyMediaMessageCategory: UNNotificationCategory
                                    let muteMessageCategory: UNNotificationCategory
                                    let muteMediaMessageCategory: UNNotificationCategory
                                    if #available(iOS 11.0, *) {
                                        var options: UNNotificationCategoryOptions = []
                                        if includeNames {
                                            options.insert(.hiddenPreviewsShowTitle)
                                        }
                                        
                                        unknownMessageCategory = UNNotificationCategory(identifier: "unknown", actions: [], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: hiddenContentString, options: options)
                                        replyMessageCategory = UNNotificationCategory(identifier: "withReply", actions: [reply], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: hiddenContentString, options: options)
                                        replyLegacyMessageCategory = UNNotificationCategory(identifier: "r", actions: [reply], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: hiddenContentString, options: options)
                                        replyLegacyMediaMessageCategory = UNNotificationCategory(identifier: "m", actions: [reply], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: hiddenContentString, options: options)
                                        replyMediaMessageCategory = UNNotificationCategory(identifier: "withReplyMedia", actions: [reply], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: hiddenContentString, options: options)
                                        muteMessageCategory = UNNotificationCategory(identifier: "withMute", actions: [], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: hiddenContentString, options: options)
                                        muteMediaMessageCategory = UNNotificationCategory(identifier: "withMuteMedia", actions: [], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: hiddenContentString, options: options)
                                    } else {
                                        unknownMessageCategory = UNNotificationCategory(identifier: "unknown", actions: [], intentIdentifiers: [], options: [])
                                        replyMessageCategory = UNNotificationCategory(identifier: "withReply", actions: [reply], intentIdentifiers: [], options: [])
                                        replyLegacyMessageCategory = UNNotificationCategory(identifier: "r", actions: [reply], intentIdentifiers: [], options: [])
                                        replyLegacyMediaMessageCategory = UNNotificationCategory(identifier: "m", actions: [reply], intentIdentifiers: [], options: [])
                                        replyMediaMessageCategory = UNNotificationCategory(identifier: "withReplyMedia", actions: [reply], intentIdentifiers: [], options: [])
                                        muteMessageCategory = UNNotificationCategory(identifier: "withMute", actions: [], intentIdentifiers: [], options: [])
                                        muteMediaMessageCategory = UNNotificationCategory(identifier: "withMuteMedia", actions: [], intentIdentifiers: [], options: [])
                                    }
                                    
                                    UNUserNotificationCenter.current().setNotificationCategories([unknownMessageCategory, replyMessageCategory, replyLegacyMessageCategory, replyLegacyMediaMessageCategory, replyMediaMessageCategory, muteMessageCategory, muteMediaMessageCategory])
                                    
                                    UIApplication.shared.registerForRemoteNotifications()
                                }
                            }
                        })
                    default:
                        break
                }
            })
        } else {
            let settings = UIUserNotificationSettings(types: [.badge, .sound, .alert], categories:[])
            UIApplication.shared.registerUserNotificationSettings(settings)
            
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    private func maybeDequeueNotificationPayloads() {
        if let contextValue = self.contextValue, case let .authorized(context) = contextValue, !self.queuedNotifications.isEmpty {
            let queuedNotifications = self.queuedNotifications
            self.queuedNotifications = []
            for payload in queuedNotifications {
                self.processPushPayload(payload, account: context.account)
            }
        }
    }
    
    private func maybeDequeueNotificationRequests() {
        if let contextValue = self.contextValue, case let .authorized(context) = contextValue {
            let requests = self.queuedNotificationRequests
            self.queuedNotificationRequests = []
            let queuedMutePolling = self.queuedMutePolling
            self.queuedMutePolling = false
            
            let _ = (context.account.postbox.transaction(ignoreDisabled: true, { transaction -> PostboxAccessChallengeData in
                return transaction.getAccessChallengeData()
            })
            |> deliverOnMainQueue).start(next: { accessChallengeData in
                guard let contextValue = self.contextValue, case let .authorized(context) = contextValue else {
                    Logger.shared.log("App \(self.episodeId)", "Couldn't process remote notification request")
                    return
                }
                
                let strings = context.account.telegramApplicationContext.currentPresentationData.with({ $0 }).strings
                
                for (title, body, apnsSound, requestId) in requests {
                    if handleVoipNotifications {
                    context.notificationManager.enqueueRemoteNotification(title: title, text: body, apnsSound: apnsSound, requestId: requestId, strings: strings, accessChallengeData: accessChallengeData)
                    }
                    
                    context.wakeupManager.wakeupForIncomingMessages(completion: { messageIds -> Signal<Void, NoError> in
                        if let contextValue = self.contextValue, case let .authorized(context) = contextValue {
                            if handleVoipNotifications {
                                return context.notificationManager.commitRemoteNotification(originalRequestId: requestId, messageIds: messageIds)
                            } else {
                                return context.notificationManager.commitRemoteNotification(originalRequestId: nil, messageIds: [])
                            }
                        } else {
                            Logger.shared.log("App \(self.episodeId)", "Couldn't process remote notifications wakeup result")
                            return .complete()
                        }
                    })
                }
                if queuedMutePolling {
                    context.wakeupManager.wakeupForIncomingMessages(completion: { messageIds -> Signal<Void, NoError> in
                        if let contextValue = self.contextValue, case .authorized = contextValue {
                            return .single(Void())
                        } else {
                            Logger.shared.log("App \(self.episodeId)", "Couldn't process remote notifications wakeup result")
                            return .single(Void())
                        }
                    })
                }
            })
        } else {
            Logger.shared.log("App \(self.episodeId)", "maybeDequeueNotificationRequests failed, no active context")
        }
    }
    
    private func maybeDequeueAnnouncements() {
        if let contextValue = self.contextValue, case let .authorized(context) = contextValue, !self.queuedAnnouncements.isEmpty {
            let queuedAnnouncements = self.queuedAnnouncements
            self.queuedAnnouncements = []
            let _ = (context.account.postbox.transaction(ignoreDisabled: true, { transaction -> [MessageId: String] in
                var result: [MessageId: String] = [:]
                let timestamp = Int32(context.account.network.globalTime)
                let servicePeer = TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: 777000), accessHash: nil, firstName: "Telegram", lastName: nil, username: nil, phone: "42777", photo: [], botInfo: nil, restrictionInfo: nil, flags: [.isVerified])
                if transaction.getPeer(servicePeer.id) == nil {
                    transaction.updatePeersInternal([servicePeer], update: { _, updated in
                        return updated
                    })
                }
                for body in queuedAnnouncements {
                    let globalId = arc4random64()
                    var attributes: [MessageAttribute] = []
                    let entities = generateTextEntities(body, enabledTypes: .all)
                    if !entities.isEmpty {
                        attributes.append(TextEntitiesMessageAttribute(entities: entities))
                    }
                    let message = StoreMessage(id: .Partial(servicePeer.id, Namespaces.Message.Local), globallyUniqueId: globalId, groupingKey: nil, timestamp: timestamp, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: servicePeer.id, text: body, attributes: attributes, media: [])
                    let ids = transaction.addMessages([message], location: .Random)
                    if let id = ids[globalId] {
                        result[id] = body
                    }
                }
                return result
            }) |> deliverOnMainQueue).start(next: { result in
                if let contextValue = self.contextValue, case let .authorized(context) = contextValue {
                    for (id, text) in result {
                        context.notificationManager.enqueueRemoteNotification(title: "", text: text, apnsSound: nil, requestId: .messageId(id), strings: context.account.telegramApplicationContext.currentPresentationData.with({ $0 }).strings, accessChallengeData: .none)
                    }
                }
            })
        }
    }
    
    private func maybeDequeueWakeups() {
        for wakeup in self.queuedWakeups {
            switch wakeup {
                case .call:
                    if let contextValue = self.contextValue, case let .authorized(context) = contextValue {
                        context.wakeupManager.wakeupForIncomingMessages()
                    }
                case .backgroundLocation:
                    if UIApplication.shared.applicationState == .background {
                        if let contextValue = self.contextValue, case let .authorized(context) = contextValue {
                            context.applicationContext.liveLocationManager?.pollOnce()
                        }
                    }
            }
        }
        
        self.queuedWakeups.removeAll()
    }
    
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        #if DEBUG
            completionHandler([.alert])
        #else
            completionHandler([])
        #endif
    }
    
    override var next: UIResponder? {
        if let contextValue = self.contextValue, case let .authorized(context) = contextValue, let controller = context.applicationContext.keyShortcutsController {
            return controller
        }
        return super.next
    }
    
    @objc func debugPressed() {
        let _ = (Logger.shared.collectLogs()
        |> deliverOnMainQueue).start(next: { logs in
            var activityItems: [Any] = []
            for (_, path) in logs {
                activityItems.append(URL(fileURLWithPath: path))
            }
            
            let activityController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
            
            self.window?.rootViewController?.present(activityController, animated: true, completion: nil)
        })
    }
}

@available(iOS 10.0, *)
private func peerIdFromNotification(_ notification: UNNotification) -> PeerId? {
    if let peerId = notification.request.content.userInfo["peerId"] as? Int64 {
        return PeerId(peerId)
    } else {
        let payload = notification.request.content.userInfo
        var peerId: PeerId?
        if let fromId = payload["from_id"] {
            let fromIdValue = fromId as! NSString
            peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: Int32(fromIdValue.intValue))
        } else if let fromId = payload["chat_id"] {
            let fromIdValue = fromId as! NSString
            peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: Int32(fromIdValue.intValue))
        } else if let fromId = payload["channel_id"] {
            let fromIdValue = fromId as! NSString
            peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: Int32(fromIdValue.intValue))
        } else if let fromId = payload["encryption_id"] {
            let fromIdValue = fromId as! NSString
            peerId = PeerId(namespace: Namespaces.Peer.SecretChat, id: Int32(fromIdValue.intValue))
        }
        return peerId
    }
}

@available(iOS 10.0, *)
private func messageIdFromNotification(peerId: PeerId, notification: UNNotification) -> MessageId? {
    let payload = notification.request.content.userInfo
    if let messageIdNamespace = payload["messageId.namespace"] as? Int32, let messageIdId = payload["messageId.id"] as? Int32 {
        return MessageId(peerId: peerId, namespace: messageIdNamespace, id: messageIdId)
    }
    
    if let msgId = payload["msg_id"] {
        let msgIdValue = msgId as! NSString
        return MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(msgIdValue.intValue))
    }
    return nil
}
