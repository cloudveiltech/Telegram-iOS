//
//  TGUserController.swift
//  SecurityManager
//
//  Created by DimaVirych on 03.03.18.
//  Copyright © 2018 Requestum. All rights reserved.
//

import UIKit

@objc open class TGUserController: NSObject {
    
    // MARK: - Singleton
    
    @objc public static let shared = TGUserController()
    
    
    // MARK: - Actions
    
    @objc open func set(userID id: NSInteger) {
        TGUserModel1.set(userID: id)
    }
    
    @objc open func set(userPhoneNumber phone: NSString) {
        TGUserModel1.set(userPhoneNumber: phone)
    }
    
    @objc open func set(userName name: NSString) {
        TGUserModel1.set(userName: name)
    }
    
    @objc open func getUserID() -> NSInteger {
        return TGUserModel1.id
    }
    
    @objc open func getUserPhoneNumber() -> NSString {
        return TGUserModel1.phoneNumber
    }
    
    @objc open func getUserName() -> NSString {
        return TGUserModel1.userName
    }
}
