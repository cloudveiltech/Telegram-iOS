//
//  SecurityManager.swift
//  SecurityManager
//
//  Created by DimaVirych on 03.03.18.
//  Copyright © 2018 Requestum. All rights reserved.
//

import UIKit

import ObjectMapper
import Alamofire

class SecurityManager: ObjectManager {
    
    // MARK: - Singleton
    
    static let shared = SecurityManager()
    
    
    // MARK: - Actions
    
    func getSettings(withRequest tgRequest: TGSettingsRequest,_ completion: @escaping (TGSettingsResponse?) -> ()) {
        
        let params: Parameters = tgRequest.toJSON()
        print("CloudVeil request: \(params)")
        request(.post, serverConstant: .settings, parameters: params).responseJSON { (response) in
            
            if let json = response.JSON() {
                let resp = Mapper<TGSettingsResponse>().map(JSON: json)
                completion(resp)
            } else {
                completion(nil)
            }
        }
    }
}
