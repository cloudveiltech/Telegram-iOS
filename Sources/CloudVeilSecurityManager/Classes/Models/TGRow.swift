//
//  TGRow.swift
//  SecurityManager
//
//  Created by DimaVirych on 03.03.18.
//  Copyright © 2018 Requestum. All rights reserved.
//

import UIKit


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
    
    static func compareArrays(lhs: SyncArray<TGRow>, rhs: SyncArray<TGRow>) -> Bool {
        if lhs.count == 0 && rhs.count == 0 {
            return true
        }
        if lhs.count == 0 && rhs.count != 0 {
            return false
        }
        if lhs.count != 0 && rhs.count == 0 {
            return false
        }
        
        for i in 0...lhs.count-1 {
            var found = false
            let itemL = lhs[i]
            for j in 0...rhs.count-1 {
                let itemR = rhs[j]
                if itemR.objectID == itemL.objectID {
                    found = true
                    break
                }
            }
            if !found {
                return false
            }
        }
        return true
    }
}
