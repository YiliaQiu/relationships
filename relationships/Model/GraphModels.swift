//
//  GraphModels.swift
//  relationships
//
//  Created by QBQ on 2026/4/9.
//  纯数据结构

import SwiftUI

struct NodeModel: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var position: CGPoint
    var color: Color = .green
    
    enum CodingKeys: String, CodingKey {
        case id, title, position, colorComponents
    }
    private struct ColorComponents: Codable {
       let red: Double
       let green: Double
       let blue: Double
       let alpha: Double
   }

    init(id: UUID = UUID(), title: String, position: CGPoint, color: Color = .green) {
        self.id = id
        self.title = title
        self.position = position
        self.color = color
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        position = try container.decode(CGPoint.self, forKey: .position)
        
        let components = try container.decode(ColorComponents.self, forKey: .colorComponents)
        color = Color(
            red: components.red,
            green: components.green,
            blue: components.blue,
            opacity: components.alpha
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(position, forKey: .position)
        
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        let components = ColorComponents(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
        try container.encode(components, forKey: .colorComponents)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
}

struct EdgeModel: Identifiable, Equatable, Codable {
    let id: UUID
    let from: UUID
    let to: UUID
    var label: String
    
    init(id: UUID = UUID(), from: UUID, to: UUID, label: String="标签") {
        self.id = id
        self.from = from
        self.to = to
        self.label = label
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
