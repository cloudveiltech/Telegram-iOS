//
//  DataSource.swift
//  meetrip
//
//  Created by Dmitriy Virych on 7/11/16.
//  Copyright © 2016. All rights reserved.
//
import Foundation

// MARK: - DataStorage
class DataSource<T: Mappable> {
    
    
    // MARK: - User Defaults
    
    class func value(forKey: String) -> Any? {
        if let userDefaults = UserDefaults(suiteName: "group.com.cloudveil.CloudVeilMessenger") {
            if let v = userDefaults.value(forKey: forKey) {
                return v
            }
            return UserDefaults.standard.value(forKey: forKey)//fallback
        }
        return nil
    }
    
    class func set(_ value: Any?, forKey: String) {
        if let userDefaults = UserDefaults(suiteName: "group.com.cloudveil.CloudVeilMessenger") {
            userDefaults.set(value, forKey: forKey)
            userDefaults.synchronize()
        }
    }
    
    
    // MARK: - Mappable single object
    
    class func set(_ value: T?, forKey: String = String(describing: T.self)) {
        
        guard let v = value else {
            return set(value, forKey: forKey)
        }
        
        set(Mapper<T>().toJSONString(v), forKey: forKey)
    }
    
    class func value(forKey: String = String(describing: T.self), mapper: Mapper<T> = Mapper<T>()) -> T? {
        
        if let jsonString = value(forKey: forKey) as? String {
            return mapper.map(JSONString: jsonString)
        }
        return nil
    }
    
    
    // MARK: - Mappable objects array
    
    class func set(_ value: [T]?, forKey: String = String(describing: T.self)) {
        
        guard let v = value else {
            return set(value, forKey: forKey)
        }
        set(Mapper().toJSONString(v), forKey: forKey)
    }
    
    class func array(forKey: String = String(describing: T.self), mapper: Mapper<T> = Mapper<T>()) -> [T]? {
        if let jsonString = value(forKey: forKey) as? String {
            return mapper.mapArray(JSONString: jsonString)
        }
        return nil
    }
}
