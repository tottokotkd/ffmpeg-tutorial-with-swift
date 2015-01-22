//
//  extensions.swift
//  Tutorials
//
//  Created by Tokuda Shusuke on 2015/01/22.
//  Copyright (c) 2015年 Tokuda Shusuke. All rights reserved.
//

import Foundation

extension Bool {
    var c: Int32 {
        return self ? 1 : 0
    }
}

extension Int32 {
    var bool: Bool {
        return self != 0 ? true : false
    }
}
