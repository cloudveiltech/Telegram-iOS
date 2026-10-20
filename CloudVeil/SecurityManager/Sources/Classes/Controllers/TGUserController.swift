//
//  TGUserController.swift
//  SecurityManager
//
//  Created by DimaVirych on 03.03.18.
//  Copyright © 2018 Requestum. All rights reserved.
//

import Foundation

@objc open class TGUserController: NSObject {
    private static let lock = NSLock()
    private static let shared = TGUserController()
    private(set) static var didChangedUserID = true
    private(set) static var didChangedOrgID = true
    
    // MARK: - Singleton

    public static func withLock<R>(_ body: (TGUserController) throws -> R) rethrows -> R {
        return try Self.lock.withLock({ try body(Self.shared) })
    }
    
    public static var userID: Int {
        return Self.withLock({ $0.getUserID() })
    }
    
    public static var orgID: Int? {
        return Self.withLock({ $0.getOrgID() })
    }
    
    // MARK: - Actions
    
    // This set func should call from a Self.withLock completion block
    @objc open func set(userID id: NSInteger) {
        // Check if id has changed
        if TGUserModel1.id != id {
            TGUserController.didChangedUserID = true
        }
        TGUserModel1.set(userID: id)
    }
    
    // This set func should call from a Self.withLock completion block
    @objc open func set(orgID id: NSInteger) {
        // Check if id has changed
        if TGUserModel1.orgId != id {
            TGUserController.didChangedOrgID = true
        }
        TGUserModel1.set(orgID: id)
    }
    
    @objc open func set(userPhoneNumber phone: NSString) {
        TGUserModel1.set(userPhoneNumber: phone)
    }
    
    @objc open func set(userName name: NSString) {
        TGUserModel1.set(userName: name)
    }
    
    @objc open func set(userNames names: [String]) {
        TGUserModel1.set(userNames: names)
    }

    @objc open func set(clientLocale locale: String) {
        TGUserModel1.set(clientLocale: locale)
    }
    
    //acknowledge that cache has been updated in CloudVeilSecurityController
    @objc open func setCacheHasBeenUpdated() {
        TGUserController.didChangedUserID = false
        TGUserController.didChangedOrgID = false
    }
    
    @objc open func getUserID() -> NSInteger {
        return TGUserModel1.id
    }
    
    @objc open func getOrgID() -> NSInteger {
        return TGUserModel1.orgId
    }
    
    @objc open func getUserPhoneNumber() -> NSString {
        return TGUserModel1.phoneNumber
    }
    
    @objc open func getUserName() -> NSString {
        return TGUserModel1.userName
    }
    
    @objc open func getUserNames() -> [String] {
        return TGUserModel1.userNames
    }

    @objc open func getClientLocale() -> String {
        return TGUserModel1.clientLocale
    }
}
