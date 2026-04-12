//
//  GraphViewModel.swift
//  relationships
//
//  Created by QBQ on 2026/4/9.
//  管理数据、处理业务逻辑、提供借口

import Foundation
import SwiftUI
import Combine

struct ArrowGeometry {
    let tip: CGPoint   // 箭头的尖端
    let tail: CGPoint  // 箭头的尾端（或者是连接的目标点）
    let left: CGPoint  // 箭头左翼
    let right: CGPoint // 箭头右翼
}

class GraphViewModel: ObservableObject, Codable {
    private let saveKey = "GraphData"
    @Published var nodes: [NodeModel] = []
    @Published var edges: [EdgeModel] = []
    
    @Published var isConnectingMode = false
    @Published var firstSelectedNodeID: UUID?
    
    var nodePositionVersions: [UUID: Int] = [:]
    init() {
        self.nodes = []
        self.edges = []
        self.firstSelectedNodeID = nil
        self.isConnectingMode = false
        load()
        if nodes.isEmpty {
            let nodeA = NodeModel(title: "A", position: .init(x: 100, y: 120))
            let nodeB = NodeModel(title: "B", position: .init(x: 260, y: 280))
            let nodeC = NodeModel(title: "C", position: .init(x: 100, y: 400))
            nodes.append(nodeA)
            nodes.append(nodeB)
            nodes.append(nodeC)
            edges = [
                EdgeModel(from: nodeA.id, to: nodeB.id, label: "母子"),
                EdgeModel(from: nodeB.id, to: nodeC.id, label: "CP")
            ]
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case nodes, edges
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nodes = try container.decode([NodeModel].self, forKey: .nodes)
        edges = try container.decode([EdgeModel].self, forKey: .edges)
        self.firstSelectedNodeID = nil
        self.isConnectingMode = false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nodes, forKey: .nodes)
        try container.encode(edges, forKey: .edges)
    }

    func updateNodePosition(id: UUID, newPosition: CGPoint) {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            nodes[index].position = newPosition
            nodePositionVersions[id] = (nodePositionVersions[id] ?? 0)+1
        }
    }
    func getNodeVersion(for nodeID: UUID) -> Int {
        nodePositionVersions[nodeID] ?? 0
    }
    
    // add new nodes
    func addNode() {
        let newTitle = "\(nodes.count + 1)"
        let x = CGFloat.random(in: 80...300)
        let y = CGFloat.random(in: 100...500)
        let newNode = NodeModel(title: newTitle, position: CGPoint(x: x, y: y))
        nodes.append(newNode)
        save()
    }
    
    func deleteNode(id: UUID) {
        nodes.removeAll { $0.id == id}
        edges.removeAll { $0.from == id || $0.to == id}
        save()
    }
    
    func updateNodeName(id: UUID, newName: String) {
        guard let index = nodes.firstIndex(where: {$0.id == id}) else { return }
        nodes[index].title = newName
        save()
    }
    
    func updateNodeColor(id: UUID, newColor: Color) {
        guard let index = nodes.firstIndex(where: {$0.id == id}) else { return }
        nodes[index].color = newColor
        save()
    }
    
    func updateEdgeLabel(id: UUID, newLabel: String) {
        guard let index = edges.firstIndex(where: {$0.id == id}) else { return }
        edges[index].label = newLabel
        save()
    }
    
    func connect(from fromID: UUID, to toID: UUID) {
        guard fromID != toID else { return }
        guard !edges.contains(where: { $0.from == fromID && $0.to == toID}) else { return }
        edges.append(EdgeModel(from: fromID, to: toID, label: "连接"))
        save()
    }
    
    func deleteEdge(id: UUID) {
        edges.removeAll { $0.id == id}
        save()
    }
    
    func getConnectionPoints(from fromId: UUID, to toId: UUID) -> (CGPoint, CGPoint)? {
        guard let fromNode = nodes.first(where: {$0.id == fromId}),
              let toNode = nodes.first(where: {$0.id == toId}) else {
            return nil
        }
        return (fromNode.position, toNode.position)
    }
    
    func getMidPoint(from fromId: UUID, to toId: UUID) -> CGPoint? {
        guard let (from, to) = getConnectionPoints(from: fromId, to: toId) else {
            return nil
        }
        return CGPoint(
            x: (from.x + to.x) / 2,
            y: (from.y + to.y) / 2
        )
    }
    
    func getArrowPoints(from fromId: UUID, to toId: UUID, arrowLength: CGFloat = 15) -> ArrowGeometry? {
        guard let (from, to) = getConnectionPoints(from: fromId, to: toId) else {
            return nil
        }
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0 else {
            return nil
        }
        
        let ux = dx / length
        let uy = dy / length
        
        let tip = CGPoint(
            x: to.x - ux * 30,
            y: to.y - uy * 30
        )
        
        let angle = CGFloat.pi / 6
        let left = CGPoint(
            x: tip.x - arrowLength * (ux * cos(angle) + uy * sin(angle)),
            y: tip.y - arrowLength * (uy * cos(angle) - ux * sin(angle))
        )
        let right = CGPoint(
            x: tip.x - arrowLength * (ux * cos(-angle) + uy * sin(-angle)),
            y: tip.y - arrowLength * (uy * cos(-angle) - ux * sin(-angle))
        )
        return ArrowGeometry(tip: tip, tail: to, left: left, right: right)
    }
    
    func save() {
        do {
            let data = try JSONEncoder().encode(self)
            UserDefaults.standard.set(data, forKey: self.saveKey)
        } catch {
            print("保存失败:\(error)")
        }
    }
    
    func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else { return }
        do {
            let vm = try JSONDecoder().decode(GraphViewModel.self, from: data)
            self.nodes = vm.nodes
            self.edges = vm.edges
        } catch {
            print("加载失败：\(error)")
        }
    }
}
