//
//  MainController.swift
//  SecurityManager
//
//  Created by Dmitriy Virych on 3/2/18.
//  Copyright © 2018 Requestum. All rights reserved.
//

import Foundation

import ObjectMapper
import Alamofire

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

    
     open static let shared = MainController()
    
    
    // MARK: - Properties
    private var blockedImageDataCache: Data?
    private let mapper = Mapper<TGSettingsResponse>()
    private var observers: [() -> ()] = []
    internal var lastRequest: TGSettingsRequest? = nil
    
    private let kWasFirstLoaded = "wasFirstLoaded"
    private var wasFirstLoaded: Bool {
        get { return UserDefaults.standard.bool(forKey: kWasFirstLoaded) }
        set { UserDefaults.standard.set(newValue, forKey: kWasFirstLoaded) }
    }
    
    private var settings: TGSettingsResponse? {
        return DataSource<TGSettingsResponse>.value(mapper: mapper)
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
    
     public var isInChatVideoRecordingEnabled: Bool {
        return settings?.inputToggleVoiceVideo ?? false
    }
    
     public var blockedImageUrl: String {
        return settings?.blockedImageResourceUrl ?? ""
    }
    
     public var blockedImageData: Data? {
        if blockedImageDataCache != nil {
            return blockedImageDataCache
        }
        if let url = URL(string: blockedImageUrl) {
            if let data = try? Data(contentsOf:url) {
                blockedImageDataCache = data
                return data
            }
        }
        return nil
    }
    
   
    
     public var secretChatMinimumLength: NSInteger {
        
        if let lenghtStr = settings?.secretChatMinimumLength {
            return Int(lenghtStr) ?? -1
        }
        
        return -1
    }
    
    // MARK: - Actions
    let getSettingsDebounced = Debouncer(delay: 0.5) {
        if MainController.shared.lastRequest == nil {
            return
        }
        
        NSLog("Settings load start\n");
        NSLog("\(MainController.shared.lastRequest?.toJSON())")
        
        SecurityManager.shared.getSettings(withRequest: MainController.shared.lastRequest!) { (resp) in
            MainController.shared.saveSettings(resp)
            let _ = MainController.shared.blockedImageData
        }
    }
    
     open func getSettings(groups: [TGRow] = [], bots: [TGRow] = [], channels: [TGRow] = []) {
        let request = TGSettingsRequest(JSON: [:])!
        request.id = TGUserController.shared.getUserID()
        request.userName = TGUserController.shared.getUserName() as String
        request.phoneNumber = TGUserController.shared.getUserPhoneNumber() as String
        request.groups = groups
        request.bots = bots
        request.channels = channels
        
        if let lastReq = self.lastRequest, TGSettingsRequest.compareRequests(lhs: lastReq, rhs: request) {
            NSLog("No changes, didn't load settings");
            return
        }
        
        self.lastRequest = request
        getSettingsDebounced.call()
    }
    
    private func saveSettings(_ settings: TGSettingsResponse?) {
        DataSource<TGSettingsResponse>.set(settings)
        for observer in observers {
            observer()
        }
        observers.removeAll()
    }
    
     open func isGroupAvailable(groupID: NSInteger) -> Bool {
        if let dictArray = settings?.access?.groups {
            if let index = dictArray.flatMap({ $0.keys }).index(where: { $0 == "\(groupID)" }) {
                return dictArray[index]["\(groupID)"] ?? false
            }
        }
        
        return true
    }
    
     open func isChannelAvailable(channelID: NSInteger) -> Bool {
        if let dictArray = settings?.access?.channels {
            if let index = dictArray.flatMap({ $0.keys }).index(where: { $0 == "\(channelID)" }) {
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
            if let index = dictArray.flatMap({ $0.keys }).index(where: { $0 == "\(botID)" }) {
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
        if let index = dictArray.flatMap({ $0.keys }).index(where: { $0 == "\(conversationId)" }) {
            return true
        }
        return false
    }
    
     open func replayRequestWithGroup(group: TGRow) {
        if let dictArray = lastRequest?.groups {
            if let index = dictArray.index(where: {$0.objectID == group.objectID}) {
                return
            }
        }
        
        lastRequest?.groups.append(group)
        
        print("Settings load start\n");
        getSettingsDebounced.call()
    }
    
     open func replayRequestWithChannel(channel: TGRow) {
        if let dictArray = lastRequest?.channels {
             if let index = dictArray.index(where: {$0.objectID == channel.objectID}) {
                return
            }
        }
        
        lastRequest?.channels.append(channel)
        
        print("Settings load start\n");
        getSettingsDebounced.call()
    }
    
     open func replayRequestWithBot(bot: TGRow) {
        if let dictArray = lastRequest?.bots {
            if let index = dictArray.index(where: {$0.objectID == bot.objectID}) {
                return
            }
        }
        
        lastRequest?.bots.append(bot)
        
        print("Settings load start\n");
        getSettingsDebounced.call()
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
}
