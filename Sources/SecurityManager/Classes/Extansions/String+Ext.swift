//
//  String+Ext.swift
//
//
//  Created by Dmitriy Virych on 4/5/17.
//  Copyright © 2017 Requestum. All rights reserved.
//

import UIKit


/// String stuct extension
extension String {
    
    
    /// Makes string localized.
    func localized() -> String {
        return NSLocalizedString(self, comment: "")
    }
}


extension String {
    
    func atributedText(characterSpace: Float) -> NSAttributedString {
        return NSAttributedString(string: self, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13), NSAttributedString.Key.kern: characterSpace as AnyObject])
    }
    
    func replacingURLParameters(urlParameters: [String: String]?) -> String {
        
        guard urlParameters != nil else {
            return self
        }
        
        var string = self
        for (param, value) in urlParameters! {
            let stringToReplace = ":" + param
            if string.contains(stringToReplace) {
                string = string.replacingOccurrences(of: stringToReplace, with: value)
            }
        }
        
        return string
    }
}


extension String {
    
    func capitalizingFirstLetter() -> String {
        
        let first = String(self.first!).capitalized
        let other = self.dropFirst()
        
        return first + other
    }
}


extension String {
    
    func width(withFont font: UIFont) -> CGFloat {
        
        let fontAttributes = [NSAttributedString.Key.font : font]
        return (self as NSString).size(withAttributes: fontAttributes).width
    }
}


extension String {
    
    func base64Encoded() -> String? {
        
        if let data = self.data(using: .utf8) {
            return data.base64EncodedString()
        }
        
        return nil
    }
    
    func base64Decoded() -> String? {
        
        if let data = Data(base64Encoded: self) {
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
    
    func getIdFromReferralLink() -> Int? {
        
        let base64 = self.replacingOccurrences(of: "projectevo://", with: "")
        let str = base64.base64Decoded()
        if let idStr = str?.replacingOccurrences(of: "projectevo", with: "") { return Int(idStr) }
        
        return nil
    }
}
