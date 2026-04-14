//
//  NodeModel.swift
//  relationships
//
//  Created by QBQ on 2026/4/14.
//
import SwiftUI

struct NodeModel: Identifiable, Equatable, Codable {
    var id: UUID
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

    static func == (lhs: NodeModel, rhs: NodeModel) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.position == rhs.position &&
        // 简单比较颜色可以使用 UIColor 的 isEqual
        UIColor(lhs.color).isEqual(UIColor(rhs.color))
    }
}
