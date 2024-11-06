//
//  NSAttributedString+Ext.swift
//  PlannerEvo
//
//  Created by Dmitriy Virych on 9/25/17.
//  Copyright © 2017 Requestum. All rights reserved.
//

import UIKit

extension NSAttributedString {
    
    func height(forWidth width: CGFloat) -> CGFloat {
        
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, context: nil)
        
        return ceil(boundingBox.height)
    }
}
