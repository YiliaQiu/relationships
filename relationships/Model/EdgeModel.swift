//
//  EdgeModel.swift
//  relationships
//
//  Created by QBQ on 2026/4/14.
//

import SwiftUI

struct EdgeModel: Identifiable, Equatable, Codable {
    var id: UUID
    var from: UUID
    var to: UUID
    var label: String
    
    init(id: UUID = UUID(), from: UUID, to: UUID, label: String="标签") {
        self.id = id
        self.from = from
        self.to = to
        self.label = label
    }

    static func == (lhs: EdgeModel, rhs: EdgeModel) -> Bool {
        lhs.id == rhs.id &&
        lhs.from == rhs.from &&
        lhs.to == rhs.to &&
        lhs.label == rhs.label
    }
}
