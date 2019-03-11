//
//  MainController.swift
//  SecurityManager
//
//  Created by Dmitriy Virych on 3/2/18.
//  Copyright © 2018 Requestum. All rights reserved.
//

import Foundation

import Alamofire

@objc open class MainController: NSObject {
    public struct SecurityStaticSettings {
        public static let disableGlobalSearch = true
        public static let disableYoutubeVideoEmbedding = true
        public static let disableInAppBrowser = true
        public static let disableAutoPlayGifs = true
        public static let disablePayments = true
        public static let disableBots = false
        public static let disableInlineBots = true
    }

    
    @objc open static let shared = MainController()
    
    
    // MARK: - Properties
    private var blockedImageDataCache: Data?
    private var observers: [() -> ()] = []
    internal var lastRequest: TGSettingsRequest? = nil
    
    private let kWasFirstLoaded = "wasFirstLoaded"
    private var wasFirstLoaded: Bool {
        get { return UserDefaults.standard.bool(forKey: kWasFirstLoaded) }
        set { UserDefaults.standard.set(newValue, forKey: kWasFirstLoaded) }
    }
    
    private var settings: TGSettingsResponse? {
        return DataSource<TGSettingsResponse>.value()
    }
    
    @objc public var disableStickers: Bool {
        return settings?.disableSticker ?? false
    }
    @objc public var disableBio: Bool {
        return settings?.disableBio ?? false
    }
    @objc public var disableBioChange: Bool {
        return settings?.disableBioChange ?? false
    }
    @objc public var disableProfilePhoto: Bool {
        return settings?.disableProfilePhoto ?? false
    }
    @objc public var disableProfilePhotoChange: Bool {
        return settings?.disableProfilePhotoChange ?? false
    }
    @objc public var isSecretChatAvailable: Bool {
        return settings?.secretChat ?? false
    }
    
    @objc public var isInChatVideoRecordingEnabled: Bool {
        return settings?.inputToggleVoiceVideo ?? false
    }
    
    @objc public var blockedImageUrl: String {
        return settings?.blockedImageResourceUrl ?? ""
    }
    
    @objc public var blockedImageData: Data? {
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
    
   
    
    @objc public var secretChatMinimumLength: NSInteger {
        
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
        SecurityManager.shared.getSettings(withRequest: MainController.shared.lastRequest!) { (resp) in
            MainController.shared.saveSettings(resp)
            let _ = MainController.shared.blockedImageData
        }
    }
    
    @objc open func getSettings(groups: [TGRow] = [], bots: [TGRow] = [], channels: [TGRow] = []) -> String {
        let request = TGSettingsRequest(JSON: [:])!
        request.id = TGUserController.shared.getUserID()
        request.userName = TGUserController.shared.getUserName() as String
        request.phoneNumber = TGUserController.shared.getUserPhoneNumber() as String
        request.groups = groups
        request.bots = bots
        request.channels = channels
        
        self.lastRequest = request
        print("Settings load start\n");
         getSettingsDebounced.call()
      
        
        let json = request.toJSON()
        print(json)
        return "\(json)"
    }
    
    private func saveSettings(_ settings: TGSettingsResponse?) {
        DataSource<TGSettingsResponse>.set(settings)
        for observer in observers {
            observer()
        }
        observers.removeAll()
    }
    
    @objc open func isGroupAvailable(groupID: NSInteger) -> Bool {
        if let dictArray = settings?.access?.groups {
            if let index = dictArray.flatMap({ $0.keys }).index(where: { $0 == "\(groupID)" }) {
                return dictArray[index]["\(groupID)"] ?? false
            }
        }
        
        return true
    }
    
    @objc open func isChannelAvailable(channelID: NSInteger) -> Bool {
        if let dictArray = settings?.access?.channels {
            if let index = dictArray.flatMap({ $0.keys }).index(where: { $0 == "\(channelID)" }) {
                return dictArray[index]["\(channelID)"] ?? false
            }
        }
        
        return true
    }
        
    @objc open func isBotAvailable(botID: NSInteger) -> Bool {
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
    
    
    @objc open func isConversationAvailable(conversationId: NSInteger) -> Bool {
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
    
    @objc open func isConversationCheckedOnServer(conversationId: NSInteger, channelId: NSInteger) -> Bool {
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
    
    @objc open func replayRequestWithGroup(group: TGRow) {
        if let dictArray = lastRequest?.groups {
            if let index = dictArray.index(where: {$0.objectID == group.objectID}) {
                return
            }
        }
        
        lastRequest?.groups.append(group)
        
        print("Settings load start\n");
        getSettingsDebounced.call()
    }
    
    @objc open func replayRequestWithChannel(channel: TGRow) {
        if let dictArray = lastRequest?.channels {
             if let index = dictArray.index(where: {$0.objectID == channel.objectID}) {
                return
            }
        }
        
        lastRequest?.channels.append(channel)
        
        print("Settings load start\n");
        getSettingsDebounced.call()
    }
    
    @objc open func replayRequestWithBot(bot: TGRow) {
        if let dictArray = lastRequest?.bots {
            if let index = dictArray.index(where: {$0.objectID == bot.objectID}) {
                return
            }
        }
        
        lastRequest?.bots.append(bot)
        
        print("Settings load start\n");
        getSettingsDebounced.call()
    }
    
    @objc open func firstRunPopup(at viewController: UIViewController) {
        if !wasFirstLoaded {
            wasFirstLoaded = true
            
            let alert = UIAlertController(title: "CloudVeil!", message: "CloudVeil Messenger uses a server based system to control access to Bots, Channels, and Groups and other policy rules. This is used to block unacceptable content. Your Telegram id and list of channels, bots, and groups will be sent to our system to allow this to work. We do not have access to your messages themselves.", preferredStyle: .alert)
            alert.addAction(.init(title: "OK", style: .default, handler: nil))
            
            viewController.present(alert, animated: true)
        }
    }
    
    @objc open func appendObserver(obs: @escaping () -> ()) {
        observers.append(obs)
    }
}
