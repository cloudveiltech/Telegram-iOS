
import Foundation

import Alamofire
import ObjectMapper

extension DataResponse {
    
    func error() -> NSError? {
        
        guard success == false else {
            return nil
        }
        
        if result.error != nil {
            return (result.error! as NSError).with(dataResponse: self)
        }
        
        return NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "", NSLocalizedRecoverySuggestionErrorKey: message ?? ""])
    }
    
    func JSON() -> [String: Any]? {
        
        var JSON: [String : Any]?
        
        if let json = result.value as? [String: Any] {
            JSON = json
        } else if (data != nil), let json = try? JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as? [String : Any] {
            JSON = json
        }
        
        return JSON
    }
    
    func resultObject<T: Mappable>() -> T? {
        
        if let JSON = JSON() {
            if let obj = Mapper<T>().map(JSON: JSON) {
                return obj
            }
        }
        return nil
    }
    
    var message: String? {
        
        if let value = result.value as? [String: AnyObject] {
            if let message = value["message"] as? String {
                return message
            }
        }
        return nil
    }
    
    var success: Bool {
        
        guard result.error == nil else {
            return false
        }
        
        if let value = result.value as? [String: AnyObject] {
            if let success = value["success"] as? Bool {
                return success
            }
        }
        return true
    }
    
    func JSONArray() -> [[String: AnyObject]]? {
        return result.value as? [[String: AnyObject]]
    }
    
    func resultArray<T: Mappable>() -> [T]? {
        
        if let JSONArray = JSONArray() {
            let objs = Mapper<T>().mapArray(JSONArray: JSONArray)
            return objs
        }
        return nil
    }
}
