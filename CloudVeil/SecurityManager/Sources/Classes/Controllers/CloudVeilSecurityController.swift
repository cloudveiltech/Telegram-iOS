//
//  MainController.swift
//  SecurityManager
//
//  Created by Dmitriy Virych on 3/2/18.
//  Copyright © 2018 Requestum. All rights reserved.
//

import Foundation

import UIKit

import ObjectMapper

open class CloudVeilSecurityController: NSObject {
	public struct SecurityStaticSettings {
		public static let disableGlobalSearch = true
		public static let disableYoutubeVideoEmbedding = true
		public static let disableInAppBrowser = true
		public static let disableAutoPlayGifs = true
		public static let disablePayments = true
		public static let disableBots = false
		public static let disableInlineBots = true
        public static let disableGifs = true
        public static let disableStories = false
	}
	
	
	public static let shared = CloudVeilSecurityController()
	
	
	// MARK: - Properties
	private let mapper = Mapper<TGSettingsResponse>()
	private var observers: [() -> ()] = []
	internal var lastRequest: TGSettingsRequest? = nil
	private var lastRequestTime: TimeInterval = 0.0
	private let UPADTE_INTERVAL = 10*60.0 //10min
	
	private let kWasFirstLoaded = "wasFirstLoaded" 
	private var wasFirstLoaded: Bool {
		get { return UserDefaults.standard.bool(forKey: kWasFirstLoaded) }
		set { UserDefaults.standard.set(newValue, forKey: kWasFirstLoaded) }
	}
	
    
    private let accessQueue = DispatchQueue(label: "TGSettingsResponseAccess", attributes: .concurrent)
	private var settingsCache: TGSettingsResponse?
    
	private var settings: TGSettingsResponse? {        
        var resp: TGSettingsResponse?
        if settingsCache != nil {
            resp = settingsCache
        } else {
            settingsCache = DataSource<TGSettingsResponse>.value(mapper: mapper)
            resp = settingsCache
        }
		return resp
	}
    
    public var needOrganizationChange: Bool {
        var res = false
        self.accessQueue.sync {
            res = settings?.organization?.needChange ?? false
        }
        return res
    }
    
	public var disableStickers: Bool {
        var res = false
        self.accessQueue.sync {
            res = settings?.disableSticker ?? false
        }
        return res
	}
	public var disableBio: Bool {
        var res = false
        self.accessQueue.sync {
            res = settings?.disableBio ?? false
        }
        return res
	}
	public var disableBioChange: Bool {
        var res = false
        self.accessQueue.sync {
            res = settings?.disableBioChange ?? false
        }
        return res
	}
	public var disableProfilePhoto: Bool {
        var res = false
        self.accessQueue.sync {
            res = settings?.disableProfilePhoto ?? false
        }
        return res
	}
	public var disableProfilePhotoChange: Bool {
        var res = false
        self.accessQueue.sync {
            res = settings?.disableProfilePhotoChange ?? false
        }
        return res
	}
    
	public var isSecretChatAvailable: Bool {
        var res = false
        self.accessQueue.sync {
            res = settings?.secretChat ?? false
        }
        return res
	}
		
	public var disableProfileVideo: Bool {
        var res = false
        self.accessQueue.sync {
            res = settings?.disableProfileVideo ?? false
        }
        return res
	}
	public var disableProfileVideoChange: Bool {
        var res = false
        self.accessQueue.sync {
            res = settings?.disableProfileVideoChange ?? false
        }
        return res
	}
	
	public var isInChatVideoRecordingEnabled: Bool {
        var res = false
        self.accessQueue.sync {
            res = settings?.inputToggleVoiceVideo ?? false
        }
        return res
	}
		
	public var profilePhotoLimit: Int {
        var v = 1
        self.accessQueue.sync {
            v = Int(settings?.profilePhotoLimit ?? "-1")!
            if v < 0 {
                v = Int.max
            } else if v == 0 {
                v = 1
            }
        }
		return v
	}

    public var organizationId: Int? {
        var res: Int?
        self.accessQueue.sync {
            res = settings?.organization?.id
        }
        return res
    }
	
	public var secretChatMinimumLength: NSInteger {
        var res = -1
        self.accessQueue.sync {
            if let lenghtStr = settings?.secretChatMinimumLength {
               res = Int(lenghtStr) ?? -1
            }
        }
		
		return res
	}
	
