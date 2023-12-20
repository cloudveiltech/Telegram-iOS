//
//  NSError+Ext.swift
//  
//
//  Created by Dmitriy Virych on 9/21/15.
//  Copyright © 2015 . All rights reserved.
//

import Foundation
import CFNetwork
import Alamofire

let kServerURLResponse = "kServerURLResponse"
let kServerResponseData = "kServerResponseData"

extension NSError {
    
    var poorConectionError: Bool {
        
        let codes: Array = [ CFNetworkErrors.cfurlErrorCancelled.rawValue, CFNetworkErrors.cfurlErrorTimedOut.rawValue, CFNetworkErrors.cfurlErrorCancelled.rawValue, CFNetworkErrors.cfurlErrorCannotFindHost.rawValue, CFNetworkErrors.cfurlErrorCannotConnectToHost.rawValue, CFNetworkErrors.cfurlErrorNetworkConnectionLost.rawValue, CFNetworkErrors.cfurlErrorDNSLookupFailed.rawValue, CFNetworkErrors.cfurlErrorResourceUnavailable.rawValue, CFNetworkErrors.cfurlErrorNotConnectedToInternet.rawValue ]
        
        return codes.contains(Int32(self.code))
    }
    
    var hostUnavailableError: Bool {
        
        let codes: Array = [ CFNetworkErrors.cfurlErrorTimedOut.rawValue, CFNetworkErrors.cfurlErrorCannotFindHost.rawValue, CFNetworkErrors.cfurlErrorCannotConnectToHost.rawValue, CFNetworkErrors.cfurlErrorResourceUnavailable.rawValue ]
        
        return codes.contains(Int32(self.code))
    }
    
    var HTTPResponseCode: Int? {
        return (userInfo[kServerURLResponse] as? HTTPURLResponse)?.statusCode
    }
    
    var responseErrorDescription: String? {
        
        if let data = userInfo[kServerResponseData] as? Data {
            do {
                if let JSON = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    var errorString = JSON["error"] as? String
                    if errorString == nil {
                        errorString = JSON["message"] as? String
                    }
                    return errorString
                }
            }
            catch (let error) {
                print(error)
            }
        }
        return nil
    }
    
    func with<T: Any>(dataResponse: DataResponse<T>) -> NSError {
        
        var newUserInfo = userInfo
        if let urlResponse = dataResponse.response {
            newUserInfo[kServerURLResponse] = urlResponse
        }
        if let serverData = dataResponse.data {
            newUserInfo[kServerResponseData] = serverData
        }
        return NSError(domain: domain, code: code, userInfo: newUserInfo)
    }
    
    var message: String? {
        
        return (userInfo[NSLocalizedRecoverySuggestionErrorKey] as? String) ?? userInfo[NSLocalizedDescriptionKey] as? String
    }
}


// MARK: Custom

extension NSError {
    
    static func appError(withDescription description: String, code: Int = 0) -> NSError {
        return NSError(domain: "", code: code, userInfo: [NSLocalizedDescriptionKey: description])
    }
    
    static func appError(withResponseData data: Data, code: Int = 0) -> NSError {
        return NSError(domain: "", code: code, userInfo: [kServerResponseData: data])
    }
}
