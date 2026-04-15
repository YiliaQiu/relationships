//
//  ContentView.swift
//  relationships
//
//  Created by QBQ on 2026/4/12.
//

import SwiftUI
import UIKit

// mainView
struct ContentView: View {
    @StateObject var viewModel = ContentViewModel()
    // 筛选类别
//    @State private var selectedFilter: GraphCategory?
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
//    @State private var searchText = "" // 搜索文本状态
    @State private var isSearchActive = false // 控制搜索框是否展开
    @FocusState private var isSearchFocused: Bool // 用于自动弹出键盘
    
    // 新增
    @State private var isShowingAddAlert = false
    @State private var newGraphTitle = ""

    @State private var selectedCategory: GraphCategory = .life

    var body: some View {
        NavigationStack {
            ZStack {
                mainContentView
            }
            .preferredColorScheme(selectedScheme) // 白天/夜间系统
            //            .navigationTitle("关系图列表")
            .focused($isSearchFocused) // 绑定搜索栏
            .toolbar {
                mainToolbar()
            }
            .sheet(isPresented: $isShowingAddAlert) {
                AddGraphSheet(isShowingAddAlert: $isShowingAddAlert, graphList: $viewModel.graphList)
            }
        }
    }

    private var mainContentView: some View {
        Group {
            if viewModel.graphList.isEmpty {
                // 情况 A：数据库完全为空，显示“欢迎与引导”
                initialGuideView
            } else if viewModel.filteredGraphs.isEmpty {
                // 情况 B：有数据，但当前筛选的分类下没有数据
                noResultView
            } else {
                // 情况 C：正常显示列表
                showAllgraphList
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
                viewModel.insertSampleData() // 调用之前写的插入函数
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // 筛选按钮
    var filterMenu: some View {
        Menu {
            Button("全部显示", systemImage: "line.3.horizontal") {
                viewModel.selectedFilter = nil
            }
            Divider()
            ForEach(GraphCategory.allCases, id: \.id) { cat in
                Button(cat.rawValue, systemImage: "tag") {
                    viewModel.selectedFilter = cat
                }
            }
        } label: {
            // 动态图标：未筛选时用空心，筛选后用实心并变色
            Label("筛选", systemImage: viewModel.selectedFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                .foregroundColor(viewModel.selectedFilter?.accentColor ?? .primary)
        }
    }
    var noResultView: some View {
        ContentUnavailableView {
            // 图标逻辑：搜索时用放大镜，仅筛选时用列表图标
            Label(viewModel.searchText.isEmpty ? "分类下无内容" : "未找到 “\(viewModel.searchText)”",
                  systemImage: viewModel.searchText.isEmpty ? "line.3.horizontal.decrease.circle" : "magnifyingglass")
        } description: {
            // --- 核心修改：根据状态切换描述 ---
            if !viewModel.searchText.isEmpty && viewModel.selectedFilter != nil {
                Text("在“\(viewModel.selectedFilter?.rawValue ?? "")”分类中没找到与“\(viewModel.searchText)”匹配的内容。")
            } else if !viewModel.searchText.isEmpty {
                Text("请检查拼写或尝试其他关键词。")
            } else {
                Text("当前“\(viewModel.selectedFilter?.rawValue ?? "")”分类下还没有关系图。")
            }
        } actions: {
            Button("清除搜索与过滤") {
                withAnimation {
                    viewModel.searchText = ""
                    viewModel.selectedFilter = nil
                }
            }
            .buttonStyle(.bordered)
        }
    }
    var showAllgraphList: some View {
        List {
            ForEach(viewModel.filteredGraphs) { graph in
                NavigationLink {
                    RelationshipGraphView(vm: GraphViewModel(nodes: graph.nodes, edges: graph.edges)) { newNodes, newEdges in
                        if let index = viewModel.graphList.firstIndex(where: { $0.id == graph.id }) {
                            viewModel.graphList[index].nodes = newNodes
                            viewModel.graphList[index].edges = newEdges
                            viewModel.saveAllToDisk()
                        }
                    }
                    .navigationTitle(graph.title)
                    .navigationBarTitleDisplayMode(.inline)
                } label: {
                    GraphRowView(graph: graph)
                }
            }
            .onDelete { indexSet in
                viewModel.deleteFromFiltered(at: indexSet)
                viewModel.saveAllToDisk()
            }
        }
    }

    var searchView: some View {
        // 搜索栏展开状态：显示输入框和取消按钮
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.footnote)
            TextField("搜索...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .frame(width: 150) // 限制宽度，防止挤掉加号
                .focused($isSearchFocused)
            Button(
                action: {
                    withAnimation {
                        isSearchActive = false
                        viewModel.searchText = ""
                    }
                },
                label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct GraphRowView: View {
    let graph: GraphItem

    var body: some View {
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
                    Text("\(graph.nodes.count) 人")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

extension ContentView {
    @ToolbarContentBuilder
    func mainToolbar() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            leadingToolbarItems
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            trailingToolbarItems
        }
    }
    
    private var leadingToolbarItems: some View {
        HStack {
            if !isSearchActive {
                filterMenu
            }
            appearancePicker // 添加切换按钮（白天/夜间/跟随系统）
        }
    }
    private var trailingToolbarItems: some View {
        if isSearchActive {
            AnyView(searchView)
        } else {
            AnyView(HStack {
                Button("多选", systemImage: "checkmark.circle") {
                    //   TODO
                }
                Button(
                    action: {
                        withAnimation(.spring()) {
                            isSearchActive = true
                            isSearchFocused = true // 自动点亮键盘
                        }
                    },
                    label: {
                        Image(systemName: "magnifyingglass")
                    }
                )
                Menu {
                    Button(
                        action: {
                            isShowingAddAlert = true
                        },
                        label: {
                            Text("新建")
                            Image(systemName: "plus")
                        }
                    )
                    Button(
                        action: {
//                                    TODO: 导入解析
//                                    isShowingImportPicker = true
                        }, label: {
                            Text("导入")
                            Image(systemName: "square.and.arrow.down")
                        }
                    )
                } label: {
                    Image(systemName: "plus")
                }
            })
        }
    }
}

struct AddGraphSheet: View {
    @Binding var isShowingAddAlert: Bool
    @Binding var graphList: [GraphItem]
    @State private var newGraphTitle = ""
    @State private var selectedCategory: GraphCategory = .life
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("图表名称", text: $newGraphTitle)
                    Picker("选择分类", selection: $selectedCategory) {
                        ForEach(GraphCategory.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isShowingAddAlert = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        graphList.append(GraphItem(title: newGraphTitle, category: selectedCategory))
                        isShowingAddAlert = false
                    }
                }
            }
        }
        .presentationDetents([.medium]) // 半屏显示
    }
}

#Preview {
    ContentView()
}