	private func sengSettingsRequest() {
        guard let body = CloudVeilSecurityController.shared.lastRequest else {
            return
        }
        let url = URL(string: "https://manage.cloudveil.org/api/v1/messenger/settings")!
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        req.httpMethod = "POST"
        req.httpBody = body.toJSONString(prettyPrint: false)!.data(using: .utf8)!
        let task = URLSession.shared.dataTask(with: req) { data, response, error in
            if let data = data, let str = String(data: data, encoding: .utf8) {
                Self.shared.saveSettings(TGSettingsResponse(JSONString: str))
                self.notifyObserbers()
            }
        }
        task.resume()
	}
	
    open func getSettings(groups: [TGRow] = [], bots: [TGRow] = [], channels: [TGRow] = [], stickers: [TGRow] = []) {
		let request = TGSettingsRequest(JSON: [:])!
		request.id = TGUserController.shared.getUserID()
		request.userName = TGUserController.shared.getUserName() as String
		request.phoneNumber = TGUserController.shared.getUserPhoneNumber() as String
        request.groups = SyncArray<TGRow>(groups)
		request.bots = SyncArray<TGRow>(bots)
		request.channels = SyncArray<TGRow>(channels)
        request.stickers = SyncArray<TGRow>(stickers)
        
        let dictionary = Bundle.main.infoDictionary!
        let version = dictionary["CFBundleShortVersionString"] as! String
        let build = dictionary["CFBundleVersion"] as! String
        request.clientVersionName = version
        request.clientVersionCode = build
		
        if let lastReq = self.lastRequest {
            if TGSettingsRequest.compareRequests(lhs: lastReq, rhs: request) {
                let now = Date().timeIntervalSince1970
                if now - self.lastRequestTime < self.UPADTE_INTERVAL {
                    NSLog("No changes, didn't load settings");
                    return
                } else {
                    NSLog("It was too long since last update, running request")
                }
            }
            
            request.clientSessionId = lastReq.clientSessionId
        } else {
            request.clientSessionId = getClientId(userId: request.id!)
        }
		
		self.lastRequest = request
		self.lastRequestTime = Date().timeIntervalSince1970
		self.sengSettingsRequest()
	}
	
    private func getClientId(userId: Int) -> String {
        if let userDefaults = UserDefaults(suiteName: "group.com.cloudveil.CloudVeilMessenger") {
            let key = "client_id__\(userId)"
            
            if let v = userDefaults.string(forKey: key) {
                return v
            }
            let guid = UUID().uuidString
            userDefaults.set(guid, forKey: key)
            userDefaults.synchronize()
            return guid
        }
        return ""
    }
    
	private func saveSettings(_ settings: TGSettingsResponse?) {
		print("Save settings called")
        self.accessQueue.sync {
            if let settings = settings {
                // if last response's org is this response's org,
                // keep old peers around even when this response doesn't have them
                if settings.organization?.id == settingsCache?.organization?.id {
                    settings.access = settings.access ?? AccessObject()

                    settings.access?.groups = settings.access?.groups ?? [:]
                    settings.access?.groups?.merge(
                        settingsCache?.access?.groups ?? [:],
                        uniquingKeysWith: { x, _ in x })

                    settings.access?.channels = settings.access?.channels ?? [:]
                    settings.access?.channels?.merge(
                        settingsCache?.access?.channels ?? [:],
                        uniquingKeysWith: { x, _ in x })

                    settings.access?.bots = settings.access?.bots ?? [:]
                    settings.access?.bots?.merge(
                        settingsCache?.access?.bots ?? [:],
                        uniquingKeysWith: { x, _ in x })

                    settings.access?.stickers = settings.access?.stickers ?? [:]
                    settings.access?.stickers?.merge(
                        settingsCache?.access?.stickers ?? [:],
                        uniquingKeysWith: { x, _ in x })

                    settings.access?.users = settings.access?.users ?? [:]
                    settings.access?.users?.merge(
                        settingsCache?.access?.users ?? [:],
                        uniquingKeysWith: { x, _ in x })
                }
                DataSource<TGSettingsResponse>.set(settings)
                settingsCache = settings
            }
        }
	}
    
