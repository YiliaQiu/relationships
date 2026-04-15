//
//  ContentViewModel.swift
//  relationships
//
//  Created by QBQ on 2026/4/15.
//

import SwiftUI
import Combine

let allGraphsKey = "AllGraphsData"
class ContentViewModel: ObservableObject {
    @Published var graphList: [GraphItem] = []
    @Published var selectedFilter: GraphCategory?
    @Published var searchText: String = ""
    
    init() {
        loadAllFromDisk()
    }
    
    // 筛选功能
    var filteredGraphs: [GraphItem] {
        graphList.filter { graph in
            // 逻辑 A：检查是否符合分类 (如果没选分类则全过)
            let matchesCategory = selectedFilter == nil || graph.category == selectedFilter
            // 逻辑 B：检查标题是否包含搜索词 (如果搜索框为空则全过)
            // localizedCaseInsensitiveContains 是关键，忽略大小写
            let matchesSearch = searchText.isEmpty || graph.title.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }
    func deleteFromFiltered(at offsets: IndexSet) {
        offsets.forEach { index in
            let itemToDelete = filteredGraphs[index]
            graphList.removeAll { $0.id == itemToDelete.id}
        }
    }
    
    private func loadAllFromDisk() {
        if let data = UserDefaults.standard.data(forKey: allGraphsKey),
           let decoded = try? JSONDecoder().decode([GraphItem].self, from: data) {
            self.graphList = decoded
        } else {
            self.graphList = []
        }
    }
    
    func saveAllToDisk() {
        if graphList.isEmpty {
            return
        }
        if let encoded = try? JSONEncoder().encode(graphList) {
            UserDefaults.standard.set(encoded, forKey: allGraphsKey)
        }
    }
    // 示例数据
    func insertSampleData() {
        // 1. 检查是否已经有数据，如果有则不插入
        guard graphList.isEmpty else { return }
        let nodeA = NodeModel(title: "A", position: .init(x: 100, y: 120))
        let nodeB = NodeModel(title: "B", position: .init(x: 260, y: 280))
        let nodeC = NodeModel(title: "C", position: .init(x: 100, y: 400))
        let nodes = [
            nodeA, nodeB, nodeC
        ]
        let edges = [
            EdgeModel(from: nodeA.id, to: nodeB.id, label: "母子"),
            EdgeModel(from: nodeB.id, to: nodeC.id, label: "CP")
        ]
        graphList.append(GraphItem(title: "我的大家庭", category: .life, nodes: nodes, edges: edges))
        
    }
    
    func copyGraph(_ graph: GraphItem) {
        var clonedGraph = graph
        clonedGraph.id = UUID()
        clonedGraph.title = "\(graph.title) 副本"
        
        if let index = graphList.firstIndex(where: { $0.id == graph.id }) {
            graphList.insert(clonedGraph, at: index + 1)
        } else {
            graphList.append(clonedGraph)
        }
        
        saveAllToDisk()
        // 触感反馈，使用时会有非常轻微的震动
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
