//
//  MainController.swift
//  SecurityManager
//
//  Created by Dmitriy Virych on 3/2/18.
//  Copyright © 2018 Requestum. All rights reserved.
//

import Foundation

import Alamofire
import UIKit

open class MainController: NSObject {
	public struct SecurityStaticSettings {
		public static let disableGlobalSearch = true
		public static let disableYoutubeVideoEmbedding = true
		public static let disableInAppBrowser = true
		public static let disableAutoPlayGifs = true
		public static let disablePayments = true
		public static let disableBots = false
		public static let disableInlineBots = true
	}
	
	
	public static let shared = MainController()
	
	
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
        self.accessQueue.sync {
            if settingsCache != nil {
                resp = settingsCache
            } else {
                settingsCache = DataSource<TGSettingsResponse>.value(mapper: mapper)
                resp = settingsCache
            }
        }
		return resp
	}
    
    public var needOrganizationChange: Bool {
        return settings?.organization?.needChange ?? false
    }
    
	public var disableStickers: Bool {
		return settings?.disableSticker ?? false
	}
	public var disableBio: Bool {
		return settings?.disableBio ?? false
	}
	public var disableBioChange: Bool {
		return settings?.disableBioChange ?? false
	}
	public var disableProfilePhoto: Bool {
		return settings?.disableProfilePhoto ?? false
	}
	public var disableProfilePhotoChange: Bool {
		return settings?.disableProfilePhotoChange ?? false
	}
	public var isSecretChatAvailable: Bool {
		return settings?.secretChat ?? false
	}
		
	public var disableProfileVideo: Bool {
		return settings?.disableProfileVideo ?? false
	}
	public var disableProfileVideoChange: Bool {
		return settings?.disableProfileVideoChange ?? false
	}
	
	public var isInChatVideoRecordingEnabled: Bool {
		return settings?.inputToggleVoiceVideo ?? false
	}
		
	public var profilePhotoLimit: Int {
		var v = Int(settings?.profilePhotoLimit ?? "-1")!
		if v < 0 {
			return Int.max
		} else if v == 0 {
			v = 1
		}
		return v
	}
		
	
	public var secretChatMinimumLength: NSInteger {
		
		if let lenghtStr = settings?.secretChatMinimumLength {
			return Int(lenghtStr) ?? -1
		}
		
		return -1
	}
	
	private func sengSettingsRequest() {
        if MainController.shared.lastRequest == nil {
            return
        }
		NSLog("Downloading settings")
		SecurityManager.shared.getSettings(withRequest: MainController.shared.lastRequest!) { (resp) in
			MainController.shared.saveSettings(resp)
		}
	}
	
	open func getSettings(groups: [TGRow] = [], bots: [TGRow] = [], channels: [TGRow] = []) {
		let request = TGSettingsRequest(JSON: [:])!
		request.id = TGUserController.shared.getUserID()
		request.userName = TGUserController.shared.getUserName() as String
		request.phoneNumber = TGUserController.shared.getUserPhoneNumber() as String
        request.groups = SyncArray<TGRow>(groups)
		request.bots = SyncArray<TGRow>(bots)
		request.channels = SyncArray<TGRow>(channels)
        
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
		if settings != nil {
			DataSource<TGSettingsResponse>.set(settings)
			settingsCache = settings
		}
		for observer in observers {
			observer()
		}
		observers.removeAll()
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
	
	open func isGroupAvailable(groupID: NSInteger) -> Bool {
		if let dictArray = settings?.access?.groups {
            if let index = dictArray.flatMap({ $0.keys }).firstIndex(where: { $0 == "\(groupID)" }) {
				return dictArray[index]["\(groupID)"] ?? false
			}
		}
		
		return true
	}
    
    open func isStickerAvailable(stickerId: NSInteger) -> Bool {
        if let dictArray = settings?.access?.stickers {
            if let index = dictArray.flatMap({ $0.keys }).firstIndex(where: { $0 == "\(stickerId)" }) {
                return dictArray[index]["\(stickerId)"] ?? false
            }
        }
        
        return true
    }
	
	open func isChannelAvailable(channelID: NSInteger) -> Bool {
		if let dictArray = settings?.access?.channels {
            if let index = dictArray.flatMap({ $0.keys }).firstIndex(where: { $0 == "\(channelID)" }) {
				return dictArray[index]["\(channelID)"] ?? false
			}
		}
		
		return true
	}
	
	open func isBotAvailable(botID: NSInteger) -> Bool {
		if SecurityStaticSettings.disableBots {
			return false
		}
        
		if let dictArray = settings?.access?.bots {
            if let index = dictArray.flatMap({ $0.keys }).firstIndex(where: { $0 == "\(botID)" }) {
				return dictArray[index]["\(botID)"] ?? false
			}
		}
		return true
	}
	
	
	open func isConversationAvailable(conversationId: NSInteger) -> Bool {
		if !isBotAvailable(botID: conversationId) {
			return false
		}
		
		if !isChannelAvailable(channelID: -conversationId) {
			return false
		}
		
		if !isGroupAvailable(groupID: -conversationId) {
			return false
		}
		
		return true
	}
	
	open func isConversationCheckedOnServer(conversationId: NSInteger, channelId: NSInteger) -> Bool {
		if settings == nil {
			print("settings is nil")
			return true
		} else {
			print("settings is ok")
		}
		if let dictArray = settings?.access?.groups {
			if isIdInDict(dictArray: dictArray, conversationId: channelId) {
				return true
			}
		}
		
		if let dictArray = settings?.access?.channels {
			if isIdInDict(dictArray: dictArray, conversationId: channelId) {
				return true
			}
		}
		
		if let dictArray = settings?.access?.bots {
			if isIdInDict(dictArray: dictArray, conversationId: conversationId) {
				return true
			}
		}
		
		
		return false
	}
	
	private func isIdInDict(dictArray: [[String:Bool]], conversationId: NSInteger) -> Bool {
        if let index = dictArray.flatMap({ $0.keys }).firstIndex(where: { $0 == "\(conversationId)" }) {
			return true
		}
		return false
	}
	
	open func replayRequestWithGroup(group: TGRow) {
		if let dictArray = lastRequest?.groups {
            if let index = dictArray.firstIndex(where: {$0.objectID == group.objectID}) {
				return
			}
		}
		
		lastRequest?.groups.append(group)
		
		self.sengSettingsRequest()
	}
	
	open func replayRequestWithChannel(channel: TGRow) {
		if let dictArray = lastRequest?.channels {
            if let index = dictArray.firstIndex(where: {$0.objectID == channel.objectID}) {
				return
			}
		}
		
		lastRequest?.channels.append(channel)
		
		self.sengSettingsRequest()
	}
	
	open func replayRequestWithBot(bot: TGRow) {
		if let dictArray = lastRequest?.bots {
			if let index = dictArray.firstIndex(where: {$0.objectID == bot.objectID}) {
				return
			}
		}
		
		lastRequest?.bots.append(bot)
		
		self.sengSettingsRequest()
	}
	
	open func firstRunPopup(at viewController: UIViewController) {
		if !wasFirstLoaded {
			wasFirstLoaded = true
			
			let alert = UIAlertController(title: "CloudVeil!", message: "CloudVeil Messenger uses a server based system to control access to Bots, Channels, and Groups and other policy rules. This is used to block unacceptable content. Your Telegram id and list of channels, bots, and groups will be sent to our system to allow this to work. We do not have access to your messages themselves.", preferredStyle: .alert)
			alert.addAction(.init(title: "OK", style: .default, handler: nil))
			
			viewController.present(alert, animated: false)
		}
	}
	
	open func appendObserver(obs: @escaping () -> ()) {
		observers.append(obs)
	}
	
	open func clearObservers() {
		observers.removeAll()
	}
}
			
