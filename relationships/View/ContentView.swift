//
//  ContentView.swift
//  relationships
//
//  Created by QBQ on 2026/4/12.
//

import SwiftUI
import UIKit

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

// mainViewList
struct GraphItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var category: GraphCategory
    
    var nodes: [NodeModel] = []
    var edges: [EdgeModel] = []
}

// mainView
struct ContentView: View {
    // 示例列表数据
    @State private var graphList: [GraphItem] = [
        GraphItem(title: "人物关系图", category: .life)
//        GraphItem(title: "知识结构图", category: .study),
//        GraphItem(title: "项目流程图", category: .work),
//        GraphItem(title: "自定义关系图", category: .other)
    ]
    
    // 筛选类别
    @State private var selectedFilter: GraphCategory?
    @State private var filterCategory: GraphCategory?
    
    // 跟随系统/白天模式/夜间模式
    @AppStorage("appearanceSelection") private var appearanceSelection = 0
    var selectedScheme: ColorScheme? {
        if appearanceSelection == 1 {
            return .light
        }
        if appearanceSelection == 2 {
            return .dark
        }
        return nil // 跟随系统
    }
    var appearancePicker: some View {
        Menu {
            Button {
                appearanceSelection = 1
            } label: {
                Label("浅色模式", systemImage: "sun.max")
            }
            Button {
                appearanceSelection = 2
            } label: {
                Label("深色模式", systemImage: "moon")
            }
            Button {
                appearanceSelection = 0
            } label: {
                Label("跟随系统", systemImage: "desktopcomputer")
            }
        } label: {
            // 根据当前选择显示图标
            Image(systemName: appearanceSelection == 2 ? "moon.fill" : "sun.max.fill")
        }
    }
    
    // 搜索
    @State private var searchText = "" // 搜索文本状态
    @State private var isSearchActive = false // 控制搜索框是否展开
    @FocusState private var isSearchFocused: Bool // 用于自动弹出键盘
    
    init() {
        if let data = UserDefaults.standard.data(forKey: "AllGraphList"),
           let decoded = try? JSONDecoder().decode([GraphItem].self, from: data) {
            _graphList = State(initialValue: decoded)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Group {
                    if graphList.isEmpty {
                        // 情况 A：数据库完全为空，显示“欢迎与引导”
//                        initialGuideView
                    } else if filteredGraphs.isEmpty {
                        // 情况 B：有数据，但当前筛选的分类下没有数据
                        noResultView
                    } else {
                        // 情况 C：正常显示列表
                        showAllgraphList
                    }
                }
            }
            .preferredColorScheme(selectedScheme) // 白天/夜间系统
//            .navigationTitle("关系图列表")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
                        if !isSearchActive {
                            filterMenu
                        }
                        appearancePicker // 添加切换按钮（白天/夜间/跟随系统）
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button("多选", systemImage: "checkmark.circle") {
//                            TODO
                        }
                        Button("查询", systemImage: "magnifyingglass") {
//                            TODO
                        }
                        Button("新增", systemImage: "plus") {
                            graphList.append(GraphItem(title: "新关系图\(graphList.count + 1)", category: .other))
                        }
                    }
                }
            }
        }
    }
    
    // 用户引导
    var initialGuideView: some View {
        ContentUnavailableView {
            Label("开启你的社交图谱", systemImage: "network")
        } description: {
            Text("目前还没有任何关系图。您可以点击下方按钮载入示例，或者点击右上角自行创建。")
        } actions: {
            Button("载入示例数据") {
                insertSampleData() // 调用之前写的插入函数
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // 示例数据
    private func insertSampleData() {
        // 1. 检查是否已经有数据，如果有则不插入
        guard graphList.isEmpty else { return }
        
    }
    
    // 筛选按钮
    var filterMenu: some View {
        Menu {
            Button("全部显示", systemImage: "line.3.horizontal") {
                selectedFilter = nil
            }
            Divider()
            ForEach(GraphCategory.allCases, id: \.id) { cat in
                Button(cat.rawValue, systemImage: "tag") {
                    selectedFilter = cat
                }
            }
        } label: {
            // 动态图标：未筛选时用空心，筛选后用实心并变色
            Label("筛选", systemImage: selectedFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                .foregroundColor(selectedFilter?.accentColor ?? .primary)
        }
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
    var noResultView: some View {
        ContentUnavailableView {
            // 图标逻辑：搜索时用放大镜，仅筛选时用列表图标
            Label(searchText.isEmpty ? "分类下无内容" : "未找到 “\(searchText)”",
                  systemImage: searchText.isEmpty ? "line.3.horizontal.decrease.circle" : "magnifyingglass")
        } description: {
            // --- 核心修改：根据状态切换描述 ---
            if !searchText.isEmpty && selectedFilter != nil {
                Text("在“\(selectedFilter?.rawValue ?? "")”分类中没找到与“\(searchText)”匹配的内容。")
            } else if !searchText.isEmpty {
                Text("请检查拼写或尝试其他关键词。")
            } else {
                Text("当前“\(selectedFilter?.rawValue ?? "")”分类下还没有关系图。")
            }
        } actions: {
            Button("清除搜索与过滤") {
                withAnimation {
                    searchText = ""
                    selectedFilter = nil
                }
            }
            .buttonStyle(.bordered)
        }
    }
    var showAllgraphList: some View {
        List {
            ForEach(filteredGraphs) { graph in
                NavigationLink {
                    RelationshipGraphView(vm: GraphViewModel(nodes: graph.nodes, edges: graph.edges)) { newNodes, newEdges in
                        if let index = graphList.firstIndex(where: { $0.id == graph.id }) {
                            graphList[index].nodes = newNodes
                            graphList[index].edges = newEdges
                            saveAllToDisk()
                        }
                    }
                    .navigationTitle(graph.title)
                    .navigationBarTitleDisplayMode(.inline)
                } label: {
                    HStack(spacing: 15) {
                        // 左侧分类色块
                        RoundedRectangle(cornerRadius: 4)
                            .fill(graph.category.accentColor)
                            .frame(width: 4)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(graph.title)
                                    .font(.headline)
                                    .padding(.leading, 8)
                                Text(graph.category.rawValue)
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(graph.category.accentColor.opacity(0.1))
                                    .foregroundColor(graph.category.accentColor)
                                    .clipShape(Capsule())
//                                Text("\(graph.nodes.count) 人")
//                                    .font(.caption2)
//                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: deleteFromFiltered)
        }
    }
    func deleteFromFiltered(at offsets: IndexSet) {
        if let index = offsets.first {
            let itemToDelete = filteredGraphs[index]
            graphList.removeAll { $0.id == itemToDelete.id}
        }
    }
    func saveAllToDisk() {
        if let encoded = try? JSONEncoder().encode(graphList) {
            UserDefaults.standard.set(encoded, forKey: "AllGraphsList")
        }
    }
}

#Preview {
    ContentView()
}
