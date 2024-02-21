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
    public var userName: NSString = ""
    public var isMegagroup: Bool?
    public var isPublic: Bool?

    public init() {}

    public required init?(map: Map) { }

    public static func == (lhs: TGRow, rhs: TGRow) -> Bool {
        return lhs.objectID == rhs.objectID
    }

    public func mapping(map: Map) {
        objectID <- map["id"]
        title <- map["title"]
        userName <- map["user_name"]
        isMegagroup <- map["is_megagroup"]
        isPublic <- map["is_public"]
    }
}
