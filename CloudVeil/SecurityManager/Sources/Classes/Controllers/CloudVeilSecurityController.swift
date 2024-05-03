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

fileprivate let SETTINGS_URL = URL(string: "https://messenger.cloudveil.org/api/v1/messenger/settings")!

public class UserBlacklist {
    private var cache: [Int64] = []
    private let key = "userBlacklist"
    
    fileprivate init() {
        cache = UserDefaults.standard.array(forKey: key)?.compactMap { $0 as? Int64 } ?? []
    }

    fileprivate func clear() {
        cache = []
        UserDefaults.standard.set(cache, forKey: key)
    }

    fileprivate func contains(_ id: Int64) -> Bool {
        return cache.contains(id)
    }

    fileprivate func remove(_ id: Int64) {
        cache.removeAll(where: { $0 == id })
        UserDefaults.standard.set(cache, forKey: key)
    }

    fileprivate func blacklist(_ id: Int64) {
        cache.append(id)
        UserDefaults.standard.set(cache, forKey: key)
    }
}

open class CloudVeilSecurityController: NSObject {
    private let SUPPORT_BOT_ID = 689684671
    
	public struct SecurityStaticSettings {
		public static let disableGlobalSearch = true
		public static let disableYoutubeVideoEmbedding = true
		public static let disableInAppBrowser = true
		public static let disableAutoPlayGifs = true
		public static let disablePayments = true
		public static let disableBots = false
		public static let disableInlineBots = true
        public static let disableGifs = true
	}
	
	public static let shared = CloudVeilSecurityController()
	
