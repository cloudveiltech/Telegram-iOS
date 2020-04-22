//
//  TGRow.swift
//  SecurityManager
//
//  Created by DimaVirych on 03.03.18.
//  Copyright © 2018 Requestum. All rights reserved.
//

import UIKit

import ObjectMapper

@objc public class TGRow: NSObject, Mappable {
    
    // MARK: - Properties
    
    public var objectID: NSInteger = -1
    public var title: NSString = ""
    public var userName: NSString = ""
    public var isMegagroup: Bool?
    public var isPublic: Bool?
    
    public override init() {}
    // MARK: Mappable
    public required init?(map: Map) { }
    
    public func mapping(map: Map) {
        objectID <- map["id"]
        title <- map["title"]
        userName <- map["user_name"]
        isMegagroup <- map["is_megagroup"]
        isPublic <- map["is_public"]
    }
    
    static func compareArrays(lhs: [TGRow], rhs: [TGRow]) -> Bool {
        if lhs.count == 0 && rhs.count == 0 {
            return true
        }
        if lhs.count == 0 && rhs.count != 0 {
            return false
        }
        if lhs.count != 0 && rhs.count == 0 {
            return false
        }
        let l = lhs.sorted(by: { $0.objectID > $1.objectID })
        let r = rhs.sorted(by: { $0.objectID > $1.objectID })
        return l.elementsEqual(r, by: { $0.objectID == $1.objectID })
    }
}
