//
//  TGSettingsRequest.swift
//  SecurityManager
//
//  Created by DimaVirych on 03.03.18.
//  Copyright © 2018 Requestum. All rights reserved.
//

import UIKit

import ObjectMapper

public class TGSettingsRequest: Mappable, Equatable {
    // MARK: - Properties
    
    public private(set) var id: Int64?
    public var phoneNumber: String?
    public var userName: String?
    public var groups: [TGRow] = []
    public var channels: [TGRow] = []
    public var bots: [TGRow] = []
    public var stickers: [TGRow] = []
    public private(set) var clientOsType = "iOS"
    public private(set) var clientSessionId: String
    public private(set) var clientVersionCode: String
    public private(set) var clientVersionName: String
    
    public init(userId: Int64? = nil, sessionId: String? = nil, groups: [TGRow] = [], bots: [TGRow] = [], channels: [TGRow] = [], stickers: [TGRow] = []) {
        self.id = userId
        if self.id == nil {
            var id = Int64()
            var userName = ""
            var phoneNumber = ""
            TGUserController.withLock({
                id = Int64($0.getUserID())
                userName = $0.getUserName() as String
                phoneNumber = $0.getUserPhoneNumber() as String
            })
            self.id = id
            self.userName = userName
            self.phoneNumber = phoneNumber
        }
        self.clientSessionId = sessionId ?? Self.getClientId(self.id!)
        let dictionary = Bundle.main.infoDictionary!
        self.clientVersionCode = dictionary["CFBundleVersion"] as! String
        self.clientVersionName = dictionary["CFBundleShortVersionString"] as! String
        self.groups = groups
        self.channels = channels
        self.bots = bots
        self.stickers = stickers
    }

    private static func getClientId(_ userId: Int64) -> String {
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

    public static func == (lhs: TGSettingsRequest, rhs: TGSettingsRequest) -> Bool {
        return lhs.id == rhs.id &&
            lhs.phoneNumber == rhs.phoneNumber &&
            lhs.userName == rhs.userName &&
            lhs.groups == rhs.groups &&
            lhs.channels == rhs.channels &&
            lhs.bots == rhs.bots &&
            lhs.stickers == rhs.stickers
    }

    // MARK: Mappable
    
    public required convenience init?(map: Map) {
        self.init()
    }
    
    public func mapping(map: Map) {
        id <- map["user_id"]
        phoneNumber <- map["user_phone"]
        userName <- map["user_name"]
        groups <- map["groups"]
        channels <- map["channels"]
        bots <- map["bots"]
        stickers <- map["stickers"]
        clientOsType <- map["client_os_type"]
        clientSessionId <- map["client_session_id"]
        clientVersionCode <- map["client_version_code"]
        clientVersionName <- map["client_version_name"]
    }
}
