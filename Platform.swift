//
//  Platform.swift
//  In The Park
//
//  Created by Zac Stewart on 9/22/18.
//  Copyright © 2018 Zac Stewart. All rights reserved.
//

import Foundation

struct Platform {
    
    static var isSimulator: Bool {
        return TARGET_OS_SIMULATOR != 0
    }
    
}
