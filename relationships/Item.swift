//
//  Item.swift
//  relationships
//
//  Created by QBQ on 2026/4/9.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
