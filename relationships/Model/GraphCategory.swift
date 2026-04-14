//
//  GraphCategory.swift
//  relationships
//
//  Created by QBQ on 2026/4/14.
//

import SwiftUI

enum GraphCategory: String, CaseIterable, Identifiable, Codable {
    case work = "工作"
    case life = "生活"
    case study = "学习"
    case secret = "私密"
    case other = "其他"
    
    var id: String { self.rawValue }
    
    // 为不同分类设置默认颜色
    var accentColor: Color {
        switch self {
        case .life: return .green
        case .work: return .blue
        case .secret: return .purple
        case .study: return .red
        case .other: return .gray
        }
    }
}
