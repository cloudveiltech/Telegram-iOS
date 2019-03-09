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
    
    @objc public var objectID: NSInteger = -1
    @objc public var title: NSString = ""
    @objc public var userName: NSString = ""
    
    public override init() {}
    // MARK: Mappable
    public required init?(map: Map) { }
    
    public func mapping(map: Map) {
        
        objectID <- map["id"]
        title <- map["title"]
        userName <- map["user_name"]
    }
}
