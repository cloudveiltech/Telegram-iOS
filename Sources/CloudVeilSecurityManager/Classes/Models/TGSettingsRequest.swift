//
//  TGSettingsRequest.swift
//  SecurityManager
//
//  Created by DimaVirych on 03.03.18.
//  Copyright © 2018 Requestum. All rights reserved.
//

import UIKit

open class TGSettingsRequest: NSObject, Mappable {
 
    // MARK: - Properties
    
    public var id: Int?
    public var phoneNumber: String?
    public var userName: String?
    public var groups = SyncArray<TGRow>()
    public var channels = SyncArray<TGRow>()
    public var bots = SyncArray<TGRow>()
    
    
    // MARK: Mappable
    
    public required init?(map: Map) { }
    
    public func mapping(map: Map) {        
        id <- map["user_id"]
        phoneNumber <- map["user_phone"]
        userName <- map["user_name"]
        groups.array <- map["groups"]
        channels.array <- map["channels"]
        bots.array <- map["bots"]
    }
    
    static func compareRequests(lhs: TGSettingsRequest, rhs: TGSettingsRequest) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if lhs.phoneNumber != rhs.phoneNumber {
            return false
        }
        if lhs.userName != rhs.userName {
            return false
        }
        
      
        if !TGRow.compareArrays(lhs: lhs.groups, rhs: rhs.groups) {
            return false
        }
        if !TGRow.compareArrays(lhs: lhs.channels, rhs: rhs.channels) {
            return false
        }
        if !TGRow.compareArrays(lhs: lhs.bots, rhs: rhs.bots) {
            return false
        }
        return true
    }
}