	private let mapper = Mapper<TGSettingsResponse>()
	
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
    public var disableStories: Bool {
        var res = false
        self.accessQueue.sync {
            res = settings?.disableStories ?? false
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
		
    public var disableEmojiStatus: Bool {
        var res = false
        self.accessQueue.sync {
            res = settings?.disableEmojiStatus ?? false
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


    // MARK - Networking
    private let netQueue = DispatchQueue(label: "CloudVeilNetwork")
	private var nextRequest: TGSettingsRequest? = nil
	private var lastRequestTime: TimeInterval = 0.0
	private let UPDATE_INTERVAL = 10*60.0 //10min

    // Blacklist of Telegram users who we shouldn't sent settings requests for.
    private let userBlacklist = UserBlacklist()

    public func clearUserBlacklist() {
        self.netQueue.async {
            self.userBlacklist.clear()
        }
    }

    // temporary: for use by web ui account delete only
    public func blacklistUser(_ userId: Int64) {
        self.netQueue.sync {
            self.userBlacklist.blacklist(userId)
        }
    }

    // temporary: for use by web ui account delete only
    public func withDeleteAccountUrl(_ userId: Int64, completion: @escaping (URL) -> Void) {
        let req = TGSettingsRequest(userId: userId)
        let task = self.sendSettingsRequest(req, ignoreBlacklist: true) { resp in
            if let resp = resp, let str = resp.removeAccountUrl, let url = URL(string: str) {
                completion(url)
            }
        }
        task?.resume()
    }

    private var getSettingsTask: URLSessionTask? = nil

    public func deleteAccount(_ tgUserID: Int64, onSucceed: @escaping () -> Void, onFail: @escaping () -> Void) {
        self.netQueue.async {
            self.userBlacklist.blacklist(tgUserID)
            let req = TGSettingsRequest(userId: tgUserID)
            let task = self.sendSettingsRequest(req, ignoreBlacklist: true) { resp in
                guard let resp = resp, let str = resp.removeAccountUrl, let url = URL(string: str) else {
                    self.netQueue.async { self.userBlacklist.remove(tgUserID) }
                    onFail()
                    return
                }
                var req = URLRequest(url: url)
                req.httpMethod = "GET"
                let task = URLSession.shared.dataTask(with: req) { data, response, error in
                    guard let resp = response, let resp = resp as? HTTPURLResponse else {
                        self.netQueue.async { self.userBlacklist.remove(tgUserID) }
                        onFail()
                        return
                    }
                    if resp.statusCode < 200 || resp.statusCode >= 300 {
                        self.netQueue.async { self.userBlacklist.remove(tgUserID) }
                        onFail()
                        return
                    }
                    onSucceed()
                }
                task.resume()
            }
            task?.resume()
        }
    }

    // Must only be called from code running on netQueue
	private func sendSettingsRequest(_ body: TGSettingsRequest) {
        if let state = self.getSettingsTask?.state, state != .completed && state != .canceling {
            return
        }
        let task = self.sendSettingsRequest(body) { response in
            self.saveSettings(response)
            self.netQueue.async {
                if let nextReq = self.nextRequest, nextReq != body {
                    self.sendSettingsRequest(nextReq)
                }
            }
        }
        if let task = task {
            task.resume()
            self.getSettingsTask = task
        }
	}

    private func sendSettingsRequest(_ body: TGSettingsRequest, ignoreBlacklist: Bool = false, _ callback: @escaping (TGSettingsResponse?) -> Void) -> URLSessionTask? {
        if let id = body.id, self.userBlacklist.contains(Int64(id)) && !ignoreBlacklist {
            return nil
        }
        var req = URLRequest(url: SETTINGS_URL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        req.httpMethod = "POST"
        req.httpBody = body.toJSONString(prettyPrint: false)!.data(using: .utf8)!
        return URLSession.shared.dataTask(with: req) { data, response, error in
            if let data = data, let str = String(data: data, encoding: .utf8) {
                callback(TGSettingsResponse(JSONString: str))
            } else {
                callback(nil)
            }
        }
    }

    open func getSettings(groups: [TGRow] = [], bots: [TGRow] = [], channels: [TGRow] = [], stickers: [TGRow] = []) {
        self.netQueue.async {
            let request = TGSettingsRequest(
                sessionId: self.nextRequest?.clientSessionId,
                groups: groups, bots: bots, channels: channels, stickers: stickers)

            if let nextReq = self.nextRequest,  nextReq == request {
                let now = Date().timeIntervalSince1970
                if now - self.lastRequestTime < self.UPDATE_INTERVAL {
                    return
                }
            }

            self.lastRequestTime = Date().timeIntervalSince1970
            self.nextRequest = request
            self.sendSettingsRequest(request)
        }
    }

    public func replayRequestWith(group: TGRow? = nil, channel: TGRow? = nil, bot: TGRow? = nil) {
        self.netQueue.async {
            guard let nextReq = self.nextRequest else {
                return
            }

            var send = false
            if let g = group, !nextReq.groups.contains(g) {
                nextReq.groups.append(g)
                send = true
            }
            if let c = channel, !nextReq.channels.contains(c) {
                nextReq.channels.append(c)
                send = true
            }
            if let b = bot, !nextReq.bots.contains(b) {
                nextReq.bots.append(b)
                send = true
            }

            if send {
                self.nextRequest = nextReq
                self.sendSettingsRequest(nextReq)
            }
        }
    }

    open func replayRequestWithGroup(group: TGRow) {
        self.replayRequestWith(group: group)
    }

    open func replayRequestWithChannel(channel: TGRow) {
        self.replayRequestWith(channel: channel)
    }

    open func replayRequestWithBot(bot: TGRow) {
        self.replayRequestWith(bot: bot)
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
        if botID == self.SUPPORT_BOT_ID {
            return true
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
	
	open func showFirstRunPopup(_ viewController: UIViewController) {
		if !wasFirstLoaded {
			wasFirstLoaded = true
			
			let alert = UIAlertController(title: "CloudVeil!", message: "CloudVeil Messenger uses a server based system to control access to Bots, Channels, and Groups and other policy rules. This is used to block unacceptable content. Your Telegram id and list of channels, bots, and groups will be sent to our system to allow this to work. We do not have access to your messages themselves.", preferredStyle: .alert)
			alert.addAction(.init(title: "OK", style: .default, handler: nil))
			
			viewController.present(alert, animated: false)
		}
	}
}
