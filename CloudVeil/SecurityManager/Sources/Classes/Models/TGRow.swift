//
//  TGRow.swift
//  SecurityManager
//
//  Created by DimaVirych on 03.03.18.
//  Copyright © 2018 Requestum. All rights reserved.
//

import UIKit

import ObjectMapper


public class TGRow: Mappable, Equatable {
    public var objectID: NSInteger = -1
    public var title: NSString = ""
    public var userNames: [String] = []
    public var isMegagroup: Bool?
    public var isPublic: Bool?
    public var isRestricted: Bool?
    public var isForum: Bool?
    public var isCreatorAdmin: Bool?
    public var migratedFromTelegramId: NSInteger = 0
    /// Unix time (seconds) of the most recent trustworthy info about this peer.
    /// Special values: `lastUpdateUntrustworthy` (-1), `lastUpdateUnknown` (0).
    public var lastUpdated: Int64 = TGRow.lastUpdateUnknown

    public static let lastUpdateUntrustworthy: Int64 = -1
    public static let lastUpdateUnknown: Int64 = 0

    public init() {}

    public required init?(map: Map) { }

    public static func == (lhs: TGRow, rhs: TGRow) -> Bool {
        return lhs.objectID == rhs.objectID
    }

    public func mapping(map: Map) {
        objectID <- map["id"]
        title <- map["title"]
        userNames <- map["user_names"]
        isMegagroup <- map["is_megagroup"]
        isPublic <- map["is_public"]
        isRestricted <- map["is_restricted"]
        isForum <- map["is_forum"]
        isCreatorAdmin <- map["is_creator_admin"]
        if (migratedFromTelegramId > 0) {
            migratedFromTelegramId <- map["migrated_from_telegram_id"]
        }
        lastUpdated <- map["last_updated"]
    }
}
