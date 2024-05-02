//
//  TGSettingsResponse.swift
//  SecurityManager
//
//  Created by DimaVirych on 03.03.18.
//  Copyright © 2018 Requestum. All rights reserved.
//

import UIKit

import ObjectMapper


class TGSettingsResponse: Mappable {
    
    // MARK: - Properties
    
    public var secretChat: Bool?
    public var secretChatMinimumLength: String?
    public var groups: [Int]?
    public var bots: [Int]?
    public var channels: [Int]?
    public var disableBio: Bool?
    public var disableBioChange: Bool?
    public var disableProfilePhoto: Bool?
    public var disableProfilePhotoChange: Bool?
	public var disableProfileVideo: Bool?
	public var disableProfileVideoChange: Bool?
    public var access: AccessObject?
    public var disableStories: Bool?
    public var disableSticker: Bool?
    public var disableStickers: Bool?
    public var disableStickersImage: String?
    public var manageUsers: Bool?
    public var inputToggleVoiceVideo: Bool?
    public var blockedImageResourceUrl: String?
    public var profilePhotoLimit: String?
    public var organization: Organization?
    public var updateRequired: Bool?
    public var removeAccountUrl: String?
    public var disableEmojiStatus: Bool?

    // MARK: FakeResponse

    public init(denyAll: Bool = false) {
        if denyAll {
            self.secretChat = false
            self.disableBio = true
            self.disableBioChange = true
            self.disableProfilePhoto = true
            self.disableProfilePhotoChange = true
            self.disableProfileVideo = true
            self.disableProfileVideoChange = true
            self.disableEmojiStatus = false
            self.disableSticker = true
            self.disableStickers = true
            self.manageUsers = false
            self.inputToggleVoiceVideo = false
            self.blockedImageResourceUrl = "data:text/html;base64,PGgzPkJsb2NrZWQ8L2gzPgo="
            self.organization = Organization()
            self.organization!.id = 23945601
            self.organization!.name = "FakeTestingOrg"
            self.organization!.needChange = false
            self.updateRequired = false
            self.removeAccountUrl = nil
        }
    }

    // MARK: Mappable
    
    public required init?(map: Map) { }
    
    public func mapping(map: Map) {
        profilePhotoLimit <- map["profile_photo_limit"]
        secretChat <- map["secret_chat"]
        secretChatMinimumLength <- map["secret_chat_minimum_length"]
        groups <- map["groups"]
        bots <- map["bots"]
        channels <- map["channels"]
        disableBio <- map["disable_bio"]
        disableBioChange <- map["disable_bio_change"]
        disableProfilePhoto <- map["disable_profile_photo"]
        disableProfilePhotoChange <- map["disable_profile_photo_change"]
        access <- map["access"]
        disableStories <- map["disable_stories"]
        disableSticker <- map["disable_sticker"]
        disableStickers <- map["disable_stickers"]
        disableStickersImage <- map["disable_stickers_image"]
        manageUsers <- map["manage_users"]
        inputToggleVoiceVideo <- map["input_toggle_voice_video"]
        blockedImageResourceUrl <- map["disable_stickers_image"]
		disableProfileVideo <- map["disable_profile_video"]
		disableProfileVideoChange <- map["disable_profile_video_change"]
        organization <- map["organization"]
        updateRequired <- map["update_required"]
        removeAccountUrl <- map["remove_account_url"]
        disableEmojiStatus <- map["disable_emoji_status"]
    }
}


class AccessObject: Mappable {
    
    // MARK: - Properties
    
    public var groups: [String: Bool]?
    public var bots: [String: Bool]?
    public var channels: [String: Bool]?
    public var stickers: [String: Bool]?
    public var users: [String: Bool]?
    
    public init() { }
    
    // MARK: Mappable
    
    public required init?(map: Map) { }
    
    public func mapping(map: Map) {
        let merge = ObjMerge<String, Bool>()
        groups <- (map["groups"], merge)
        bots <- (map["bots"], merge)
        channels <- (map["channels"], merge)
        stickers <- (map["stickers"], merge)
        users <- (map["users"], merge)
    }
}

class Organization: Mappable {
    public var id: Int?
    public var name: String?
    public var needChange: Bool?
    
    public init() { }
    
    public required init?(map: Map) { }
    
    public func mapping(map: Map) {
        id <- map["id"]
        name <- map["name"]
        needChange <- map["need_change"]
    }
}
