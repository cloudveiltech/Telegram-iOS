//
//  ServerConstant.swift
//
//
//  Created by Dmitriy Virych on 3/28/17.
//  Copyright © 2017 Requestum. All rights reserved.
//

import UIKit


enum ServerConstant: String {
    
    //  MARK: - Cases
    
    case settings = "settings"
 
    
    // MARK: - Properties
    
    static let baseUrl = "https://manage.cloudveil.org/api/v1/"
    static let serverAPIUrl = baseUrl + "messenger/"
    static let actionCheckChannels = "org.cloudveil.messenger.service.check.channels"
}
