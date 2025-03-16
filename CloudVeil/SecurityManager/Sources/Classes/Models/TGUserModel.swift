//
//  TGUserModel.swift
//  SecurityManager
//
//  Created by DimaVirych on 03.03.18.
//  Copyright © 2018 Requestum. All rights reserved.
//

import UIKit

class TGUserModel1: NSObject {
    
    // MARK: - Constants
    
    static let kTGUserModelId = "TGUserModelId"
    static let kTGUserModelPhoneNumber = "TGUserModelPhoneNumber"
    static let kTGUserModelUserName = "TGUserModelUserName"
    static let kTGUserModelUserNames = "TGUserModelUserNames"
    
    
    // MARK: - Properties
    
    public static private(set) var id: NSInteger {
        
        set { UserDefaults.standard.set(newValue, forKey: kTGUserModelId) }
        get { return UserDefaults.standard.object(forKey: kTGUserModelId) as? NSInteger ?? 0}
    }
    
    public static private(set) var phoneNumber: NSString {
        
        set { UserDefaults.standard.set(newValue, forKey: kTGUserModelPhoneNumber) }
        get { return (UserDefaults.standard.object(forKey: kTGUserModelPhoneNumber) as? NSString ?? "") }
    }
    
    public static private(set) var userName: NSString {
        
        set { UserDefaults.standard.set(newValue, forKey: kTGUserModelUserName) }
        get { return (UserDefaults.standard.object(forKey: kTGUserModelUserName) as? NSString ?? "") }
    }
    
    public static private(set) var userNames: [String] {
        
        set { UserDefaults.standard.set(newValue, forKey: kTGUserModelUserNames) }
        get { return (UserDefaults.standard.array(forKey: kTGUserModelUserNames) as? [String] ?? []) }
    }
    
    
    // MARK: - Actions
    
    public static func set(userID: NSInteger) {
        id = userID
    }
    
    public static func set(userPhoneNumber phone: NSString) {
        phoneNumber = phone
    }
    
    public static func set(userName name: NSString) {
        userName = name
    }
    
    public static func set(userNames names: [String]) {
        userNames = names
    }
}
