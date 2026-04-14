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
    @Published var nodes: [NodeModel]
    @Published var edges: [EdgeModel]
    
    @Published var isConnectingMode = false
    @Published var firstSelectedNodeID: UUID?
    
    @Published var undoHistory: [UndoSnapshot] = []
    @Published var isDraggingNode = false

    var nodePositionVersions: [UUID: Int] = [:]
    
    init(nodes: [NodeModel] = [], edges: [EdgeModel] = []) {
        self.nodes = nodes
        self.edges = edges
        self.firstSelectedNodeID = nil
        self.isConnectingMode = false
        self.isDraggingNode = false
        self.undoHistory = []
        self.nodePositionVersions = [:]
    }
    enum CodingKeys: String, CodingKey {
        case nodes, edges
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.nodes = try container.decode([NodeModel].self, forKey: .nodes)
        self.edges = try container.decode([EdgeModel].self, forKey: .edges)
        
        // 不参与codable的属性
        self.firstSelectedNodeID = nil
        self.isConnectingMode = false
        self.isDraggingNode = false
        self.undoHistory = []
        self.nodePositionVersions = [:]
    }
    struct UndoSnapshot: Codable {
        let nodes: [NodeModel]
        let edges: [EdgeModel]
        
        init(nodes: [NodeModel], edges: [EdgeModel]) {
            self.nodes = nodes.map {
                NodeModel(
                    id: $0.id,
                    title: $0.title,
                    position: $0.position,
                    color: $0.color
                )
            }
            self.edges = edges.map {
                EdgeModel(
                    id: $0.id,
                    from: $0.from,
                    to: $0.to,
                    label: $0.label
                )
            }
        }
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
        saveSnapshot()
        let newTitle = "\(nodes.count + 1)"
        let x = CGFloat.random(in: 80...300)
        let y = CGFloat.random(in: 100...500)
        let newNode = NodeModel(title: newTitle, position: CGPoint(x: x, y: y))
        nodes.append(newNode)
    }
    
    func deleteNode(id: UUID) {
        saveSnapshot()
        nodes.removeAll { $0.id == id}
        edges.removeAll { $0.from == id || $0.to == id}
    }
    
    func updateNodeName(id: UUID, newName: String) {
        saveSnapshot()
        guard let index = nodes.firstIndex(where: {$0.id == id}) else { return }
        nodes[index].title = newName
    }
    
    func updateNodeColor(id: UUID, newColor: Color) {
        saveSnapshot()
        guard let index = nodes.firstIndex(where: {$0.id == id}) else { return }
        nodes[index].color = newColor
    }
    
    func updateEdgeLabel(id: UUID, newLabel: String) {
        saveSnapshot()
        guard let index = edges.firstIndex(where: {$0.id == id}) else { return }
        edges[index].label = newLabel
    }
    
    func connect(from fromID: UUID, to toID: UUID) {
        saveSnapshot()
        guard fromID != toID else { return }
        guard !edges.contains(where: { $0.from == fromID && $0.to == toID}) else { return }
        edges.append(EdgeModel(from: fromID, to: toID, label: "连接"))
    }
    
    func deleteEdge(id: UUID) {
        saveSnapshot()
        edges.removeAll { $0.id == id}
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
    
    func clearAll() {
        saveSnapshot()
        nodes.removeAll()
        edges.removeAll()
        firstSelectedNodeID = nil
        isConnectingMode = false
    }
    
    func saveInitSnapShot() {
        guard undoHistory.isEmpty else { return }
        let snapshot = UndoSnapshot(nodes: nodes, edges: edges)
        undoHistory.append(snapshot)
    }
    
    func saveSnapshot() {
        guard !isDraggingNode else { return }
        let snapshot = UndoSnapshot(nodes: nodes, edges: edges)
        undoHistory.append(snapshot)
        // 最多存20步
        if undoHistory.count > 20 {
            undoHistory.removeFirst()
        }
    }
    func undo() {
        guard !undoHistory.isEmpty else {
            return
        }
        let last = undoHistory.removeLast()
        
        // 先清空，强制线条回位
        nodes.removeAll()
        edges.removeAll()
        
        nodes = last.nodes
        edges = last.edges
        firstSelectedNodeID = nil
//        isConnectingMode = false
        
        objectWillChange.send() // 强制重绘连线
    }
    
    func finishedDragAndSaveSnapshot() {
        isDraggingNode = false
        saveSnapshot()
    }
}
