//
//  ObjectManager.swift
//
//
//  Created by Dmitriy Virych on 3/20/17.
//  Copyright © 2017 Requestum. All rights reserved.
//

import Foundation

import Alamofire

typealias JSON = [String: Any]
typealias JSONArray = [[String: Any]]

class ObjectManager {
    var sessionManager: SessionManager?
    
    func headers() -> HTTPHeaders {
        
        let headers: HTTPHeaders = [:]
        
        return headers
    }
    
    func request(_ method: HTTPMethod,
                 serverConstant: ServerConstant,
                 parameters: Parameters? = nil,
                 urlParameters: [String: String]? = nil,
                 encoding: ParameterEncoding = JSONEncoding.default) -> DataRequest {
        
        let serverTrustPolicies: [String: ServerTrustPolicy] = [
            "manage.cloudveil.org": ServerTrustPolicy.disableEvaluation
        ]
        
        if self.sessionManager == nil {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 10
            configuration.timeoutIntervalForResource = 10
            self.sessionManager = SessionManager(configuration: configuration,
                serverTrustPolicyManager: ServerTrustPolicyManager(policies: serverTrustPolicies)
            )
        }
        
        let urlString = ServerConstant.serverAPIUrl + serverConstant.rawValue
        
        let url = urlString.replacingURLParameters(urlParameters: urlParameters)
        
        return self.sessionManager!.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers())
    }
}