    open func isUrlWhitelisted(_ url: String) -> Bool {
        let parsedUrl = URL(string: url)
        if let host = parsedUrl?.host {
            if host.contains("telegram.org") || host.contains("cloudveil.org") {
                return true
            }
        }
        return false
    }
	
    open func isAvailable(groupID: NSInteger) -> Bool? {
        var res: Bool?
        self.accessQueue.sync {
            res = settings?.access?.groups?["\(groupID)"]
        }
		return res
	}
	
	open func isAvailable(channelID: NSInteger) -> Bool? {
        var res: Bool?
        self.accessQueue.sync {
            res = settings?.access?.channels?["\(channelID)"]
        }
		return res
	}
    
	open func isAvailable(botID: NSInteger) -> Bool? {
		if SecurityStaticSettings.disableBots {
			return false
		}
        var res: Bool?
        self.accessQueue.sync {
            res = settings?.access?.bots?["\(botID)"]
        }
		return res
	}
    
    open func isAvailable(stickerId: NSInteger) -> Bool? {
        if disableStickers {
            return false
        }
        
        var res: Bool?
        self.accessQueue.sync {
            res = settings?.access?.stickers?["\(stickerId)"]
        }
        return res
    }
	
	open func isBotAvailable(botID: NSInteger) -> Bool {
        return isAvailable(botID: botID) ?? false
	}
    
    open func isStickerAvailable(stickerId: NSInteger) -> Bool {
        return isAvailable(stickerId: stickerId) ?? false
    }
	
	open func isConversationAvailable(conversationId: NSInteger) -> Bool? {
        var res: Bool?
        if let avail = isAvailable(botID: conversationId) {
            res = (res ?? false) || avail
        }
        if let avail = isAvailable(channelID: -conversationId) {
            res = (res ?? false) || avail
        }
        if let avail = isAvailable(groupID: -conversationId) {
            res = (res ?? false) || avail
        }
		
		return res
	}
	
	open func isConversationCheckedOnServer(conversationId: NSInteger, channelId: NSInteger) -> Bool {
		var res = false
        self.accessQueue.sync {
            guard let settings = settings else {
                res = true
                return
            }

            guard let access = settings.access else {
                return
            }

            let haveGroup = access.groups?["\(channelId)"] != nil
            let haveChannel = access.channels?["\(channelId)"] != nil
            let haveBot = access.bots?["\(conversationId)"] != nil

            res = haveGroup || haveChannel || haveBot
        }
		return res
	}
	
	open func replayRequestWithGroup(group: TGRow) {
		if let dictArray = lastRequest?.groups {
            if let _ = dictArray.firstIndex(where: {$0.objectID == group.objectID}) {
                notifyObserbers()
				return
			}
		}
		
		lastRequest?.groups.append(group)
		
		self.sengSettingsRequest()
	}
	
	open func replayRequestWithChannel(channel: TGRow) {
		if let dictArray = lastRequest?.channels {
            if let _ = dictArray.firstIndex(where: {$0.objectID == channel.objectID}) {
                notifyObserbers()
				return
			}
		}
		
		lastRequest?.channels.append(channel)
		
		self.sengSettingsRequest()
	}
	
	open func replayRequestWithBot(bot: TGRow) {
		if let dictArray = lastRequest?.bots {
			if let _ = dictArray.firstIndex(where: {$0.objectID == bot.objectID}) {
                notifyObserbers()
				return
			}
		}
		
		lastRequest?.bots.append(bot)
		
		self.sengSettingsRequest()
	}
	
	open func showFirstRunPopup(_ viewController: UIViewController) {
		if !wasFirstLoaded {
			wasFirstLoaded = true
			
			let alert = UIAlertController(title: "CloudVeil!", message: "CloudVeil Messenger uses a server based system to control access to Bots, Channels, and Groups and other policy rules. This is used to block unacceptable content. Your Telegram id and list of channels, bots, and groups will be sent to our system to allow this to work. We do not have access to your messages themselves.", preferredStyle: .alert)
			alert.addAction(.init(title: "OK", style: .default, handler: nil))
			
			viewController.present(alert, animated: false)
		}
	}
    
    
    open func notifyObserbers() {
        for observer in self.observers {
            observer()
        }
        self.observers.removeAll()
    }
	
	open func appendObserver(obs: @escaping () -> ()) {
		observers.append(obs)
	}
	
	open func clearObservers() {
		observers.removeAll()
	}
}
			
