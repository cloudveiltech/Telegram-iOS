//
//  TGSettingsResponse.swift
//  SecurityManager
//
//  Created by DimaVirych on 03.03.18.
//  Copyright © 2018 Requestum. All rights reserved.
//

import UIKit


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
    public var disableSticker: Bool?
    public var disableStickers: Bool?
    public var disableStickersImage: String?
    public var manageUsers: Bool?
    public var inputToggleVoiceVideo: Bool?
    public var blockedImageResourceUrl: String?
    public var profilePhotoLimit: String?
    public var organization: Organization?
    
    
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
        disableSticker <- map["disable_sticker"]
        disableStickers <- map["disable_stickers"]
        disableStickersImage <- map["disable_stickers_image"]
        manageUsers <- map["manage_users"]
        inputToggleVoiceVideo <- map["input_toggle_voice_video"]
        blockedImageResourceUrl <- map["disable_stickers_image"]
		disableProfileVideo <- map["disable_profile_video"]
		disableProfileVideoChange <- map["disable_profile_video_change"]
        organization <- map["organization"]
    }
}


class AccessObject: Mappable {
    
    // MARK: - Properties
    
    public var groups: [[String: Bool]]?
    public var bots: [[String: Bool]]?
    public var channels: [[String: Bool]]?
    public var stickers: [[String: Bool]]?
    public var users: [[String: Bool]]?
    
    
    // MARK: Mappable
    
    public required init?(map: Map) { }
    
    public func mapping(map: Map) {
        
        groups <- map["groups"]
        bots <- map["bots"]
        channels <- map["channels"]
        stickers <- map["channels"]
        users <- map["channels"]
    }
}

class Organization: Mappable {
    public var id: Int?
    public var name: String?
    public var needChange: Bool?
    
    public required init?(map: Map) { }
    
    public func mapping(map: Map) {
        id <- map["id"]
        name <- map["name"]
        needChange <- map["need_change"]
    }
}
