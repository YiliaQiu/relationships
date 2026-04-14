//
//  GraphModels.swift
//  relationships
//
//  Created by QBQ on 2026/4/9.
//  纯数据结构

import Foundation

struct GraphItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var category: GraphCategory
    
    var nodes: [NodeModel] = []
    var edges: [EdgeModel] = []
}
